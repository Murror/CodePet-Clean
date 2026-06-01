import Foundation
import Combine
import os

/// Serial enrichment worker. Calls Cloud Function for each turn and writes
/// the narrative back to NarrativeStore. Retries network failures once.
@MainActor
final class NarrativeEnricher: ObservableObject {

    /// Turn IDs whose most recent enrichment attempt failed. Reactive — the
    /// reflection UI reads this through `@EnvironmentObject` and threads it
    /// into `TurnAssembler` so failed turns render the failure UI instead of
    /// being permanently stuck on the "summarizing" skeleton.
    @Published private(set) var failedTurns: [String: FailureReason] = [:]

    /// Turn IDs currently being enriched via streaming. The UI observes this
    /// to show "Generating story…" immediately when the SSE connection opens,
    /// replacing the ~8s blank wait.
    @Published private(set) var enrichingTurns: Set<String> = []

    private let api: ReflectionAPIClientProtocol
    private let store: NarrativeStore
    var language: String
    private let retryDelay: TimeInterval
    private var inFlight: [String: Task<TurnState, Never>] = [:]
    private let logger = Logger(subsystem: "app.murror.codepet", category: "NarrativeEnricher")

    init(
        api: ReflectionAPIClientProtocol,
        store: NarrativeStore,
        language: String,
        retryDelay: TimeInterval = 10
    ) {
        self.api = api
        self.store = store
        self.language = language
        self.retryDelay = retryDelay
    }

    /// Enrich a single turn. Awaits completion. If a turn with the same id is
    /// already in flight, returns the same task's result.
    /// `petPersona` is optional — when provided, Claude will mirror the
    /// pet's personality and domain in the narrative voice.
    @discardableResult
    func enrich(
        turn: Turn,
        petPersona: SummarizeTurnRequest.PetPersonaDTO? = nil
    ) async -> TurnState {
        // Skip turns with no write operations — these are "check-in" turns
        // where the user only ran read-only commands (git status, ls) or got
        // a text-only reply. No file edits means nothing meaningful to narrate.
        guard turn.hasWriteEvents else {
            logger.info("skipping read-only turn (no write events): \(turn.id)")
            return .ready
        }

        if let existing = inFlight[turn.id] {
            return await existing.value
        }
        let task = Task<TurnState, Never> { [weak self] in
            guard let self else { return .failed(reason: .unknown) }
            return await self.runEnrich(turn: turn, petPersona: petPersona)
        }
        inFlight[turn.id] = task
        let result = await task.value
        inFlight[turn.id] = nil
        return result
    }

    private func runEnrich(
        turn: Turn,
        petPersona: SummarizeTurnRequest.PetPersonaDTO?
    ) async -> TurnState {
        // Clear any prior failure for this turn so the UI flips back to the
        // summarizing skeleton during the new attempt.
        failedTurns.removeValue(forKey: turn.id)

        let request = makeRequest(for: turn, petPersona: petPersona)
        for attempt in 0...1 {
            do {
                let narrative = try await streamEnrich(turnId: turn.id, sessionId: turn.sessionId, request: request)
                do {
                    try store.appendNarrative(turnId: turn.id, sessionId: turn.sessionId, language: language, narrative: narrative)
                } catch {
                    logger.error("failed to persist narrative: turn=\(turn.id) error=\(error.localizedDescription)")
                }
                return .ready
            } catch let err as ReflectionAPIError {
                switch err {
                case .notSignedIn, .http(401, _):
                    return recordFailure(turn.id, reason: .auth, error: err)
                case .http(429, _):
                    return recordFailure(turn.id, reason: .quota, error: err)
                case .http(400, _), .malformedResponse:
                    return recordFailure(turn.id, reason: .badResponse, error: err)
                case .http, .network:
                    if attempt == 0 {
                        logger.warning("turn enrich transient error, retrying: turn=\(turn.id) error=\(String(describing: err))")
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }
                    return recordFailure(turn.id, reason: .network, error: err)
                }
            } catch {
                if attempt == 0 {
                    logger.warning("turn enrich unexpected error, retrying: turn=\(turn.id) error=\(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                return recordFailure(turn.id, reason: .unknown, error: error)
            }
        }
        return recordFailure(turn.id, reason: .unknown, error: nil)
    }

    /// Stream-based enrichment. Opens SSE connection, publishes enrichingTurns
    /// immediately so the UI can show "Generating story…", then returns the
    /// complete Narrative when done.
    private func streamEnrich(
        turnId: String,
        sessionId: String,
        request: SummarizeTurnRequest
    ) async throws -> Narrative {
        let stream = api.summarizeTurnStream(request)
        var narrativePayload: SummarizeTurnResponse.NarrativePayload?
        var model = ""

        for try await event in stream {
            switch event {
            case .started:
                enrichingTurns.insert(turnId)
            case .jsonDelta:
                // JSON deltas accumulate server-side; we just need to stay
                // connected. The UI already shows "generating" via enrichingTurns.
                break
            case .done(let payload, let m, _):
                narrativePayload = payload
                model = m
            }
        }

        enrichingTurns.remove(turnId)

        guard let payload = narrativePayload else {
            throw ReflectionAPIError.malformedResponse
        }

        return Narrative(
            title: payload.title,
            whatYouWanted: payload.whatYouWanted,
            whatHappened: payload.whatHappened,
            lesson: payload.lesson,
            nextSteps: payload.nextSteps ?? "",
            mood: payload.mood ?? "idle",
            model: model,
            generatedAt: Date(),
            schemaVersion: 1
        )
    }

    private func recordFailure(_ turnId: String, reason: FailureReason, error: Error?) -> TurnState {
        let detail = error.map { String(describing: $0) } ?? "no_error"
        logger.error("turn enrich failed: turn=\(turnId) reason=\(reason.rawValue) error=\(detail)")
        print("[NarrativeEnricher] ✗ turn=\(turnId) reason=\(reason.rawValue) error=\(detail)")
        enrichingTurns.remove(turnId)
        failedTurns[turnId] = reason
        return .failed(reason: reason)
    }

    private func makeRequest(
        for turn: Turn,
        petPersona: SummarizeTurnRequest.PetPersonaDTO?
    ) -> SummarizeTurnRequest {
        let events = turn.rawEvents.map {
            SummarizeTurnRequest.EventDTO(
                time: $0.time,
                tool: extractTool(from: $0.text),
                path: extractPath(from: $0.text),
                text: $0.text
            )
        }
        let rawSummary = events.map { "\($0.tool) \($0.path ?? $0.text ?? "")" }.joined(separator: " · ")
        let projectPath = turn.rawEvents.compactMap(\.cwd).first
        return SummarizeTurnRequest(
            turnId: turn.id,
            sessionId: turn.sessionId,
            language: language,
            prompt: turn.prompt,
            events: events,
            rawSummary: rawSummary,
            petPersona: petPersona,
            userBrief: Self.currentUserBrief(projectPath: projectPath),
            petMemory: PetMemoryStore.shared.promptPayload(for: projectPath)
        )
    }

    /// Read the user's project brief. Checks per-project brief first (via
    /// ProjectStore), then falls back to the global welcome-screen brief.
    /// Returns nil when the brief is unset or whitespace-only so the wire
    /// payload omits the field instead of sending an empty string.
    static func currentUserBrief(projectPath: String? = nil) -> String? {
        // Try per-project brief first
        if let path = projectPath {
            let key = "cp_detected_projects"
            if let data = UserDefaults.standard.data(forKey: key),
               let projects = try? JSONDecoder().decode([String: Project].self, from: data),
               let project = projects[path] {
                let trimmed = project.brief.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        // Fall back to global brief
        let raw = UserDefaults.standard.string(forKey: "cp_user_project_brief") ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func extractTool(from text: String) -> String {
        // text is like "Edit ReflectionTab.swift" or "Bash: git commit"
        if text.hasPrefix("Bash:") { return "Bash" }
        return text.components(separatedBy: " ").first ?? text
    }

    private func extractPath(from text: String) -> String? {
        let parts = text.components(separatedBy: " ")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: " ")
    }
}
