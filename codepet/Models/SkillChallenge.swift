import Foundation

// =============================================================================
// MARK: - Skill Challenge
// =============================================================================

/// A specific exercise the user can complete to practice a skill.
/// Challenges are project-aware — they reference the user's actual project
/// and files. The AI auto-verifies completion during coding sessions.
struct SkillChallenge: Identifiable, Codable, Equatable {
    let id: String
    let skillId: String            // e.g. "component_composition"
    let title: String              // Short name: "Extract a reusable component"
    let description: String        // What to do, referencing user's project
    let acceptanceCriteria: String // How the AI knows it's done
    let difficulty: ChallengeDifficulty
    let projectPath: String?       // Which project this applies to (nil = any)

    enum ChallengeDifficulty: String, Codable, Equatable {
        case starter    // First thing to try
        case practice   // Building the habit
        case stretch    // Pushing further
    }
}

// =============================================================================
// MARK: - Challenge Progress
// =============================================================================

/// Tracks which challenges the user has completed.
final class ChallengeProgress: ObservableObject {

    @Published var completedChallengeIds: Set<String> = []
    @Published var activeChallenges: [SkillChallenge] = []

    private let completedKey = "cp_challenge_completed"
    private let activeKey = "cp_challenge_active"

    init() { load() }

    func isCompleted(_ challengeId: String) -> Bool {
        completedChallengeIds.contains(challengeId)
    }

    func markCompleted(_ challengeId: String) {
        completedChallengeIds.insert(challengeId)
        save()
    }

    func activeChallenges(for skillId: String) -> [SkillChallenge] {
        activeChallenges.filter { $0.skillId == skillId && !completedChallengeIds.contains($0.id) }
    }

    func completedChallenges(for skillId: String) -> [SkillChallenge] {
        activeChallenges.filter { $0.skillId == skillId && completedChallengeIds.contains($0.id) }
    }

    // MARK: - Persistence

    func save() {
        UserDefaults.standard.set(Array(completedChallengeIds), forKey: completedKey)
        if let data = try? JSONEncoder().encode(activeChallenges) {
            UserDefaults.standard.set(data, forKey: activeKey)
        }
    }

    func load() {
        completedChallengeIds = Set(UserDefaults.standard.stringArray(forKey: completedKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: activeKey),
           let challenges = try? JSONDecoder().decode([SkillChallenge].self, from: data) {
            activeChallenges = challenges
        }
    }

    func resetAll() {
        completedChallengeIds.removeAll()
        activeChallenges.removeAll()
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.removeObject(forKey: activeKey)
    }
}

// =============================================================================
// MARK: - Challenge Generator
// =============================================================================

/// Generates project-specific challenges based on the user's actual projects.
enum ChallengeGenerator {

    /// Generate challenges for a skill, personalized to the user's project.
    static func generate(
        skillId: String,
        projectName: String,
        projectPath: String
    ) -> [SkillChallenge] {
        switch skillId {
        case "component_composition":
            return [
                SkillChallenge(
                    id: "cc_extract_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Extract a reusable component",
                    description: "Find the largest section in your \(projectName) project and move it into its own file. It should work independently when imported back.",
                    acceptanceCriteria: "Created a new file and moved code from the main file into it",
                    difficulty: .starter,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "cc_shared_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Create a shared utility",
                    description: "Find code that's duplicated in at least 2 places in \(projectName) and extract it into a shared helper function or file.",
                    acceptanceCriteria: "Created a shared utility file used by multiple parts of the project",
                    difficulty: .practice,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "cc_three_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Split into 3+ components",
                    description: "Break one large file in \(projectName) into at least 3 smaller, focused files. Each should do one thing well.",
                    acceptanceCriteria: "Split a file into 3 or more separate component files",
                    difficulty: .stretch,
                    projectPath: projectPath
                ),
            ]

        case "loading_error_states":
            return [
                SkillChallenge(
                    id: "le_trycatch_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Add your first try-catch",
                    description: "Find a place in \(projectName) where data loads or an API is called, and wrap it in a try-catch with a helpful error message.",
                    acceptanceCriteria: "Added try-catch error handling around a data loading function",
                    difficulty: .starter,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "le_spinner_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Add a loading spinner",
                    description: "Add a visual loading indicator to \(projectName) that shows while data is being loaded or processed.",
                    acceptanceCriteria: "Added a loading spinner or indicator that shows during data loading",
                    difficulty: .practice,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "le_fallback_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Build a fallback UI",
                    description: "When something goes wrong in \(projectName), show a friendly error screen with a retry button instead of crashing or showing a blank page.",
                    acceptanceCriteria: "Added a user-friendly error state with retry option",
                    difficulty: .stretch,
                    projectPath: projectPath
                ),
            ]

        case "form_validation_ux":
            return [
                SkillChallenge(
                    id: "fv_required_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Validate required fields",
                    description: "Add validation to a form in \(projectName) — check that required fields are not empty before submission.",
                    acceptanceCriteria: "Added required field validation to a form",
                    difficulty: .starter,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "fv_realtime_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Add real-time validation",
                    description: "Make your \(projectName) form show errors AS the user types, not after they hit submit. Show inline messages next to each field.",
                    acceptanceCriteria: "Added real-time inline validation that triggers on input change",
                    difficulty: .practice,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "fv_format_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Validate data formats",
                    description: "Add format checking to \(projectName) — make sure numbers are positive, emails have @, and dates make sense.",
                    acceptanceCriteria: "Added format validation for specific data types",
                    difficulty: .stretch,
                    projectPath: projectPath
                ),
            ]

        case "accessibility_basics":
            return [
                SkillChallenge(
                    id: "ab_alt_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Add alt text to images",
                    description: "Find all images in \(projectName) and add descriptive alt text so screen readers can describe them.",
                    acceptanceCriteria: "Added alt text attributes to images",
                    difficulty: .starter,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "ab_keyboard_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Make it keyboard navigable",
                    description: "Make sure every interactive element in \(projectName) can be reached and used with just the Tab and Enter keys.",
                    acceptanceCriteria: "Added keyboard navigation support with tab order and enter handlers",
                    difficulty: .practice,
                    projectPath: projectPath
                ),
                SkillChallenge(
                    id: "ab_aria_\(projectPath.hashValue)",
                    skillId: skillId,
                    title: "Add aria-labels to buttons",
                    description: "Add aria-label attributes to icon buttons in \(projectName) so screen readers announce what each button does.",
                    acceptanceCriteria: "Added aria-label attributes to interactive elements",
                    difficulty: .stretch,
                    projectPath: projectPath
                ),
            ]

        default:
            return []
        }
    }

    /// Generate challenges for all skills based on the user's most active project.
    static func generateAll(
        projectName: String,
        projectPath: String
    ) -> [SkillChallenge] {
        let skillIds = [
            "component_composition",
            "loading_error_states",
            "form_validation_ux",
            "accessibility_basics"
        ]
        return skillIds.flatMap { generate(skillId: $0, projectName: projectName, projectPath: projectPath) }
    }
}

// =============================================================================
// MARK: - Challenge Matcher
// =============================================================================

/// Checks if a detected skill from a coding session matches an active challenge.
enum ChallengeMatcher {

    /// Given a detected skill and its evidence, find if any active challenge was completed.
    static func findCompletedChallenges(
        detectedSkill: DetectedSkill,
        activeChallenges: [SkillChallenge]
    ) -> [SkillChallenge] {
        let matching = activeChallenges.filter { challenge in
            guard challenge.skillId == detectedSkill.skillId else { return false }
            guard detectedSkill.confidence == "strong" else { return false }

            // Check if the evidence text relates to the challenge's acceptance criteria
            let evidence = detectedSkill.evidence.lowercased()
            let criteria = challenge.acceptanceCriteria.lowercased()

            // Simple keyword matching — check if key phrases from criteria appear in evidence
            let criteriaWords = criteria.components(separatedBy: .whitespaces)
                .filter { $0.count > 4 } // skip short words
            let matchCount = criteriaWords.filter { evidence.contains($0) }.count
            let matchRatio = criteriaWords.isEmpty ? 0 : Double(matchCount) / Double(criteriaWords.count)

            return matchRatio > 0.3 // 30% keyword overlap = likely match
        }
        return matching
    }
}
