import Foundation
import SwiftUI
import Combine

// MARK: - Skill progress tracking

/// Progress for a single vibe-coding skill tile.
/// Each skill has 5 practice slots (dots); filling all 5 marks it as mastered.
struct SkillProgress: Codable, Equatable {
    let skillId: String
    var practiceCount: Int          // 0–5
    var lastPracticedDate: Date?
    var isMastered: Bool { practiceCount >= 5 }

    /// Record one practice. Clamps at 5.
    mutating func recordPractice() {
        practiceCount = min(practiceCount + 1, 5)
        lastPracticedDate = Date()
    }
}

// MARK: - AI-generated guidance

/// Response from the generateGuidance Cloud Function.
/// Cached locally so we only call once per day.
struct GuidanceResult: Codable, Equatable {
    let headline: String
    let body: String
    let actionLabel: String?
    let mood: String               // NarrativeMood raw value
    /// Brief list of patterns the AI noticed (e.g. "skipped tests twice").
    let sourcePatterns: [String]
    /// First-person quote from the expert whose knowledge informed this guidance.
    let expertQuote: String?
    /// The expert's name (e.g. "Astro Tran").
    let expertName: String?
    let generatedAt: Date

    /// Whether this guidance is still fresh (generated today).
    var isFresh: Bool {
        Calendar.current.isDateInToday(generatedAt)
    }
}

// MARK: - Tips state

/// Central state for the Tips tab. Tracks skill progress, mastery count,
/// and the current AI-generated daily guidance.
///
/// Registered as an @EnvironmentObject in CodePetApp so all Tips views
/// can read and write progress.
///
/// Persistence: UserDefaults with `cp_tips_` prefix (Phase 5).
/// For MVP, state lives in memory and is saved/loaded via TipsPersistence.
final class TipsState: ObservableObject {

    // MARK: - Skill progress

    /// Keyed by a stable skill identifier: "{petId}_{skillIndex}" e.g. "nova_0".
    /// Each pet has 4 skills (from TipsContent.tipSkillsByPet), indexed 0–3.
    @Published var skillProgress: [String: SkillProgress] = [:]

    /// Total skills across all pets (7 pets x 4 skills = 28, but user only
    /// practices their active pet's skills). For the progress ring we count
    /// mastery within the active pet's discipline.
    var totalSkillsPerPet: Int { 4 }

    /// Count of mastered skills for the given pet.
    func masteredCount(for petId: String) -> Int {
        (0..<totalSkillsPerPet).count { index in
            let key = Self.skillKey(petId: petId, index: index)
            return skillProgress[key]?.isMastered == true
        }
    }

    /// Get or create progress for a specific skill.
    func progress(for petId: String, index: Int) -> SkillProgress {
        let key = Self.skillKey(petId: petId, index: index)
        return skillProgress[key] ?? SkillProgress(skillId: key, practiceCount: 0)
    }

    /// Record a practice for a skill and publish the change.
    func recordPractice(for petId: String, index: Int) {
        let key = Self.skillKey(petId: petId, index: index)
        var current = skillProgress[key] ?? SkillProgress(skillId: key, practiceCount: 0)
        current.recordPractice()
        skillProgress[key] = current
    }

    // MARK: - AI guidance

    /// The current daily guidance from the Cloud Function.
    /// nil means not yet fetched or not available.
    @Published var currentGuidance: GuidanceResult?

    /// Whether guidance is currently being fetched.
    @Published var isLoadingGuidance: Bool = false

    /// Last error from a failed guidance fetch, for UI display.
    @Published var guidanceError: String? = nil

    /// IDs of guidance the user has dismissed ("Not now").
    /// Keyed by the date string (yyyy-MM-dd) so dismissals reset daily.
    @Published var dismissedGuidanceDates: Set<String> = []

    /// Whether today's guidance has been dismissed.
    var isGuidanceDismissed: Bool {
        dismissedGuidanceDates.contains(Self.todayKey)
    }

    /// Dismiss the current guidance for today.
    func dismissGuidance() {
        dismissedGuidanceDates.insert(Self.todayKey)
    }

    /// Whether we need to fetch fresh guidance (no cached result for today).
    var needsGuidanceFetch: Bool {
        guard let guidance = currentGuidance else { return true }
        return !guidance.isFresh
    }

    // MARK: - Setup section state

    /// Which setup actions the user has completed or dismissed.
    /// Keyed by "{petId}_{setupIndex}".
    @Published var completedSetupActions: Set<String> = []

    func isSetupCompleted(petId: String, index: Int) -> Bool {
        completedSetupActions.contains("\(petId)_\(index)")
    }

    func markSetupCompleted(petId: String, index: Int) {
        completedSetupActions.insert("\(petId)_\(index)")
    }

    // MARK: - Reset

    /// Clears all in-memory tips state. Used before re-populating demo data
    /// so repeated ⌥9 presses don't stack progress.
    func reset() {
        skillProgress = [:]
        currentGuidance = nil
        isLoadingGuidance = false
        guidanceError = nil
        dismissedGuidanceDates = []
        completedSetupActions = []
    }

    // MARK: - Helpers

    static func skillKey(petId: String, index: Int) -> String {
        "\(petId)_\(index)"
    }

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
