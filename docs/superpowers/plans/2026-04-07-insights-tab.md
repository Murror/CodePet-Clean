# Insights Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the InsightsView placeholder with a 6-card learning analytics dashboard supporting Fun/Details toggle, powered by Swift Charts and a new DailySnapshot history model.

**Architecture:** DailySnapshot model added to AppState for time-series data, persisted via PersistenceManager. InsightsView renders a 2-column LazyVGrid of 6 card views, each with two rendering modes toggled by a shared Bool. Swift Charts used for line/bar charts in Details mode.

**Tech Stack:** SwiftUI, Swift Charts (import Charts), UserDefaults persistence

---

### Task 1: DailySnapshot Model & AppState Integration

**Files:**
- Modify: `Models/AppState.swift:244-254` (add DailySnapshot struct after WeeklyStats)
- Modify: `Models/AppState.swift:38-41` (add dailySnapshots property)
- Modify: `Models/AppState.swift:84-100` (call snapshot check in init)

- [ ] **Step 1: Add DailySnapshot struct to AppState.swift**

Add after the `PerformanceEntry` struct (line 250):

```swift
struct DailySnapshot: Codable, Identifiable {
    let id: UUID
    let date: Date
    var totalXP: Int
    var lessonsCompleted: Int
    var challengesCompleted: Int
    var streak: Int
    var reviewsDone: Int
}
```

- [ ] **Step 2: Add dailySnapshots property to AppState**

Add after `lessonReviewCounts` (line 40):

```swift
    @Published var dailySnapshots: [DailySnapshot] = []
```

- [ ] **Step 3: Add checkAndUpdateSnapshot method to AppState**

Add after the `markReviewed` method (line 181):

```swift
    // MARK: - Daily Snapshots

    func checkAndUpdateSnapshot() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let idx = dailySnapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            // Update today's snapshot with current values
            dailySnapshots[idx].totalXP = totalXP
            dailySnapshots[idx].lessonsCompleted = completedLessons.count
            dailySnapshots[idx].challengesCompleted = completedChallenges.count
            dailySnapshots[idx].streak = streak
        } else {
            // Create new snapshot for today
            let snapshot = DailySnapshot(
                id: UUID(),
                date: today,
                totalXP: totalXP,
                lessonsCompleted: completedLessons.count,
                challengesCompleted: completedChallenges.count,
                streak: streak,
                reviewsDone: 0
            )
            dailySnapshots.append(snapshot)

            // Trim to 90 days
            if dailySnapshots.count > 90 {
                dailySnapshots = Array(dailySnapshots.suffix(90))
            }
        }
    }

    func incrementTodayReviews() {
        let calendar = Calendar.current
        if let idx = dailySnapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            dailySnapshots[idx].reviewsDone += 1
        }
    }
```

- [ ] **Step 4: Call checkAndUpdateSnapshot in AppState.init**

Add after `syncTierToCompletedLessons()` call (line 91):

```swift
        checkAndUpdateSnapshot()
```

- [ ] **Step 5: Wire incrementTodayReviews into markReviewed**

In the existing `markReviewed` method, add at the end (after line 180):

```swift
        incrementTodayReviews()
```

- [ ] **Step 6: Add dailySnapshots to resetProgress**

In `resetProgress()` (line 212), add:

```swift
        dailySnapshots = []
```

- [ ] **Step 7: Commit**

```bash
git add Models/AppState.swift
git commit -m "feat(insights): add DailySnapshot model and tracking to AppState"
```

---

### Task 2: Persistence for DailySnapshots

**Files:**
- Modify: `Managers/PersistenceManager.swift:10-43` (add key)
- Modify: `Managers/PersistenceManager.swift:47-112` (save snapshots)
- Modify: `Managers/PersistenceManager.swift:117-207` (load snapshots)

- [ ] **Step 1: Add UserDefaults key**

Add inside `enum Key` (after line 42):

```swift
        static let dailySnapshots = "cp_dailySnapshots"
```

- [ ] **Step 2: Add save logic**

Add in `save(_:)` method, after the lessonReviewCounts block (after line 106):

```swift
        // Daily Snapshots
        if let data = try? JSONEncoder().encode(state.dailySnapshots) {
            defaults.set(data, forKey: Key.dailySnapshots)
        }
```

- [ ] **Step 3: Add load logic**

Add in `load(into:)` method, after the lessonReviewCounts block (after line 202):

```swift
        // Daily Snapshots
        if let data = defaults.data(forKey: Key.dailySnapshots),
           let snapshots = try? JSONDecoder().decode([DailySnapshot].self, from: data) {
            state.dailySnapshots = snapshots
        }
```

- [ ] **Step 4: Commit**

```bash
git add Managers/PersistenceManager.swift
git commit -m "feat(insights): persist DailySnapshots via UserDefaults"
```

---

### Task 3: InsightCardView (Reusable Card Wrapper)

**Files:**
- Create: `Views/Insights/InsightCardView.swift`

- [ ] **Step 1: Create InsightCardView**

```swift
import SwiftUI

struct InsightCardView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .textCase(.uppercase)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/InsightCardView.swift
git commit -m "feat(insights): add reusable InsightCardView wrapper"
```

---

### Task 4: XP Progress Card

**Files:**
- Create: `Views/Insights/XPProgressCard.swift`

- [ ] **Step 1: Create XPProgressCard**

```swift
import SwiftUI
import Charts

struct XPProgressCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var xpComment: String {
        let todayXP = todayXPGain
        if todayXP == 0 { return "\(character.name) says: Let's learn something today!" }
        if todayXP >= 100 { return "\(character.name) says: You're on fire! 🔥" }
        return "\(character.name) says: Nice progress!" 
    }

    private var todayXPGain: Int {
        guard let today = appState.dailySnapshots.last,
              Calendar.current.isDateInToday(today.date) else { return 0 }
        let yesterday = appState.dailySnapshots.dropLast().last
        return today.totalXP - (yesterday?.totalXP ?? 0)
    }

    var body: some View {
        InsightCardView(title: "XP Progress", icon: "star.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(appState.totalXP)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(character.color)
                    .contentTransition(.numericText())
                Text("XP")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }

            HStack(spacing: 6) {
                Text("Level \(appState.userLevel)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(character.color))
            }

            Text(xpComment)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                .italic()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.dailySnapshots.count < 2 {
            Text("Complete a few days of learning to see your XP trend.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            Chart(appState.dailySnapshots.suffix(30)) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.date, unit: .day),
                    y: .value("XP", snapshot.totalXP)
                )
                .foregroundStyle(character.color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", snapshot.date, unit: .day),
                    y: .value("XP", snapshot.totalXP)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [character.color.opacity(0.2), character.color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 120)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/XPProgressCard.swift
git commit -m "feat(insights): add XP Progress card with fun/detail modes"
```

---

### Task 5: Streak Card

**Files:**
- Create: `Views/Insights/StreakCard.swift`

- [ ] **Step 1: Create StreakCard**

```swift
import SwiftUI

struct StreakCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        InsightCardView(title: "Streak", icon: "flame.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("🔥")
                    .font(.system(size: 28))
                Text("\(appState.streak)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF8C00"))
                Text(appState.streak == 1 ? "day" : "days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }

            if appState.longestStreak > appState.streak {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#D4960A"))
                    Text("Best: \(appState.longestStreak) days")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                }
            } else if appState.streak > 0 {
                Text("You're at your best! 🏆")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let snapshots = appState.dailySnapshots.suffix(28)
        if snapshots.isEmpty {
            Text("Start learning to build your streak calendar.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // 4 weeks x 7 days grid
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let activeDates = Set(snapshots.map { calendar.startOfDay(for: $0.date) })

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<28, id: \.self) { offset in
                        let day = calendar.date(byAdding: .day, value: -(27 - offset), to: today)!
                        let isActive = activeDates.contains(day)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isActive ? character.color : Color(hex: "#F0EDE6"))
                            .frame(height: 14)
                    }
                }

                HStack {
                    Text("4 weeks ago")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/StreakCard.swift
git commit -m "feat(insights): add Streak card with calendar grid detail view"
```

---

### Task 6: Skills Mastered Card

**Files:**
- Create: `Views/Insights/SkillsMasteredCard.swift`

- [ ] **Step 1: Create SkillsMasteredCard**

```swift
import SwiftUI
import Charts

struct SkillsMasteredCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var totalSkills: Int {
        GameData.skillTiers.reduce(0) { $0 + $1.skills.count }
    }

    private var completedCount: Int {
        appState.completedLessons.count
    }

    private var progress: Double {
        totalSkills > 0 ? Double(completedCount) / Double(totalSkills) : 0
    }

    var body: some View {
        InsightCardView(title: "Skills Mastered", icon: "checkmark.seal.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(hex: "#F0EDE6"), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(character.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)

                Text("\(completedCount)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(character.color)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedCount) of \(totalSkills)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                Text("skills completed")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                Text("Tier \(appState.currentTier) — \(characterOutfits[appState.currentTier]?.name ?? "Starter")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(character.color)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let tierData = GameData.skillTiers.map { tier -> (name: String, completed: Int, total: Int, color: Color) in
            let done = tier.skills.filter { appState.completedLessons.contains($0.id) }.count
            return (name: tier.name, completed: done, total: tier.skills.count, color: tier.color)
        }

        Chart(tierData, id: \.name) { tier in
            BarMark(
                x: .value("Completed", tier.completed),
                y: .value("Tier", tier.name)
            )
            .foregroundStyle(tier.color)

            BarMark(
                x: .value("Remaining", tier.total - tier.completed),
                y: .value("Tier", tier.name)
            )
            .foregroundStyle(Color(hex: "#F0EDE6"))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .frame(height: 100)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/SkillsMasteredCard.swift
git commit -m "feat(insights): add Skills Mastered card with progress ring and tier chart"
```

---

### Task 7: Weekly Activity Card

**Files:**
- Create: `Views/Insights/WeeklyActivityCard.swift`

- [ ] **Step 1: Create WeeklyActivityCard**

```swift
import SwiftUI
import Charts

struct WeeklyActivityCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var activityStars: Int {
        let stats = appState.weeklyStats
        let total = stats.challengesDone + stats.skillsLearned
        if total >= 10 { return 5 }
        if total >= 7 { return 4 }
        if total >= 4 { return 3 }
        if total >= 2 { return 2 }
        if total >= 1 { return 1 }
        return 0
    }

    private var petReaction: String {
        switch activityStars {
        case 5: return "Amazing week! 🎉"
        case 4: return "Great job! 💪"
        case 3: return "Solid progress!"
        case 2: return "Getting started!"
        case 1: return "Keep it up!"
        default: return "Let's get going!"
        }
    }

    var body: some View {
        InsightCardView(title: "Weekly Activity", icon: "calendar") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < activityStars ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundColor(i < activityStars ? Color(hex: "#D4960A") : Color(hex: "#E0DDD6"))
                }
            }

            Text(petReaction)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                .italic()

            HStack(spacing: 12) {
                Label("\(appState.weeklyStats.skillsLearned) lessons", systemImage: "book.fill")
                Label("\(appState.weeklyStats.challengesDone) challenges", systemImage: "flag.fill")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let last7 = (0..<7).map { offset -> (day: String, date: Date) in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return (day: formatter.string(from: date), date: date)
        }

        let chartData = last7.map { item -> (day: String, lessons: Int, challenges: Int) in
            let snapshot = appState.dailySnapshots.first { calendar.isDate($0.date, inSameDayAs: item.date) }
            let prevSnapshot = appState.dailySnapshots.first {
                calendar.isDate($0.date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: item.date)!)
            }
            let lessonsToday = (snapshot?.lessonsCompleted ?? 0) - (prevSnapshot?.lessonsCompleted ?? 0)
            let challengesToday = (snapshot?.challengesCompleted ?? 0) - (prevSnapshot?.challengesCompleted ?? 0)
            return (day: item.day, lessons: max(0, lessonsToday), challenges: max(0, challengesToday))
        }

        if appState.dailySnapshots.count < 2 {
            Text("A few more days of learning and your weekly chart will appear here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            Chart {
                ForEach(chartData, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.lessons)
                    )
                    .foregroundStyle(character.color)
                    .position(by: .value("Type", "Lessons"))

                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.challenges)
                    )
                    .foregroundStyle(Color(hex: "#D4960A"))
                    .position(by: .value("Type", "Challenges"))
                }
            }
            .chartForegroundStyleScale([
                "Lessons": character.color,
                "Challenges": Color(hex: "#D4960A")
            ])
            .frame(height: 100)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/WeeklyActivityCard.swift
git commit -m "feat(insights): add Weekly Activity card with stars and daily bar chart"
```

---

### Task 8: Tier Progress Card

**Files:**
- Create: `Views/Insights/TierProgressCard.swift`

- [ ] **Step 1: Create TierProgressCard**

```swift
import SwiftUI

struct TierProgressCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var currentTierData: SkillTier? {
        GameData.skillTiers.first { $0.id == appState.currentTier }
    }

    private var tierProgress: (done: Int, total: Int) {
        guard let tier = currentTierData else { return (0, 0) }
        let done = tier.skills.filter { appState.completedLessons.contains($0.id) }.count
        return (done, tier.skills.count)
    }

    private var tierPercent: Int {
        let p = tierProgress
        guard p.total > 0 else { return 0 }
        return Int(Double(p.done) / Double(p.total) * 100)
    }

    var body: some View {
        InsightCardView(title: "Tier Progress", icon: "shield.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(characterOutfits[appState.currentTier]?.badge ?? "🥚")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tier \(appState.currentTier)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26"))
                    Text(currentTierData?.name ?? "")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(character.color)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#F0EDE6"))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(character.color)
                        .frame(width: geo.size.width * CGFloat(tierProgress.done) / max(CGFloat(tierProgress.total), 1))
                        .animation(.easeOut(duration: 0.6), value: tierProgress.done)
                }
            }
            .frame(height: 8)

            Text("\(tierPercent)% to next tier")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
        }
    }

    @ViewBuilder
    private var detailView: some View {
        guard let tier = currentTierData else { return }

        VStack(alignment: .leading, spacing: 6) {
            Text("Remaining in \(tier.name):")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))

            let remaining = tier.skills.filter { !appState.completedLessons.contains($0.id) }
            if remaining.isEmpty {
                Text("All skills completed! Ready for next tier.")
                    .font(.system(size: 12))
                    .foregroundColor(character.color)
                    .italic()
            } else {
                ForEach(remaining) { skill in
                    HStack(spacing: 6) {
                        Text(skill.icon)
                            .font(.system(size: 12))
                        Text(skill.name)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#2D2B26"))
                    }
                }
            }
        }
    }
}
```

Note: The `detailView` uses `guard let` with a return in `@ViewBuilder`. This requires wrapping in a `Group`:

Replace the `detailView` computed property with:

```swift
    @ViewBuilder
    private var detailView: some View {
        let tier = currentTierData
        VStack(alignment: .leading, spacing: 6) {
            if let tier = tier {
                Text("Remaining in \(tier.name):")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))

                let remaining = tier.skills.filter { !appState.completedLessons.contains($0.id) }
                if remaining.isEmpty {
                    Text("All skills completed! Ready for next tier.")
                        .font(.system(size: 12))
                        .foregroundColor(character.color)
                        .italic()
                } else {
                    ForEach(remaining) { skill in
                        HStack(spacing: 6) {
                            Text(skill.icon)
                                .font(.system(size: 12))
                            Text(skill.name)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#2D2B26"))
                        }
                    }
                }
            }
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/TierProgressCard.swift
git commit -m "feat(insights): add Tier Progress card with progress bar and remaining skills"
```

---

### Task 9: Recent Performance Card

**Files:**
- Create: `Views/Insights/RecentPerformanceCard.swift`

- [ ] **Step 1: Create RecentPerformanceCard**

```swift
import SwiftUI
import Charts

struct RecentPerformanceCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private func gradeEmoji(score: Int) -> String {
        if score >= 95 { return "S" }
        if score >= 85 { return "A" }
        if score >= 70 { return "B" }
        if score >= 55 { return "C" }
        if score >= 40 { return "D" }
        return "F"
    }

    private func gradeColor(score: Int) -> Color {
        if score >= 95 { return Color(hex: "#FFD700") }
        if score >= 85 { return Color(hex: "#6BCB77") }
        if score >= 70 { return Color(hex: "#4FC3F7") }
        if score >= 55 { return Color(hex: "#D4960A") }
        if score >= 40 { return Color(hex: "#FF8C00") }
        return Color(hex: "#E04040")
    }

    var body: some View {
        InsightCardView(title: "Recent Performance", icon: "chart.line.uptrend.xyaxis") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        let recent = appState.performanceHistory.suffix(3).reversed()
        if recent.isEmpty {
            Text("Complete challenges to see your scores here!")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(recent), id: \.skillId) { entry in
                    HStack(spacing: 8) {
                        Text(gradeEmoji(score: entry.score))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(gradeColor(score: entry.score))
                            .frame(width: 20)

                        Text(skillName(for: entry.skillId))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#2D2B26"))
                            .lineLimit(1)

                        Spacer()

                        Text("\(entry.score)%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let history = Array(appState.performanceHistory.suffix(10))
        if history.isEmpty {
            Text("Complete challenges to see your performance trend.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            Chart(history, id: \.skillId) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(character.color)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(character.color)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100])
            }
            .frame(height: 100)
        }
    }

    private func skillName(for id: String) -> String {
        for tier in GameData.skillTiers {
            if let skill = tier.skills.first(where: { $0.id == id }) {
                return skill.name
            }
        }
        return id
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/RecentPerformanceCard.swift
git commit -m "feat(insights): add Recent Performance card with grades and trend chart"
```

---

### Task 10: Main InsightsView Assembly

**Files:**
- Modify: `Views/Insights/InsightsView.swift` (full rewrite)

- [ ] **Step 1: Rewrite InsightsView**

Replace entire contents of `Views/Insights/InsightsView.swift`:

```swift
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDetail = false

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("◆ CODEPET")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(character.color)
                        Text("Insights")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color(hex: "#2D2B26"))
                        Text(showDetail ? "Detailed analytics for your learning journey." : "Your learning at a glance.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                    }

                    Spacer()

                    // Fun / Details toggle
                    HStack(spacing: 0) {
                        toggleButton(label: "Fun", isSelected: !showDetail) {
                            showDetail = false
                            SoundManager.shared.playTap()
                        }
                        toggleButton(label: "Details", isSelected: showDetail) {
                            showDetail = true
                            SoundManager.shared.playTap()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#F0EDE6"))
                    )
                }

                // Cards grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    XPProgressCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    StreakCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    SkillsMasteredCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    WeeklyActivityCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    TierProgressCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    RecentPerformanceCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                }
            }
            .padding(20)
        }
        .background(Color(hex: "#FBF9F1"))
        .onAppear {
            appState.checkAndUpdateSnapshot()
        }
    }

    private func toggleButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#2D2B26").opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? character.color : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InsightsView()
        .environmentObject(AppState())
}
```

- [ ] **Step 2: Commit**

```bash
git add Views/Insights/InsightsView.swift
git commit -m "feat(insights): rewrite InsightsView with 6-card dashboard and Fun/Details toggle"
```

---

### Task 11: Build Verification

**Files:** None (verification only)

- [ ] **Step 1: Build the project**

```bash
cd /Users/williamdominich/Documents/Murror/CodePet-Clean
xcodebuild -scheme CodePet-Clean -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Fix any build errors**

If there are compile errors, fix them in the relevant files and re-run the build.

- [ ] **Step 3: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix(insights): resolve build errors"
```
