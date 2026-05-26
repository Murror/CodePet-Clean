# Dictionary tab — design

**Status:** Approved 2026-05-11. Implementation follows.

## Goal

Add a Dictionary tab that explains ~30 technical terms in an
education-first, easy-to-understand way. Browse-to-learn use case —
user opens the tab without a specific term in mind, picks a topic from
the sidebar, and reads through cards. Each card has a short definition
on the surface and a "Learn more" expander that reveals an analogy,
optional code example, and an optional "When to use" note.

## Non-goals

- No "favorite" / "viewed" state. The tab is pure reference.
- No AI generation. All content is static Swift literals so the tab
  works offline and ships without per-term API cost.
- No cross-tab "tap a word to look it up." A later iteration could add
  Skills/Reflection entry points; out of scope for MVP.
- No bilingual toggle. English-only for v1.
- No syntax-highlighted code. Plain monospaced block is enough at this
  scope.

## UX

Two-pane layout, mirroring the Reflection tab's sidebar-plus-content
shape so the user sees a familiar pattern.

```
┌─────────────────┬────────────────────────────────┐
│ DICTIONARY      │ [🔍 Search...]                 │
│                 │                                │
│ 🧱 Variables    │ ┌──────────────────────────┐   │
│ 🔧 Functions    │ │ Variable                 │   │
│ 🔀 Control Flow │ │ A named slot that holds  │   │
│ 🛠 Tools        │ │ a value.                 │   │
│ 🌐 Web Basics   │ │ Learn more ▾             │   │
│                 │ └──────────────────────────┘   │
│                 │ ┌──────────────────────────┐   │
│                 │ │ Constant                 │   │
│                 │ │ ...                      │   │
└─────────────────┴────────────────────────────────┘
```

**Sidebar (left, ~220pt)**

- One row per topic: SF Symbol icon + title.
- Selected row highlighted with the accent purple background; others
  hover to a faint surface tint.

**Content pane (right)**

- Search field at the top. Empty query → list scoped to selected topic.
  Non-empty query → filter terms across **all** topics by case-
  insensitive substring match on `title` + `shortDefinition`.
- Scrollable list of `DictionaryCard`s.
- Empty-state when the search returns nothing: "No matches for
  `<query>`."

**Card states**

Collapsed (default):

- Term title (`CodepetTheme.display(18)`)
- Short definition (`CodepetTheme.body(13)`, two lines max)
- "Learn more ▾" trailing-right button

Expanded:

- Analogy block, prefixed with the label "Analogy"
- If `codeExample != nil`: monospaced code block, no highlighting,
  light surface tint
- If `whenToUse != nil`: "When to use" labeled paragraph
- "Show less ▴" button replaces the trailing button

Expansion is per-card and per-session — no persistence. State held in
`@State private var expandedTermIds: Set<String>` on `DictionaryView`.

## Data model — `codepet/Models/DictionaryContent.swift`

```swift
struct DictionaryTopic: Identifiable, Hashable {
    let id: String        // slug, e.g. "variables"
    let title: String     // "Variables & Types"
    let icon: String      // SF Symbol name
}

struct DictionaryTerm: Identifiable, Hashable {
    let id: String                // slug, e.g. "pure-function"
    let topicId: String           // FK
    let title: String             // "Pure function"
    let shortDefinition: String   // 1–2 sentences shown on card
    let analogy: String           // everyday analogy paragraph
    let codeExample: String?
    let whenToUse: String?
}

enum DictionaryContent {
    static let topics: [DictionaryTopic] = [ ... ]
    static let terms:  [DictionaryTerm]  = [ ... ]
    static func terms(in topicId: String) -> [DictionaryTerm]
    static func search(_ query: String) -> [DictionaryTerm]
}
```

`search` is a pure function on the static arrays — no caching, no
indexing. 30 terms is well below any threshold where filtering matters.

## Content scope — MVP

5 topics × 6 terms = 30 entries.

| Topic                | Terms |
|----------------------|-------|
| Variables & Types    | Variable, Constant, String, Number, Boolean, Array |
| Functions            | Function, Parameter, Return value, Pure function, Side effect, Callback |
| Control Flow         | If/else, Loop, Iteration, Recursion, Conditional, Break/Continue |
| Tools                | Git, Commit, Branch, Pull request, Terminal, Package manager |
| Web Basics           | HTML, CSS, HTTP, API, JSON, Frontend vs Backend |

Each entry written for a beginner reader. Analogies prefer concrete
everyday objects (mailbox, recipe, light switch) over jargon.

## Views — `codepet/Views/Dictionary/`

- `DictionaryView.swift` — top-level container. Holds `selectedTopicId`,
  `searchQuery`, `expandedTermIds`. Renders sidebar + content pane.
- `DictionaryCard.swift` — single expandable card. Takes `term`,
  `isExpanded`, `onToggleExpand` closure. Pure view, no state inside.

Both views use `CodepetTheme` tokens (`primaryText`, `mutedText`,
`surface`, `cardRadius`, `display`, `body`) so the look matches the
rest of the app.

## Tab wiring

1. `codepet/Models/AppState.swift`
   - Add `case dictionary = "Dictionary"` to `Tab` enum.
   - Add `"book.fill"` to the `icon` switch.

2. `codepet/Views/MainTabView.swift`
   - Add `case .dictionary: DictionaryView()` to the body switch.
   - GameHUDBar is intentionally hidden for this tab (consistent with
     Reflection / Insights / Tips / Profile).

Because `Tab` is `CaseIterable` the SidebarNav loop picks up the new
case without code changes there.

## Files

| File | Action |
|------|--------|
| `codepet/Models/AppState.swift` | modify (1 case, 1 icon) |
| `codepet/Models/DictionaryContent.swift` | new |
| `codepet/Views/Dictionary/DictionaryView.swift` | new |
| `codepet/Views/Dictionary/DictionaryCard.swift` | new |
| `codepet/Views/MainTabView.swift` | modify (1 switch case) |

## Testing

Manual:

- Open app → tab "Dictionary" appears in sidebar at the bottom (just
  before Profile, following enum order).
- Click each topic → cards filter to that topic.
- Type in search → cards span all topics and filter live.
- Click "Learn more" on a card → expands; click "Show less" → collapses.
- Switch tab away and back → expansion state resets (intentional).
- Empty search result → empty-state message visible.

No unit tests planned for MVP. Content is static; the views are thin
wrappers around the static data. If filtering grows complex
(fuzzy / scoring), revisit.
