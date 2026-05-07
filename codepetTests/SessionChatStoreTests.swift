import XCTest
@testable import codepet

final class SessionChatStoreTests: XCTestCase {

    func testChatMessageRoundTripsThroughCodable() throws {
        let original = ChatMessage(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            role: .pet,
            text: "Hỏi mình về phiên này nhé.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testThreadRoundTripsThroughCodable() throws {
        let thread = SessionChatThread(
            sessionId: "s1",
            messages: [
                ChatMessage(id: UUID(), role: .user, text: "what happened?", createdAt: Date(timeIntervalSince1970: 1_700_000_001)),
                ChatMessage(id: UUID(), role: .pet, text: "Together we…", createdAt: Date(timeIntervalSince1970: 1_700_000_002))
            ],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_002)
        )
        let data = try JSONEncoder().encode(thread)
        let decoded = try JSONDecoder().decode(SessionChatThread.self, from: data)
        XCTAssertEqual(decoded.sessionId, thread.sessionId)
        XCTAssertEqual(decoded.messages, thread.messages)
        XCTAssertEqual(decoded.updatedAt, thread.updatedAt)
    }
}
