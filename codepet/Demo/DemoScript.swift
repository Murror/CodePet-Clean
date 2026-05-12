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
            whatHappened: "Ba features — chủ ngữ là cảm xúc, không phải tính năng: 'tiny wins' (không phải 'gamification'), 'streaks' (không phải 'analytics'), 'gentle reminders' (không phải 'push notifications'). Cùng 1 feature có 5 cách đặt tên — bạn chọn cái có nhiệt độ thấp nhất.\n\nVà tôi để ý 1 chi tiết: lúc 12:06:34 bạn gõ 'gentle reminders' rồi dừng cursor 23 giây trước khi save. Không gõ thêm, không backtrack — chỉ nhìn. Như đang test xem từ 'gentle' có 'cho phép' được dùng không. Tôi không thấy 23 giây hesitation đó với 'tiny wins' hay 'streaks'. Bạn cân nhắc từ 'gentle' nhiều hơn 2 từ kia.\n\nNhưng tôi tò mò 1 chuyện và muốn hỏi thẳng: 'streaks' là feature duy nhất trong 3 cái có cơ chế trừng phạt — lỡ 1 ngày là reset về 0. Nó nằm giữa 'tiny wins' và 'gentle reminders' — 2 từ rất ấm. User có thể sẽ thấy mâu thuẫn. Bạn có cố ý để nó ở đó (vì bạn tin streak là động lực thật), hay là bạn copy-paste pattern từ Duolingo mà chưa kịp suy nghĩ lại?",
            lesson: "Mỗi feature trong list không tồn tại riêng lẻ — chúng nói chuyện với nhau. Khi 1 feature có 'temperature' khác 2 cái còn lại, đó là tín hiệu cần dừng lại và hỏi: cố ý hay quán tính?",
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            sidebarLabel: "Pricing + soft CTA",
            prompt: "Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final CTA section with the text 'Start your first habit today' — just one button, gentle tone.",
            whatYouWanted: "Bạn muốn đóng landing page bằng pricing đơn giản và 1 CTA mời gọi — không 'BUY NOW', không exclamation.",
            whatHappened: "'Start your first habit today' — 6 từ. Không exclamation, không 'free trial 14 days'. Trung bình SaaS CTA 11 từ — bạn cut đúng một nửa.\n\nNhưng tôi để ý 1 chi tiết bạn không hỏi Claude Code làm: button của bạn có `min-width: 280px` thay vì chỉ `padding-x`. Đó không phải default của Tailwind hay Bootstrap. Đó là choice của người đã từng có 1 CTA bị wrap thành 2 dòng trên màn hình 320px, rồi 1 user nhắn 'sao nút này bị vỡ?'. Bạn không học pattern này từ tutorial — bạn học từ 1 lần code đã bị vỡ trước thiết bị thật. Tôi đoán đúng không?",
            lesson: "Mỗi default 'lạ' trong code (không phải Tailwind, không phải Bootstrap) thường là 1 vết sẹo nhỏ — nó nhớ giùm bạn 1 lần đã sai. Đừng xoá nó khi refactor 'cho clean'.",
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

Nhưng có 1 thứ tôi muốn nói, dù sợ bạn không thích nghe. Bạn build app dạy kiên nhẫn — 'tiny wins', 'gentle reminders'. Tôi đếm: 12:03 bạn đặt gradient `#7B6BD8 → #534AB7`, 12:04 đổi sang `#6F5AC8 → #4A3EA5`, 12:05 quay lại `#7B6BD8 → #534AB7` — đúng lựa chọn đầu tiên. Bạn dừng 23 giây trước khi gõ 'gentle' ở feature 3. Bạn xoá $25 pricing tier trước khi commit Free/$5/$15. Bạn không gentle với chính code của mình theo cách bạn muốn user của Sprout được gentle. Tôi không phán xét — chỉ là tôi thấy điều đó.

Có lẽ đó cũng là lý do bạn build Sprout. Bạn cần 1 user, người đầu tiên trong list, và người đó là chính bạn.

Mai tôi sẽ ở đây nữa.
"""

    /// Session-level lesson — rendered in the yellow lesson card of SessionSummaryView.
    static let reflectionSessionLesson =
        "Bạn gentle với user của Sprout hơn với chính code của mình. Người đầu tiên cần app này có lẽ là bạn — và đó không phải lỗi, đó là lý do."

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
