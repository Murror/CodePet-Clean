# Insights Tab - Learning Analytics Dashboard

## Overview

Replace the current InsightsView placeholder with a dashboard of 6 analytics cards. Two viewing modes: "Fun" (gamified, learner-facing) and "Details" (data-rich, parent/teacher-facing). Uses Swift Charts for visualizations and a new DailySnapshot model for time-series data.

## Target Users

- **Learners** (kids/teens): Fun mode with animated numbers, character comments, emoji grades
- **Parents/Teachers**: Details mode with charts, percentages, breakdowns

## Data Layer

### New Model: DailySnapshot

```swift
struct DailySnapshot: Codable, Identifiable {
    let id: UUID
    let date: Date
    let totalXP: Int
    let lessonsCompleted: Int   // cumulative count at time of snapshot
    let challengesCompleted: Int
    let streak: Int
    let reviewsDone: Int        // spaced repetition reviews done that day
}
```

### AppState Changes

- Add `dailySnapshots: [DailySnapshot]` array
- Add `checkAndUpdateSnapshot()` method:
  - Called on app open / when day changes
  - If no snapshot for today exists, create one from current state
  - If snapshot for today exists, update it with current values
  - Cap at 90 days (trim oldest entries)
- Persist via PersistenceManager using existing UserDefaults pattern

### No Other Model Changes

All other data already exists in AppState: totalXP, completedLessons, completedChallenges, streak, longestStreak, performanceHistory, weeklyStats, lessonReviewDates, lessonReviewCounts, currentTier, activeChar.

## Dashboard Cards

6 cards on a 2-column LazyVGrid.

### 1. XP Progress Card
- **Fun mode:** Animated XP number with count-up effect, level badge, character comment based on recent XP gain
- **Details mode:** Line chart (Swift Charts) showing XP over time from dailySnapshots

### 2. Streak Card
- **Fun mode:** Flame icon + current streak count, "longest streak" badge
- **Details mode:** Calendar dot grid showing active days from dailySnapshots

### 3. Skills Mastered Card
- **Fun mode:** Animated progress ring (completed/total lessons) with tier color
- **Details mode:** Bar chart breakdown per tier (e.g., Tier 1: 4/4, Tier 2: 2/4)

### 4. Weekly Activity Card
- **Fun mode:** Simple star rating (1-5) based on weekly activity, pet reaction
- **Details mode:** Bar chart showing lessons + challenges per day (last 7 days from dailySnapshots)

### 5. Tier Progress Card
- **Fun mode:** Current tier badge, % to next tier, character outfit preview
- **Details mode:** List of remaining skills needed to unlock next tier

### 6. Recent Performance Card
- **Fun mode:** Last 3 challenge scores with emoji grades (S/A/B/C/D/F)
- **Details mode:** Score trend line from performanceHistory using Swift Charts

## View Structure

```
Views/Insights/
├── InsightsView.swift          — main view: toggle + LazyVGrid
├── InsightCardView.swift       — reusable card wrapper (rounded rect, shadow, title)
├── XPProgressCard.swift
├── StreakCard.swift
├── SkillsMasteredCard.swift
├── WeeklyActivityCard.swift
├── TierProgressCard.swift
├── RecentPerformanceCard.swift
```

### Integration

- InsightsView uses `@EnvironmentObject appState` (same pattern as all other tabs)
- `@State var showDetailView: Bool = false` toggles Fun/Details
- Each card receives appState and showDetailView to render appropriate mode
- No changes needed to MainTabView — it already routes to InsightsView()
- Snapshot creation triggered in `checkAndUpdateSnapshot()` called from ContentView.onAppear or on Insights tab selection

### Swift Charts

Import `Charts` only in card files that need charts: XPProgressCard, SkillsMasteredCard, WeeklyActivityCard, RecentPerformanceCard.

## Character Integration

- Fun mode cards can show 1-line comment from active character
- Static function maps data conditions to comment strings:
  - streak > 5 → "{character} says: Impressive streak!"
  - XP gain today = 0 → "{character} says: Let's learn something today!"
  - etc.
- Uses `appState.activeChar` for character name

## Animations

- Cards fade in staggered using existing `.fadeUp()` modifier
- Progress ring animated fill via `.trim()` animation
- XP number count-up animation on first appear
- Reuse `SoundManager.shared.play(.tabSwitch)` for Fun/Details toggle
- No new sounds needed

## Empty States

- Day 1 with no data: cards show encouraging messages instead of empty charts
- Example: "Complete your first lesson to see progress here!"
- Each card handles its own empty state

## Technical Constraints

- macOS 13+ required for Swift Charts
- UserDefaults storage for dailySnapshots (90 day cap keeps size manageable)
- No external dependencies — Swift Charts is Apple-native
- Follow existing patterns: dark/light theme via ThemeManager, monospaced fonts for stats
