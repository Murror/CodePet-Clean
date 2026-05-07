import Foundation

struct SessionSummary: Codable, Hashable {
    let sessionId: String
    let summary: String       // ≤500 chars — narrative arc of the session
    let lesson: String        // ≤300 chars — overarching takeaway
    let generatedAt: Date
    let model: String
    let schemaVersion: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case summary
        case lesson
        case generatedAt = "generated_at"
        case model
        case schemaVersion = "schema_version"
    }
}

/// Session = N turns + optional summary. Pure aggregation, no I/O.
struct Session: Identifiable, Hashable {
    let id: String              // sessionId
    let turns: [Turn]           // sorted oldest-first (chronological reading)
    let startedAt: Date
    let endedAt: Date?
    let summary: SessionSummary?
}

extension Session {
    static let welcomeSessionId = "welcome-onboarding"
    var isWelcome: Bool { id == Self.welcomeSessionId }

    static func makeWelcome() -> Session {
        Session(
            id: welcomeSessionId,
            turns: [],
            startedAt: Date(),
            endedAt: nil,
            summary: nil
        )
    }
}

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

#if DEBUG
extension Turn {
    /// Convenience factory for unit tests. Fills required fields with neutral defaults.
    static func makeForTesting(
        id: String = "test-turn-id",
        sessionId: String = "test-session",
        prompt: String,
        startedAt: Date,
        endedAt: Date?,
        narrative: Narrative?,
        rawEvents: [CapturedEvent]
    ) -> Turn {
        Turn(
            id: id,
            sessionId: sessionId,
            startedAt: startedAt,
            endedAt: endedAt,
            prompt: prompt,
            rawEvents: rawEvents,
            narrative: narrative,
            state: .ready
        )
    }
}

extension Session {
    /// Convenience factory for unit tests.
    static func makeForTesting(
        id: String,
        startedAt: Date,
        endedAt: Date?,
        turns: [Turn],
        summary: SessionSummary?
    ) -> Session {
        Session(
            id: id,
            turns: turns,
            startedAt: startedAt,
            endedAt: endedAt,
            summary: summary
        )
    }
}

extension SessionSummary {
    /// Convenience factory for unit tests that mirrors the test call-site signature.
    static func makeForTesting(
        sessionId: String,
        summary: String,
        lesson: String,
        createdAt: Date
    ) -> SessionSummary {
        SessionSummary(
            sessionId: sessionId,
            summary: summary,
            lesson: lesson,
            generatedAt: createdAt,
            model: "test-model",
            schemaVersion: 1
        )
    }
}
#endif
