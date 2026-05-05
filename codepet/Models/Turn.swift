import Foundation

struct Narrative: Codable, Hashable {
    let title: String          // ≤60 chars
    let whatYouWanted: String  // ≤240 chars
    let whatHappened: String   // ≤240 chars
    let lesson: String         // ≤240 chars or "" if none
    let model: String
    let generatedAt: Date
    let schemaVersion: Int

    enum CodingKeys: String, CodingKey {
        case title
        case whatYouWanted = "what_you_wanted"
        case whatHappened = "what_happened"
        case lesson
        case model
        case generatedAt = "generated_at"
        case schemaVersion = "schema_version"
    }
}

enum FailureReason: String, Codable, Hashable {
    case network
    case auth
    case quota
    case badResponse = "bad_response"
    case unknown
}

enum TurnState: Hashable {
    case pending           // no Stop event yet
    case summarizing       // API call in flight
    case ready             // narrative present
    case failed(reason: FailureReason)
    case pendingOrphan     // no Stop event after 30 min
}

struct Turn: Identifiable, Hashable {
    let id: String              // turn_id
    let sessionId: String
    let startedAt: Date
    let endedAt: Date?
    let prompt: String
    let rawEvents: [CapturedEvent]
    let narrative: Narrative?
    let state: TurnState

    static func makeID(sessionId: String, promptISO: String) -> String {
        "\(sessionId):\(promptISO)"
    }
}
