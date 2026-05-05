import Foundation

enum LanguagePersona: String, CaseIterable, Codable {
    case student
    case productOwner
    case developer

    var displayName: String {
        switch self {
        case .student:      return "Student"
        // Internal case stays `productOwner` for persistence compatibility;
        // user-facing label is "CTO" (a CTO who doesn't code).
        case .productOwner: return "CTO"
        case .developer:    return "Developer"
        }
    }

    var icon: String {
        switch self {
        case .student:      return "🎒"
        case .productOwner: return "👔"
        case .developer:    return "💻"
        }
    }

    var blurb: String {
        switch self {
        case .student:      return "Simple words, fun framing"
        case .productOwner: return "Non-coding CTO — strategy & value, no jargon"
        case .developer:    return "Technical, default tone"
        }
    }
}

struct PersonaText {
    let student: String
    let productOwner: String
    let developer: String

    func value(for persona: LanguagePersona) -> String {
        switch persona {
        case .student:      return student
        case .productOwner: return productOwner
        case .developer:    return developer
        }
    }
}
