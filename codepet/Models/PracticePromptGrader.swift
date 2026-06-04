import Foundation

/// A lightweight, generic grader for the prompt the user writes during an
/// exercise. Unlike `PromptAnalyzer` (which needs per-scenario required
/// elements), this scores any prompt on the universal qualities of a good
/// vibe-coding instruction, so every SkillChallenge can grade a from-scratch
/// prompt without bespoke data. Rule-based — costs zero tokens.
enum PracticePromptGrader {

    struct Grade: Equatable {
        let score: Int          // 0–100
        let letter: String      // S / A / B / C / D
        let strengths: [String]
        let tips: [String]      // what to add to score higher
    }

    private static let actionVerbs = [
        "extract", "move", "create", "add", "wrap", "refactor", "split",
        "rename", "replace", "validate", "handle", "show", "make", "build", "fix"
    ]

    static func grade(prompt: String, goal: String) -> Grade {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let words = text.split { $0 == " " || $0 == "\n" }.count

        var score = 0
        var strengths: [String] = []
        var tips: [String] = []

        // 1) Enough detail to act on (0–30)
        if words >= 25 { score += 30; strengths.append("Detailed enough to act on") }
        else if words >= 12 { score += 18; tips.append("Add a bit more detail — what, where, and what 'done' looks like") }
        else { tips.append("Too short — describe the change in a sentence or two") }

        // 2) A concrete action verb (0–20)
        if actionVerbs.contains(where: { lower.contains($0) }) {
            score += 20; strengths.append("Clear action")
        } else {
            tips.append("Start with a concrete verb (extract, wrap, add, validate…)")
        }

        // 3) Names a target — a file, component, or place (0–25)
        if mentionsTarget(lower) {
            score += 25; strengths.append("Points at a specific place")
        } else {
            tips.append("Say where — name the file, component, or section to change")
        }

        // 4) States an outcome / acceptance ("so that", "should", "make sure") (0–25)
        if lower.contains("so that") || lower.contains("should") ||
           lower.contains("make sure") || lower.contains("without breaking") ||
           lower.contains("still work") {
            score += 25; strengths.append("Describes the desired outcome")
        } else {
            tips.append("Add the outcome — what should be true when it's done")
        }

        score = min(100, score)
        return Grade(score: score, letter: letter(for: score),
                     strengths: strengths, tips: tips)
    }

    private static func mentionsTarget(_ lower: String) -> Bool {
        if lower.contains(".tsx") || lower.contains(".ts") || lower.contains(".js")
            || lower.contains("file") || lower.contains("component")
            || lower.contains("function") || lower.contains("section")
            || lower.contains("form") || lower.contains("page") { return true }
        return false
    }

    private static func letter(for score: Int) -> String {
        switch score {
        case 90...: return "S"
        case 75..<90: return "A"
        case 60..<75: return "B"
        case 40..<60: return "C"
        default: return "D"
        }
    }
}
