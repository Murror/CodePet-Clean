# Systems Thinking Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3 systems-thinking features to CodePet: Feedback Loop Card, Resilience Score Card, and System Trap Alerts (Home + Insights).

**Architecture:** AppState extension (`AppState+SystemsThinking.swift`) holds all computation logic. Three new SwiftUI cards follow existing `InsightCardView` pattern. Home screen speech bubble rotation is extended to include trap messages.

**Tech Stack:** SwiftUI, Swift Charts, AppState/EnvironmentObject pattern

**Spec:** `docs/superpowers/specs/2026-04-08-systems-thinking-insights-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Models/AppState+SystemsThinking.swift` | Create | Resilience score, trap detection, feedback loops, trap messages |
| `Views/Insights/FeedbackLoopCard.swift` | Create | Feedback Loop insight card (Fun + Details) |
| `Views/Insights/ResilienceCard.swift` | Create | Resilience Score insight card (Fun + Details) |
| `Views/Insights/ActiveTrapsCard.swift` | Create | System Trap summary card (Fun + Details) |
| `Views/Insights/InsightsView.swift` | Modify | Add 3 new cards to grid |
| `Views/Home/HomeView.swift` | Modify | Inject trap messages into speech bubble rotation |
| `CodePet.xcodeproj/project.pbxproj` | Modify | Register 4 new files |

---

### Task 1: AppState+SystemsThinking.swift — Data Models & Resilience Score

**Files:**
- Create: `Models/AppState+SystemsThinking.swift`

- [ ] **Step 1: Create the extension file with data models and resilience score**

Create `Models/AppState+SystemsThinking.swift`:

```swift
import SwiftUI

// MARK: - Systems Thinking Data Models

enum SystemTrapType: String, CaseIterable {
    case driftToLowPerformance
    case successToSuccessful
    case shiftingBurden

    var name: String {
        switch self {
        case .driftToLowPerformance: return "Drift to Low Performance"
        case .successToSuccessful: return "Success to Successful"
        case .shiftingBurden: return "Shifting the Burden"
        }
    }

    var icon: String {
        switch self {
        case .driftToLowPerformance: return "arrow.down.right"
        case .successToSuccessful: return "arrow.triangle.2.circlepath"
        case .shiftingBurden: return "scalemass"
        }
    }

    var description: String {
        switch self {
        case .driftToLowPerformance:
            return "Your recent scores are trending downward. Small drops feel okay, but they compound over time."
        case .successToSuccessful:
            return "You keep practicing skills you're already good at, while avoiding weaker areas."
        case .shiftingBurden:
            return "You're doing new challenges but skipping reviews. New learning without reinforcement fades quickly."
        }
    }

    var suggestedAction: String {
        switch self {
        case .driftToLowPerformance:
            return "Retry a recent challenge and aim for a higher score."
        case .successToSuccessful:
            return "Try a skill you haven't practiced recently."
        case .shiftingBurden:
            return "Complete your overdue reviews before starting new challenges."
        }
    }
}

struct SystemTrap {
    let type: SystemTrapType
    let severity: Double  // 0.0–1.0
    let detectedDate: Date
}

struct FeedbackLoop {
    let name: String
    let description: String
    let strength: Double  // 0.0–1.0
    let isPositive: Bool
}

struct FeedbackLoopData {
    let reinforcingLoops: [FeedbackLoop]
    let balancingLoops: [FeedbackLoop]

    var strongestReinforcing: FeedbackLoop? {
        reinforcingLoops.max(by: { $0.strength < $1.strength })
    }
}

// MARK: - Resilience Score

extension AppState {

    /// Overall resilience score (0–100) combining consistency, recovery, and review health
    var resilienceScore: Int {
        let score = Double(consistencyScore) * 0.4
            + Double(recoverySpeedScore) * 0.3
            + Double(reviewHealthScore) * 0.3
        return Int(score.rounded())
    }

    /// Human-readable resilience label
    var resilienceLabel: String {
        switch resilienceScore {
        case 80...100: return "Deep Lake"
        case 60..<80: return "Steady River"
        case 40..<60: return "Mountain Stream"
        default: return "Morning Dew"
        }
    }

    /// Days with a snapshot in the last 30 days / 30 * 100
    var consistencyScore: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) else { return 0 }
        let recentDays = dailySnapshots.filter { $0.date >= thirtyDaysAgo }.count
        return min(100, recentDays * 100 / 30)
    }

    /// Based on average gap length between active days. No gaps = 100.
    var recoverySpeedScore: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) else { return 0 }

        let activeDates = dailySnapshots
            .filter { $0.date >= thirtyDaysAgo }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        guard activeDates.count >= 2 else {
            return activeDates.isEmpty ? 0 : 50
        }

        var totalGap = 0
        var gapCount = 0
        for i in 1..<activeDates.count {
            let gap = calendar.dateComponents([.day], from: activeDates[i - 1], to: activeDates[i]).day ?? 0
            if gap > 1 {
                totalGap += gap
                gapCount += 1
            }
        }

        if gapCount == 0 { return 100 }
        let avgGap = Double(totalGap) / Double(gapCount)
        return max(0, Int((100.0 - avgGap * 15.0).rounded()))
    }

    /// Skills reviewed on time / total skills due for review * 100
    var reviewHealthScore: Int {
        let completed = completedLessons
        guard !completed.isEmpty else { return 100 }

        let overdueCount = lessonsReadyForReview.count
        let onTrack = completed.count - overdueCount
        return max(0, min(100, onTrack * 100 / completed.count))
    }
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd /Users/williamdominich/Documents/Murror/CodePet-Clean && xcodebuild -project CodePet.xcodeproj -scheme CodePet -destination 'platform=macOS' build 2>&1 | tail -5`

Note: File must be added to Xcode project first (Task 6). For now just verify syntax is valid.

- [ ] **Step 3: Commit**

```bash
git add Models/AppState+SystemsThinking.swift
git commit -m "feat(systems): add resilience score computation to AppState extension"
```

---

### Task 2: AppState+SystemsThinking.swift — Trap Detection & Feedback Loops

**Files:**
- Modify: `Models/AppState+SystemsThinking.swift`

- [ ] **Step 1: Add trap detection logic**

Append to `Models/AppState+SystemsThinking.swift`:

```swift
// MARK: - System Trap Detection

extension AppState {

    /// Currently active system traps detected from user data
    var activeTraps: [SystemTrap] {
        var traps: [SystemTrap] = []

        if let trap = detectDriftToLowPerformance() { traps.append(trap) }
        if let trap = detectSuccessToSuccessful() { traps.append(trap) }
        if let trap = detectShiftingBurden() { traps.append(trap) }

        return traps
    }

    private func detectDriftToLowPerformance() -> SystemTrap? {
        let recent = performanceHistory.suffix(5)
        guard recent.count >= 3 else { return nil }

        let scores = recent.map(\.score)
        var declining = true
        for i in 1..<scores.count {
            if scores[i] >= scores[i - 1] {
                declining = false
                break
            }
        }

        guard declining else { return nil }

        let drop = Double(scores.first! - scores.last!) / 100.0
        return SystemTrap(
            type: .driftToLowPerformance,
            severity: min(1.0, drop * 2),
            detectedDate: Date()
        )
    }

    private func detectSuccessToSuccessful() -> SystemTrap? {
        // Check if user has uncompleted skills but only practices from limited tiers
        let allSkillIds = GameData.skillTiers.flatMap { $0.skills.map(\.id) }
        let uncompleted = allSkillIds.filter { !completedLessons.contains($0) }
        guard !uncompleted.isEmpty else { return nil }

        // Check recent performance — which tiers are being practiced
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 86400)
        let recentSkillIds = performanceHistory
            .filter { $0.date >= twoWeeksAgo }
            .map(\.skillId)

        guard !recentSkillIds.isEmpty else { return nil }

        let practicedTiers = Set(recentSkillIds.compactMap { skillId in
            GameData.skillTiers.first { tier in
                tier.skills.contains { $0.id == skillId }
            }?.id
        })

        let tiersWithUncompleted = Set(uncompleted.compactMap { skillId in
            GameData.skillTiers.first { tier in
                tier.skills.contains { $0.id == skillId }
            }?.id
        })

        // Trap: practicing from ≤2 tiers while ignoring tiers with uncompleted skills
        let neglectedTiers = tiersWithUncompleted.subtracting(practicedTiers)
        guard practicedTiers.count <= 2 && !neglectedTiers.isEmpty else { return nil }

        return SystemTrap(
            type: .successToSuccessful,
            severity: min(1.0, Double(neglectedTiers.count) / Double(GameData.skillTiers.count)),
            detectedDate: Date()
        )
    }

    private func detectShiftingBurden() -> SystemTrap? {
        let overdueCount = lessonsReadyForReview.count
        guard overdueCount >= 3 else { return nil }

        // Check if user is still doing new challenges despite overdue reviews
        let oneWeekAgo = Date().addingTimeInterval(-7 * 86400)
        let recentChallenges = performanceHistory.filter { $0.date >= oneWeekAgo }
        guard !recentChallenges.isEmpty else { return nil }

        return SystemTrap(
            type: .shiftingBurden,
            severity: min(1.0, Double(overdueCount) / Double(max(1, completedLessons.count))),
            detectedDate: Date()
        )
    }
}
```

- [ ] **Step 2: Add feedback loop detection logic**

Append to `Models/AppState+SystemsThinking.swift`:

```swift
// MARK: - Feedback Loop Detection

extension AppState {

    /// Detected feedback loops based on current user data
    var feedbackLoops: FeedbackLoopData {
        FeedbackLoopData(
            reinforcingLoops: detectReinforcingLoops(),
            balancingLoops: detectBalancingLoops()
        )
    }

    private func detectReinforcingLoops() -> [FeedbackLoop] {
        var loops: [FeedbackLoop] = []

        // Learning Momentum — XP trend increasing over last 7 days
        let recentSnapshots = dailySnapshots.suffix(7)
        if recentSnapshots.count >= 2 {
            let first = recentSnapshots.first!.totalXP
            let last = recentSnapshots.last!.totalXP
            let growth = last - first
            if growth > 0 {
                let strength = min(1.0, Double(growth) / 300.0)
                loops.append(FeedbackLoop(
                    name: "Learning Momentum",
                    description: "Skills → XP → Level Up → New Skills",
                    strength: strength,
                    isPositive: true
                ))
            }
        }

        // Streak Power — Active streak > 3 days
        if streak > 3 {
            loops.append(FeedbackLoop(
                name: "Streak Power",
                description: "Daily Practice → Streak → Motivation → More Practice",
                strength: min(1.0, Double(streak) / 14.0),
                isPositive: true
            ))
        }

        // Skill Compound — Completed 2+ skills in last 7 days
        let oneWeekAgo = Date().addingTimeInterval(-7 * 86400)
        let recentLessons = performanceHistory.filter { $0.date >= oneWeekAgo }
        let uniqueSkills = Set(recentLessons.map(\.skillId))
        if uniqueSkills.count >= 2 {
            loops.append(FeedbackLoop(
                name: "Skill Compound",
                description: "Multiple Skills → Cross-Pollination → Deeper Understanding",
                strength: min(1.0, Double(uniqueSkills.count) / 4.0),
                isPositive: true
            ))
        }

        return loops
    }

    private func detectBalancingLoops() -> [FeedbackLoop] {
        var loops: [FeedbackLoop] = []

        // Energy Drain — Pet energy < 40
        if petEnergy < 40 {
            loops.append(FeedbackLoop(
                name: "Energy Drain",
                description: "Low Energy → Low Mood → Less Practice → Lower Energy",
                strength: Double(40 - petEnergy) / 40.0,
                isPositive: false
            ))
        }

        // Knowledge Decay — 2+ skills overdue for review
        let overdueCount = lessonsReadyForReview.count
        if overdueCount >= 2 {
            loops.append(FeedbackLoop(
                name: "Knowledge Decay",
                description: "Skipped Reviews → Forgetting → Weaker Foundation → Harder Lessons",
                strength: min(1.0, Double(overdueCount) / Double(max(1, completedLessons.count))),
                isPositive: false
            ))
        }

        // Performance Plateau — Last 5 scores within 5 points of each other
        let recentScores = performanceHistory.suffix(5).map(\.score)
        if recentScores.count >= 5 {
            let minScore = recentScores.min() ?? 0
            let maxScore = recentScores.max() ?? 0
            if maxScore - minScore <= 5 {
                loops.append(FeedbackLoop(
                    name: "Performance Plateau",
                    description: "Same Difficulty → Same Score → No Growth Signal → Same Difficulty",
                    strength: 0.6,
                    isPositive: false
                ))
            }
        }

        return loops
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Models/AppState+SystemsThinking.swift
git commit -m "feat(systems): add trap detection and feedback loop logic"
```

---

### Task 3: AppState+SystemsThinking.swift — Character Trap Messages

**Files:**
- Modify: `Models/AppState+SystemsThinking.swift`

- [ ] **Step 1: Add character-specific trap messages**

Append to `Models/AppState+SystemsThinking.swift`:

```swift
// MARK: - Character-Specific Trap Messages

extension AppState {

    /// Get a trap alert message for the current character and a specific trap type
    func trapMessage(for trapType: SystemTrapType) -> String {
        let charId = activeChar
        let messages = Self.trapMessages[charId] ?? Self.trapMessages["byte"]!
        return messages[trapType] ?? "Something feels off in your learning pattern."
    }

    /// All character trap messages: [characterId: [trapType: message]]
    static let trapMessages: [String: [SystemTrapType: String]] = [
        "byte": [
            .driftToLowPerformance: "⚠️ *static* ...scores fragmenting. Pattern: decline. Recalibrate?",
            .successToSuccessful: "⚠️ You keep orbiting the same skills. There are unexplored sectors.",
            .shiftingBurden: "⚠️ New data in, old data fading. Reviews are your memory defrag.",
        ],
        "nova": [
            .driftToLowPerformance: "⚠️ Scores slipping! We're not here to coast — push harder!",
            .successToSuccessful: "⚠️ Comfort zone detected! Real growth is in the skills you avoid.",
            .shiftingBurden: "⚠️ All forward, no reinforcement? Go back and lock in what you learned!",
        ],
        "crash": [
            .driftToLowPerformance: "⚠️ Scores are dropping! Don't settle for 'good enough'!",
            .successToSuccessful: "⚠️ You keep doing easy stuff! Level up to something harder!",
            .shiftingBurden: "⚠️ New challenges but no reviews? Foundation is cracking!",
        ],
        "luna": [
            .driftToLowPerformance: "⚠️ Recent scores are a bit lower... no pressure, but let's improve together?",
            .successToSuccessful: "⚠️ I notice you keep returning to familiar skills... want to try something new?",
            .shiftingBurden: "⚠️ You're moving fast! Let's pause and review — knowledge needs time to settle.",
        ],
        "sage": [
            .driftToLowPerformance: "⚠️ I observe a declining pattern. Pause. Reflect. Then recalibrate.",
            .successToSuccessful: "⚠️ You're in the 'success to successful' trap. Diversify your practice.",
            .shiftingBurden: "⚠️ Challenges without reviews is building on sand. Rebalance.",
        ],
        "glitch": [
            .driftToLowPerformance: "⚠️ Scores going down? That's a bug in your process. Let's hack it.",
            .successToSuccessful: "⚠️ Same skills on repeat? Break the loop — try something weird!",
            .shiftingBurden: "⚠️ All new, nothing reviewed? Even hackers back up their data.",
        ],
        "zero": [
            .driftToLowPerformance: "⚠️ Declining. Inefficient. Fix.",
            .successToSuccessful: "⚠️ Repetition without variety. Suboptimal.",
            .shiftingBurden: "⚠️ Reviews overdue. New input without retention = waste.",
        ],
        "null": [
            .driftToLowPerformance: "⚠️ Uh oh, scores going brrr... downward! Let's reverse that chaos!",
            .successToSuccessful: "⚠️ You're stuck in a loop! I should know — I LIVE in loops!",
            .shiftingBurden: "⚠️ Reviews? What reviews? Oh... THOSE reviews. Yeah, do those.",
        ],
    ]
}
```

- [ ] **Step 2: Commit**

```bash
git add Models/AppState+SystemsThinking.swift
git commit -m "feat(systems): add character-specific trap messages for all 8 pets"
```

---

### Task 4: FeedbackLoopCard.swift

**Files:**
- Create: `Views/Insights/FeedbackLoopCard.swift`

- [ ] **Step 1: Create the Feedback Loop card**

Create `Views/Insights/FeedbackLoopCard.swift`:

```swift
import SwiftUI

struct FeedbackLoopCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var loopData: FeedbackLoopData {
        appState.feedbackLoops
    }

    var body: some View {
        InsightCardView(title: "Feedback Loops", icon: "arrow.trianglehead.2.clockwise") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        if let strongest = loopData.strongestReinforcing {
            VStack(alignment: .leading, spacing: 8) {
                Text(strongest.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(character.color)

                Text(strongest.description)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))

                // Strength dots
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < Int((strongest.strength * 5).rounded()) ? character.color : Color(hex: "#F0EDE6"))
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                }

                Text(loopComment)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No active loops yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                Text("Complete a few days of learning to see your feedback loops.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let allLoops = loopData.reinforcingLoops + loopData.balancingLoops
        if allLoops.isEmpty {
            Text("Complete a few days of learning to see your feedback loops.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(allLoops.enumerated()), id: \.offset) { _, loop in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(loop.isPositive ? character.color : Color(hex: "#FF8C00"))
                                .frame(width: 6, height: 6)
                            Text(loop.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                        }

                        Text(loop.description)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                        // Strength bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#F0EDE6"))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(loop.isPositive ? character.color : Color(hex: "#FF8C00"))
                                    .frame(width: geo.size.width * loop.strength, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
    }

    private var loopComment: String {
        let charId = appState.activeChar
        switch charId {
        case "crash": return "Loop is spinning hard! Don't stop!"
        case "sage": return "Good momentum. Maintain this rhythm."
        case "luna": return "Your loops are growing nicely~"
        case "nova": return "MOMENTUM! Keep feeding the loop!"
        case "glitch": return "Nice loop hack. Keep it running."
        case "zero": return "Efficient. Continue."
        case "null": return "Loops within loops! I love it!"
        default: return "Feedback loop detected... interesting."
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/FeedbackLoopCard.swift
git commit -m "feat(systems): add Feedback Loop insight card"
```

---

### Task 5: ResilienceCard.swift

**Files:**
- Create: `Views/Insights/ResilienceCard.swift`

- [ ] **Step 1: Create the Resilience Score card**

Create `Views/Insights/ResilienceCard.swift`:

```swift
import SwiftUI

struct ResilienceCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        InsightCardView(title: "Resilience", icon: "shield.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        if appState.dailySnapshots.count < 7 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Building...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                Text("Complete 7 days of learning to see your resilience score.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(appState.resilienceScore)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(character.color)
                        .contentTransition(.numericText())
                    Text("/ 100")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                }

                Text(appState.resilienceLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(character.color))

                Text(resilienceComment)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.dailySnapshots.count < 7 {
            Text("Complete 7 days of learning to see resilience details.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                resilienceBar(
                    label: "Consistency",
                    value: appState.consistencyScore,
                    detail: "\(appState.consistencyScore * 30 / 100)/30 days"
                )
                resilienceBar(
                    label: "Recovery",
                    value: appState.recoverySpeedScore,
                    detail: scoreLabel(appState.recoverySpeedScore)
                )
                resilienceBar(
                    label: "Review Health",
                    value: appState.reviewHealthScore,
                    detail: "\(appState.completedLessons.count - appState.lessonsReadyForReview.count)/\(appState.completedLessons.count) on track"
                )
            }
        }
    }

    private func resilienceBar(label: String, value: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                Spacer()
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "#F0EDE6"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: value))
                        .frame(width: geo.size.width * Double(value) / 100.0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func barColor(for value: Int) -> Color {
        switch value {
        case 70...100: return Color(hex: "#20B090")
        case 40..<70: return Color(hex: "#FF8C00")
        default: return Color(hex: "#E04040")
        }
    }

    private func scoreLabel(_ value: Int) -> String {
        switch value {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs work"
        }
    }

    private var resilienceComment: String {
        let score = appState.resilienceScore
        let charId = appState.activeChar
        if score >= 80 {
            switch charId {
            case "crash": return "Tank mode! Nothing can break you!"
            case "sage": return "Strong foundation. Continue."
            case "luna": return "Your resilience is beautiful~"
            case "nova": return "UNSTOPPABLE! Keep this energy!"
            case "glitch": return "System hardened. Impressive."
            case "zero": return "Optimal resilience. Efficient."
            case "null": return "Even chaos can't shake you!"
            default: return "Resilience core: stable."
            }
        } else if score >= 40 {
            switch charId {
            case "crash": return "Getting there! Toughen up!"
            case "sage": return "Building steadily. Patience."
            case "luna": return "Growing stronger each day, I believe in you!"
            case "nova": return "Not bad, but we can do better!"
            case "glitch": return "Half-patched. Keep going."
            case "zero": return "Suboptimal. Improve consistency."
            case "null": return "Wobbly but standing! That counts!"
            default: return "Building resilience... keep going."
            }
        } else {
            switch charId {
            case "crash": return "Fragile! We need to fix this NOW!"
            case "sage": return "Consistency is the path. Begin again."
            case "luna": return "It's okay to start small. I'm here with you."
            case "nova": return "We need to focus on consistency!"
            case "glitch": return "System vulnerable. Patch needed."
            case "zero": return "Critical. Focus on daily practice."
            case "null": return "Uh oh... but every journey starts somewhere!"
            default: return "Resilience low... let's build it up."
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/ResilienceCard.swift
git commit -m "feat(systems): add Resilience Score insight card"
```

---

### Task 6: ActiveTrapsCard.swift

**Files:**
- Create: `Views/Insights/ActiveTrapsCard.swift`

- [ ] **Step 1: Create the Active Traps card**

Create `Views/Insights/ActiveTrapsCard.swift`:

```swift
import SwiftUI

struct ActiveTrapsCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var traps: [SystemTrap] {
        appState.activeTraps
    }

    var body: some View {
        InsightCardView(title: "System Health", icon: "exclamationmark.triangle.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        if traps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#20B090"))
                    Text("All Clear!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#20B090"))
                }

                Text(allClearComment)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("⚠️")
                        .font(.system(size: 20))
                    Text("\(traps.count) trap\(traps.count == 1 ? "" : "s") detected")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#FF8C00"))
                }

                // Show most severe trap name
                if let worst = traps.max(by: { $0.severity < $1.severity }) {
                    Text(worst.type.name)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                }

                Text(appState.trapMessage(for: traps.first!.type).replacingOccurrences(of: "⚠️ ", with: ""))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if traps.isEmpty {
            Text("No system traps detected. Your learning patterns are healthy.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(traps.enumerated()), id: \.offset) { _, trap in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(severityColor(trap.severity))
                                .frame(width: 8, height: 8)
                            Image(systemName: trap.type.icon)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                            Text(trap.type.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                        }

                        Text(trap.type.description)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 9))
                                .foregroundColor(character.color)
                            Text(trap.type.suggestedAction)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(character.color)
                        }
                    }
                }
            }
        }
    }

    private func severityColor(_ severity: Double) -> Color {
        switch severity {
        case 0.7...1.0: return Color(hex: "#E04040")
        case 0.4..<0.7: return Color(hex: "#FF8C00")
        default: return Color(hex: "#20B090")
        }
    }

    private var allClearComment: String {
        switch appState.activeChar {
        case "crash": return "No traps! System is rock solid!"
        case "sage": return "Harmony in your learning patterns."
        case "luna": return "Everything looks healthy~ keep going!"
        case "nova": return "Clean system! Full speed ahead!"
        case "glitch": return "No bugs in the matrix today."
        case "zero": return "System clean. Optimal."
        case "null": return "No traps? That's... suspicious. Just kidding!"
        default: return "System health: nominal."
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/ActiveTrapsCard.swift
git commit -m "feat(systems): add Active Traps insight card"
```

---

### Task 7: Integrate cards into InsightsView

**Files:**
- Modify: `Views/Insights/InsightsView.swift`

- [ ] **Step 1: Add 3 new cards to the LazyVGrid**

In `Views/Insights/InsightsView.swift`, find the closing of the grid (after `RecentPerformanceCard`):

```swift
                    TierProgressCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    RecentPerformanceCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
```

Add after `RecentPerformanceCard`:

```swift
                    FeedbackLoopCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    ResilienceCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    ActiveTrapsCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/InsightsView.swift
git commit -m "feat(systems): add 3 systems-thinking cards to Insights grid"
```

---

### Task 8: Inject trap messages into Home speech bubble

**Files:**
- Modify: `Views/Home/HomeView.swift`

- [ ] **Step 1: Modify the greeting rotation to include trap messages**

In `Views/Home/HomeView.swift`, in `PetAreaView5`, find the `currentGreeting` computed property:

```swift
    var currentGreeting: String {
        guard !character.greeting.isEmpty else { return "Hello!" }
        return character.greeting[greetingIndex % character.greeting.count]
    }
```

Replace with:

```swift
    var currentGreeting: String {
        guard !character.greeting.isEmpty else { return "Hello!" }

        // Every 3rd rotation, show a trap message if traps exist
        let traps = appState.activeTraps
        if greetingIndex % 3 == 2 && !traps.isEmpty {
            let trapIndex = (greetingIndex / 3) % traps.count
            return appState.trapMessage(for: traps[trapIndex].type)
        }

        return character.greeting[greetingIndex % character.greeting.count]
    }
```

- [ ] **Step 2: Update the greeting rotation counter to not be limited by greeting count**

In the same file, find inside `startGreetingRotation()`:

```swift
                greetingIndex = (greetingIndex + 1) % max(1, character.greeting.count)
```

Replace with:

```swift
                greetingIndex += 1
                if greetingIndex > 999 { greetingIndex = 0 }  // prevent overflow
```

This allows `greetingIndex` to increment freely so the modulo-3 trap logic works correctly. The `currentGreeting` computed property handles the wrapping for both greetings and traps.

- [ ] **Step 3: Commit**

```bash
git add Views/Home/HomeView.swift
git commit -m "feat(systems): inject trap alerts into Home pet speech bubble"
```

---

### Task 9: Add new files to Xcode project

**Files:**
- Modify: `CodePet.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add 4 new files to the Xcode project**

In `CodePet.xcodeproj/project.pbxproj`, add the following entries.

**In PBXBuildFile section** (near lines 42–47, after existing entries):

```
		CC88888888888888AAAAAAAA /* AppState+SystemsThinking.swift in Sources */ = {isa = PBXBuildFile; fileRef = CC88888888888888BBBBBBBB /* AppState+SystemsThinking.swift */; };
		CC99999999999999AAAAAAAA /* FeedbackLoopCard.swift in Sources */ = {isa = PBXBuildFile; fileRef = CC99999999999999BBBBBBBB /* FeedbackLoopCard.swift */; };
		CCAAAAAAAAAAAAAAAAAAAAA1 /* ResilienceCard.swift in Sources */ = {isa = PBXBuildFile; fileRef = CCAAAAAAAAAAAAAAABBBBBB1 /* ResilienceCard.swift */; };
		CCBBBBBBBBBBBBBBAAAAAAAA /* ActiveTrapsCard.swift in Sources */ = {isa = PBXBuildFile; fileRef = CCBBBBBBBBBBBBBBBBBBBBBB /* ActiveTrapsCard.swift */; };
```

**In PBXFileReference section** (near lines 83–88, after existing entries):

```
		CC88888888888888BBBBBBBB /* AppState+SystemsThinking.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "AppState+SystemsThinking.swift"; sourceTree = "<group>"; };
		CC99999999999999BBBBBBBB /* FeedbackLoopCard.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FeedbackLoopCard.swift; sourceTree = "<group>"; };
		CCAAAAAAAAAAAAAAABBBBBB1 /* ResilienceCard.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ResilienceCard.swift; sourceTree = "<group>"; };
		CCBBBBBBBBBBBBBBBBBBBBBB /* ActiveTrapsCard.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ActiveTrapsCard.swift; sourceTree = "<group>"; };
```

**In PBXGroup for Models** (the group with id `4980E6A74034910D82E43ABA`), add after `SkillData.swift`:

```
				CC88888888888888BBBBBBBB /* AppState+SystemsThinking.swift */,
```

**In PBXGroup for Insights** (the group with id `1BEDEA48AE5B89586AC3E340`), add after `RecentPerformanceCard.swift`:

```
				CC99999999999999BBBBBBBB /* FeedbackLoopCard.swift */,
				CCAAAAAAAAAAAAAAABBBBBB1 /* ResilienceCard.swift */,
				CCBBBBBBBBBBBBBBBBBBBBBB /* ActiveTrapsCard.swift */,
```

**In PBXSourcesBuildPhase** (near lines 353–358), add:

```
				CC88888888888888AAAAAAAA /* AppState+SystemsThinking.swift in Sources */,
				CC99999999999999AAAAAAAA /* FeedbackLoopCard.swift in Sources */,
				CCAAAAAAAAAAAAAAAAAAAAA1 /* ResilienceCard.swift in Sources */,
				CCBBBBBBBBBBBBBBAAAAAAAA /* ActiveTrapsCard.swift in Sources */,
```

- [ ] **Step 2: Verify the project builds**

Run: `cd /Users/williamdominich/Documents/Murror/CodePet-Clean && xcodebuild -project CodePet.xcodeproj -scheme CodePet -destination 'platform=macOS' build 2>&1 | tail -20`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add CodePet.xcodeproj/project.pbxproj
git commit -m "fix(xcode): add systems thinking files to Xcode project"
```

---

### Task 10: Final build verification

- [ ] **Step 1: Clean build**

Run: `cd /Users/williamdominich/Documents/Murror/CodePet-Clean && xcodebuild -project CodePet.xcodeproj -scheme CodePet -destination 'platform=macOS' clean build 2>&1 | tail -20`

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Verify all new files exist**

Run: `ls -la Models/AppState+SystemsThinking.swift Views/Insights/FeedbackLoopCard.swift Views/Insights/ResilienceCard.swift Views/Insights/ActiveTrapsCard.swift`

Expected: All 4 files listed

- [ ] **Step 3: Final commit if any fixes needed**

If build errors occurred, fix them and commit:

```bash
git add -A
git commit -m "fix(systems): resolve build issues for systems thinking features"
```
