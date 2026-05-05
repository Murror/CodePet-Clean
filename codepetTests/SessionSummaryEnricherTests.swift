import XCTest
@testable import codepet

// MARK: - Mock session API client

final class MockSessionAPIClient: ReflectionAPIClientProtocol {
    var sessionSummaryCalls: [SummarizeSessionRequest] = []
    var sessionError: Error?

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        // Not used in session enricher tests
        return SummarizeTurnResponse(
            turnId: request.turnId,
            narrative: .init(title: "T", whatYouWanted: "w", whatHappened: "h", lesson: "l"),
            model: "claude-haiku-4-5-20251001",
            cacheHit: false
        )
    }

    func summarizeSession(_ request: SummarizeSessionRequest) async throws -> SummarizeSessionResponse {
        sessionSummaryCalls.append(request)
        if let error = sessionError { throw error }
        return SummarizeSessionResponse(
            sessionId: request.sessionId,
            summary: .init(summary: "Test arc summary", lesson: "Test lesson"),
            model: "claude-haiku-4-5-20251001"
        )
    }
}

// MARK: - Tests

@MainActor
final class SessionSummaryEnricherTests: XCTestCase {
    private var tmpURL: URL!
    private var store: SessionSummaryStore!
    private var api: MockSessionAPIClient!
    private var enricher: SessionSummaryEnricher!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-enricher-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tmpURL = dir.appendingPathComponent("session_summaries.jsonl")
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        store = SessionSummaryStore(fileURL: tmpURL, pollInterval: 0.1)
        store.start()
        api = MockSessionAPIClient()
        enricher = SessionSummaryEnricher(api: api, store: store, language: "vi", idleThreshold: 30 * 60)
    }

    override func tearDown() async throws {
        store.stop()
        enricher = nil
        api = nil
        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }

    // MARK: - Helpers

    private func makeSession(
        id: String = "s1",
        turnEndedAt: Date? = Date().addingTimeInterval(-60),
        summary: SessionSummary? = nil
    ) -> Session {
        let turn = Turn(
            id: "\(id):prompt",
            sessionId: id,
            startedAt: (turnEndedAt ?? Date()).addingTimeInterval(-120),
            endedAt: turnEndedAt,
            prompt: "do the thing",
            rawEvents: [],
            narrative: nil,
            state: .ready
        )
        return Session(
            id: id,
            turns: [turn],
            startedAt: turn.startedAt,
            endedAt: turnEndedAt,
            summary: summary
        )
    }

    // MARK: - shouldAutoSummarize tests

    func testShouldAutoSummarizeFalseIfHasSummary() async {
        let existingSummary = SessionSummary(
            sessionId: "s1",
            summary: "Already summarized",
            lesson: "",
            generatedAt: Date(),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        )
        let session = makeSession(id: "s1", summary: existingSummary)

        let result = enricher.shouldAutoSummarize(session: session, endedSessionIds: [])
        XCTAssertFalse(result, "Should not re-summarize a session that already has a summary")
    }

    func testShouldAutoSummarizeTrueIfInEndedSet() async {
        let session = makeSession(id: "s-ended")

        let result = enricher.shouldAutoSummarize(session: session, endedSessionIds: ["s-ended"])
        XCTAssertTrue(result, "Should summarize immediately when session is in endedSessionIds")
    }

    func testShouldAutoSummarizeTrueIfIdleOver30Min() async {
        let longAgo = Date().addingTimeInterval(-(31 * 60))
        let session = makeSession(id: "s-idle", turnEndedAt: longAgo)

        let result = enricher.shouldAutoSummarize(session: session, endedSessionIds: [])
        XCTAssertTrue(result, "Should summarize when last activity was > 30 min ago")
    }

    func testShouldAutoSummarizeFalseIfRecent() async {
        // Turn ended just 5 minutes ago — well within threshold
        let recentEnd = Date().addingTimeInterval(-(5 * 60))
        let session = makeSession(id: "s-recent", turnEndedAt: recentEnd)

        let result = enricher.shouldAutoSummarize(session: session, endedSessionIds: [])
        XCTAssertFalse(result, "Should not summarize a recently active session not in endedSessionIds")
    }
}
