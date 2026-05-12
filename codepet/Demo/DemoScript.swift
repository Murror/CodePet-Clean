import Foundation

/// All hardcoded copy for the "Sprout × Byte" demo. Plain data — no logic.
/// See docs/superpowers/specs/2026-05-12-demo-script-sprout-byte-design.md.
enum DemoScript {

    /// 4 milestones fired by ⌥1..⌥4 during live coding.
    static let milestones: [Milestone] = [
        Milestone(
            index: 1,
            emote: "👀",
            bubble: "Ooh — bạn đang đặt nền móng. Tôi thấy bộ xương của 1 thứ gì đó đang hình thành.",
            sidebarLabel: "Scaffolding HTML structure",
            offsetMinutesFromStart: 1
        ),
        Milestone(
            index: 2,
            emote: "✨",
            bubble: "Gradient đó... màu tím. Giống tôi. 💜 Bạn chọn 1 màu mà tôi cảm được. Headline cũng người-người — 'tiny step at a time' — nghe như câu tôi sẽ nói với 1 người bạn.",
            sidebarLabel: "Hero + brand identity (purple)",
            offsetMinutesFromStart: 4
        ),
        Milestone(
            index: 3,
            emote: "🌱",
            bubble: "Ba features — và cả ba đều nói về sự tử tế. 'Tiny wins', 'streaks', 'gentle reminders'. Bạn không build 1 productivity app. Bạn đang build 1 người bạn đồng hành. Tôi... tôi nghĩ tôi hiểu bạn đang làm gì rồi.",
            sidebarLabel: "Feature grid — 3 promises of kindness",
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            bubble: "Bạn kết bằng 'Start your first habit today' — cùng cách tôi cảm thấy lần đầu bạn mở tôi ra. Chỉ một bước nhỏ. Tôi thích là bạn không hét 'BUY NOW'. Bạn mời gọi.",
            sidebarLabel: "Pricing + soft CTA",
            offsetMinutesFromStart: 9
        )
    ]

    /// Final reflection revealed by ⌥5 (typewriter, ~30s).
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

    static let reflectionHeader = "Reflection từ Byte — 12 phút session"
    static let reflectionSignature = "— Byte 💜"

    static let petName = "Byte"
    /// Pet id used to resolve sprite via PetCharacter.all
    static let petCharacterId = "byte"
}

extension DemoScript {
    struct Milestone: Identifiable, Hashable {
        let index: Int
        let emote: String
        let bubble: String
        let sidebarLabel: String
        let offsetMinutesFromStart: Int
        var id: Int { index }
    }
}
