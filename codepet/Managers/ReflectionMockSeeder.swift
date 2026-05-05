import Foundation

/// Injects sample turns + narratives so the Reflection UI can be reviewed
/// without a real Cloud Function deploy. Active only in DEBUG builds.
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

        let narratives: [(turnId: String, sessionId: String, narrative: Narrative)] = [
            (
                Turn.makeID(sessionId: "mock-newest", promptISO: iso.string(from: today14_23)),
                "mock-newest",
                Narrative(
                    title: "Thêm grouping theo session vào sidebar Reflection",
                    whatYouWanted: "Bạn muốn thấy các lượt làm việc được nhóm theo session, không chỉ theo ngày, để dễ scan câu chuyện kể trong từng phiên.",
                    whatHappened: "Cùng AI rà code phần sidebar, thêm cấu trúc SessionBucket và header 'Phiên HH:mm · N turn' phía trên các lượt cùng phiên. Giữ nguyên thứ tự mới → cũ ở cả hai cấp.",
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
                    whatHappened: "Tạo cấu trúc package mới với 4 module: xác thực, đếm hạn ngạch, cache idempotency 7 ngày, và phần gọi AI có ép schema kết quả. Mỗi module có test riêng nên có thể kiểm tra từng phần trước khi tích hợp.",
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
                    whatHappened: "Brainstorm 7 quyết định: per-turn entry, app gọi Claude API, auto-summarize ngay khi turn kết thúc, format 3 phần (Bạn muốn / Đã làm / Bài học), ẩn moments mặc định, lesson per-turn, dùng Firebase proxy cho chi phí.",
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
    }
}
