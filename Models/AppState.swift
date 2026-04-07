import SwiftUI
import Combine

class AppState: ObservableObject {
    // Onboarding
    @Published var onboardingComplete: Bool = false
    @Published var userAge: String = ""
    @Published var obWho: String = ""
    @Published var obDesire: String = ""
    @Published var obGoal: String = ""
    @Published var skillLevel: String = ""
    @Published var dailyGoalMinutes: Int = 0
    @Published var preferredLanguage: String = "javascript"

    // User
    @Published var displayName: String = ""
    @Published var activeChar: String = "byte"
    @Published var userInterests: [String] = []

    // Progress
    @Published var totalXP: Int = 0
    @Published var userLevel: Int = 1
    @Published var currentTier: Int = 1
    @Published var charOutfit: Int = 1
    @Published var completedLessons: [String] = []
    @Published var completedChallenges: [String] = []

    // Streak
    @Published var streak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var lastVisit: Date? = nil
    @Published var weeklyStats: WeeklyStats = WeeklyStats()

    // Difficulty
    @Published var difficultyLevel: String = "medium"
    @Published var performanceHistory: [PerformanceEntry] = []

    // Review / Spaced Repetition
    @Published var lessonReviewDates: [String: Date] = [:]  // skillId -> last review date
    @Published var lessonReviewCounts: [String: Int] = [:]  // skillId -> review count

    // Daily Challenge
    @Published var dailyChallengeCompleted: Bool = false

    // UI State
    @Published var selectedTab: Tab = .home
    @Published var showWeeklyRecap: Bool = false
    @Published var petEnergy: Int = 60
    @Published var petMood: String = "Idle"

    // Phase 5: Theme & Sound
    @Published var isDarkMode: Bool = false
    @Published var soundEnabled: Bool = true

    // Phase 5: Level-up tracking
    @Published var showLevelUp: Bool = false
    @Published var previousLevel: Int = 1

    // Tier unlock tracking
    @Published var showTierUnlock: Bool = false
    @Published var newTierNum: Int = 0

    // Auto-save cancellable
    private var saveCancellable: AnyCancellable?

    enum Tab: String, CaseIterable {
        case home = "Home"
        case skills = "Skills"
        case sessions = "Sessions"
        case insights = "Insights"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .skills: return "sparkles"
            case .sessions: return "doc.text.fill"
            case .insights: return "chart.bar.fill"
            case .profile: return "person.fill"
            }
        }
    }

    init() {
        // Load saved data
        PersistenceManager.shared.load(into: self)
        SoundManager.shared.isEnabled = soundEnabled
        previousLevel = userLevel

        // Ensure tier progression matches completed lessons (fixes existing progress)
        syncTierToCompletedLessons()

        // Auto-save whenever any @Published property changes (debounced 2s)
        saveCancellable = objectWillChange
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                PersistenceManager.shared.save(self)
            }
    }

    // MARK: - XP & Level Helpers

    /// Call this instead of manually setting totalXP — handles level-up detection + sound
    func addXP(_ amount: Int) {
        previousLevel = userLevel
        totalXP += amount
        userLevel = (totalXP / 100) + 1

        // Sound effect
        SoundManager.shared.playXPGain()

        // Detect level up
        if userLevel > previousLevel {
            SoundManager.shared.playLevelUp()
            showLevelUp = true
        }

        // Character outfit evolves with tier
        charOutfit = currentTier

        // Energy boost from activity
        petEnergy = min(100, petEnergy + 5)
    }

    /// Silently sync currentTier to match completed lessons (called on init)
    private func syncTierToCompletedLessons() {
        for tier in GameData.skillTiers {
            let allCompleted = tier.skills.allSatisfy { completedLessons.contains($0.id) }
            if allCompleted && currentTier <= tier.id && tier.id < 4 {
                currentTier = tier.id + 1
                charOutfit = currentTier
            }
        }
    }

    /// Call after completing a lesson to check if a new tier should unlock
    func checkTierProgression() {
        let oldTier = currentTier
        for tier in GameData.skillTiers {
            let allCompleted = tier.skills.allSatisfy { completedLessons.contains($0.id) }
            if allCompleted && currentTier <= tier.id && tier.id < 4 {
                currentTier = tier.id + 1
            }
        }

        // Trigger tier unlock overlay
        if currentTier > oldTier {
            newTierNum = currentTier
            charOutfit = currentTier
            showTierUnlock = true
            SoundManager.shared.playLevelUp()
        }
    }

    // MARK: - Spaced Repetition

    /// Lessons ready for review (spaced repetition: 1d, 3d, 7d, 14d intervals)
    var lessonsReadyForReview: [String] {
        completedLessons.filter { skillId in
            guard let lastReview = lessonReviewDates[skillId] else {
                // Never reviewed — ready if completed more than 1 day ago
                return true
            }
            let reviewCount = lessonReviewCounts[skillId] ?? 0
            let interval: TimeInterval
            switch reviewCount {
            case 0: interval = 86400       // 1 day
            case 1: interval = 86400 * 3   // 3 days
            case 2: interval = 86400 * 7   // 7 days
            default: interval = 86400 * 14 // 14 days
            }
            return Date().timeIntervalSince(lastReview) >= interval
        }
    }

    /// Mark a lesson as reviewed
    func markReviewed(_ skillId: String) {
        lessonReviewDates[skillId] = Date()
        lessonReviewCounts[skillId] = (lessonReviewCounts[skillId] ?? 0) + 1
    }

    /// Toggle dark mode with sound
    func toggleDarkMode() {
        isDarkMode.toggle()
        SoundManager.shared.playTap()
    }

    /// Toggle sound
    func toggleSound() {
        soundEnabled.toggle()
        SoundManager.shared.isEnabled = soundEnabled
    }

    /// Complete daily challenge
    func completeDailyChallenge(xpReward: Int, challengeId: String) {
        guard !dailyChallengeCompleted else { return }
        dailyChallengeCompleted = true
        if !completedChallenges.contains(challengeId) {
            completedChallenges.append(challengeId)
        }
        addXP(xpReward)
        SoundManager.shared.playSuccess()
    }

    /// Force save (for manual save button in profile)
    func forceSave() {
        PersistenceManager.shared.save(self)
    }

    /// Reset all progress
    func resetProgress() {
        PersistenceManager.shared.resetAll()
        totalXP = 0
        userLevel = 1
        currentTier = 1
        streak = 0
        longestStreak = 0
        completedLessons = []
        completedChallenges = []
        dailyChallengeCompleted = false
        petEnergy = 60
        petMood = "Idle"
        weeklyStats = WeeklyStats()
        performanceHistory = []
    }

    /// Reset onboarding only (for testing)
    func resetOnboarding() {
        onboardingComplete = false
        obWho = ""
        obDesire = ""
        obGoal = ""
        skillLevel = ""
        userAge = ""
        dailyGoalMinutes = 0
        userInterests = []
        activeChar = "byte"
        displayName = ""
        PersistenceManager.shared.save(self)
    }
}

struct WeeklyStats: Codable {
    var challengesDone: Int = 0
    var skillsLearned: Int = 0
    var xpEarned: Int = 0
}

struct PerformanceEntry: Codable {
    let score: Int
    let date: Date
    let skillId: String
}
