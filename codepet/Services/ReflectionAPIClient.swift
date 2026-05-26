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
    let userBrief: String?     // user's project brief from welcome screen

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
        let voiceGuide: String   // how they talk — rhythm, humor, style
        let lensGuide: String    // what they notice and advise on
        let emotionalTriggers: String  // what excites vs. concerns them
        let metaphorFamily: String     // preferred metaphor domains
        let signatureEmojis: String    // 3-4 emojis they gravitate toward

        enum CodingKeys: String, CodingKey {
            case id, name, personality, domain
            case voiceGuide = "voice_guide"
            case lensGuide = "lens_guide"
            case emotionalTriggers = "emotional_triggers"
            case metaphorFamily = "metaphor_family"
            case signatureEmojis = "signature_emojis"
        }
    }

    enum CodingKeys: String, CodingKey {
        case turnId = "turn_id"
        case sessionId = "session_id"
        case language
        case prompt
        case events
        case rawSummary = "raw_summary"
        case petPersona = "pet_persona"
        case userBrief = "user_brief"
    }
}

struct SummarizeTurnResponse: Codable {
    let turnId: String
    let narrative: NarrativePayload
    let model: String
    let cacheHit: Bool

    struct NarrativePayload: Codable, Equatable {
        let title: String
        let whatYouWanted: String
        let whatHappened: String
        let lesson: String
        let nextSteps: String?
        let mood: String?  // "idle" | "excited" | "thinking" | "proud" | "concerned" | "cheering"

        enum CodingKeys: String, CodingKey {
            case title
            case whatYouWanted = "what_you_wanted"
            case whatHappened = "what_happened"
            case lesson
            case nextSteps = "next_steps"
            case mood
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
    let userBrief: String?

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
        case userBrief = "user_brief"
    }
}

struct SummarizeSessionResponse: Codable {
    let sessionId: String
    let summary: SummaryPayload
    let model: String

    struct SummaryPayload: Codable, Equatable {
        let summary: String
        let lesson: String
        let briefUpdate: String?

        enum CodingKeys: String, CodingKey {
            case summary, lesson
            case briefUpdate = "brief_update"
        }
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

// MARK: - Narrative Stream DTOs

enum NarrativeStreamEvent: Equatable {
    /// The SSE connection opened — show "generating" UI immediately.
    case started
    /// A chunk of partial JSON from the tool_use input_json_delta.
    case jsonDelta(String)
    /// The final complete narrative.
    case done(narrative: SummarizeTurnResponse.NarrativePayload, model: String, cacheHit: Bool)
}

enum SessionSummaryStreamEvent: Equatable {
    case started
    case jsonDelta(String)
    case done(summary: SummarizeSessionResponse.SummaryPayload, model: String, briefUpdate: String?)
}

enum ChatStreamEvent: Equatable {
    case delta(String)
    case done(model: String, cacheHit: Bool)
}

// MARK: - Client

protocol ReflectionAPIClientProtocol {
    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse
    func summarizeTurnStream(_ request: SummarizeTurnRequest) -> AsyncThrowingStream<NarrativeStreamEvent, Error>
    func summarizeSession(_ request: SummarizeSessionRequest) async throws -> SummarizeSessionResponse
    func summarizeSessionStream(_ request: SummarizeSessionRequest) -> AsyncThrowingStream<SessionSummaryStreamEvent, Error>
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

    static let endpoint = URL(string: "https://us-central1-devpet-8f4b1.cloudfunctions.net/summarizeTurn")!
    private static let sessionEndpoint = URL(string: "https://us-central1-devpet-8f4b1.cloudfunctions.net/summarizeSession")!
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

    func summarizeTurnStream(_ request: SummarizeTurnRequest) -> AsyncThrowingStream<NarrativeStreamEvent, Error> {
        let capturedSession = session
        let capturedAuthTokenProvider = authTokenProvider
        // Append ?stream=true to the endpoint URL
        var streamURL = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
        streamURL.queryItems = [URLQueryItem(name: "stream", value: "true")]
        let url = streamURL.url!

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    let token = try await capturedAuthTokenProvider()

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await capturedSession.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw ReflectionAPIError.malformedResponse
                    }

                    if http.statusCode != 200 {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
                        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
                    }

                    // SSE connection opened — signal generating state
                    continuation.yield(.started)

                    var parser = SSEParser()
                    var lineBuffer: [UInt8] = []
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer.removeAll(keepingCapacity: true)
                            for frame in parser.feedLines([line]) {
                                try Self.handleNarrativeFrame(frame: frame, continuation: continuation)
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    if !lineBuffer.isEmpty {
                        let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                        for frame in parser.feedLines([line]) {
                            try Self.handleNarrativeFrame(frame: frame, continuation: continuation)
                        }
                    }
                    for frame in parser.feedLines([""]) {
                        try Self.handleNarrativeFrame(frame: frame, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func handleNarrativeFrame(
        frame: SSEFrame,
        continuation: AsyncThrowingStream<NarrativeStreamEvent, Error>.Continuation
    ) throws {
        guard let payload = frame.data.data(using: .utf8) else { return }
        switch frame.event {
        case "delta":
            struct DeltaPayload: Codable { let json: String }
            if let d = try? JSONDecoder().decode(DeltaPayload.self, from: payload) {
                continuation.yield(.jsonDelta(d.json))
            }
        case "done":
            struct DonePayload: Codable {
                let turnId: String
                let narrative: SummarizeTurnResponse.NarrativePayload
                let model: String
                let cacheHit: Bool
                enum CodingKeys: String, CodingKey {
                    case turnId = "turn_id"
                    case narrative, model
                    case cacheHit = "cache_hit"
                }
            }
            if let d = try? JSONDecoder().decode(DonePayload.self, from: payload) {
                continuation.yield(.done(narrative: d.narrative, model: d.model, cacheHit: d.cacheHit))
            }
        case "error":
            let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: payload)
            throw ReflectionAPIError.http(status: 502, body: parsed)
        default:
            break
        }
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

    func summarizeSessionStream(_ request: SummarizeSessionRequest) -> AsyncThrowingStream<SessionSummaryStreamEvent, Error> {
        let capturedSession = session
        let capturedAuthTokenProvider = authTokenProvider
        var streamURL = URLComponents(url: Self.sessionEndpoint, resolvingAgainstBaseURL: false)!
        streamURL.queryItems = [URLQueryItem(name: "stream", value: "true")]
        let url = streamURL.url!

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    let token = try await capturedAuthTokenProvider()

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await capturedSession.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw ReflectionAPIError.malformedResponse
                    }

                    if http.statusCode != 200 {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
                        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
                    }

                    continuation.yield(.started)

                    var parser = SSEParser()
                    var lineBuffer: [UInt8] = []
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer.removeAll(keepingCapacity: true)
                            for frame in parser.feedLines([line]) {
                                try Self.handleSessionFrame(frame: frame, continuation: continuation)
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    if !lineBuffer.isEmpty {
                        let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                        for frame in parser.feedLines([line]) {
                            try Self.handleSessionFrame(frame: frame, continuation: continuation)
                        }
                    }
                    for frame in parser.feedLines([""]) {
                        try Self.handleSessionFrame(frame: frame, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func handleSessionFrame(
        frame: SSEFrame,
        continuation: AsyncThrowingStream<SessionSummaryStreamEvent, Error>.Continuation
    ) throws {
        guard let payload = frame.data.data(using: .utf8) else { return }
        switch frame.event {
        case "delta":
            struct DeltaPayload: Codable { let json: String }
            if let d = try? JSONDecoder().decode(DeltaPayload.self, from: payload) {
                continuation.yield(.jsonDelta(d.json))
            }
        case "done":
            struct DonePayload: Codable {
                let sessionId: String
                let summary: SummarizeSessionResponse.SummaryPayload
                let model: String
                enum CodingKeys: String, CodingKey {
                    case sessionId = "session_id"
                    case summary, model
                }
            }
            if let d = try? JSONDecoder().decode(DonePayload.self, from: payload) {
                continuation.yield(.done(summary: d.summary, model: d.model, briefUpdate: d.summary.briefUpdate))
            }
        case "error":
            let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: payload)
            throw ReflectionAPIError.http(status: 502, body: parsed)
        default:
            break
        }
    }

    func chatSessionStream(_ request: ChatSessionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        // Capture actor-isolated values before entering the Task, so the Task
        // can run detached (off MainActor) and freely use URLSession.bytes without
        // risking a deadlock on the main actor while waiting for streaming data.
        let capturedSession = session
        let capturedAuthTokenProvider = authTokenProvider
        let chatEndpoint = Self.chatEndpoint

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    let token = try await capturedAuthTokenProvider()

                    var urlRequest = URLRequest(url: chatEndpoint)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await capturedSession.bytes(for: urlRequest)
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
                    var lineBuffer: [UInt8] = []
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer.removeAll(keepingCapacity: true)
                            for frame in parser.feedLines([line]) {
                                try Self.handle(frame: frame, continuation: continuation)
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    // Flush leftover bytes (no trailing newline).
                    if !lineBuffer.isEmpty {
                        let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
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
