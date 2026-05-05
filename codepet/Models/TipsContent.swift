import Foundation

/// A pet-specialized vibe-coding skill tile shown in the Tips tab.
struct TipSkillTile {
    let icon: String   // SF Symbol name
    let title: String
    let hint: String
}

/// State shown next to each setup row.
enum TipSetupState: String {
    case done, warning, missing

    /// SF Symbol for the status indicator. View layer maps to a color.
    var icon: String {
        switch self {
        case .done:    return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .missing: return "circle"
        }
    }
}

/// A pet-specialized "Your setup" row.
struct TipSetupItem {
    let title: String
    let status: String
    let state: TipSetupState
    let actionLabel: String?
}

/// A pet-specialized "Recommended reading" entry.
struct TipReadingItem {
    let title: String
    let author: String
    let kind: String
    let why: String
}

/// Per-pet content for the Tips tab. Each pet represents a discipline, and
/// the Tips section dives deep into that discipline.
///
/// Lookup pattern: `TipsContent.tipSkillsByPet[appState.activeChar] ?? defaultTiles`.
/// Pet without an entry falls back to the original default tiles in the view.
struct TipsContent {

    static let tipSkillsByPet: [String: [TipSkillTile]] = [

        // Crash — Backend Dev (tough-love hype)
        "crash": [
            TipSkillTile(
                icon: "arrow.clockwise",
                title: "Idempotent endpoints",
                hint: "Make POST safe to retry. Network drops shouldn't double-charge users."
            ),
            TipSkillTile(
                icon: "server.rack",
                title: "Database transactions",
                hint: "Wrap multi-step writes. One failure shouldn't leave data half-baked."
            ),
            TipSkillTile(
                icon: "clock.arrow.circlepath",
                title: "Background jobs",
                hint: "Anything slow goes in a queue. Block the user, lose the user."
            ),
            TipSkillTile(
                icon: "gauge.high",
                title: "API rate limiting",
                hint: "Protect prod from abuse — and yourself from runaway scripts."
            ),
        ],

        // Nova — Frontend Dev (fiery / fast)
        "nova": [
            TipSkillTile(
                icon: "square.on.square",
                title: "Component composition",
                hint: "Small reusable pieces beat one giant component every time."
            ),
            TipSkillTile(
                icon: "exclamationmark.triangle",
                title: "Loading & error states",
                hint: "Every async call needs a spinner and a fallback. No exceptions."
            ),
            TipSkillTile(
                icon: "checkmark.rectangle.stack",
                title: "Form validation UX",
                hint: "Be helpful, not pedantic. Validate as users type, not on submit."
            ),
            TipSkillTile(
                icon: "figure.walk",
                title: "Accessibility basics",
                hint: "Keyboard nav, contrast, alt text. A11y is shipping, not extra."
            ),
        ],

        // Luna — Designer / UX-UI (warm / creative)
        "luna": [
            TipSkillTile(
                icon: "ruler",
                title: "Spacing & rhythm",
                hint: "Pick a 4 or 8 px scale. Use it everywhere. Consistency is invisible kindness."
            ),
            TipSkillTile(
                icon: "textformat.size",
                title: "Type hierarchy",
                hint: "Three sizes max in one screen. Big, medium, small. That's it."
            ),
            TipSkillTile(
                icon: "circle.lefthalf.filled",
                title: "Color contrast",
                hint: "Body text needs 4.5:1 against background. Test it, don't eyeball it."
            ),
            TipSkillTile(
                icon: "tray",
                title: "Empty states",
                hint: "Every list has zero. Design that view as carefully as the full one."
            ),
        ],

        // Sage — Product Owner (zen / methodical)
        "sage": [
            TipSkillTile(
                icon: "checkmark.seal",
                title: "Define done, not features",
                hint: "Done is testable. 'Feature' is wishful. Spec the proof, not the work."
            ),
            TipSkillTile(
                icon: "person.text.rectangle",
                title: "User stories",
                hint: "As a [who], I [want] so I [outcome]. Missing the 'so' is where scope drifts."
            ),
            TipSkillTile(
                icon: "scissors",
                title: "Cut scope, not quality",
                hint: "When pressed, drop features. Quality is non-negotiable."
            ),
            TipSkillTile(
                icon: "person.3",
                title: "Stakeholder triage",
                hint: "Know who decides, who advises, who's just informed. Don't confuse the three."
            ),
        ],

        // Glitch — DevOps (punk / rebel)
        "glitch": [
            TipSkillTile(
                icon: "doc.text.below.ecg",
                title: "Infra as code",
                hint: "If it can't be reproduced from a repo, it's not infrastructure. It's a wish."
            ),
            TipSkillTile(
                icon: "arrow.triangle.2.circlepath",
                title: "CI/CD pipelines",
                hint: "Red on main = nothing else moves until it's green. No exceptions."
            ),
            TipSkillTile(
                icon: "list.bullet.indent",
                title: "Logs > metrics > alerts",
                hint: "Log everything, measure what matters, alert only on what wakes someone."
            ),
            TipSkillTile(
                icon: "exclamationmark.triangle.fill",
                title: "Disaster recovery drills",
                hint: "Prod will fail. Practice it now or panic later. Pick one."
            ),
        ],

        // Byte — Data / ML (glitchy / fragments)
        "byte": [
            TipSkillTile(
                icon: "square.grid.3x3",
                title: "Data quality first",
                hint: "Garbage in, garbage out. 80% of effort goes on data, 20% on the model."
            ),
            TipSkillTile(
                icon: "chart.line.uptrend.xyaxis",
                title: "Train / val / test discipline",
                hint: "Three sets. Never touch test until the end. Touching it early is cheating."
            ),
            TipSkillTile(
                icon: "chart.bar.xaxis",
                title: "Eval beyond accuracy",
                hint: "Accuracy lies on imbalanced data. Use precision, recall, F1, AUC."
            ),
            TipSkillTile(
                icon: "drop.fill",
                title: "Feature pipelines",
                hint: "If you can't reproduce features, you can't reproduce results."
            ),
        ],

        // Zero — QA / Testing (minimal / terse)
        "zero": [
            TipSkillTile(
                icon: "triangle",
                title: "Test pyramid",
                hint: "Many unit. Few integration. Fewer e2e. Never invert."
            ),
            TipSkillTile(
                icon: "exclamationmark.octagon",
                title: "Edge cases",
                hint: "Zero. Null. Max. Negative. Empty string. Test those before the happy path."
            ),
            TipSkillTile(
                icon: "square.split.2x1",
                title: "Test data isolation",
                hint: "Each test owns its data. Shared fixtures are bugs waiting."
            ),
            TipSkillTile(
                icon: "eye",
                title: "Behavior over implementation",
                hint: "Test what code does, not how. Refactor without breaking tests."
            ),
        ],

        // Null — Mobile Dev (chaotic / silly)
        "null": [
            TipSkillTile(
                icon: "battery.50",
                title: "Battery & network awareness",
                hint: "Background tasks drain users. Network calls drain trust. Both = uninstall."
            ),
            TipSkillTile(
                icon: "bell.badge",
                title: "Push notification etiquette",
                hint: "Notify only when it's about THEM. Marketing pings = settings off."
            ),
            TipSkillTile(
                icon: "wifi.slash",
                title: "Offline-first patterns",
                hint: "Assume the network is gone. Design for it. Online is a bonus."
            ),
            TipSkillTile(
                icon: "shippingbox",
                title: "App size discipline",
                hint: "Every MB is a download barrier. Strip assets, lazy-load, ship lean."
            ),
        ],
    ]

    // MARK: - Setup section per pet

    static let tipSetupByPet: [String: [TipSetupItem]] = [
        "crash": [
            TipSetupItem(title: "Postgres database",       status: "Connected · prod schema synced", state: .done,    actionLabel: nil),
            TipSetupItem(title: "Redis cache layer",       status: "Hit ratio 47% — investigate",    state: .warning, actionLabel: "Tune"),
            TipSetupItem(title: "Background job queue",    status: "Not configured — block-and-wait", state: .missing, actionLabel: "Set up"),
            TipSetupItem(title: "API monitoring",          status: "No latency dashboard wired",     state: .missing, actionLabel: "Wire it"),
        ],
        "nova": [
            TipSetupItem(title: "Storybook",               status: "Running · 4 components catalogued", state: .done,    actionLabel: nil),
            TipSetupItem(title: "Lighthouse CI",           status: "LCP 3.2s — over budget",           state: .warning, actionLabel: "Optimize"),
            TipSetupItem(title: "Visual regression suite", status: "No screenshot baseline",           state: .missing, actionLabel: "Capture"),
            TipSetupItem(title: "Bundle analyzer",         status: "Last run: never",                  state: .missing, actionLabel: "Run now"),
        ],
        "luna": [
            TipSetupItem(title: "Figma library",           status: "Linked · 47 components",           state: .done,    actionLabel: nil),
            TipSetupItem(title: "Design tokens export",    status: "Out of sync · 3 tokens drifted",   state: .warning, actionLabel: "Re-sync"),
            TipSetupItem(title: "Accessibility audit",     status: "No WCAG check this cycle",         state: .missing, actionLabel: "Audit"),
            TipSetupItem(title: "Brand voice guide",       status: "Tone doc not written",             state: .missing, actionLabel: "Draft"),
        ],
        "sage": [
            TipSetupItem(title: "Product spec doc",        status: "Linked · last updated yesterday",  state: .done,    actionLabel: nil),
            TipSetupItem(title: "North-star metric",       status: "Defined but not instrumented",     state: .warning, actionLabel: "Instrument"),
            TipSetupItem(title: "User research log",       status: "0 interviews this quarter",        state: .missing, actionLabel: "Schedule"),
            TipSetupItem(title: "Roadmap snapshot",        status: "No public version",                state: .missing, actionLabel: "Publish"),
        ],
        "glitch": [
            TipSetupItem(title: "Terraform state",         status: "S3 backend · locked",              state: .done,    actionLabel: nil),
            TipSetupItem(title: "CI pipeline",             status: "Avg 14m — over 10m budget",        state: .warning, actionLabel: "Profile"),
            TipSetupItem(title: "On-call runbook",         status: "Empty · no incident playbook",     state: .missing, actionLabel: "Write"),
            TipSetupItem(title: "Chaos drill schedule",    status: "Last drill: never",                state: .missing, actionLabel: "Plan"),
        ],
        "byte": [
            TipSetupItem(title: "Experiment tracker",      status: "MLflow · 23 runs logged",          state: .done,    actionLabel: nil),
            TipSetupItem(title: "Data versioning",         status: "DVC stale · last commit 9d ago",   state: .warning, actionLabel: "Re-snapshot"),
            TipSetupItem(title: "Feature store",           status: "Features re-derived per notebook", state: .missing, actionLabel: "Centralize"),
            TipSetupItem(title: "Model monitoring",        status: "No drift alerts in prod",          state: .missing, actionLabel: "Wire alerts"),
        ],
        "zero": [
            TipSetupItem(title: "Unit test suite",         status: "1,847 tests · 94% pass",           state: .done,    actionLabel: nil),
            TipSetupItem(title: "Integration tests",       status: "Flaky rate 8% — over budget",      state: .warning, actionLabel: "Triage"),
            TipSetupItem(title: "E2E coverage",            status: "Critical paths untested",          state: .missing, actionLabel: "Cover"),
            TipSetupItem(title: "Test data fixtures",      status: "Shared · isolation drift",         state: .missing, actionLabel: "Isolate"),
        ],
        "null": [
            TipSetupItem(title: "Crashlytics",             status: "Connected · 99.7% crash-free",     state: .done,    actionLabel: nil),
            TipSetupItem(title: "App size budget",         status: "82MB — 8MB over budget",           state: .warning, actionLabel: "Trim"),
            TipSetupItem(title: "Background task audit",   status: "No drain measurement",             state: .missing, actionLabel: "Measure"),
            TipSetupItem(title: "Offline cache layer",     status: "Empty cache strategy",             state: .missing, actionLabel: "Define"),
        ],
    ]

    // MARK: - Reading section per pet

    static let tipReadingByPet: [String: [TipReadingItem]] = [
        "crash": [
            TipReadingItem(
                title: "Designing Data-Intensive Applications",
                author: "Martin Kleppmann",
                kind: "Book · 624 pages",
                why: "Chapters 5–7 on replication & consistency are the foundation every backend ships on."
            ),
            TipReadingItem(
                title: "The Twelve-Factor App",
                author: "12factor.net",
                kind: "Essay · 30 min",
                why: "Operational discipline that holds up across every stack. Re-read once a year."
            ),
        ],
        "nova": [
            TipReadingItem(
                title: "Refactoring UI",
                author: "Steve Schoger & Adam Wathan",
                kind: "Book · 220 pages",
                why: "Practical taste for engineers. Solves 90% of 'why does my UI look off' moments."
            ),
            TipReadingItem(
                title: "Inclusive Components",
                author: "Heydon Pickering",
                kind: "Series · 12 essays",
                why: "Accessible by default. Each essay is one component done right end-to-end."
            ),
        ],
        "luna": [
            TipReadingItem(
                title: "The Design of Everyday Things",
                author: "Don Norman",
                kind: "Book · 368 pages",
                why: "Affordances and signifiers — the language of why things feel right or wrong."
            ),
            TipReadingItem(
                title: "The Humane Interface",
                author: "Jef Raskin",
                kind: "Book · 256 pages",
                why: "Cognetics — design for human attention, not just human eyes. Surprisingly current."
            ),
        ],
        "sage": [
            TipReadingItem(
                title: "Inspired",
                author: "Marty Cagan",
                kind: "Book · 368 pages",
                why: "How great product teams really decide what to build. The anti-feature-factory bible."
            ),
            TipReadingItem(
                title: "Continuous Discovery Habits",
                author: "Teresa Torres",
                kind: "Book · 240 pages",
                why: "Make discovery a weekly habit, not a quarterly event. Concrete framework."
            ),
        ],
        "glitch": [
            TipReadingItem(
                title: "Site Reliability Engineering",
                author: "Google SRE Team",
                kind: "Book · 528 pages",
                why: "The SRE bible. Skip to error budgets and toil first. Skim the rest later."
            ),
            TipReadingItem(
                title: "The Phoenix Project",
                author: "Kim, Behr & Spafford",
                kind: "Novel · 432 pages",
                why: "DevOps as a story. Read it once and you'll spot the pattern in every org."
            ),
        ],
        "byte": [
            TipReadingItem(
                title: "Designing Machine Learning Systems",
                author: "Chip Huyen",
                kind: "Book · 386 pages",
                why: "End-to-end ML in production. Covers what courses skip — drift, monitoring, ops."
            ),
            TipReadingItem(
                title: "Hidden Technical Debt in ML Systems",
                author: "Sculley et al.",
                kind: "Paper · 9 pages",
                why: "Re-read every six months. Each time another section starts to land."
            ),
        ],
        "zero": [
            TipReadingItem(
                title: "The Art of Unit Testing",
                author: "Roy Osherove",
                kind: "Book · 296 pages",
                why: "Testable code is just well-designed code. The book makes the link explicit."
            ),
            TipReadingItem(
                title: "xUnit Test Patterns",
                author: "Gerard Meszaros",
                kind: "Book · 944 pages",
                why: "Reference, not cover-to-cover. The smell catalogue alone is worth it."
            ),
        ],
        "null": [
            TipReadingItem(
                title: "iOS App Architecture",
                author: "Chris Eidhof et al.",
                kind: "Book · 232 pages",
                why: "Patterns that survive 5+ year apps. MVVM, coordinators, DI in real practice."
            ),
            TipReadingItem(
                title: "Mobile UX Guidelines",
                author: "Nielsen Norman Group",
                kind: "Series · ~20 essays",
                why: "Touch targets, gestures, accessibility on small screens. Bookmarkable reference."
            ),
        ],
    ]

    // MARK: - Pet note bottom (1 string per pet)

    static let tipPetNoteByPet: [String: String] = [
        "crash":  "Caught two endpoints without idempotency keys yesterday. Won't bite us today, will bite us at scale. Worth a 30-min sweep.",
        "nova":   "Two components shipped without loading states this week. Users see blank screens for a beat before content. Quick wins on each.",
        "luna":   "I love the new empty state on the dashboard. The reset CTA in settings, though — color, weight, position all say 'don't tap me.' Worth a pass.",
        "sage":   "Three of the last five 'must-haves' didn't ship and weren't missed. Worth a retro on how the bar gets set — and by whom.",
        "glitch": "Three deploys this week needed manual touch. That's three bugs waiting in the gap between 'works on staging' and 'works on prod'.",
        "byte":   "Two notebooks shipped without a fixed seed this week. Results aren't reproducible. Past-you's findings are dead until you can re-run them.",
        "zero":   "Three tests changed this week to make them pass instead of fixing the bug. Worth flagging before the pattern compounds.",
        "null":   "Push permission asked on first launch this week — consent rate 11%. Try waiting until value is proven; usually 4× lift.",
    ]
}
