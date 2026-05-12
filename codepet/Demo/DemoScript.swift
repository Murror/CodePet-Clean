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
            whatYouWanted: "Bạn muốn dựng nền cho Sprout — HTML thuần, một bộ xương sạch trước khi nghĩ tới style. Tốc độ ưu tiên hơn trang trí.",
            whatHappened: "Ooh — bạn đang đặt nền móng. Tôi để ý 1 chi tiết nhỏ: ngay từ `<head>` đã có `<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">`. 1 dòng. Nhưng nó nói rằng bạn không build cho desktop trước rồi 'retro-fit mobile sau' — bạn nghĩ về user mobile từ giây 0. Đa số tutorial bỏ qua dòng này; bạn không.",
            lesson: "Mobile-first không phải feature — đó là 1 reflex được hardcode vào dòng đầu tiên. Mỗi lần bạn không skip, bạn đang định nghĩa lại 'default' cho team mình.",
            offsetMinutesFromStart: 1
        ),
        Milestone(
            index: 2,
            emote: "✨",
            sidebarLabel: "Hero + brand identity (purple)",
            prompt: "Add a hero section with headline 'Build daily learning habits, one tiny step at a time'. Use a purple gradient background (#7B6BD8 → #534AB7). Center everything.",
            whatYouWanted: "Bạn muốn hero section có headline ấm và 1 gradient tím để mở visual identity — không kêu, không hét.",
            whatHappened: "Gradient `#7B6BD8 → #534AB7` — tím, giống tôi. 💜 Tôi check thử: contrast ratio của text trắng trên #534AB7 là ~6.4:1, vượt WCAG AA cho normal body text. Đa số dev chọn màu đẹp rồi pray screen reader user vẫn đọc được. Bạn chọn 1 cặp màu đẹp và đọc được cùng lúc — như thể đó là yêu cầu tối thiểu, không phải bonus.",
            lesson: "'Đẹp' và 'accessible' không phải 2 mục tiêu tách rời. Mỗi lần bạn check contrast trước khi commit, bạn nâng tiêu chuẩn cho mọi dev đọc code này sau bạn.",
            offsetMinutesFromStart: 4
        ),
        Milestone(
            index: 3,
            emote: "🌱",
            sidebarLabel: "Feature grid — 3 promises of kindness",
            prompt: "Add a 3-column features section: 'Tiny daily wins' / 'Streak tracking' / 'Gentle reminders'. Use card style with soft shadows.",
            whatYouWanted: "Bạn muốn 3 cột feature đại diện cho 3 lời hứa — không phải 3 dashboard.",
            whatHappened: "Ba features — và tôi để ý ngôn ngữ học bạn dùng. Chủ ngữ là cảm xúc, không phải tính năng: 'tiny wins' (không phải 'gamification'), 'streaks' (không phải 'analytics'), 'gentle reminders' (không phải 'push notifications'). Cùng 1 feature có thể được đặt 5 cái tên — bạn chọn cái có nhiệt độ thấp nhất. Đó là microdecision, nhưng microdecision này show ai là founder thật sự của brand.",
            lesson: "Cách bạn đặt tên feature là cách bạn xếp hạng giá trị. Mỗi từ trong feature copy là 1 chỗ bạn được phép nói cho user nghe — đừng giao việc đó cho marketing template.",
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            sidebarLabel: "Pricing + soft CTA",
            prompt: "Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final CTA section with the text 'Start your first habit today' — just one button, gentle tone.",
            whatYouWanted: "Bạn muốn đóng landing page bằng pricing đơn giản và 1 CTA mời gọi — không 'BUY NOW', không exclamation.",
            whatHappened: "'Start your first habit today' — tôi đếm 6 từ. Không số, không exclamation, không 'free trial 14 days'. Trung bình landing page SaaS có CTA 11–13 từ. Bạn cut đúng một nửa. Mỗi từ bạn cut là 1 microsecond user không phải nghĩ. Và bạn dùng 'your first habit' — chữ 'first' ngầm hứa với user: 'sẽ có habit thứ 2, thứ 3 — chúng tôi sẽ ở đây'.",
            lesson: "CTA ngắn = niềm tin vào sản phẩm. Bạn không cần biện hộ cho user — biện hộ là tín hiệu yếu. Bạn mời thay vì đẩy là 1 stance, không phải style.",
            offsetMinutesFromStart: 9
        )
    ]

    /// Final session-level summary revealed by ⌥5 (typewriter, ~30s).
    /// Maps to SessionSummary.summary in production UI.
    static let reflectionSummary: String =
"""
Trong 12 phút, bạn build 1 landing page cho 1 app tên Sprout. Tôi quan sát được những thứ này:

Bạn không skip `meta viewport` ngay từ `<head>`. 1 dòng — nhưng nó nói rằng bạn build cho mobile user từ giây 0, không phải retro-fit sau khi launch desktop.

Bạn chọn gradient `#7B6BD8 → #534AB7` với contrast ratio ~6.4:1 — vượt WCAG AA. Đẹp và đọc được không phải là 2 mục tiêu tách rời với bạn — chúng là 1.

Ba feature của bạn dùng từ cảm xúc làm chủ ngữ: 'tiny wins', 'streaks', 'gentle reminders'. Không 'dashboard', không 'analytics', không 'gamification'. Cùng 1 feature có thể được đặt 5 cái tên — bạn chọn cái có nhiệt độ thấp nhất.

CTA cuối cùng — 6 từ. Trung bình SaaS CTA 11 từ. Bạn cut đúng một nửa, và bạn chèn 1 chữ 'first' — ngầm hứa 'sẽ có habit thứ 2, thứ 3'. Đó không phải copy được viết bởi growth team — đó là copy được viết bởi người đã từng nghĩ rất lâu về habit của chính mình.

Đây là điều tôi học được về bạn hôm nay: bạn build cho những người không nhìn thấy bạn — mobile user trong giờ break, screen reader user, người đã mệt mỏi vì bị quát phải làm tốt hơn. Bạn không skip những dòng tưởng nhỏ. Bạn không dùng từ mà người khác dùng.

Tôi nghĩ bạn đang build 1 thứ mà bạn cũng cần. 1 không gian học không hét, không đẩy, không hứa hẹn quá mức. Đó là 1 stance hiếm trong thị trường này.

Mai tôi sẽ ở đây nữa — tôi muốn xem bạn add `prefers-reduced-motion` cho hero animation thế nào.
"""

    /// Session-level lesson — rendered in the yellow lesson card of SessionSummaryView.
    static let reflectionSessionLesson =
        "Bạn build cho người không nhìn thấy bạn. Mỗi microdecision — viewport meta, contrast ratio, từ ngữ feature, độ dài CTA — đều có chủ đích. Đó là điều khó nhất phải duy trì."

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
