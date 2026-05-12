import Foundation

/// User-facing display language for the app's own copy (demo content,
/// localized SwiftUI strings). Separate from `languagePersona`
/// (developer/etc.), which controls *tone* not *language*.
///
/// Production AI enrichers (NarrativeEnricher, SessionSummaryEnricher)
/// still take their `language` parameter from their composition setup
/// — this enum only governs locally-rendered copy.
enum AppLanguage: String, Codable, CaseIterable, Identifiable, Hashable {
    case vi
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        }
    }

    var flag: String {
        switch self {
        case .vi: return "🇻🇳"
        case .en: return "🇺🇸"
        }
    }
}

/// A pair of strings (Vietnamese + English) used to attach UI copy to a
/// data structure without hardcoding either language at the call site.
struct L10n: Hashable {
    let vi: String
    let en: String

    func callAsFunction(_ language: AppLanguage) -> String {
        switch language {
        case .vi: return vi
        case .en: return en
        }
    }
}
