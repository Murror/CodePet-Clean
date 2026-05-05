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

// MARK: - Client

protocol ReflectionAPIClientProtocol {
    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse
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

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        guard let user = Auth.auth().currentUser else {
            throw ReflectionAPIError.notSignedIn
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw ReflectionAPIError.network(error)
        }

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
}
