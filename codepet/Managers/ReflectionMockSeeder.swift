import Foundation

/// Injects sample turns + narratives + session summaries so the Reflection UI
/// can be reviewed without a real Cloud Function deploy.
/// Active only in DEBUG builds.
@MainActor
enum ReflectionMockSeeder {

    static func seed(into composition: ReflectionComposition) {
        let cal = Calendar.current
        let now = Date()

        let today9_15  = cal.date(bySettingHour: 9,  minute: 15, second: 0, of: now)!
        let today9_25  = cal.date(bySettingHour: 9,  minute: 25, second: 0, of: now)!
        let today9_50  = cal.date(bySettingHour: 9,  minute: 50, second: 0, of: now)!
        let today14_23 = cal.date(bySettingHour: 14, minute: 23, second: 0, of: now)!
        let yesterday  = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterday16_00 = cal.date(bySettingHour: 16, minute: 0, second: 0, of: yesterday)!

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let events: [(type: String, isoTime: String, sessionId: String, text: String)] = [
            // Today afternoon — 1 turn (will be ready, has narrative)
            ("prompt",  iso.string(from: today14_23),                          "mock-newest", "Sửa giúp tôi UI Reflection để hiện grouping theo session"),
            ("tool",    iso.string(from: today14_23.addingTimeInterval(30)),  "mock-newest", "Edit ReflectionTab.swift"),
            ("summary", iso.string(from: today14_23.addingTimeInterval(60)),  "mock-newest", "Edit ReflectionTab.swift"),

            // Today morning session — 3 turns
            // Turn A: ready (has narrative)
            ("prompt",  iso.string(from: today9_15),                           "mock-morning", "Setup Cloud Function tạo narrative cho từng lượt"),
            ("tool",    iso.string(from: today9_15.addingTimeInterval(60)),   "mock-morning", "Edit summarizeTurn.ts"),
            ("summary", iso.string(from: today9_15.addingTimeInterval(120)),  "mock-morning", "Edit summarizeTurn.ts"),

            // Turn B: closed but no narrative (will become .summarizing → .failed via enricher trying REPLACE_ME URL)
            ("prompt",  iso.string(from: today9_25),                           "mock-morning", "Thử deploy lên Firebase project"),
            ("tool",    iso.string(from: today9_25.addingTimeInterval(60)),   "mock-morning", "Bash: firebase deploy"),
            ("summary", iso.string(from: today9_25.addingTimeInterval(180)),  "mock-morning", "Bash: firebase deploy"),

            // Turn C: prompt with no summary — will be .pendingOrphan if current time > 09:50 + 30min
            ("prompt",  iso.string(from: today9_50),                           "mock-morning", "Còn 1 chỗ chưa xong"),

            // Yesterday afternoon — 1 turn (ready, has narrative)
            ("prompt",  iso.string(from: yesterday16_00),                          "mock-yesterday", "Brainstorm thiết kế Reflection log mới"),
            ("tool",    iso.string(from: yesterday16_00.addingTimeInterval(120)), "mock-yesterday", "Edit design-spec.md"),
            ("summary", iso.string(from: yesterday16_00.addingTimeInterval(300)), "mock-yesterday", "Edit design-spec.md"),
        ]

        composition.eventStore.seedMockEvents(events)

        // MARK: - Per-turn narratives (educational whatHappened)

        let narratives: [(turnId: String, sessionId: String, narrative: Narrative)] = [
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_23)),
                "mock-newest",
                Narrative(
                    title: "Thêm grouping theo session vào sidebar Reflection",
                    whatYouWanted: "Bạn muốn thấy các lượt làm việc được nhóm theo session, không chỉ theo ngày, để dễ scan câu chuyện kể trong từng phiên.",
                    whatHappened: "Việc grouping theo session giải quyết vấn đề cognitive load: khi danh sách dài, mắt cần landmarks để định vị. Thêm 1 lớp group là thêm 1 lớp landmarks. Cách Swift làm: dictionary group theo sessionId + sort theo newest turn — không động data model, chỉ thay render layer. Kết quả là sidebar 2 lớp (ngày → session) giúp mắt phân biệt ngay mà không cần đọc kỹ từng dòng.",
                    lesson: "Khi sidebar có 2 lớp grouping, dùng font/độ đậm khác nhau cho 2 lớp giúp mắt phân biệt nhanh thay vì đọc kỹ.",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today14_23.addingTimeInterval(180),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-morning", promptISO: iso.string(from: today9_15)),
                "mock-morning",
                Narrative(
                    title: "Setup Cloud Function tạo narrative",
                    whatYouWanted: "Bạn muốn ghép một dịch vụ trung gian giữa app và Claude API để app không lộ key, đồng thời giới hạn được số lượng tóm tắt mỗi ngày.",
                    whatHappened: "Cloud Function hoạt động như một proxy có trí tuệ: nhận request từ app, kiểm tra Firebase ID token (xác thực), đếm số lần gọi trong ngày (rate limit), kiểm tra cache idempotency 7 ngày (tránh tốn tiền gọi lại cùng turn), rồi mới gọi Claude. Lý do chia 4 module riêng (auth, rate-limit, cache, AI call): mỗi module có thể test độc lập như pure function — phát hiện logic sai sớm hơn nhiều so với test end-to-end khi deploy.",
                    lesson: "Tách auth, rate limit, cache thành module riêng biệt giúp test pure function trước khi wire vào handler — phát hiện logic sai sớm hơn nhiều so với test end-to-end.",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: today9_15.addingTimeInterval(300),
                    schemaVersion: 1
                )
            ),
            (
                Turn.makeID(sessionId: "mock-yesterday", promptISO: iso.string(from: yesterday16_00)),
                "mock-yesterday",
                Narrative(
                    title: "Thiết kế Reflection log thành câu chuyện kể",
                    whatYouWanted: "Bạn muốn log Reflection đỡ kỹ thuật, dễ đọc cho người không phải dev, có thêm bài học rút ra từ mỗi lượt làm việc với AI.",
                    whatHappened: "Thiết kế tốt bắt đầu từ câu hỏi: ai đọc, đọc khi nào, đọc để làm gì? Với Reflection log: người dùng đọc sau khi xong việc, để hiểu mình đã làm gì và học được gì — không phải để debug. Nên format 3 phần (Bạn muốn / Đã xảy ra / Bài học) phù hợp hơn raw event log. Quyết định ẩn moments mặc định giữ giao diện sạch cho 90% usecase; raw events vẫn có nhưng collapsed. Đây là pattern 'progressive disclosure' — thông tin nặng ẩn sau 1 click, không bị ẩn hoàn toàn.",
                    lesson: "Khi yêu cầu thay đổi cách hiển thị, tách rạch raw data và presentation giúp đỡ rối khi đổi UI — mỗi lớp giải quyết một việc.",
                    model: "claude-haiku-4-5-20251001",
                    generatedAt: yesterday16_00.addingTimeInterval(600),
                    schemaVersion: 1
                )
            )
        ]

        for entry in narratives {
            composition.narrativeStore.seedMockNarrative(turnId: entry.turnId, narrative: entry.narrative)
        }

        // MARK: - Session summaries

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-newest",
            summary: "Phiên 18 phút tập trung vào việc làm sidebar dễ scan hơn. Bắt đầu từ feedback rằng các lượt khác nhau bị trộn chung trong 1 ngày, đi qua việc thêm grouping theo session với header 'Phiên HH:mm', kết thúc với layout sidebar 2 lớp gọn gàng.",
            lesson: "Khi UX feedback đề cập đến cảm giác 'rối', thường vấn đề là cognitive load — mắt thiếu landmarks. Thêm 1 lớp grouping nhẹ thường giải quyết được mà không cần thay data model hay business logic.",
            generatedAt: today14_23.addingTimeInterval(15 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-morning",
            summary: "Phiên buổi sáng 35 phút xây dựng nền tảng Cloud Function cho hệ thống Reflection. Lượt đầu hoàn thành cấu trúc 4 module (auth, rate-limit, cache, AI call). Lượt hai thực hành deploy thực tế và gặp lỗi cấu hình Firebase. Lượt ba bỏ dở — mạch tập trung đã đứt sau khi gặp lỗi deploy.",
            lesson: "Gặp lỗi infrastructure (Firebase deploy) dễ làm mất đà hơn gặp lỗi code — vì không có stack trace rõ ràng để debug. Khi bị block bởi infra, đặt timer 15 phút: nếu chưa giải được thì note lại và chuyển sang task khác thay vì tiếp tục mất momentum.",
            generatedAt: today9_15.addingTimeInterval(45 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))

        composition.summaryStore.seedMockSummary(SessionSummary(
            sessionId: "mock-yesterday",
            summary: "Phiên chiều hôm qua 25 phút brainstorm thiết kế hệ thống Reflection từ đầu. 7 quyết định kiến trúc lớn: granularity (per-turn), nguồn dữ liệu (app gọi Claude API thay vì IDE plugin), timing (auto-summarize khi turn kết thúc), format hiển thị (3 phần narrative), mức độ chi tiết mặc định (ẩn moments), lesson granularity (per-turn), và cost control (Firebase proxy).",
            lesson: "Brainstorm kiến trúc hiệu quả nhất khi bạn liệt kê các quyết định cần ra, không phải liệt kê các tính năng muốn có. Mỗi quyết định kiến trúc nên có lý do rõ ràng — nếu không giải thích được tại sao, đó là dấu hiệu quyết định đó chưa đủ chín.",
            generatedAt: yesterday16_00.addingTimeInterval(30 * 60),
            model: "claude-haiku-4-5-20251001",
            schemaVersion: 1
        ))
    }
}
