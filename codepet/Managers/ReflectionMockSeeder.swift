import Foundation

/// Injects sample turns + narratives + session summaries so the Reflection UI
/// can be reviewed without a real Cloud Function deploy.
/// Active only in DEBUG builds.
@MainActor
enum ReflectionMockSeeder {

    static func seed(into composition: ReflectionComposition) {
        let cal = Calendar.current
        let now = Date()

        // Today afternoon session — 7-turn UX iteration arc (mirrors today's real session)
        let today14_23 = cal.date(bySettingHour: 14, minute: 23, second: 0, of: now)!
        let today14_28 = today14_23.addingTimeInterval(5 * 60)
        let today14_32 = today14_23.addingTimeInterval(9 * 60)
        let today14_36 = today14_23.addingTimeInterval(13 * 60)
        let today14_40 = today14_23.addingTimeInterval(17 * 60)
        let today14_45 = today14_23.addingTimeInterval(22 * 60)
        let today14_50 = today14_23.addingTimeInterval(27 * 60)

        // Today morning session — Cloud Function buildout
        let today9_15 = cal.date(bySettingHour: 9, minute: 15, second: 0, of: now)!
        let today9_22 = today9_15.addingTimeInterval(7 * 60)
        let today9_30 = today9_15.addingTimeInterval(15 * 60)
        let today9_42 = today9_15.addingTimeInterval(27 * 60)

        // Yesterday afternoon — design brainstorm
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterday16_00 = cal.date(bySettingHour: 16, minute: 0, second: 0, of: yesterday)!
        let yesterday16_06 = yesterday16_00.addingTimeInterval(6 * 60)
        let yesterday16_11 = yesterday16_00.addingTimeInterval(11 * 60)
        let yesterday16_17 = yesterday16_00.addingTimeInterval(17 * 60)
        let yesterday16_22 = yesterday16_00.addingTimeInterval(22 * 60)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        // MARK: - Events (prompt → tool(s) → summary per turn)

        var events: [(type: String, isoTime: String, sessionId: String, text: String)] = []

        // === Today afternoon: mock-newest — 7-turn conversation arc ===

        events += turnEvents(at: today14_23, sessionId: "mock-newest",
            prompt: "Sửa giúp tôi UI Reflection để hiện grouping theo session",
            tools: ["Edit ReflectionTab.swift", "Edit ReflectionTheme.swift"],
            iso: iso, summaryDelay: 90)

        events += turnEvents(at: today14_28, sessionId: "mock-newest",
            prompt: "Tại sao tôi vẫn chưa thấy thay đổi UI session?",
            tools: ["Bash: ls -la .worktrees/", "Read CodePetApp.swift"],
            iso: iso, summaryDelay: 75)

        events += turnEvents(at: today14_32, sessionId: "mock-newest",
            prompt: "Tôi muốn quy về branch feat-refactor-core",
            tools: ["Bash: git stash push", "Bash: git merge --ff-only", "Bash: git worktree remove"],
            iso: iso, summaryDelay: 90)

        events += turnEvents(at: today14_36, sessionId: "mock-newest",
            prompt: "Giờ tôi chat thì sẽ hiện luôn hay sao?",
            tools: ["Read events.jsonl"],
            iso: iso, summaryDelay: 60)

        events += turnEvents(at: today14_40, sessionId: "mock-newest",
            prompt: "Thử tiêm mock narrative để test UI",
            tools: ["Write ReflectionMockSeeder.swift", "Edit ReflectionEventStore.swift", "Edit NarrativeStore.swift"],
            iso: iso, summaryDelay: 120)

        events += turnEvents(at: today14_45, sessionId: "mock-newest",
            prompt: "UI có thể nào như Claude chat hay GPT chat không, kiểu có avatar?",
            tools: ["Write NarrativeChatView.swift", "Edit ReflectionTab.swift"],
            iso: iso, summaryDelay: 90)

        events += turnEvents(at: today14_50, sessionId: "mock-newest",
            prompt: "Một session nên là một conversation, ở cuối có summary và bài học",
            tools: ["Edit Turn.swift", "Write SessionSummaryStore.swift", "Write SessionSummaryView.swift", "Edit ReflectionTab.swift"],
            iso: iso, summaryDelay: 180)

        // === Today morning: mock-morning — 4-turn Cloud Function arc ===

        events += turnEvents(at: today9_15, sessionId: "mock-morning",
            prompt: "Setup Cloud Function tạo narrative cho từng lượt làm việc",
            tools: ["Write functions/src/index.ts", "Write summarizeTurn.ts", "Write rateLimit.ts", "Write cache.ts"],
            iso: iso, summaryDelay: 180)

        events += turnEvents(at: today9_22, sessionId: "mock-morning",
            prompt: "Thêm idempotency cache để tránh tốn quota khi retry",
            tools: ["Edit cache.ts", "Edit summarizeTurn.ts"],
            iso: iso, summaryDelay: 90)

        // Turn 3: closed but no narrative — will become .summarizing → .failed
        events += turnEvents(at: today9_30, sessionId: "mock-morning",
            prompt: "Thử deploy lên Firebase project devpet-8f4b1",
            tools: ["Bash: firebase deploy --only functions"],
            iso: iso, summaryDelay: 240)

        // Turn 4: prompt with no summary — orphan if current time > 09:42 + 30 min
        events.append(("prompt", iso.string(from: today9_42), "mock-morning", "Còn 1 chỗ chưa fix xong"))

        // === Yesterday afternoon: mock-yesterday — 5-turn brainstorm arc ===

        events += turnEvents(at: yesterday16_00, sessionId: "mock-yesterday",
            prompt: "Brainstorm thiết kế Reflection log mới — log đỡ kỹ thuật, có bài học",
            tools: ["Read existing-spec.md", "Edit design-spec.md"],
            iso: iso, summaryDelay: 240)

        events += turnEvents(at: yesterday16_06, sessionId: "mock-yesterday",
            prompt: "Mỗi lượt prompt sẽ là 1 entry hay gom theo session?",
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 90)

        events += turnEvents(at: yesterday16_11, sessionId: "mock-yesterday",
            prompt: "Ai sinh ra narrative — hook gọi API trực tiếp hay app?",
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 120)

        events += turnEvents(at: yesterday16_17, sessionId: "mock-yesterday",
            prompt: "Format hiển thị nên thế nào — 1 đoạn hay tách phần?",
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 100)

        events += turnEvents(at: yesterday16_22, sessionId: "mock-yesterday",
            prompt: "Còn raw events thì sao — giữ hay bỏ?",
            tools: ["Edit design-spec.md"],
            iso: iso, summaryDelay: 80)

        composition.eventStore.seedMockEvents(events)

        // MARK: - Per-turn narratives (educational whatHappened)

        let narratives: [(turnId: String, narrative: Narrative)] = [

            // === mock-newest: 7 turns ===

            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_23)),
                Narrative(
                    title: "Thêm grouping theo session vào sidebar",
                    whatYouWanted: "Bạn muốn thấy các lượt làm việc được nhóm theo session, không chỉ theo ngày.",
                    whatHappened: "Việc grouping theo session giải quyết vấn đề cognitive load: khi danh sách dài, mắt cần landmarks để định vị. Cách Swift làm: dictionary group theo sessionId rồi sort theo newest turn — không động data model, chỉ thay render layer.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_23.addingTimeInterval(180),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_28)),
                Narrative(
                    title: "Debug: tại sao UI không cập nhật?",
                    whatYouWanted: "Bạn đã rebuild app nhưng vẫn không thấy thay đổi. Cảm giác như code không chạy.",
                    whatHappened: "Lỗi không phải ở code mà ở environment: Xcode đang mở project ở main checkout, trong khi code mới nằm ở worktree riêng. Khi làm work cô lập trên 1 branch khác, phải mở đúng .xcodeproj của worktree đó. Đây là pattern phổ biến với git worktree — dễ nhầm.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_28.addingTimeInterval(150),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_32)),
                Narrative(
                    title: "Gộp branch worktree về main",
                    whatYouWanted: "Bạn muốn mọi thay đổi trên 1 branch duy nhất để đỡ bị nhầm lẫn worktree.",
                    whatHappened: "Có 1188 dòng WIP chưa commit từ session trước trong main worktree, conflict với code từ worktree feat-reflection-narratives. Giải pháp 3 bước: stash WIP để an toàn, fast-forward merge worktree branch vào main, xóa worktree. Stash giữ WIP ở chỗ riêng — có thể lấy lại bằng git stash pop nếu đổi ý.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_32.addingTimeInterval(180),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_36)),
                Narrative(
                    title: "Hỏi: chat sẽ hiện luôn không?",
                    whatYouWanted: "Bạn muốn biết flow: khi chat với Claude Code, entry có hiện ngay trong app không?",
                    whatHappened: "Flow hoạt động: hook ghi vào events.jsonl khi user gõ → app poll 1.5s/lần → tạo Turn → hiện trong sidebar. Nhưng chưa thấy narrative thật vì Cloud Function chưa deploy — turn sẽ vào state failed(.network). Click 'Xem chi tiết kỹ thuật' vẫn xem được raw prompt.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_36.addingTimeInterval(120),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_40)),
                Narrative(
                    title: "Tiêm mock data để test UI không cần deploy",
                    whatYouWanted: "Bạn muốn xem UI thật trông thế nào mà không phải đợi deploy Cloud Function.",
                    whatHappened: "Pattern 'mock seeder' chỉ active trong DEBUG build qua #if DEBUG. Inject trực tiếp vào in-memory store (không ghi file thật) — relaunch là biến mất. Cover được tất cả UI states: ready (có narrative), summarizing (skeleton), failed (network), pendingOrphan (prompt cũ không có summary). Production build sẽ không bao giờ chạy code này.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_40.addingTimeInterval(180),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_45)),
                Narrative(
                    title: "Chuyển sang layout chat-style với avatar",
                    whatYouWanted: "Bạn muốn UI giống Claude/GPT — bong bóng chat, avatar pet bên user, AI bên kia.",
                    whatHappened: "Chat layout làm câu chuyện dễ scan hơn 3-section card: bong bóng nhỏ, mắt theo dõi flow tự nhiên trái-phải. Pet avatar dùng PNG pixel-art có sẵn (`char-byte`, `char-luna`...) với .interpolation(.none) để giữ chất pixel sắc nét. AI avatar là SF Symbol sparkles có gradient — đơn giản, không cần thêm asset.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_45.addingTimeInterval(150),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_50)),
                Narrative(
                    title: "Pivot: session-as-conversation",
                    whatYouWanted: "Bạn muốn 1 session là 1 cuộc trò chuyện đầy đủ với nhiều turn, có summary + bài học ở cuối.",
                    whatHappened: "Đây là sự thay đổi mental model: đơn vị đọc shift từ 'turn' (vi mô) sang 'session' (vĩ mô). Sidebar chọn session, body show all turns chronologically + summary card cuối. Bài học không còn ở mỗi turn — chuyển lên cấp session, vì 1 lesson tổng quát có giá trị hơn 7 lesson rời rạc. Per-turn narrative tập trung vào EXPLAIN — giải thích WHY chứ không chỉ WHAT.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_50.addingTimeInterval(240),
                    schemaVersion: 1
                )
            ),

            // === mock-morning: 2 ready turns (3rd will fail, 4th orphan) ===

            (
                Turn.makeID(sessionId: "mock-morning", promptISO: iso.string(from: today9_15)),
                Narrative(
                    title: "Dựng Cloud Function với 4 module riêng",
                    whatYouWanted: "Bạn muốn 1 dịch vụ trung gian giữa app và Claude API — app không lộ key, có thể giới hạn quota.",
                    whatHappened: "Cloud Function hoạt động như proxy có trí tuệ: nhận request từ app → kiểm tra Firebase ID token (auth) → đếm số lần gọi trong ngày (rate limit) → check cache idempotency 7 ngày (tránh tốn tiền gọi lại cùng turn) → mới gọi Claude. Tách 4 module riêng giúp test pure function — phát hiện logic sai sớm hơn nhiều so với test end-to-end.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today9_15.addingTimeInterval(300),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-morning", promptISO: iso.string(from: today9_22)),
                Narrative(
                    title: "Idempotency cache 7 ngày tránh tốn quota",
                    whatYouWanted: "Bạn lo: nếu app gọi lại 1 turn (do retry, race condition), Anthropic sẽ tính quota 2 lần.",
                    whatHappened: "Idempotency cache key theo (uid + turn_id), TTL 7 ngày. Cache check chạy TRƯỚC rate limit — quota chỉ tính khi thật sự gọi Anthropic. Dùng Firestore TTL field để tự xóa, không cần job dọn dẹp. Khi 2 instance cùng gọi 1 turn (race), instance đầu thắng — instance sau đọc cache, không tốn quota.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today9_22.addingTimeInterval(180),
                    schemaVersion: 1
                )
            ),

            // === mock-yesterday: 5 ready turns (the brainstorm) ===

            (
                Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_00)),
                Narrative(
                    title: "Khởi đầu brainstorm thiết kế Reflection log",
                    whatYouWanted: "Bạn muốn log Reflection đỡ kỹ thuật, dễ đọc cho người không phải dev, có thêm bài học rút ra.",
                    whatHappened: "Brainstorm hiệu quả nhất khi liệt kê các quyết định cần ra, không phải tính năng muốn có. Sản phẩm hiện tại chỉ log 'Edit foo.swift' — quá kỹ thuật. Mục tiêu mới: biến raw events thành narrative đọc được. Đặt câu hỏi: ai đọc, đọc khi nào, đọc để làm gì? Đáp án: user đọc sau khi xong việc, để hiểu mình đã làm gì + học được gì.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: yesterday16_00.addingTimeInterval(300),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_06)),
                Narrative(
                    title: "Quyết định: per-turn entry",
                    whatYouWanted: "Bạn cần chốt: mỗi entry trong sidebar là 1 prompt hay là toàn bộ 1 phiên?",
                    whatHappened: "Per-turn được chọn vì granularity nhỏ giúp tracking tốt hơn — user nhìn thấy từng quyết định một. Trade-off: nhiều entry hơn nhưng dễ điều hướng. Nếu gom theo session, sẽ mất chi tiết của các quyết định nhỏ. (Pivot sau này shift sang per-session, nhưng giữ per-turn ở data layer.)",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: yesterday16_06.addingTimeInterval(120),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_11)),
                Narrative(
                    title: "Quyết định: app gọi Claude API qua Firebase proxy",
                    whatYouWanted: "Bạn cần chọn: hook gọi Anthropic trực tiếp hay app gọi qua server?",
                    whatHappened: "App + Firebase proxy được chọn vì 3 lý do: (1) không lộ Anthropic key trong client app, (2) có thể giới hạn quota per-user qua Firestore counter, (3) dễ thêm logic — caching, retry — ở 1 chỗ. Trade-off: cần backend infra (Firebase Functions). Nhưng project đã có Firebase Auth nên chi phí thấp.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: yesterday16_11.addingTimeInterval(180),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_17)),
                Narrative(
                    title: "Quyết định: 3-section narrative format",
                    whatYouWanted: "Bạn cần chọn cách hiển thị: 1 đoạn dài hay tách phần rõ ràng?",
                    whatHappened: "Tách 3 phần được chọn: 'Bạn muốn / Đã làm / Bài học' — mirror cấu trúc nhật ký classic. Mỗi phần có vai trò riêng: intent (motivation), action (what was done), insight (what was learned). Trade-off: nhiều cấu trúc hơn 1 đoạn, nhưng dễ scan và dễ format AI output.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: yesterday16_17.addingTimeInterval(150),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_22)),
                Narrative(
                    title: "Quyết định: ẩn raw events mặc định",
                    whatYouWanted: "Bạn cần chốt: có giữ list raw events kỹ thuật hay bỏ luôn?",
                    whatHappened: "Pattern 'progressive disclosure': giữ data nhưng ẩn behind 1 click — 'Xem chi tiết kỹ thuật'. Giữ giao diện sạch cho 90% usecase đọc journal, vẫn cho power user truy cập raw data khi cần debug. Đây là cách dung hòa: bỏ hoàn toàn thì mất context, hiện luôn thì rối.",
                    lesson: "",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: yesterday16_22.addingTimeInterval(120),
                    schemaVersion: 1
                )
            ),
        ]

        for entry in narratives {
            composition.narrativeStore.seedMockNarrative(turnId: entry.turnId, narrative: entry.narrative)
        }

        // MARK: - Session summaries

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-newest",
            summary: "Phiên 27 phút iterate UX của Reflection tab. Bắt đầu từ feedback rằng các lượt bị trộn chung trong 1 ngày, đi qua việc fix worktree confusion, gộp branch về main, tiêm mock để test UI, chuyển sang chat-style với avatar pet, kết thúc bằng pivot lớn: session là đơn vị conversation, không phải turn.",
            lesson: "Khi feedback đến nhiều đợt, đừng vội gộp tất cả vào 1 PR khổng lồ. Mỗi vòng là 1 thử nghiệm có thể đo và rollback riêng. Pivot lớn nên đến cuối, sau khi đã hiểu rõ pain point qua các vòng nhỏ — nhảy thẳng vào pivot khi chưa hiểu rõ thường tốn thời gian gấp đôi.",
            generatedAt: today14_50.addingTimeInterval(8 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-morning",
            summary: "Phiên buổi sáng 35 phút xây Cloud Function cho hệ thống Reflection. Lượt 1 hoàn thành cấu trúc 4 module (auth, rate-limit, cache, AI call). Lượt 2 thêm idempotency cache để chống tốn quota. Lượt 3 thực hành deploy thực tế và gặp lỗi cấu hình Firebase. Lượt 4 bỏ dở — mạch tập trung đứt sau lỗi deploy.",
            lesson: "Gặp lỗi infrastructure dễ làm mất đà hơn lỗi code — vì không có stack trace rõ. Khi bị block bởi infra, đặt timer 15 phút: nếu chưa giải được thì note lại và chuyển task khác thay vì tiếp tục mất momentum.",
            generatedAt: today9_42.addingTimeInterval(10 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))

        // Intentionally NOT seeding summary for mock-yesterday — so the
        // "Đang tóm tắt phiên..." placeholder + "Tóm tắt phiên ngay" manual
        // button are visible when you click that session.
        // Uncomment to restore:
        // composition.summaryStore.seedMockSummary(SessionSummary(
        //     sessionId: "mock-yesterday",
        //     summary: "Phiên chiều hôm qua 25 phút brainstorm thiết kế hệ thống Reflection từ đầu...",
        //     lesson: "Brainstorm kiến trúc hiệu quả nhất khi liệt kê các QUYẾT ĐỊNH cần ra...",
        //     generatedAt: yesterday16_22.addingTimeInterval(8 * 60),
        //     model: "claude-haiku-4-5-20251001",
        //     schemaVersion: 1
        // ))
    }

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
