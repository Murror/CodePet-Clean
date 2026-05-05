import Foundation
import Combine
import os

/// Serial enrichment worker. Calls Cloud Function for each turn and writes
/// the narrative back to NarrativeStore. Retries network failures once.
@MainActor
final class NarrativeEnricher: ObservableObject {

    let objectWillChange = PassthroughSubject<Void, Never>()

    private let api: ReflectionAPIClientProtocol
    private let store: NarrativeStore
    private let language: String
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
        let request = makeRequest(for: turn, petPersona: petPersona)
        for attempt in 0...1 {
            do {
                let response = try await api.summarizeTurn(request)
                let n = Narrative(
                    title: response.narrative.title,
                    whatYouWanted: response.narrative.whatYouWanted,
                    whatHappened: response.narrative.whatHappened,
                    lesson: response.narrative.lesson,
                    model: response.model,
                    generatedAt: Date(),
                    schemaVersion: 1
                )
                do {
                    try store.appendNarrative(turnId: turn.id, sessionId: turn.sessionId, narrative: n)
                } catch {
                    logger.error("failed to persist narrative: \(error.localizedDescription)")
                }
                return .ready
            } catch let err as ReflectionAPIError {
                switch err {
                case .notSignedIn, .http(401, _):
                    return .failed(reason: .auth)
                case .http(429, _):
                    return .failed(reason: .quota)
                case .http(400, _), .malformedResponse:
                    return .failed(reason: .badResponse)
                case .http, .network:
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }
                    return .failed(reason: .network)
                }
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                return .failed(reason: .unknown)
            }
        }
        return .failed(reason: .unknown)
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
        return SummarizeTurnRequest(
            turnId: turn.id,
            sessionId: turn.sessionId,
            language: language,
            prompt: turn.prompt,
            events: events,
            rawSummary: rawSummary,
            petPersona: petPersona
        )
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
