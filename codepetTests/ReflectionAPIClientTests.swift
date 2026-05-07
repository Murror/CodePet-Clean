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
            rawSummary: "Edit foo.swift",
            petPersona: nil
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

    func testChatSessionRequestEncodesSnakeCase() throws {
        let request = ChatSessionRequest(
            sessionId: "s1",
            language: "vi",
            petPersona: SummarizeTurnRequest.PetPersonaDTO(
                id: "byte", name: "Byte", personality: "glitchy", domain: "Data"
            ),
            sessionContext: ChatSessionRequest.SessionContextDTO(
                userBrief: "building",
                summary: ChatSessionRequest.SessionContextDTO.SummaryDTO(
                    summary: "We worked.", lesson: "Stay focused."
                ),
                turns: [
                    ChatSessionRequest.SessionContextDTO.TurnDTO(
                        prompt: "fix",
                        whatYouWanted: "you wanted",
                        whatHappened: "you did",
                        lesson: "be patient",
                        durationMinutes: 12,
                        events: [SummarizeTurnRequest.EventDTO(
                            time: "09:00", tool: "Edit", path: "foo.swift", text: nil
                        )]
                    )
                ]
            ),
            history: [
                ChatSessionRequest.ChatMessageDTO(role: "user", text: "hi"),
                ChatSessionRequest.ChatMessageDTO(role: "pet", text: "hi back")
            ],
            userMessage: "what was tricky?"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["session_id"] as? String, "s1")
        XCTAssertEqual(json["language"] as? String, "vi")
        XCTAssertEqual(json["user_message"] as? String, "what was tricky?")

        let context = json["session_context"] as! [String: Any]
        XCTAssertEqual(context["user_brief"] as? String, "building")
        let turns = context["turns"] as! [[String: Any]]
        XCTAssertEqual(turns.first?["prompt"] as? String, "fix")
        XCTAssertEqual(turns.first?["what_you_wanted"] as? String, "you wanted")
        XCTAssertEqual(turns.first?["duration_minutes"] as? Int, 12)
        let history = json["history"] as! [[String: Any]]
        XCTAssertEqual(history.first?["role"] as? String, "user")
    }
}
