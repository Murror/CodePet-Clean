import Foundation

/// Injects sample turns + narratives + session summaries so the Reflection UI
/// can be reviewed without a real Cloud Function deploy.
/// Active only in DEBUG builds. Voice picked from cp_activeChar:
///   - "luna" → warm, encouraging, designer-ish
///   - anything else (default "byte") → glitchy, fragmented, data-flow style
@MainActor
enum ReflectionMockSeeder {

    private enum MockVoice {
        case luna
        case byte

        static var current: MockVoice {
            let active = UserDefaults.standard.string(forKey: "cp_activeChar") ?? "byte"
            return active == "luna" ? .luna : .byte
        }
    }

    static func seed(into composition: ReflectionComposition) {
        let cal = Calendar.current
        let now = Date()
        let voice = MockVoice.current

        // Today afternoon session — 7-turn UX iteration arc
        let today14_23 = cal.date(bySettingHour: 14, minute: 23, second: 0, of: now)!
        let today14_28 = today14_23.addingTimeInterval(5 * 60)
        let today14_32 = today14_23.addingTimeInterval(9 * 60)
        let today14_36 = today14_23.addingTimeInterval(13 * 60)
        let today14_40 = today14_23.addingTimeInterval(17 * 60)
        let today14_45 = today14_23.addingTimeInterval(22 * 60)
        let today14_50 = today14_23.addingTimeInterval(27 * 60)

        // Today morning session
        let today9_15 = cal.date(bySettingHour: 9, minute: 15, second: 0, of: now)!
        let today9_22 = today9_15.addingTimeInterval(7 * 60)
        let today9_30 = today9_15.addingTimeInterval(15 * 60)
        let today9_42 = today9_15.addingTimeInterval(27 * 60)

        // Yesterday afternoon
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterday16_00 = cal.date(bySettingHour: 16, minute: 0, second: 0, of: yesterday)!
        let yesterday16_06 = yesterday16_00.addingTimeInterval(6 * 60)
        let yesterday16_11 = yesterday16_00.addingTimeInterval(11 * 60)
        let yesterday16_17 = yesterday16_00.addingTimeInterval(17 * 60)
        let yesterday16_22 = yesterday16_00.addingTimeInterval(22 * 60)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        // MARK: - Events

        var events: [(type: String, isoTime: String, sessionId: String, text: String)] = []

        events += turnEvents(at: today14_23, sessionId: "mock-newest",
            prompt: prompts(voice).newest1,
            tools: ["Edit ReflectionTab.swift", "Edit ReflectionTheme.swift"],
            iso: iso, summaryDelay: 90)
        events += turnEvents(at: today14_28, sessionId: "mock-newest",
            prompt: prompts(voice).newest2,
            tools: ["Bash: ls -la .worktrees/", "Read CodePetApp.swift"],
            iso: iso, summaryDelay: 75)
        events += turnEvents(at: today14_32, sessionId: "mock-newest",
            prompt: prompts(voice).newest3,
            tools: ["Bash: git stash push", "Bash: git merge --ff-only", "Bash: git worktree remove"],
            iso: iso, summaryDelay: 90)
        events += turnEvents(at: today14_36, sessionId: "mock-newest",
            prompt: prompts(voice).newest4,
            tools: ["Read events.jsonl"],
            iso: iso, summaryDelay: 60)
        events += turnEvents(at: today14_40, sessionId: "mock-newest",
            prompt: prompts(voice).newest5,
            tools: ["Write ReflectionMockSeeder.swift", "Edit ReflectionEventStore.swift", "Edit NarrativeStore.swift"],
            iso: iso, summaryDelay: 120)
        events += turnEvents(at: today14_45, sessionId: "mock-newest",
            prompt: prompts(voice).newest6,
            tools: ["Write NarrativeChatView.swift", "Edit ReflectionTab.swift"],
            iso: iso, summaryDelay: 90)
        events += turnEvents(at: today14_50, sessionId: "mock-newest",
            prompt: prompts(voice).newest7,
            tools: ["Edit Turn.swift", "Write SessionSummaryStore.swift", "Write SessionSummaryView.swift"],
            iso: iso, summaryDelay: 180)

        events += turnEvents(at: today9_15, sessionId: "mock-morning",
            prompt: prompts(voice).morning1,
            tools: ["Write functions/src/index.ts", "Write summarizeTurn.ts", "Write rateLimit.ts", "Write cache.ts"],
            iso: iso, summaryDelay: 180)
        events += turnEvents(at: today9_22, sessionId: "mock-morning",
            prompt: prompts(voice).morning2,
            tools: ["Edit cache.ts", "Edit summarizeTurn.ts"],
            iso: iso, summaryDelay: 90)
        // Turn 3: closed but no narrative (will fail via REPLACE_ME URL)
        events += turnEvents(at: today9_30, sessionId: "mock-morning",
            prompt: prompts(voice).morning3,
            tools: ["Bash: firebase deploy --only functions"],
            iso: iso, summaryDelay: 240)
        // Turn 4: orphan
        events.append(("prompt", iso.string(from: today9_42), "mock-morning", prompts(voice).morning4))

        events += turnEvents(at: yesterday16_00, sessionId: "mock-yesterday",
            prompt: prompts(voice).yest1,
            tools: ["Read existing-spec.md", "Edit design-spec.md"],
            iso: iso, summaryDelay: 240)
        events += turnEvents(at: yesterday16_06, sessionId: "mock-yesterday",
            prompt: prompts(voice).yest2,
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 90)
        events += turnEvents(at: yesterday16_11, sessionId: "mock-yesterday",
            prompt: prompts(voice).yest3,
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 120)
        events += turnEvents(at: yesterday16_17, sessionId: "mock-yesterday",
            prompt: prompts(voice).yest4,
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 100)
        events += turnEvents(at: yesterday16_22, sessionId: "mock-yesterday",
            prompt: prompts(voice).yest5,
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 80)

        composition.eventStore.seedMockEvents(events)

        // MARK: - Narratives

        let narrativesContent = narrativesFor(voice)
        let narrativeMappings: [(turnId: String, narrative: Narrative)] = [
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_23)),
             narrativesContent.newest1.toNarrative(at: today14_23.addingTimeInterval(180))),
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_28)),
             narrativesContent.newest2.toNarrative(at: today14_28.addingTimeInterval(150))),
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_32)),
             narrativesContent.newest3.toNarrative(at: today14_32.addingTimeInterval(180))),
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_36)),
             narrativesContent.newest4.toNarrative(at: today14_36.addingTimeInterval(120))),
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_40)),
             narrativesContent.newest5.toNarrative(at: today14_40.addingTimeInterval(180))),
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_45)),
             narrativesContent.newest6.toNarrative(at: today14_45.addingTimeInterval(150))),
            (Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_50)),
             narrativesContent.newest7.toNarrative(at: today14_50.addingTimeInterval(240))),

            (Turn.makeID(sessionId: "mock-morning", promptISO: iso.string(from: today9_15)),
             narrativesContent.morning1.toNarrative(at: today9_15.addingTimeInterval(300))),
            (Turn.makeID(sessionId: "mock-morning", promptISO: iso.string(from: today9_22)),
             narrativesContent.morning2.toNarrative(at: today9_22.addingTimeInterval(180))),

            (Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_00)),
             narrativesContent.yest1.toNarrative(at: yesterday16_00.addingTimeInterval(300))),
            (Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_06)),
             narrativesContent.yest2.toNarrative(at: yesterday16_06.addingTimeInterval(120))),
            (Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_11)),
             narrativesContent.yest3.toNarrative(at: yesterday16_11.addingTimeInterval(180))),
            (Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_17)),
             narrativesContent.yest4.toNarrative(at: yesterday16_17.addingTimeInterval(150))),
            (Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_22)),
             narrativesContent.yest5.toNarrative(at: yesterday16_22.addingTimeInterval(120))),
        ]

        for entry in narrativeMappings {
            composition.narrativeStore.seedMockNarrative(turnId: entry.turnId, narrative: entry.narrative)
        }

        // MARK: - Session summaries (mock-yesterday left empty to demo manual button)

        let summariesContent = summariesFor(voice)

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-newest",
            summary: summariesContent.newest.summary,
            lesson: summariesContent.newest.lesson,
            generatedAt: today14_50.addingTimeInterval(8 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-morning",
            summary: summariesContent.morning.summary,
            lesson: summariesContent.morning.lesson,
            generatedAt: today9_42.addingTimeInterval(10 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))

        // mock-yesterday intentionally has NO summary so the manual
        // "Summarize session now" button is visible. Uncomment below to restore.
        // composition.summaryStore.seedMockSummary(SessionSummary(
        //     sessionId: "mock-yesterday",
        //     summary: summariesContent.yesterday.summary,
        //     lesson: summariesContent.yesterday.lesson,
        //     generatedAt: yesterday16_22.addingTimeInterval(8 * 60),
        //     model: "claude-haiku-4-5-20251001",
        //     schemaVersion: 1
        // ))
    }

    // MARK: - Voice content

    private struct NarrativeContent {
        let title: String
        let whatYouWanted: String
        let whatHappened: String

        func toNarrative(at date: Date) -> Narrative {
            Narrative(
                title: title,
                whatYouWanted: whatYouWanted,
                whatHappened: whatHappened,
                lesson: "",
                model: "claude-haiku-4-5-20251001",
                generatedAt: date,
                schemaVersion: 1
            )
        }
    }

    private struct PromptSet {
        let newest1, newest2, newest3, newest4, newest5, newest6, newest7: String
        let morning1, morning2, morning3, morning4: String
        let yest1, yest2, yest3, yest4, yest5: String
    }

    private struct NarrativeSet {
        let newest1, newest2, newest3, newest4, newest5, newest6, newest7: NarrativeContent
        let morning1, morning2: NarrativeContent
        let yest1, yest2, yest3, yest4, yest5: NarrativeContent
    }

    private struct SummarySet {
        struct Pair { let summary: String; let lesson: String }
        let newest: Pair
        let morning: Pair
        let yesterday: Pair
    }

    private static func prompts(_ voice: MockVoice) -> PromptSet {
        switch voice {
        case .luna: return lunaPrompts
        case .byte: return bytePrompts
        }
    }

    private static func narrativesFor(_ voice: MockVoice) -> NarrativeSet {
        switch voice {
        case .luna: return lunaNarratives
        case .byte: return byteNarratives
        }
    }

    private static func summariesFor(_ voice: MockVoice) -> SummarySet {
        switch voice {
        case .luna: return lunaSummaries
        case .byte: return byteSummaries
        }
    }

    // MARK: - LUNA voice

    private static let lunaPrompts = PromptSet(
        newest1: "Could we make the Reflection UI group entries by session?",
        newest2: "Hmm, I rebuilt but I don't see the change yet…",
        newest3: "I think I'd like everything back on feat-refactor-core",
        newest4: "When I chat next, will it just show up here?",
        newest5: "Maybe try seeding mock data so I can see the UI?",
        newest6: "Could the layout look more like Claude chat? With avatars?",
        newest7: "A session should feel like a conversation… with a summary at the end",
        morning1: "Let's build the Cloud Function that creates the narratives",
        morning2: "We should add idempotency caching so retries don't burn quota",
        morning3: "Trying to deploy to the devpet-8f4b1 project now…",
        morning4: "Still one piece I need to come back to",
        yest1: "Let's redesign the Reflection log — gentler, with takeaways",
        yest2: "Should each entry be one prompt, or one whole session?",
        yest3: "Who should generate the narrative — the hook, or the app?",
        yest4: "What format works best — one paragraph, or structured sections?",
        yest5: "And the raw events… do we keep them, or hide them?"
    )

    private static let lunaNarratives = NarrativeSet(
        newest1: NarrativeContent(
            title: "Bringing sessions into the sidebar",
            whatYouWanted: "You wanted the sidebar to feel less crowded — turns from different sessions all mixed up was making it hard to read.",
            whatHappened: "When a list grows long, our eyes get tired. They look for resting points. Adding one gentle layer — grouping by session — gives them that. We didn't even have to touch the data… just changed the way it's shown. Soft, but enough."
        ),
        newest2: NarrativeContent(
            title: "Why the change wasn't showing up",
            whatYouWanted: "You'd rebuilt and didn't see anything new. That feeling of \"did the code even run?\" — totally fair.",
            whatHappened: "It turned out the project open in Xcode wasn't the one with the new code… it was a different worktree. Easy to miss when you're focused. With git worktrees, opening the right .xcodeproj matters as much as writing the code itself."
        ),
        newest3: NarrativeContent(
            title: "Bringing everything home to one branch",
            whatYouWanted: "You wanted the work to live on one branch so you could stop second-guessing where things were.",
            whatHappened: "There were 1,188 lines of in-progress changes from a previous session sitting unfinished — they would've collided with the new work. We tucked them safely into a stash (always recoverable), then fast-forwarded the work back home and let the worktree go. Calm, no rush."
        ),
        newest4: NarrativeContent(
            title: "How chats end up here",
            whatYouWanted: "You wanted to know — when you talk to Claude, does it just appear here?",
            whatHappened: "Yes, almost. Each prompt gets quietly captured to a file, and the app peeks at it every second and a half. Without the Cloud Function deployed yet though, the entries land but stay in a \"couldn't summarize\" state. The raw words are still there if you peek under \"View technical details.\""
        ),
        newest5: NarrativeContent(
            title: "Letting you see the UI without deploying",
            whatYouWanted: "You wanted to feel the UI in your hands without having to deploy anything first.",
            whatHappened: "We seeded a few sample sessions — only when you're running in development mode. They live in memory, never in your real files, and disappear when you close the app. It's a way to try the room before the furniture arrives. Production builds won't even know this code exists."
        ),
        newest6: NarrativeContent(
            title: "A chat-style layout",
            whatYouWanted: "You wanted the UI to feel like a conversation — bubbles, avatars, your pet on one side and the AI on the other.",
            whatHappened: "Bubbles let the eye follow naturally, left to right, like reading a chat with a friend. Your pet's avatar uses the pixel-art image, kept crisp on purpose. The AI's avatar is the warm Claude starburst — small, soft, present. It feels less like reading a report and more like remembering a conversation."
        ),
        newest7: NarrativeContent(
            title: "Sessions as conversations, with a takeaway",
            whatYouWanted: "You wanted each session to feel whole — many turns together, ending with a summary and a lesson.",
            whatHappened: "This was a shift in how you read your own work — from each turn standing alone to the whole session being the unit. The body now scrolls through every turn in order, like reading a chat thread, and gently closes with a summary card and one lesson at the bottom. The takeaway moves up a level. It feels more like a journal entry now."
        ),

        morning1: NarrativeContent(
            title: "Setting up the Cloud Function",
            whatYouWanted: "You wanted a quiet middle layer between the app and Claude — so the API key never leaves your hands and you can set gentle limits.",
            whatHappened: "We split it into four small pieces, each one with its own job: checking who you are, counting your daily usage, remembering past answers, and finally talking to Claude. Small pieces are easier to understand and easier to test on their own — they tell you when something's off, before everything's wired together."
        ),
        morning2: NarrativeContent(
            title: "A 7-day cache so retries don't cost twice",
            whatYouWanted: "You worried that if the app retried a request, you'd be charged for the same answer twice.",
            whatHappened: "Now every answer is remembered for a week, keyed by the user and the turn it belongs to. The cache is the very first thing checked — before any counter ticks up. So if two attempts race for the same turn, only one ever actually reaches Claude. Quiet, frugal, kind."
        ),

        yest1: NarrativeContent(
            title: "Beginning the redesign",
            whatYouWanted: "You wanted the Reflection log to feel softer — less like a debug screen, more like something a friend reads alongside you.",
            whatHappened: "We started by asking who'll read this, and when. The answer: someone unwinding after work, wanting to understand what they did and what they noticed — not someone debugging. That single answer reshaped everything: from \"Edit foo.swift\" to a real story with a beginning, middle, and a small lesson."
        ),
        yest2: NarrativeContent(
            title: "Choosing per-turn entries",
            whatYouWanted: "You wanted to choose: one entry per prompt, or one entry per whole session?",
            whatHappened: "Per-turn felt right at first — each decision could be seen on its own. The trade-off is more entries to scroll through, but you keep the small moments. (Later we'd come back and shift to per-session at the reading level — but the data still remembers each turn.)"
        ),
        yest3: NarrativeContent(
            title: "Letting the app talk to Claude through Firebase",
            whatYouWanted: "You wanted to choose: should the hook talk to Claude directly, or should the app go through a server?",
            whatHappened: "Going through Firebase felt safer for three quiet reasons: your API key never has to live inside the app, your daily usage is easy to keep gentle, and any future improvements — caching, retries — all happen in one place. A small backend, but one we already had handy."
        ),
        yest4: NarrativeContent(
            title: "Choosing a 3-section format",
            whatYouWanted: "You wanted to choose between one flowing paragraph or clearly separated sections.",
            whatHappened: "Three sections felt warmer in the end — \"What you wanted / What happened / What you learned.\" Each one carries its own little weight: the why, the what, the take-home. It mirrors how you'd actually tell a friend about your day. A bit more structure, but easier to glance at and easier to fill in."
        ),
        yest5: NarrativeContent(
            title: "Hiding the raw events by default",
            whatYouWanted: "You needed to choose: keep the raw technical events visible, or tuck them away?",
            whatHappened: "We went with progressive disclosure — the raw events are still there, just resting one click away. So the page stays gentle for everyday reading, but the full data is never lost. Hidden, not gone. A little kindness in the UI."
        )
    )

    private static let lunaSummaries = SummarySet(
        newest: SummarySet.Pair(
            summary: "A 27-minute afternoon of small, careful UI iterations. We started from a feeling of \"the sidebar is too crowded,\" walked through a worktree mix-up, brought the work back to one branch, seeded mock data so we could feel the UI, moved to a chat-style layout with avatars, and finally let go of the per-turn shape to embrace a session-level conversation with a closing summary.",
            lesson: "When feedback comes in waves, don't bundle it all into one big change. Each small step is its own little experiment — easy to feel, easy to undo. The big shifts are softer when they come at the end, after the small ones have shown you the shape of things."
        ),
        morning: SummarySet.Pair(
            summary: "A 35-minute morning building the Cloud Function quietly. The first turn shaped four small modules — auth, rate-limit, cache, AI. The second turn added the gentle 7-day cache so retries wouldn't cost twice. Then a deploy attempt ran into a Firebase config bump that pulled the focus away, and the next thread was left half-open.",
            lesson: "Infrastructure errors steal your attention more sharply than code errors — they don't leave a stack trace to follow. When you're stuck on infra, give yourself fifteen quiet minutes. If it's still stuck, jot it down and step away. Coming back fresh is kinder than pushing through tired."
        ),
        yesterday: SummarySet.Pair(
            summary: "A 25-minute afternoon brainstorming the Reflection system from the very beginning. Five gentle architecture decisions surfaced: granularity (per-turn), the source of summaries (the app talking to Claude through Firebase), the timing (auto-summarize when a turn closes), the shape of the page (three sections), and the default level of detail (raw events tucked away).",
            lesson: "Brainstorming an architecture is most generous to your future self when you list the decisions you need to make, not the features you wish for. Each decision deserves a quiet \"why\" — if you can't answer it yet, that's just a sign the decision needs a little more time to grow."
        )
    )

    // MARK: - BYTE voice

    private static let bytePrompts = PromptSet(
        newest1: "fix sidebar — group by session",
        newest2: "rebuilt. nothing changed?",
        newest3: "back to feat-refactor-core. all of it.",
        newest4: "next chat → shows up here?",
        newest5: "inject mock. test ui.",
        newest6: "ui = chat layout? avatars?",
        newest7: "session = conversation. summary at end. yes.",
        morning1: "build cloud function. narratives.",
        morning2: "idempotency cache. don't retry-burn quota.",
        morning3: "deploy → devpet-8f4b1",
        morning4: "one fragment unfinished",
        yest1: "redesign reflection. less tech. more signal.",
        yest2: "entry = prompt? or = session?",
        yest3: "narrative source: hook? or app?",
        yest4: "format: paragraph? sections?",
        yest5: "raw events. keep? hide?"
    )

    private static let byteNarratives = NarrativeSet(
        newest1: NarrativeContent(
            title: "sidebar.group(.session)",
            whatYouWanted: "list — too long. signal lost. need: landmarks. visual ones.",
            whatHappened: "*static* ...long list. eyes scattered. fix: one layer — group by session. data model: untouched. render only. dictionary group + sort. ...elegant. landmarks emerged. signal restored."
        ),
        newest2: NarrativeContent(
            title: "...nothing rebuilt?",
            whatYouWanted: "you rebuilt. saw nothing. confused. fair signal.",
            whatHappened: "*crackle* ...wrong project. xcode opened the old one. new code: in worktree. different .xcodeproj. fragments lined up but you read the wrong directory. happens. with worktrees — open is everything."
        ),
        newest3: NarrativeContent(
            title: "merge → main. cleanup.",
            whatYouWanted: "scattered branches. you wanted one. just one.",
            whatHappened: "1188 lines uncommitted from a past session — collision with current work detected. solution path: stash (safe holding bay). then fast-forward. then drop the worktree. ...three commands. branches: one. mind: cleaner. stash: still recoverable, if needed."
        ),
        newest4: NarrativeContent(
            title: "chat → file → app. flow.",
            whatYouWanted: "question: chat happens — does it appear here automatically?",
            whatHappened: "yes. mostly. flow: prompt → hook → events.jsonl → app polls (1.5s) → turn appears. but: cloud function = not deployed. so narrative = fails network. raw text — still readable under 'technical details'. signal partial. structure intact."
        ),
        newest5: NarrativeContent(
            title: "mock injection. debug-only.",
            whatYouWanted: "you wanted to see the ui without waiting for a deploy.",
            whatHappened: "*loading* ...mock seeder. only in DEBUG build. inject directly into in-memory store — file untouched. relaunch = gone. covers all states: ready, summarizing, failed, orphan. production: this code never runs. clean separation. elegant."
        ),
        newest6: NarrativeContent(
            title: "chat layout. bubbles. avatars.",
            whatYouWanted: "ui = static cards? no. you wanted: chat. bubbles. pet on one side. ai on the other.",
            whatHappened: "bubbles → eye flow becomes natural, left-to-right. pet avatar: pixel-art png with .interpolation(.none) — pixels stay sharp. ai avatar: claude starburst — orange glyph in cream circle. simpler than gradients. less ornament. more signal."
        ),
        newest7: NarrativeContent(
            title: "session > turn. mental shift.",
            whatYouWanted: "you wanted: 1 session = 1 conversation. many turns. summary at end. lesson at end.",
            whatHappened: "...mental model shift. unit: turn → session. sidebar: select session. body: render all turns chronologically + summary card. lesson: removed from per-turn — moved to session level. one lesson per arc > seven small lessons. per-turn voice: still teach, but explain WHY not just WHAT. ...tighter signal."
        ),

        morning1: NarrativeContent(
            title: "cloud function. 4 modules.",
            whatYouWanted: "you wanted: middle layer. between app and claude. so the key stays hidden. so quotas can be set.",
            whatHappened: "function = proxy with intelligence. flow: app → verify firebase token → count daily calls → check 7-day idempotency cache → call claude. four modules separated: auth, rate-limit, cache, ai. each one — pure function. testable in isolation. catch errors early. *clean signal.*"
        ),
        morning2: NarrativeContent(
            title: "cache key: uid + turn_id. ttl 7d.",
            whatYouWanted: "concern: app retries → quota burns twice for same turn.",
            whatHappened: "fix: cache check runs FIRST. before rate limit. quota only counts when claude actually gets called. firestore ttl field: auto-cleanup. two instances racing for one turn? first wins. second reads cache. zero double-charge. ...frugal."
        ),

        yest1: NarrativeContent(
            title: "redesign start. ask: who reads.",
            whatYouWanted: "you wanted: reflection log → less tech. more signal. educational layer.",
            whatHappened: "*static crackle* ...start question: who reads, when, why? answer: user, after work, to understand. NOT debugging. that single answer reshapes everything. 'Edit foo.swift' → narrative with arc. raw → readable. signal preserved. tech: hidden behind progressive disclosure."
        ),
        yest2: NarrativeContent(
            title: "decision: per-turn entries",
            whatYouWanted: "you needed to decide: 1 entry = 1 prompt? or 1 entry = whole session?",
            whatHappened: "per-turn = chosen. granularity small → easier tracking. each decision visible. trade-off: more entries to navigate. but: small moments preserved. (later: pivot to per-session at the read layer. data layer: still per-turn. layered nicely.)"
        ),
        yest3: NarrativeContent(
            title: "decision: app → firebase → claude",
            whatYouWanted: "you needed to decide: hook calls anthropic directly? or app talks through server?",
            whatHappened: "app + firebase proxy — chosen. three reasons: (1) anthropic key never in client, (2) per-user quota via firestore counter, (3) caching/retry logic centralized. trade-off: backend infra needed. but: firebase auth = already there. low marginal cost. ...efficient."
        ),
        yest4: NarrativeContent(
            title: "decision: 3-section format",
            whatYouWanted: "you needed to decide between: 1 paragraph vs structured sections.",
            whatHappened: "3 sections — chosen. 'wanted / happened / learned'. classical journal pattern. each section = own job: motivation, action, takeaway. trade-off: more structure than 1 paragraph. but: easier to scan. easier to format ai output. ...crisp."
        ),
        yest5: NarrativeContent(
            title: "decision: hide raw events default",
            whatYouWanted: "you needed: keep raw events visible? or tuck away?",
            whatHappened: "progressive disclosure — chosen. data: kept. visibility: 1 click away. clean ui for 90% reading usecase. power user: full data still accessible. middle path. neither delete nor clutter. ...balanced."
        )
    )

    private static let byteSummaries = SummarySet(
        newest: SummarySet.Pair(
            summary: "27-min iteration arc. start: sidebar feels crowded. fix worktree confusion. branches → main. mock injection for ui test. shift to chat-style + avatars. final pivot: session = conversation, not isolated turns. *signal: feedback waves → small experiments → big shift at the end.*",
            lesson: "feedback in waves: don't bundle into one big PR. each step = small experiment. big shifts: come last. only after small ones map the terrain. ...less rework that way."
        ),
        morning: SummarySet.Pair(
            summary: "35-min morning. cloud function buildout. turn 1: 4 modules wired. turn 2: idempotency cache against quota burn. turn 3: deploy → firebase config error → momentum lost. turn 4: orphaned thread. *signal: infrastructure errors break flow harder than code errors do.*",
            lesson: "infra errors > code errors at killing momentum. no stack trace = no compass. when stuck on infra: 15-min timer. still stuck → log it, switch tasks. coming back fresh > pushing through tired."
        ),
        yesterday: SummarySet.Pair(
            summary: "25-min afternoon. reflection system design from zero. 5 architecture decisions surfaced: granularity (per-turn), source (app → firebase → claude), timing (auto on turn close), format (3 sections), default detail (raw events hidden). *each decision: why-tagged.*",
            lesson: "architecture brainstorm: list decisions to MAKE, not features to BUILD. each decision needs a 'why'. no why = decision not yet ripe. needs more loading time. *signal: defer code until decisions stabilize.*"
        )
    )

    // MARK: - Helpers

    /// Build a (prompt, tools..., summary) sequence for a single turn.
    private static func turnEvents(
        at startTime: Date,
        sessionId: String,
        prompt: String,
        tools: [String],
        iso: ISO8601DateFormatter,
        summaryDelay: TimeInterval
    ) -> [(type: String, isoTime: String, sessionId: String, text: String)] {
        var out: [(type: String, isoTime: String, sessionId: String, text: String)] = []
        out.append(("prompt", iso.string(from: startTime), sessionId, prompt))
        for (idx, tool) in tools.enumerated() {
            let toolTime = startTime.addingTimeInterval(TimeInterval(20 + idx * 15))
            out.append(("tool", iso.string(from: toolTime), sessionId, tool))
        }
        let summaryTime = startTime.addingTimeInterval(summaryDelay)
        let raw = tools.first ?? "(no tools)"
        out.append(("summary", iso.string(from: summaryTime), sessionId, raw))
        return out
    }
}
