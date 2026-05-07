import Foundation
import FirebaseAuth

// MARK: - DTOs

struct SummarizeTurnRequest: Codable {
    let turnId: String
    let sessionId: String
    let language: String       // "vi" | "en"
    let prompt: String
    let events: [EventDTO]
    let rawSummary: String
    let petPersona: PetPersonaDTO?

    struct EventDTO: Codable {
        let time: String       // "HH:mm"
        let tool: String
        let path: String?
        let text: String?
    }

    struct PetPersonaDTO: Codable {
        let id: String           // "byte"
        let name: String         // "Byte"
        let personality: String  // "glitchy, chaotic, thinks in fragments"
        let domain: String       // "Data / ML"
    }

    enum CodingKeys: String, CodingKey {
        case turnId = "turn_id"
        case sessionId = "session_id"
        case language
        case prompt
        case events
        case rawSummary = "raw_summary"
        case petPersona = "pet_persona"
    }
}

struct SummarizeTurnResponse: Codable {
    let turnId: String
    let narrative: NarrativePayload
    let model: String
    let cacheHit: Bool

    struct NarrativePayload: Codable {
        let title: String
        let whatYouWanted: String
        let whatHappened: String
        let lesson: String

        enum CodingKeys: String, CodingKey {
            case title
            case whatYouWanted = "what_you_wanted"
            case whatHappened = "what_happened"
            case lesson
        }
    }

    enum CodingKeys: String, CodingKey {
        case turnId = "turn_id"
        case narrative
        case model
        case cacheHit = "cache_hit"
    }
}

struct SummarizeTurnError: Codable, Error {
    let error: String
    let resetAt: String?
    let limit: Int?
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case error
        case resetAt = "reset_at"
        case limit
        case detail
    }
}

// MARK: - Session DTOs

struct SummarizeSessionRequest: Codable {
    let sessionId: String
    let language: String
    let turns: [TurnDTO]
    let petPersona: SummarizeTurnRequest.PetPersonaDTO?

    struct TurnDTO: Codable {
        let prompt: String
        let whatYouWanted: String?
        let whatHappened: String?
        let durationMinutes: Int?

        enum CodingKeys: String, CodingKey {
            case prompt
            case whatYouWanted = "what_you_wanted"
            case whatHappened = "what_happened"
            case durationMinutes = "duration_minutes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case language
        case turns
        case petPersona = "pet_persona"
    }
}

struct SummarizeSessionResponse: Codable {
    let sessionId: String
    let summary: SummaryPayload
    let model: String

    struct SummaryPayload: Codable {
        let summary: String
        let lesson: String
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case summary
        case model
    }
}

// MARK: - Chat DTOs

struct ChatSessionRequest: Codable {
    let sessionId: String
    let language: String
    let petPersona: SummarizeTurnRequest.PetPersonaDTO?
    let sessionContext: SessionContextDTO
    let history: [ChatMessageDTO]
    let userMessage: String

    struct SessionContextDTO: Codable {
        let userBrief: String?
        let summary: SummaryDTO?
        let turns: [TurnDTO]

        struct SummaryDTO: Codable {
            let summary: String
            let lesson: String
        }

        struct TurnDTO: Codable {
            let prompt: String
            let whatYouWanted: String?
            let whatHappened: String?
            let lesson: String?
            let durationMinutes: Int?
            let events: [SummarizeTurnRequest.EventDTO]

            enum CodingKeys: String, CodingKey {
                case prompt
                case whatYouWanted = "what_you_wanted"
                case whatHappened = "what_happened"
                case lesson
                case durationMinutes = "duration_minutes"
                case events
            }
        }

        enum CodingKeys: String, CodingKey {
            case userBrief = "user_brief"
            case summary
            case turns
        }
    }

    struct ChatMessageDTO: Codable {
        let role: String   // "user" | "pet"
        let text: String
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case language
        case petPersona = "pet_persona"
        case sessionContext = "session_context"
        case history
        case userMessage = "user_message"
    }
}

enum ChatStreamEvent: Equatable {
    case delta(String)
    case done(model: String, cacheHit: Bool)
}

// MARK: - Client

protocol ReflectionAPIClientProtocol {
    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse
    func summarizeSession(_ request: SummarizeSessionRequest) async throws -> SummarizeSessionResponse
    func chatSessionStream(_ request: ChatSessionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
}

enum ReflectionAPIError: Error {
    case notSignedIn
    case http(status: Int, body: SummarizeTurnError?)
    case malformedResponse
    case network(Error)
}

@MainActor
final class ReflectionAPIClient: ReflectionAPIClientProtocol {

    /// Replace with the deployed Cloud Function URL after Task 10.
    static let endpoint = URL(string: "https://summarizeturn-REPLACE_ME-uc.a.run.app")!

    private static let sessionEndpoint = URL(string: "https://summarizesession-REPLACE_ME-uc.a.run.app")!
    private static let chatEndpoint = URL(string: "https://us-central1-devpet-8f4b1.cloudfunctions.net/chatSession")!

    private let session: URLSession
    private let authTokenProvider: () async throws -> String

    init(
        session: URLSession = .shared,
        authTokenProvider: (() async throws -> String)? = nil
    ) {
        self.session = session
        self.authTokenProvider = authTokenProvider ?? {
            guard let user = Auth.auth().currentUser else {
                throw ReflectionAPIError.notSignedIn
            }
            do {
                return try await user.getIDToken()
            } catch {
                throw ReflectionAPIError.network(error)
            }
        }
    }

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        let token = try await authTokenProvider()

        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ReflectionAPIError.malformedResponse
        }

        if http.statusCode == 200 {
            do {
                return try JSONDecoder().decode(SummarizeTurnResponse.self, from: data)
            } catch {
                throw ReflectionAPIError.malformedResponse
            }
        }

        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
    }

    func summarizeSession(_ request: SummarizeSessionRequest) async throws -> SummarizeSessionResponse {
        let token = try await authTokenProvider()

        var urlRequest = URLRequest(url: Self.sessionEndpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw ReflectionAPIError.malformedResponse }

        if http.statusCode == 200 {
            do {
                return try JSONDecoder().decode(SummarizeSessionResponse.self, from: data)
            } catch { throw ReflectionAPIError.malformedResponse }
        }

        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
    }

    func chatSessionStream(_ request: ChatSessionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let token = try await authTokenProvider()

                    var urlRequest = URLRequest(url: Self.chatEndpoint)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw ReflectionAPIError.malformedResponse
                    }

                    if http.statusCode != 200 {
                        // Non-streaming error body. Read fully then throw.
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                        }
                        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
                        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
                    }

                    var parser = SSEParser()
                    for try await line in bytes.lines {
                        for frame in parser.feedLines([line]) {
                            try Self.handle(frame: frame, continuation: continuation)
                        }
                    }
                    // Flush any final frame (server should always end with blank line, but be safe).
                    for frame in parser.feedLines([""]) {
                        try Self.handle(frame: frame, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func handle(
        frame: SSEFrame,
        continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation
    ) throws {
        guard let payload = frame.data.data(using: .utf8) else { return }
        switch frame.event {
        case "delta":
            struct DeltaPayload: Codable { let text: String }
            if let d = try? JSONDecoder().decode(DeltaPayload.self, from: payload) {
                continuation.yield(.delta(d.text))
            }
        case "done":
            struct DonePayload: Codable {
                let model: String
                let cacheHit: Bool
                enum CodingKeys: String, CodingKey { case model; case cacheHit = "cache_hit" }
            }
            if let d = try? JSONDecoder().decode(DonePayload.self, from: payload) {
                continuation.yield(.done(model: d.model, cacheHit: d.cacheHit))
            }
        case "error":
            let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: payload)
            throw ReflectionAPIError.http(status: 502, body: parsed)
        default:
            break
        }
    }
}
