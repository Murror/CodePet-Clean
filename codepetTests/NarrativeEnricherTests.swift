import XCTest
@testable import codepet

final class MockAPIClient: ReflectionAPIClientProtocol {
    var calls: [SummarizeTurnRequest] = []
    var response: SummarizeTurnResponse?
    var error: Error?
    var delay: TimeInterval = 0

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        calls.append(request)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let error = error { throw error }
        if let response = response { return response }
        return SummarizeTurnResponse(
            turnId: request.turnId,
            narrative: .init(title: "T", whatYouWanted: "w", whatHappened: "h", lesson: "l"),
            model: "claude-haiku-4-5-20251001",
            cacheHit: false
        )
    }
}

@MainActor
final class NarrativeEnricherTests: XCTestCase {
    var tmpURL: URL!
    var store: NarrativeStore!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("enricher-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tmpURL = dir.appendingPathComponent("narratives.jsonl")
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.start()
    }

    override func tearDown() async throws {
        store.stop()
        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }

    private func makeTurn(id: String = "s1:2026-05-05T09:00:00Z") -> Turn {
        Turn(
            id: id,
            sessionId: "s1",
            startedAt: Date(),
            endedAt: Date(),
            prompt: "do the thing",
            rawEvents: [],
            narrative: nil,
            state: .summarizing
        )
    }

    func testHappyPathPersistsNarrative() async {
        let api = MockAPIClient()
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        await enricher.enrich(turn: makeTurn())

        XCTAssertEqual(api.calls.count, 1)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNotNil(store.narratives["s1:2026-05-05T09:00:00Z"])
    }

    func testNetworkFailReturnsFailedNetwork() async {
        let api = MockAPIClient()
        api.error = ReflectionAPIError.network(URLError(.notConnectedToInternet))
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi", retryDelay: 0)

        let result = await enricher.enrich(turn: makeTurn())

        XCTAssertEqual(result, .failed(reason: .network))
        XCTAssertEqual(api.calls.count, 2)  // 1 attempt + 1 retry
    }

    func testQuotaReturnsFailedQuota() async {
        let api = MockAPIClient()
        api.error = ReflectionAPIError.http(
            status: 429,
            body: SummarizeTurnError(error: "daily_limit_reached", resetAt: "2026-05-06T00:00:00Z", limit: 50, detail: nil)
        )
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        let result = await enricher.enrich(turn: makeTurn())

        XCTAssertEqual(result, .failed(reason: .quota))
        XCTAssertEqual(api.calls.count, 1)  // no retry on quota
    }

    func testAuthErrorReturnsFailedAuth() async {
        let api = MockAPIClient()
        api.error = ReflectionAPIError.http(status: 401, body: nil)
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        let result = await enricher.enrich(turn: makeTurn())
        XCTAssertEqual(result, .failed(reason: .auth))
        XCTAssertEqual(api.calls.count, 1)
    }

    func testEnqueueProcessesSerially() async {
        let api = MockAPIClient()
        api.delay = 0.1
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = await enricher.enrich(turn: self.makeTurn(id: "s1:t1")) }
            group.addTask { _ = await enricher.enrich(turn: self.makeTurn(id: "s1:t2")) }
        }

        XCTAssertEqual(api.calls.count, 2)
    }
}
