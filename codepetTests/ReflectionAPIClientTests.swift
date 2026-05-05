import XCTest
@testable import codepet

final class ReflectionAPIClientTests: XCTestCase {

    func testRequestEncodingShape() throws {
        let payload = SummarizeTurnRequest(
            turnId: "s1:2026-05-05T09:00:00Z",
            sessionId: "s1",
            language: "vi",
            prompt: "fix",
            events: [
                .init(time: "09:00", tool: "Edit", path: "foo.swift", text: nil)
            ],
            rawSummary: "Edit foo.swift"
        )
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["turn_id"] as? String, "s1:2026-05-05T09:00:00Z")
        XCTAssertEqual(json["session_id"] as? String, "s1")
        XCTAssertEqual(json["language"] as? String, "vi")
        let events = json["events"] as! [[String: Any]]
        XCTAssertEqual(events.first?["tool"] as? String, "Edit")
        XCTAssertEqual(events.first?["path"] as? String, "foo.swift")
    }

    func testResponseDecodes() throws {
        let json = """
        {
          "turn_id": "s1:2026-05-05T09:00:00Z",
          "narrative": {
            "title": "T",
            "what_you_wanted": "w",
            "what_happened": "h",
            "lesson": "l"
          },
          "model": "claude-haiku-4-5-20251001",
          "cache_hit": false
        }
        """.data(using: .utf8)!

        let resp = try JSONDecoder().decode(SummarizeTurnResponse.self, from: json)
        XCTAssertEqual(resp.narrative.title, "T")
        XCTAssertEqual(resp.model, "claude-haiku-4-5-20251001")
        XCTAssertFalse(resp.cacheHit)
    }

    func testQuotaErrorDecodes() throws {
        let json = """
        {
          "error": "daily_limit_reached",
          "reset_at": "2026-05-06T00:00:00Z",
          "limit": 50
        }
        """.data(using: .utf8)!
        let err = try JSONDecoder().decode(SummarizeTurnError.self, from: json)
        XCTAssertEqual(err.error, "daily_limit_reached")
        XCTAssertEqual(err.limit, 50)
    }
}
