# Systems Thinking Insights — Design Spec

**Date:** 2026-04-08
**Branch:** feat-skill
**Status:** Approved

## Summary

Add 3 systems-thinking features inspired by Donella Meadows' *Thinking in Systems* to CodePet:

1. **Feedback Loop Card** — Insight card showing the user's active reinforcing and balancing feedback loops
2. **Resilience Score Card** — Insight card measuring learning resilience (consistency + recovery + review health)
3. **System Trap Alerts** — Reactive alerts via pet commentary on Home + summary card in Insights

## Architecture Decision

**Approach: AppState Extensions** — All new logic lives in `Models/AppState+SystemsThinking.swift` as computed properties and methods. No new managers or environment objects. Views read directly from `appState`. Consistent with existing codebase pattern.

## Files to Create

| File | Purpose |
|---|---|
| `Models/AppState+SystemsThinking.swift` | Resilience score, trap detection, feedback loop data |
| `Views/Insights/FeedbackLoopCard.swift` | Feedback Loop insight card |
| `Views/Insights/ResilienceCard.swift` | Resilience Score insight card |
| `Views/Insights/ActiveTrapsCard.swift` | System Trap summary card |

## Files to Modify

| File | Change |
|---|---|
| `Views/Insights/InsightsView.swift` | Add 3 new cards to grid |
| `Views/Home/HomeView.swift` | Inject trap messages into pet speech bubble rotation |

---

## Section 1: Data Model — AppState+SystemsThinking.swift

### Resilience Score

Computed property `resilienceScore: Int` (0–100):

```
resilienceScore = (consistency * 0.4) + (recoverySpeed * 0.3) + (reviewHealth * 0.3)
```

**Sub-components (each 0–100):**

- **consistencyScore**: Days with snapshot in last 30 days / 30 * 100
- **recoverySpeedScore**: Based on average gap length between active days. No gaps = 100. Formula: `max(0, 100 - (avgGapLength * 15))`
- **reviewHealthScore**: Skills reviewed on time / total skills due for review * 100. If no skills due = 100.

**Resilience Label** (computed `resilienceLabel: String`):
- 80+: "Deep Lake"
- 60–79: "Steady River"
- 40–59: "Mountain Stream"
- <40: "Morning Dew"

### System Trap Detection

```swift
enum SystemTrapType: String, CaseIterable {
    case driftToLowPerformance
    case successToSuccessful
    case shiftingBurden
}

struct SystemTrap {
    let type: SystemTrapType
    let severity: Double  // 0.0–1.0
    let detectedDate: Date
}
```

Computed property `activeTraps: [SystemTrap]`:

- **Drift to Low Performance**: Last 3+ performance entries have decreasing trend (each lower than previous)
- **Success to Successful**: In last 14 days, user only practiced skills from ≤2 tiers while having uncompleted skills in other tiers
- **Shifting Burden**: 3+ skills are overdue for review while user continues doing new challenges

### Feedback Loop Data

```swift
struct FeedbackLoopData {
    let reinforcingLoops: [FeedbackLoop]
    let balancingLoops: [FeedbackLoop]
}

struct FeedbackLoop {
    let name: String
    let description: String
    let strength: Double  // 0.0–1.0
    let isPositive: Bool
}
```

Computed property `feedbackLoops: FeedbackLoopData`:

**Reinforcing loops** (detected from data):
- "Learning Momentum" — XP trend increasing over last 7 days. Strength = normalized XP growth rate.
- "Streak Power" — Active streak > 3 days. Strength = min(1.0, streak / 14).
- "Skill Compound" — Completed 2+ skills in last 7 days. Strength = skills completed / 4.

**Balancing loops** (detected from data):
- "Energy Drain" — Pet energy < 40. Strength = (40 - energy) / 40.
- "Knowledge Decay" — 2+ skills overdue for review. Strength = overdue count / total completed.
- "Performance Plateau" — Last 5 performance scores within 5 points of each other. Strength based on variance.

---

## Section 2: Feedback Loop Card

**File:** `Views/Insights/FeedbackLoopCard.swift`

Uses `InsightCardView` wrapper with title "Feedback Loops" and icon `arrow.trianglehead.2.clockwise`.

### Fun Mode
- Shows strongest active reinforcing loop
- Flow diagram text: e.g., "Skills -> XP -> Level Up -> New Skills"
- Strength indicator: 1–5 filled dots
- Character-specific encouragement about the strongest loop

### Details Mode
- Lists ALL loops (reinforcing + balancing)
- Each loop: name, flow description, strength bar (horizontal fill)
- Reinforcing loops: character color
- Balancing loops: orange warning color (#FF8C00)
- Placeholder if <3 snapshots: "Complete a few days of learning to see your feedback loops."

---

## Section 3: Resilience Score Card

**File:** `Views/Insights/ResilienceCard.swift`

Uses `InsightCardView` wrapper with title "Resilience" and icon `shield.fill`.

### Fun Mode
- Large number: resilience score (0–100) in character color
- Capsule badge: resilience label ("Deep Lake", etc.)
- Character-specific commentary based on score range:
  - 80+: Positive reinforcement
  - 40–79: Encouraging, acknowledging progress
  - <40: Motivating to improve consistency

### Details Mode
- 3 horizontal progress bars:
  - "Consistency" — x/30 days — fill %
  - "Recovery" — speed rating — fill %
  - "Review Health" — x on track / total — fill %
- Bar colors: green (70+), orange (40–69), red (<40)
- Placeholder if <7 snapshots

---

## Section 4: System Trap Alerts

### 4A. Home Screen — Pet Speech Bubble

In `PetAreaView5`, add computed property `trapGreeting: String?` reading from `appState.activeTraps`.

When traps are active, interleave trap messages into greeting rotation: every 2 normal greetings, show 1 trap message.

**Character-specific trap messages** (stored in AppState extension, 8 characters x 3 traps = 24 messages):

| Trap | Example (Crash) | Example (Sage) | Example (Luna) |
|---|---|---|---|
| Drift to Low Performance | "Scores are slipping! Don't settle for 'good enough'!" | "I see a declining pattern. Pause and recalibrate." | "Recent scores are lower... but that's okay, let's improve together?" |
| Success to Successful | "You keep doing the easy skills! Level up already!" | "You're in the 'success to successful' trap. Try unfamiliar skills." | "I notice you keep returning to familiar skills... try branching out?" |
| Shifting Burden | "New challenges but no reviews? Your foundation is shaking!" | "Challenges are good, but reviews are being neglected. Rebalance." | "You're moving fast! Let's go back and review a bit, knowledge needs time." |

### 4B. Active Traps Card in Insights

**File:** `Views/Insights/ActiveTrapsCard.swift`

Uses `InsightCardView` wrapper with title "System Health" and icon `exclamationmark.triangle.fill`.

### Fun Mode
- No traps: "All Clear!" with green checkmark, pet says "System is clean!"
- Has traps: Count of active traps, name of most severe, character commentary

### Details Mode
- List of each active trap:
  - Trap name (English, systems terminology)
  - Short description in user's context
  - Severity dot (green/orange/red)
  - Suggested action: e.g., "Review your Tier 1 skills", "Try a skill you haven't practiced"
- No traps: "No system traps detected. Your learning patterns are healthy."

---

## Section 5: Integration

### InsightsView.swift

Add to existing LazyVGrid after the 6 current cards:
- `FeedbackLoopCard(showDetail: showDetail)` — position 7
- `ResilienceCard(showDetail: showDetail)` — position 8
- `ActiveTrapsCard(showDetail: showDetail)` — position 9

Total: 9 cards in 2-column grid (4.5 rows, last card alone on left).

### HomeView.swift

In `PetAreaView5`:
- Add computed `trapGreeting` that reads `appState.activeTraps` and returns character-specific message
- Interleave into existing greeting rotation: when `greetingIndex % 3 == 2` and traps exist, show trap message instead of normal greeting. This means every 3rd rotation shows a trap alert.
- Trap message selection: pick from `activeTraps` round-robin by `greetingIndex / 3 % activeTraps.count`
- No UI changes — only content expansion of speech bubble

### No Other Changes
- AppState.swift untouched (extension only)
- Existing cards untouched
- No new tabs
- Xcode project file needs new files added
