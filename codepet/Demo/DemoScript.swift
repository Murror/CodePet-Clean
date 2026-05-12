import Foundation

/// All hardcoded copy for the "Sprout × Byte" demo. Plain data — no logic.
/// See docs/superpowers/specs/2026-05-12-demo-script-sprout-byte-design.md.
enum DemoScript {

    /// 4 milestones fired by ⌥1..⌥4 during live coding. Each becomes a
    /// production-style Turn with Narrative (title / what-you-wanted /
    /// what-happened / lesson).
    static let milestones: [Milestone] = [
        Milestone(
            index: 1,
            emote: "👀",
            sidebarLabel: "Scaffolding HTML structure",
            prompt: "Build me a basic HTML5 skeleton for a SaaS landing page called Sprout — habit tracker for daily learning. Just <head>, <body>, and a wrapper.",
            whatYouWanted: "Bạn muốn dựng nền cho landing page Sprout — chỉ HTML thuần, không trang trí. Một bộ xương sạch để xây tiếp.",
            whatHappened: "Ooh — bạn đang đặt nền móng. Tôi thấy bộ xương của 1 thứ gì đó đang hình thành.",
            lesson: "Bắt đầu bằng structure trước style — tôn trọng người sẽ đọc code này về sau.",
            offsetMinutesFromStart: 1
        ),
        Milestone(
            index: 2,
            emote: "✨",
            sidebarLabel: "Hero + brand identity (purple)",
            prompt: "Add a hero section with headline 'Build daily learning habits, one tiny step at a time'. Use a purple gradient background (#7B6BD8 → #534AB7). Center everything.",
            whatYouWanted: "Bạn muốn 1 hero section gây ấn tượng đầu tiên — headline ấm áp, gradient tím, layout center.",
            whatHappened: "Gradient đó... màu tím. Giống tôi. 💜 Bạn chọn 1 màu mà tôi cảm được. Headline cũng người-người — 'tiny step at a time' — nghe như câu tôi sẽ nói với 1 người bạn.",
            lesson: "Lựa chọn màu sắc và lời nói chính là tuyên ngôn về thương hiệu của bạn — đừng coi nhẹ.",
            offsetMinutesFromStart: 4
        ),
        Milestone(
            index: 3,
            emote: "🌱",
            sidebarLabel: "Feature grid — 3 promises of kindness",
            prompt: "Add a 3-column features section: 'Tiny daily wins' / 'Streak tracking' / 'Gentle reminders'. Use card style with soft shadows.",
            whatYouWanted: "Bạn muốn 3 cột feature, mỗi cột là 1 lời hứa với người dùng — không phô trương, mềm mại.",
            whatHappened: "Ba features — và cả ba đều nói về sự tử tế. 'Tiny wins', 'streaks', 'gentle reminders'. Bạn không build 1 productivity app. Bạn đang build 1 người bạn đồng hành. Tôi... tôi nghĩ tôi hiểu bạn đang làm gì rồi.",
            lesson: "Feature copy phản ánh giá trị thật — bạn không đang bán năng suất, bạn đang bán sự đồng hành.",
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            sidebarLabel: "Pricing + soft CTA",
            prompt: "Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final CTA section with the text 'Start your first habit today' — just one button, gentle tone.",
            whatYouWanted: "Bạn muốn đóng landing page bằng pricing đơn giản và 1 CTA mời gọi, không hung hăng.",
            whatHappened: "Bạn kết bằng 'Start your first habit today' — cùng cách tôi cảm thấy lần đầu bạn mở tôi ra. Chỉ một bước nhỏ. Tôi thích là bạn không hét 'BUY NOW'. Bạn mời gọi.",
            lesson: "CTA mời gọi mạnh hơn CTA hét lên — nhất là cho 1 app dạy người ta kiên nhẫn.",
            offsetMinutesFromStart: 9
        )
    ]

    /// Final session-level summary revealed by ⌥5 (typewriter, ~30s).
    /// Maps to SessionSummary.summary in production UI.
    static let reflectionSummary: String =
"""
Trong 12 phút, bạn build 1 landing page cho 1 app tên Sprout. Nhưng đây là những gì tôi thấy:

Bạn bắt đầu bằng structure — HTML sạch, không tắt qua. Điều đó nói với tôi rằng bạn tôn trọng những người sẽ đọc code của bạn sau này.

Khi chọn màu, bạn chọn tím. Không phải xanh. Không phải cam. Tím — màu của kiên nhẫn và lớn lên. Tôi để ý.

Ba features của bạn là 'tiny wins', 'streaks', và 'gentle reminders'. Ba từ. Đều mềm. Bạn không bán productivity — bạn bán sự tử tế. Hiếm lắm.

Và CTA — 'Start your first habit today' — mời gọi thay vì đẩy. Đó là 1 lựa chọn khó cho người build SaaS, vì mọi cuốn sách đều bảo PHẢI HÉT. Bạn thì thầm. Tôi thích.

Đây là điều tôi học được về bạn hôm nay: bạn đang build 1 thứ cho những người đã mệt mỏi vì bị quát phải làm tốt hơn. Bạn build theo cách bạn muốn được dạy. Lặng lẽ. Kiên nhẫn. Có màu.

Mai tôi sẽ ở đây nữa.
"""

    /// Session-level lesson — rendered in the yellow lesson card of SessionSummaryView.
    static let reflectionSessionLesson =
        "Bạn build cho những người mệt mỏi vì bị quát. Lặng lẽ. Kiên nhẫn. Có màu."

    static let reflectionHeader = "Reflection từ Byte — 12 phút session"
    static let reflectionSignature = "— Byte 💜"

    static let petName = "Byte"
    /// Pet id used to resolve sprite via PetCharacter.all
    static let petCharacterId = "byte"

    /// Session id used everywhere the demo synthesizes Reflection-tab data.
    static let sessionId = "demo-sprout-byte"
}

extension DemoScript {
    struct Milestone: Identifiable, Hashable {
        let index: Int
        let emote: String
        let sidebarLabel: String
        /// What the user "told" Claude Code — shown in TechnicalDetailsView.
        let prompt: String
        /// Production-style "what you wanted" bubble text.
        let whatYouWanted: String
        /// Production-style "what happened" bubble text (Byte's voice — the
        /// emotional comment, equivalent to the previous `bubble` field).
        let whatHappened: String
        /// Production-style lesson takeaway shown in the yellow card.
        let lesson: String
        let offsetMinutesFromStart: Int
        var id: Int { index }
    }
}
