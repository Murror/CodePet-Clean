# Language Persona System — Design Spec

**Date:** 2026-04-28
**Author:** dominich (with Claude)
**Status:** Draft

## Goal

Add a **language persona** axis to Codepet so the same user-facing content can be rendered in three different voices:

| Persona | Audience | Language style |
|---|---|---|
| `student` | 13-year-old, never coded | Simple words, fun framing, school-like analogies |
| `productOwner` | Non-technical, business-focused | Outcome/value framing, no jargon |
| `developer` | Engineer, missing product mindset | Technical, default tone (matches existing copy) |

Initial scope is **test-driven**: a small but visible slice of content across **Sessions**, **Reflection**, and **Tips** must switch voices live when the user picks a persona in **Profile → Settings**. The mechanism must be cheap to extend later without touching unrelated code.

## Non-Goals

- Translating UI chrome (tab labels, buttons, navigation).
- Onboarding integration (a future step — the picker lives only in Profile for now).
- LLM-driven on-the-fly transformation.
- Companion AI dialogue, Home screen text, lesson content (`LessonContent.swift`), Insights — out of scope.
- Localization to other natural languages (Vietnamese, etc.) — orthogonal axis.

## Approach

**External registry with fallback.** All persona variants live in a new file `codepet/Models/PersonaContent.swift`. Existing data structs (`Skill`, `Challenge`, `ReflectionPrompt`, `SkillTile`, etc.) and existing data files (`SkillData.swift`, `ReflectionModels.swift`, `TipsMockupView.swift`) are **not modified**. Render sites do a lookup; if no entry exists for an item, the original `String` is used as fallback.

This keeps refactor scope small, makes pilot content additive (no risk of breaking unrelated screens), and lets us scale coverage at our own pace.

### Rejected alternatives

- **Replace `String` fields with `PersonaText` in existing structs.** Type-safe but forces every item to ship 3 variants on day 1 and ripples through hundreds of call sites. Too heavy for a test slice.
- **Per-persona twin files (`SkillData_Student.swift` …).** Triplicates the data layer; drift is inevitable.

## Design

### 1. Persona enum

New file: `codepet/Models/LanguagePersona.swift`

```swift
enum LanguagePersona: String, CaseIterable, Codable {
    case student
    case productOwner
    case developer

    var displayName: String {
        switch self {
        case .student:      return "Student"
        case .productOwner: return "Product Owner"
        case .developer:    return "Developer"
        }
    }

    var icon: String {
        switch self {
        case .student:      return "🎒"
        case .productOwner: return "💼"
        case .developer:    return "💻"
        }
    }

    var blurb: String {
        switch self {
        case .student:      return "Simple words, fun framing"
        case .productOwner: return "Business value, no jargon"
        case .developer:    return "Technical, default tone"
        }
    }
}
```

### 2. Wrapper struct

In the same file:

```swift
struct PersonaText {
    let student: String
    let productOwner: String
    let developer: String

    func value(for p: LanguagePersona) -> String {
        switch p {
        case .student:      return student
        case .productOwner: return productOwner
        case .developer:    return developer
        }
    }
}
```

### 3. AppState integration

In `codepet/Models/AppState.swift`:

- Add `@Published var languagePersona: LanguagePersona = .developer` (default = developer keeps current behavior unchanged for users who never switch).
- The existing `objectWillChange` debounced auto-save covers persistence.

In `codepet/Managers/PersistenceManager.swift`:

- Add key `static let languagePersona = "cp_languagePersona"`.
- In `save(_:)`: `defaults.set(state.languagePersona.rawValue, forKey: Key.languagePersona)`.
- In `load(into:)`: read the rawValue, fall back to `.developer` when absent or invalid. Place this read **outside** the `onboardingComplete` guard — persona is a device preference like dark mode, not onboarding state.
- Add `Key.languagePersona` to the `keysToPreserve` set in `clearProgress()` (it should survive a progress reset).

### 4. Content registry

New file: `codepet/Models/PersonaContent.swift`

```swift
struct PersonaContent {
    // Sessions / Skills
    static let skillName: [String: PersonaText] = [ /* ... */ ]
    static let skillDesc: [String: PersonaText] = [ /* ... */ ]

    // Sessions / Challenges
    static let challengeBrief:        [String: PersonaText] = [ /* ... */ ]
    static let challengePassFeedback: [String: PersonaText] = [ /* ... */ ]

    // Reflection — pilot covers only "today's" prompt, so no dictionary key needed yet.
    // ReflectionPrompt has no `id` field today, so future expansion will require either
    // adding one or keying by a synthetic day identifier; out of scope for the pilot.
    static let reflectionTodayHeadline: PersonaText? = /* ... */
    static let reflectionTodayBody:     PersonaText? = /* ... */
    static let reflectionTodayProbe:    PersonaText? = /* ... */

    // Tips
    static let tipSkillHint: [String: PersonaText] = [ /* ... */ ]
    static let tipGuidanceBody: PersonaText? = /* ... */   // single block, no ID

    // Convenience helper
    static func resolve(
        _ table: [String: PersonaText],
        id: String,
        persona: LanguagePersona,
        fallback: String
    ) -> String {
        table[id]?.value(for: persona) ?? fallback
    }
}
```

Lookup IDs reuse the existing `id` fields on `Skill`, `Challenge`, and `ReflectionPrompt`. For the **Tips** SkillTile and "Today's guidance" block (which currently have no stable ID), the spec adds string keys derived from the existing `title` field — see Pilot Scope.

### 5. Profile → Settings picker

Add a new row to `SettingsSection` in `codepet/Views/Profile/ProfileView.swift` (around line 187, alongside the existing daily-goal row). Pattern matches the existing `showGoalPicker` popover (`ProfileView.swift:174` and `:208`):

```swift
@State private var showPersonaPicker = false

// row
Button { showPersonaPicker = true } label: {
    SettingsRow(
        icon: "text.bubble",
        label: "Language Style",
        value: appState.languagePersona.icon + " " + appState.languagePersona.displayName
    )
}
.popover(isPresented: $showPersonaPicker) {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(LanguagePersona.allCases, id: \.self) { p in
            Button {
                appState.languagePersona = p
                showPersonaPicker = false
            } label: {
                HStack {
                    Text(p.icon)
                    VStack(alignment: .leading) {
                        Text(p.displayName).bold()
                        Text(p.blurb).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if appState.languagePersona == p {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    .padding()
    .frame(width: 300)
}
```

Switching persona triggers `@Published` → all views observing `appState` re-render → text updates immediately. No app restart needed.

### 6. Render-site changes

Three small edits, one per area:

**Sessions** (`codepet/Views/Sessions/SessionsView.swift`)
At each site that renders `skill.name`, `skill.desc`, `challenge.brief`, `challenge.passFeedback`, replace the bare reference with:
```swift
PersonaContent.resolve(PersonaContent.skillName, id: skill.id,
                       persona: appState.languagePersona, fallback: skill.name)
```
(Add `@EnvironmentObject var appState: AppState` to any subview that doesn't already have it.)

**Reflection** (`codepet/Views/Reflection/ReflectionTab.swift`)
At the site that renders today's prompt headline / body / probe, render `PersonaContent.reflectionTodayHeadline?.value(for: appState.languagePersona) ?? prompt.headline` (and likewise for body / probe). Pilot only converts the "today" entry; other days fall through unchanged.

**Tips** (`codepet/Views/Tips/TipsMockupView.swift`)
- For the 4 `SkillTile.hint` rendered, use the tile's `title` as the lookup key (titles are stable and unique within the file).
- For the "Today's guidance" block, render `PersonaContent.tipGuidanceBody?.value(for: appState.languagePersona) ?? <existing literal>`.

### 7. Pilot content (test scope)

Hand-author **3 variants × the items below**. Anything else falls back to the original copy.

| Area | Items | Approx string count |
|---|---|---|
| Sessions — Skills | 4 Tier-1 (Molten Forge) skills × {name, desc} | 8 entries × 3 = 24 |
| Sessions — Challenges | 2 challenges × {brief, passFeedback} | 4 entries × 3 = 12 |
| Reflection | "Today's" prompt × {headline, body, probe} | 3 entries × 3 = 9 |
| Tips — Skills | 4 SkillTile hints | 4 entries × 3 = 12 |
| Tips — Today's guidance | 1 body block | 1 entry × 3 = 3 |
| **Total** | | **~60 strings** |

Specific Tier-1 skill IDs and challenge IDs to be confirmed against `SkillData.swift` during plan/implementation phase — the spec commits to "first 4 skills under tier 1" and "first 2 challenges under tier 1", whatever they happen to be.

## Data flow

```
User taps Profile → Language Style → picks Student
        │
        ▼
appState.languagePersona = .student
        │
        ├──► objectWillChange fires → SwiftUI re-renders
        │
        └──► debounced 2s → PersistenceManager.save → UserDefaults

Render time:
View reads PersonaContent.skillName[id]?.value(for: appState.languagePersona)
    ├─ entry exists → student variant string
    └─ entry missing → falls back to skill.name (original)
```

## Error handling

- **Missing entry in registry**: silent fallback to original String. By design — pilot scope is partial.
- **Corrupt persistence value** (`UserDefaults` returns a string that doesn't match any case): `LanguagePersona(rawValue: …) ?? .developer`.
- **No persona ever selected** (fresh install): default `.developer`. Existing copy is unchanged for never-switching users.

## Testing

Manual, since this is UI/content work:

1. Fresh install → confirm default is `developer` and copy matches today's app.
2. Profile → Language Style → pick `student`. Navigate to Sessions, Reflection, Tips. Confirm the pilot items show student variants and non-pilot items still read in the developer voice (fallback works).
3. Pick `productOwner` → confirm the same pilot items show PO variants.
4. Force-quit and relaunch → confirm the chosen persona persists.
5. Trigger `clearProgress()` (if reachable from Profile reset) → confirm persona survives, since it's a device preference.

No automated tests planned for the pilot. If the persona system survives the pilot review, a follow-up plan can add unit tests over `PersonaText.value(for:)` and `PersonaContent.resolve(…)`.

## Out-of-scope follow-ups (for awareness, not this spec)

- Onboarding step that auto-selects persona (`<16 → student`, etc.).
- Expanding pilot to all 16 skills, 20 challenges, full reflection corpus, all tips.
- Companion AI dialogue persona variants.
- LLM-driven transformation for long-form lesson content.
- Cloud sync of `languagePersona` via `CloudSyncService` (currently local-only).
