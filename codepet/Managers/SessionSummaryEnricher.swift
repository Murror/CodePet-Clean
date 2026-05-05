import Foundation
import Combine
import os

/// Triggers session-level summarization. Decides which sessions need
/// summarizing based on:
///   - explicit SessionEnd signal (immediate), OR
///   - idle ≥ idleThreshold (default 30 min) since last activity
@MainActor
final class SessionSummaryEnricher: ObservableObject {

    let objectWillChange = PassthroughSubject<Void, Never>()

    private let api: ReflectionAPIClientProtocol
    private let store: SessionSummaryStore
    private let language: String
    private let idleThreshold: TimeInterval
    private var inFlight: Set<String> = []
    private let logger = Logger(subsystem: "app.murror.codepet", category: "SessionSummaryEnricher")

    init(
        api: ReflectionAPIClientProtocol,
        store: SessionSummaryStore,
        language: String,
        idleThreshold: TimeInterval = 30 * 60
    ) {
        self.api = api
        self.store = store
        self.language = language
        self.idleThreshold = idleThreshold
    }

    /// Returns true if a session should be auto-summarized:
    ///   - it has at least 1 turn with a closed (ended) state
    ///   - it has no summary yet
    ///   - either it's in endedSessionIds, OR last activity was > idleThreshold ago
    func shouldAutoSummarize(
        session: Session,
        endedSessionIds: Set<String>,
        now: Date = Date()
    ) -> Bool {
        guard session.summary == nil else { return false }
        guard session.turns.contains(where: { $0.endedAt != nil }) else { return false }
        if endedSessionIds.contains(session.id) { return true }
        let lastActivity = session.turns.compactMap { $0.endedAt ?? $0.startedAt }.max() ?? session.startedAt
        return now.timeIntervalSince(lastActivity) > idleThreshold
    }

    /// Trigger summarization for a session. Idempotent — won't re-fire if in-flight.
    @discardableResult
    func enrich(session: Session, petPersona: SummarizeTurnRequest.PetPersonaDTO? = nil) async -> Bool {
        guard !inFlight.contains(session.id) else { return false }
        inFlight.insert(session.id)
        defer { inFlight.remove(session.id) }

        let request = makeRequest(for: session, persona: petPersona)
        do {
            let response = try await api.summarizeSession(request)
            let summary = SessionSummary(
                sessionId: session.id,
                summary: response.summary.summary,
                lesson: response.summary.lesson,
                generatedAt: Date(),
                model: response.model,
                schemaVersion: 1
            )
            do {
                try store.appendSummary(summary)
            } catch {
                logger.error("failed to persist session summary: \(error.localizedDescription)")
            }
            return true
        } catch {
            logger.warning("session enrichment failed for \(session.id): \(String(describing: error))")
            return false
        }
    }

    private func makeRequest(
        for session: Session,
        persona: SummarizeTurnRequest.PetPersonaDTO?
    ) -> SummarizeSessionRequest {
        let turns = session.turns.map { turn -> SummarizeSessionRequest.TurnDTO in
            let durMin: Int? = {
                guard let ended = turn.endedAt else { return nil }
                return max(1, Int(ended.timeIntervalSince(turn.startedAt) / 60))
            }()
            return SummarizeSessionRequest.TurnDTO(
                prompt: turn.prompt,
                whatYouWanted: turn.narrative?.whatYouWanted,
                whatHappened: turn.narrative?.whatHappened,
                durationMinutes: durMin
            )
        }
        return SummarizeSessionRequest(
            sessionId: session.id,
            language: language,
            turns: turns,
            petPersona: persona
        )
    }
}
