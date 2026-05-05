import Foundation

// MARK: - Sources

enum EventSource: String, Codable, CaseIterable {
    case cursorChat = "Cursor chat"
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case manualLog = "Manual log"
}

// MARK: - Triggers

struct TriggerTag: Hashable, Identifiable {
    var id: String { code }
    let code: String          // "T1"
    let label: String         // "Scope creep"
    let confidence: Double    // 0.0 – 1.0
}

// MARK: - Events

struct CapturedEvent: Identifiable, Hashable {
    let id: UUID
    let time: String          // "14:15"
    let source: EventSource
    let text: String          // user's prompt (cursor chat) or AI action (claude code)
    let aiSummary: String?    // short summary of AI's response — only populated for cursor chat
    let trigger: TriggerTag?
    let context: String?      // pet's narrative observation — shown on expand
    let isManualLog: Bool

    init(
        id: UUID = UUID(),
        time: String,
        source: EventSource,
        text: String,
        aiSummary: String? = nil,
        trigger: TriggerTag? = nil,
        context: String? = nil,
        isManualLog: Bool = false
    ) {
        self.id = id
        self.time = time
        self.source = source
        self.text = text
        self.aiSummary = aiSummary
        self.trigger = trigger
        self.context = context
        self.isManualLog = isManualLog
    }
}

// MARK: - Patterns

enum PatternTrend {
    case up, down, flat, new
}

struct PatternSummary: Identifiable, Hashable {
    var id: String { triggerCode }
    let triggerCode: String   // "T1"
    let label: String         // "Scope creep"
    let count: Int
    let deltaText: String     // "+2 vs last week"
    let trend: PatternTrend
}

// MARK: - Reflection prompt

struct ReflectionPrompt: Hashable {
    let headline: String
    let body: String
    let probe: String
    let sourceCitation: String
}

// MARK: - Mood

enum PetMood: String {
    case calm, engaged, alert

    static func derive(risks: Int, decisions: Int) -> PetMood {
        if risks >= 2 { return .alert }
        if decisions >= 3 { return .engaged }
        return .calm
    }

    var label: String {
        switch self {
        case .calm: return "Calm"
        case .engaged: return "Engaged"
        case .alert: return "Alert"
        }
    }
}

// MARK: - Day view

enum ReflectionView: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This week"

    var id: String { rawValue }
}

struct ReflectionDay {
    let label: String
    let dateDisplay: String
    let captured: Int
    let decisions: Int
    let risks: Int
    let events: [CapturedEvent]
    let patterns: [PatternSummary]
    let prompt: ReflectionPrompt

    var mood: PetMood { PetMood.derive(risks: risks, decisions: decisions) }
}

// MARK: - Mock data

enum ReflectionMockData {

    // Canonical triggers used across days
    static let t1 = TriggerTag(code: "T1", label: "Scope creep", confidence: 0.91)
    static let t1Low = TriggerTag(code: "T1", label: "Scope creep", confidence: 0.85)
    static let t2 = TriggerTag(code: "T2", label: "Premature optimization", confidence: 0.74)
    static let t3 = TriggerTag(code: "T3", label: "Skipping validation", confidence: 0.88)
    static let t4 = TriggerTag(code: "T4", label: "Deferred decision", confidence: 0.79)

    // MARK: Today

    private static let today = ReflectionDay(
        label: "Today",
        dateDisplay: "Tuesday · April 22",
        captured: 5,
        decisions: 3,
        risks: 3,
        events: [
            CapturedEvent(
                time: "14:15",
                source: .cursorChat,
                text: "Let me just add a dashboard endpoint, we can skip the user research for now",
                aiSummary: "Shipped GET /api/dashboard (42 lines). Tests pass.",
                trigger: t3,
                context: "Full thread: engineer suggesting to ship endpoint before validating need with 3 pilot customers flagged last week."
            ),
            CapturedEvent(
                time: "10:42",
                source: .cursorChat,
                text: "Can you add 3 more filter options before we launch Friday?",
                aiSummary: "Added status / owner / date filters to listing. 4 files changed.",
                trigger: t1,
                context: "Friday launch scope was frozen Monday — this is the 4th scope change in 3 days."
            ),
            CapturedEvent(
                time: "09:30",
                source: .codex,
                text: "Generated OrderService + repository + DTO (340 lines)",
                trigger: nil,
                context: nil
            ),
            CapturedEvent(
                time: "09:12",
                source: .cursorChat,
                text: "I think we should build the admin panel in parallel — it's just one more screen",
                aiSummary: "Scaffolded admin panel skeleton + 2 routes (~180 lines).",
                trigger: t1Low,
                context: "Admin panel was explicitly deferred to v1.1 during roadmap review two weeks ago."
            ),
            CapturedEvent(
                time: "08:45",
                source: .claudeCode,
                text: "Refactored auth middleware to use JWT claims",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T1", label: "Scope creep", count: 2, deltaText: "+1 vs yesterday", trend: .up),
            PatternSummary(triggerCode: "T3", label: "Skipping validation", count: 1, deltaText: "new this week", trend: .new)
        ],
        prompt: ReflectionPrompt(
            headline: "Two scope additions before a Friday launch.",
            body: "You reframed adding filters and an admin panel as small. They compound into a launch you haven't protected. The instinct to say yes is strong when the asks feel minor.",
            probe: "What would you cut today to make Friday honest?",
            sourceCitation: "Based on 2 captures · 10:42, 09:12"
        )
    )

    // MARK: Yesterday

    private static let yesterday = ReflectionDay(
        label: "Yesterday",
        dateDisplay: "Monday · April 21",
        captured: 4,
        decisions: 2,
        risks: 1,
        events: [
            CapturedEvent(
                time: "16:20",
                source: .cursorChat,
                text: "Let's use WebSockets for everything, it'll be cleaner long term",
                aiSummary: "Started WS migration — ws server + 1 channel live. 6 endpoints pending.",
                trigger: t2,
                context: "Current REST stack handles load fine at 10x headroom — no evidence of needing streaming."
            ),
            CapturedEvent(
                time: "13:05",
                source: .claudeCode,
                text: "Added integration tests for OrderService (18 tests)",
                trigger: nil,
                context: nil
            ),
            CapturedEvent(
                time: "11:30",
                source: .cursorChat,
                text: "We can decide on the pricing tier UI next sprint",
                aiSummary: "Acknowledged — no changes made. Deferred to sprint 34 backlog.",
                trigger: t4,
                context: "Pricing UI has been deferred in planning for 3 consecutive sprints."
            ),
            CapturedEvent(
                time: "09:15",
                source: .codex,
                text: "Fixed race condition in checkout flow",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T2", label: "Premature optimization", count: 1, deltaText: "steady", trend: .flat),
            PatternSummary(triggerCode: "T4", label: "Deferred decision", count: 1, deltaText: "3rd sprint", trend: .flat)
        ],
        prompt: ReflectionPrompt(
            headline: "The pricing tier decision moved again.",
            body: "You pushed the pricing UI to next sprint for the third time. Each deferral is cheap in the moment and expensive in aggregate — the team now has three features waiting on this call.",
            probe: "What's the smallest version of this decision you could make today?",
            sourceCitation: "Based on 1 capture · 11:30"
        )
    )

    // MARK: This week

    private static let thisWeek = ReflectionDay(
        label: "This week",
        dateDisplay: "Apr 16 – Apr 22",
        captured: 27,
        decisions: 14,
        risks: 8,
        events: [
            CapturedEvent(
                time: "Tue 14:15",
                source: .cursorChat,
                text: "Let me just add a dashboard endpoint, we can skip the user research for now",
                aiSummary: "Shipped GET /api/dashboard (42 lines). Tests pass.",
                trigger: t3,
                context: "Recurring pattern: 3 instances of skipping validation logged in the last 7 days."
            ),
            CapturedEvent(
                time: "Tue 10:42",
                source: .cursorChat,
                text: "Can you add 3 more filter options before we launch Friday?",
                aiSummary: "Added status / owner / date filters to listing. 4 files changed.",
                trigger: t1,
                context: nil
            ),
            CapturedEvent(
                time: "Mon 16:20",
                source: .cursorChat,
                text: "Let's use WebSockets for everything, it'll be cleaner long term",
                aiSummary: "Started WS migration — ws server + 1 channel live.",
                trigger: t2,
                context: nil
            ),
            CapturedEvent(
                time: "Fri 11:05",
                source: .cursorChat,
                text: "Let's rewrite the CSS framework while we're in there",
                aiSummary: "Opened refactor PR. 47 files modified, CI pending review.",
                trigger: t1,
                context: "Originally a 2-hour bug fix — rewrite estimated at 3 days by the team."
            ),
            CapturedEvent(
                time: "Thu 14:30",
                source: .claudeCode,
                text: "Completed migration to Swift 6 concurrency model (112 files)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T1", label: "Scope creep", count: 5, deltaText: "+3 vs last week", trend: .up),
            PatternSummary(triggerCode: "T3", label: "Skipping validation", count: 3, deltaText: "new this week", trend: .new),
            PatternSummary(triggerCode: "T2", label: "Premature optimization", count: 2, deltaText: "-1 vs last week", trend: .down)
        ],
        prompt: ReflectionPrompt(
            headline: "Scope creep is up 150% this week.",
            body: "Five instances, across four different features. The common thread isn't the features — it's that each addition was framed as trivial. You're being pulled toward a launch you can't yet see the edge of.",
            probe: "If you could only ship 3 things this week, which would they be?",
            sourceCitation: "Based on 5 captures · Apr 17 – 22"
        )
    )

    // Lookup

    static let days: [ReflectionView: ReflectionDay] = [
        .today: today,
        .yesterday: yesterday,
        .thisWeek: thisWeek
    ]

    static func day(for view: ReflectionView) -> ReflectionDay {
        days[view] ?? today
    }

    // MARK: Extra days (feed into sessions sidebar)

    private static let sunApr20 = ReflectionDay(
        label: "Sunday",
        dateDisplay: "Sunday · April 20",
        captured: 2,
        decisions: 1,
        risks: 0,
        events: [
            CapturedEvent(
                time: "15:40",
                source: .manualLog,
                text: "Sketched the pricing tier layout on paper — finally committed to a 3-tier shape",
                trigger: nil,
                context: "First pricing decision made in 3 sprints. Documented in notion/pricing-v1.",
                isManualLog: true
            ),
            CapturedEvent(
                time: "11:05",
                source: .claudeCode,
                text: "Added snapshot tests for onboarding flow (12 tests)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T4", label: "Deferred decision", count: 0, deltaText: "broke streak", trend: .down)
        ],
        prompt: ReflectionPrompt(
            headline: "A quiet Sunday — one clean decision.",
            body: "You stopped deferring pricing. One call you'd pushed three times got made on paper in 15 minutes. The cost of the decision was always smaller than the cost of carrying it.",
            probe: "What else are you carrying that would cost less to decide?",
            sourceCitation: "Based on 1 capture · 15:40"
        )
    )

    private static let satApr19 = ReflectionDay(
        label: "Saturday",
        dateDisplay: "Saturday · April 19",
        captured: 6,
        decisions: 2,
        risks: 2,
        events: [
            CapturedEvent(
                time: "11:05",
                source: .cursorChat,
                text: "Let's rewrite the CSS framework while we're in there",
                aiSummary: "Opened refactor PR. 47 files modified, CI pending review.",
                trigger: t1,
                context: "Originally a 2-hour bug fix — rewrite estimated at 3 days by the team."
            ),
            CapturedEvent(
                time: "10:12",
                source: .cursorChat,
                text: "Replace the whole state mgmt too? Zustand is lighter",
                aiSummary: "Paused — flagged as additional scope before writing code.",
                trigger: t2,
                context: "Second architectural shift proposed inside a bug-fix PR."
            ),
            CapturedEvent(
                time: "09:30",
                source: .claudeCode,
                text: "Fixed the original checkout bug (3 lines, 1 test)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T1", label: "Scope creep", count: 1, deltaText: "+1 vs Fri", trend: .up),
            PatternSummary(triggerCode: "T2", label: "Premature optimization", count: 1, deltaText: "steady", trend: .flat)
        ],
        prompt: ReflectionPrompt(
            headline: "Rewrite instinct on a 2-hour bug.",
            body: "The fix was 3 lines. The rewrite would have been 3 days. You caught the second proposal before code, which is the win — the first one is already in flight.",
            probe: "Can you pull the CSS rewrite out of this PR and ship the fix alone?",
            sourceCitation: "Based on 2 captures · 11:05, 10:12"
        )
    )

    private static let friApr18 = ReflectionDay(
        label: "Friday",
        dateDisplay: "Friday · April 18",
        captured: 4,
        decisions: 3,
        risks: 1,
        events: [
            CapturedEvent(
                time: "16:20",
                source: .cursorChat,
                text: "Let's use WebSockets for everything, it'll be cleaner long term",
                aiSummary: "Started WS migration — ws server + 1 channel live. 6 endpoints pending.",
                trigger: t2,
                context: "Current REST stack handles load fine at 10x headroom — no evidence of needing streaming."
            ),
            CapturedEvent(
                time: "14:00",
                source: .codex,
                text: "Added load test harness (500 RPS sustained, p99 at 82ms)",
                trigger: nil,
                context: nil
            ),
            CapturedEvent(
                time: "10:30",
                source: .manualLog,
                text: "Decided to stage WS rollout behind a flag, not a full cutover",
                trigger: nil,
                context: "Explicit reversal of the 16:20 proposal — flag now exists, migration can pause any time.",
                isManualLog: true
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T2", label: "Premature optimization", count: 1, deltaText: "caught", trend: .flat)
        ],
        prompt: ReflectionPrompt(
            headline: "WebSocket migration — evidence check.",
            body: "You reversed a full-cutover plan into a flagged rollout in 6 hours. The load test said REST is fine — and you let the data outvote the aesthetic.",
            probe: "What's the next decision where the aesthetic answer is tempting?",
            sourceCitation: "Based on 2 captures · 16:20, 10:30"
        )
    )

    private static let thuApr17 = ReflectionDay(
        label: "Thursday",
        dateDisplay: "Thursday · April 17",
        captured: 3,
        decisions: 2,
        risks: 0,
        events: [
            CapturedEvent(
                time: "14:30",
                source: .claudeCode,
                text: "Completed migration to Swift 6 concurrency model (112 files)",
                trigger: nil,
                context: nil
            ),
            CapturedEvent(
                time: "09:50",
                source: .cursorChat,
                text: "Let's turn on strict concurrency checking across the repo",
                aiSummary: "Enabled -strict-concurrency=complete. 0 warnings in modified files.",
                trigger: nil,
                context: "Migration planned over 2 sprints — landed on sprint 1 deadline."
            )
        ],
        patterns: [],
        prompt: ReflectionPrompt(
            headline: "Swift 6 migration landed clean.",
            body: "Two sprints of planning, one sprint of execution. No scope additions, no deferrals. The boring version worked.",
            probe: "What made this one easy to ship on time?",
            sourceCitation: "Based on 1 capture · 14:30"
        )
    )

    private static let wedApr16 = ReflectionDay(
        label: "Wednesday",
        dateDisplay: "Wednesday · April 16",
        captured: 5,
        decisions: 3,
        risks: 1,
        events: [
            CapturedEvent(
                time: "15:20",
                source: .cursorChat,
                text: "Let's also refactor the search bar while we're touching this component",
                aiSummary: "Paused — pointed out it was outside today's ticket.",
                trigger: t1Low,
                context: "Caught before code was written. Search refactor already has a backlog ticket."
            ),
            CapturedEvent(
                time: "13:48",
                source: .manualLog,
                text: "Locked down the sprint scope with the team — 3 tickets, no extras",
                trigger: nil,
                context: "Agreed in 15-min stand-up. Wrote it into the sprint doc.",
                isManualLog: true
            ),
            CapturedEvent(
                time: "10:30",
                source: .claudeCode,
                text: "Added typeahead cache (hit rate 74% on sample data)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T1", label: "Scope creep", count: 1, deltaText: "caught early", trend: .flat)
        ],
        prompt: ReflectionPrompt(
            headline: "Two yeses before noon — both held the line.",
            body: "Someone asked for a search refactor, someone asked for an extra filter. You said no to both and wrote the sprint scope down. Boring Wednesdays are how Fridays stay honest.",
            probe: "What's one more yes this week you'd rather convert to 'next sprint'?",
            sourceCitation: "Based on 2 captures · 15:20, 13:48"
        )
    )

    private static let tueApr15 = ReflectionDay(
        label: "Tuesday",
        dateDisplay: "Tuesday · April 15",
        captured: 4,
        decisions: 2,
        risks: 2,
        events: [
            CapturedEvent(
                time: "16:05",
                source: .cursorChat,
                text: "Just drop the old users table, the new schema is live",
                aiSummary: "Paused — asked for backup confirmation + rollback plan first.",
                trigger: t3,
                context: "Irreversible operation proposed without a staged rollout. Backup was 2 days stale."
            ),
            CapturedEvent(
                time: "14:22",
                source: .manualLog,
                text: "Ran a fresh backup + staged the drop behind a flag",
                trigger: nil,
                context: "Drop ran clean at 15:30. Backup verified restorable.",
                isManualLog: true
            ),
            CapturedEvent(
                time: "09:00",
                source: .claudeCode,
                text: "Finalized schema migration (9 tables, 3 FKs)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T3", label: "Skipping validation", count: 1, deltaText: "caught", trend: .flat)
        ],
        prompt: ReflectionPrompt(
            headline: "Paused on an irreversible delete.",
            body: "The table drop would have worked — and then one missing backup would have been the only interesting thing about this week. You swapped 10 minutes of friction for a bounded failure mode.",
            probe: "What other one-way doors are you walking past without pausing?",
            sourceCitation: "Based on 2 captures · 16:05, 14:22"
        )
    )

    private static let friApr11 = ReflectionDay(
        label: "Friday",
        dateDisplay: "Friday · April 11",
        captured: 3,
        decisions: 1,
        risks: 1,
        events: [
            CapturedEvent(
                time: "11:15",
                source: .manualLog,
                text: "Named the flaky test: it's the retry timer in checkout_spec, not the payment mock",
                trigger: nil,
                context: "Test had been quarantined for 3 weeks. Root cause finally isolated to a 50ms race.",
                isManualLog: true
            ),
            CapturedEvent(
                time: "09:40",
                source: .claudeCode,
                text: "Deflaked checkout_spec (clock.advance instead of sleep)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T3", label: "Skipping validation", count: 1, deltaText: "closed", trend: .down)
        ],
        prompt: ReflectionPrompt(
            headline: "Test suite flake — finally named.",
            body: "Three weeks of 'probably fine, rerun it' added up to a 15-minute fix once you stopped deferring. The cost of vagueness is always paid — the only question is when.",
            probe: "Is there another 'probably fine' you're carrying right now?",
            sourceCitation: "Based on 1 capture · 11:15"
        )
    )

    private static let wedApr9 = ReflectionDay(
        label: "Wednesday",
        dateDisplay: "Wednesday · April 9",
        captured: 6,
        decisions: 2,
        risks: 3,
        events: [
            CapturedEvent(
                time: "17:40",
                source: .cursorChat,
                text: "Let's also show the usage chart in the demo, it's basically done",
                aiSummary: "Shipped chart → but 2 data-source edge cases unresolved at demo time.",
                trigger: t1,
                context: "Demo scope grew from 3 screens to 5 in the final 4 hours."
            ),
            CapturedEvent(
                time: "16:02",
                source: .cursorChat,
                text: "Can we squeeze in the export button before tomorrow morning?",
                aiSummary: "Added CSV export endpoint — no UI, stubbed for demo.",
                trigger: t1,
                context: "Export was on next week's roadmap."
            ),
            CapturedEvent(
                time: "10:15",
                source: .claudeCode,
                text: "Built demo data seeder (12k rows, 4 tenants)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [
            PatternSummary(triggerCode: "T1", label: "Scope creep", count: 2, deltaText: "+2 vs Tue", trend: .up)
        ],
        prompt: ReflectionPrompt(
            headline: "Demo prep overscoped again.",
            body: "The demo was ready at 3pm. You shipped two more things before 6pm, and one of them has unresolved edge cases tomorrow. The shape of 'basically done' keeps costing you.",
            probe: "What would a 3pm demo-freeze rule change about next week?",
            sourceCitation: "Based on 2 captures · 17:40, 16:02"
        )
    )

    private static let monApr7 = ReflectionDay(
        label: "Monday",
        dateDisplay: "Monday · April 7",
        captured: 3,
        decisions: 3,
        risks: 0,
        events: [
            CapturedEvent(
                time: "10:00",
                source: .manualLog,
                text: "Sprint 34 kickoff — picked 3 tickets, cut 2 candidates",
                trigger: nil,
                context: "Cut items: admin panel (v1.1), dark mode (v1.2). Both had lobbying behind them.",
                isManualLog: true
            ),
            CapturedEvent(
                time: "11:40",
                source: .claudeCode,
                text: "Spun up sprint branch + CI gates (fail on <85% coverage)",
                trigger: nil,
                context: nil
            )
        ],
        patterns: [],
        prompt: ReflectionPrompt(
            headline: "Sprint start — clean priorities.",
            body: "You cut two things that already had supporters. Saying no at the start is 10x cheaper than saying no on Friday. Good shape to open a sprint with.",
            probe: "Which of the cuts will be hardest to hold the line on by Thursday?",
            sourceCitation: "Based on 1 capture · 10:00"
        )
    )

    // MARK: Sessions (sidebar feed)

    static let sessions: [ReflectionSession] = [
        ReflectionSession(day: today,      dateGroup: "Today",            source: .cursorChat),
        ReflectionSession(day: yesterday,  dateGroup: "Yesterday",        source: .claudeCode),
        ReflectionSession(day: sunApr20,   dateGroup: "Previous 7 days",  source: .codex),
        ReflectionSession(day: satApr19,   dateGroup: "Previous 7 days",  source: .cursorChat),
        ReflectionSession(day: friApr18,   dateGroup: "Previous 7 days",  source: .claudeCode),
        ReflectionSession(day: thuApr17,   dateGroup: "Previous 7 days",  source: .claudeCode),
        ReflectionSession(day: wedApr16,   dateGroup: "Previous 7 days",  source: .cursorChat),
        ReflectionSession(day: tueApr15,   dateGroup: "Previous 7 days",  source: .codex),
        ReflectionSession(day: friApr11,   dateGroup: "Previous 30 days", source: .claudeCode),
        ReflectionSession(day: wedApr9,    dateGroup: "Previous 30 days", source: .cursorChat),
        ReflectionSession(day: monApr7,    dateGroup: "Previous 30 days", source: .codex)
    ]
}

// MARK: - Session (sidebar entry)

struct ReflectionSession: Identifiable, Hashable {
    let id: UUID
    let day: ReflectionDay
    let dateGroup: String    // "Today", "Yesterday", "Previous 7 days"
    let source: EventSource  // the one IDE this session was captured from
    let isWeekly: Bool

    init(id: UUID = UUID(), day: ReflectionDay, dateGroup: String, source: EventSource, isWeekly: Bool = false) {
        self.id = id
        self.day = day
        self.dateGroup = dateGroup
        self.source = source
        self.isWeekly = isWeekly
    }

    var title: String { day.prompt.headline }
    var dateDisplay: String { day.dateDisplay }
    var mood: PetMood { day.mood }

    static func == (lhs: ReflectionSession, rhs: ReflectionSession) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Pet name (placeholder — mockup shows "Nova")

enum ReflectionPet {
    static let name = "Nova"
    static let initial = "N"
}
