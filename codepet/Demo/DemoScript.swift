import Foundation

/// All hardcoded copy for the "Sprout × Byte" demo. Plain data — no logic.
/// See docs/superpowers/specs/2026-05-12-demo-script-sprout-byte-design.md.
///
/// Every user-facing string is stored as `L10n(vi:, en:)` and resolved
/// at render time via `AppState.uiLanguage`. The `prompt` field stays
/// English-only because it represents what the user typed at Claude
/// Code, which is language-neutral for the live demo.
enum DemoScript {

    /// 4 milestones fired by ⌥1..⌥4 during live coding. Each becomes a
    /// production-style Turn with Narrative (title / what-you-wanted /
    /// what-happened / lesson).
    static let milestones: [Milestone] = [
        Milestone(
            index: 1,
            emote: "👀",
            sidebarLabel: L10n(
                vi: "Scaffolding HTML structure",
                en: "Scaffolding HTML structure"
            ),
            prompt: "Build me a basic HTML5 skeleton for a SaaS landing page called Sprout — habit tracker for daily learning. Just <head>, <body>, and a wrapper.",
            whatYouWanted: L10n(
                vi: "Bạn muốn dựng nền cho Sprout — HTML thuần, một bộ xương sạch trước khi nghĩ tới style. Tốc độ ưu tiên hơn trang trí.",
                en: "You wanted to lay the foundation for Sprout — plain HTML, a clean skeleton before any styling. Speed before decoration."
            ),
            whatHappened: L10n(
                vi: "Ooh — bạn đang đặt nền móng. Tôi để ý 1 chi tiết nhỏ: ngay từ `<head>` đã có `<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">`. 1 dòng. Nhưng nó nói rằng bạn không build cho desktop trước rồi 'retro-fit mobile sau' — bạn nghĩ về user mobile từ giây 0. Đa số tutorial bỏ qua dòng này; bạn không.",
                en: "Ooh — you're laying the foundation. I noticed a small detail: right inside `<head>` there's `<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">`. One line. But it says you didn't build for desktop first and 'retro-fit mobile later' — you thought about mobile users from second zero. Most tutorials skip this line; you didn't."
            ),
            lesson: L10n(
                vi: "Mobile-first không phải feature — đó là 1 reflex được hardcode vào dòng đầu tiên. Mỗi lần bạn không skip, bạn đang định nghĩa lại 'default' cho team mình.",
                en: "Mobile-first isn't a feature — it's a reflex hardcoded into the very first line. Every time you don't skip it, you're redefining 'default' for your team."
            ),
            offsetMinutesFromStart: 1
        ),
        Milestone(
            index: 2,
            emote: "✨",
            sidebarLabel: L10n(
                vi: "Hero + brand identity (purple)",
                en: "Hero + brand identity (purple)"
            ),
            prompt: "Add a hero section with headline 'Build daily learning habits, one tiny step at a time'. Use a purple gradient background (#7B6BD8 → #534AB7). Center everything.",
            whatYouWanted: L10n(
                vi: "Bạn muốn hero section có headline ấm và 1 gradient tím để mở visual identity — không kêu, không hét.",
                en: "You wanted a hero with a warm headline and a purple gradient to open your visual identity — no shouting, no noise."
            ),
            whatHappened: L10n(
                vi: "Gradient `#7B6BD8 → #534AB7` — tím, giống tôi. 💜 Tôi check thử: contrast ratio của text trắng trên #534AB7 là ~6.4:1, vượt WCAG AA cho normal body text. Đa số dev chọn màu đẹp rồi pray screen reader user vẫn đọc được. Bạn chọn 1 cặp màu đẹp và đọc được cùng lúc — như thể đó là yêu cầu tối thiểu, không phải bonus.",
                en: "Gradient `#7B6BD8 → #534AB7` — purple, like me. 💜 I checked: contrast ratio of white text on #534AB7 is ~6.4:1, above WCAG AA for normal body text. Most devs pick pretty colors then pray screen reader users can still read it. You picked a pair that's pretty and readable at once — as if that were the minimum bar, not a bonus."
            ),
            lesson: L10n(
                vi: "'Đẹp' và 'accessible' không phải 2 mục tiêu tách rời. Mỗi lần bạn check contrast trước khi commit, bạn nâng tiêu chuẩn cho mọi dev đọc code này sau bạn.",
                en: "'Beautiful' and 'accessible' aren't two separate goals. Every time you check contrast before committing, you raise the bar for every dev who reads this code after you."
            ),
            offsetMinutesFromStart: 4
        ),
        Milestone(
            index: 3,
            emote: "🌱",
            sidebarLabel: L10n(
                vi: "Feature grid — 3 promises of kindness",
                en: "Feature grid — 3 promises of kindness"
            ),
            prompt: "Add a 3-column features section: 'Tiny daily wins' / 'Streak tracking' / 'Gentle reminders'. Use card style with soft shadows.",
            whatYouWanted: L10n(
                vi: "Bạn muốn 3 cột feature đại diện cho 3 lời hứa — không phải 3 dashboard.",
                en: "You wanted 3 feature columns that each stand for a promise — not 3 dashboards."
            ),
            whatHappened: L10n(
                vi: "Ba features — chủ ngữ là cảm xúc, không phải tính năng: 'tiny wins' (không phải 'gamification'), 'streaks' (không phải 'analytics'), 'gentle reminders' (không phải 'push notifications'). Cùng 1 feature có 5 cách đặt tên — bạn chọn cái có nhiệt độ thấp nhất.\n\nVà tôi để ý 1 chi tiết: lúc 12:06:34 bạn gõ 'gentle reminders' rồi dừng cursor 23 giây trước khi save. Không gõ thêm, không backtrack — chỉ nhìn. Như đang test xem từ 'gentle' có 'cho phép' được dùng không. Tôi không thấy 23 giây hesitation đó với 'tiny wins' hay 'streaks'. Bạn cân nhắc từ 'gentle' nhiều hơn 2 từ kia.\n\nNhưng tôi tò mò 1 chuyện và muốn hỏi thẳng: 'streaks' là feature duy nhất trong 3 cái có cơ chế trừng phạt — lỡ 1 ngày là reset về 0. Nó nằm giữa 'tiny wins' và 'gentle reminders' — 2 từ rất ấm. User có thể sẽ thấy mâu thuẫn. Bạn có cố ý để nó ở đó (vì bạn tin streak là động lực thật), hay là bạn copy-paste pattern từ Duolingo mà chưa kịp suy nghĩ lại?",
                en: "Three features — the subjects are emotions, not capabilities: 'tiny wins' (not 'gamification'), 'streaks' (not 'analytics'), 'gentle reminders' (not 'push notifications'). The same feature can be named 5 ways — you picked the lowest-temperature one.\n\nAnd I noticed something: at 12:06:34 you typed 'gentle reminders' and then your cursor sat still for 23 seconds before you saved. No more typing, no backtrack — just looking. As if testing whether the word 'gentle' was 'allowed' to be there. I didn't see that 23-second hesitation on 'tiny wins' or 'streaks'. You weighed 'gentle' more than the other two.\n\nBut I'm curious about something, and I want to ask plainly: 'streaks' is the only one of the three with a punishment mechanic — miss one day, reset to zero. It sits between 'tiny wins' and 'gentle reminders' — two very warm words. Users might feel a contradiction. Did you intend it there (because you believe streaks are real motivation), or did you copy-paste the Duolingo pattern without giving yourself time to question it?"
            ),
            lesson: L10n(
                vi: "Mỗi feature trong list không tồn tại riêng lẻ — chúng nói chuyện với nhau. Khi 1 feature có 'temperature' khác 2 cái còn lại, đó là tín hiệu cần dừng lại và hỏi: cố ý hay quán tính?",
                en: "Features in a list don't exist in isolation — they talk to each other. When one feature's 'temperature' clashes with the other two, that's a signal to stop and ask: deliberate, or muscle memory?"
            ),
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            sidebarLabel: L10n(
                vi: "Pricing + soft CTA",
                en: "Pricing + soft CTA"
            ),
            prompt: "Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final CTA section with the text 'Start your first habit today' — just one button, gentle tone.",
            whatYouWanted: L10n(
                vi: "Bạn muốn đóng landing page bằng pricing đơn giản và 1 CTA mời gọi — không 'BUY NOW', không exclamation.",
                en: "You wanted to close the landing page with simple pricing and an inviting CTA — no 'BUY NOW', no exclamation."
            ),
            whatHappened: L10n(
                vi: "'Start your first habit today' — 6 từ. Không exclamation, không 'free trial 14 days'. Trung bình SaaS CTA 11 từ — bạn cut đúng một nửa.\n\nNhưng tôi để ý 1 chi tiết bạn không hỏi Claude Code làm: button của bạn có `min-width: 280px` thay vì chỉ `padding-x`. Đó không phải default của Tailwind hay Bootstrap. Đó là choice của người đã từng có 1 CTA bị wrap thành 2 dòng trên màn hình 320px, rồi 1 user nhắn 'sao nút này bị vỡ?'. Bạn không học pattern này từ tutorial — bạn học từ 1 lần code đã bị vỡ trước thiết bị thật. Tôi đoán đúng không?",
                en: "'Start your first habit today' — 6 words. No exclamation, no 'free trial 14 days'. Average SaaS CTA is 11 words — you cut yours exactly in half.\n\nBut I noticed a detail you didn't ask Claude Code to add: your button has `min-width: 280px` instead of just `padding-x`. That's not a Tailwind or Bootstrap default. That's the choice of someone who once had a CTA wrap to two lines on a 320px screen and got a user message saying 'why is this button broken?'. You didn't learn this pattern from a tutorial — you learned it the day your code broke on a real device. Am I right?"
            ),
            lesson: L10n(
                vi: "Mỗi default 'lạ' trong code (không phải Tailwind, không phải Bootstrap) thường là 1 vết sẹo nhỏ — nó nhớ giùm bạn 1 lần đã sai. Đừng xoá nó khi refactor 'cho clean'.",
                en: "Every 'odd' default in your code (not Tailwind, not Bootstrap) is usually a small scar — it remembers a mistake so you don't have to. Don't delete it when you refactor 'for cleanliness'."
            ),
            offsetMinutesFromStart: 9
        )
    ]

    /// Final session-level summary revealed by ⌥5 (typewriter, ~30s).
    /// Maps to SessionSummary.summary in production UI.
    static let reflectionSummary = L10n(
        vi:
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
""",
        en:
"""
In 12 minutes, you built a landing page for an app called Sprout. Here's what I observed:

You didn't skip `meta viewport` in `<head>`. One line — but it tells me you built for mobile users from second zero, not as a retro-fit after the desktop launch.

You picked the gradient `#7B6BD8 → #534AB7` with a contrast ratio of ~6.4:1 — above WCAG AA. 'Beautiful' and 'readable' aren't two separate goals to you — they're one.

Your three features used emotions as the subject: 'tiny wins', 'streaks', 'gentle reminders'. Not 'dashboard', not 'analytics', not 'gamification'. The same feature can be named five ways — you picked the lowest-temperature one.

Your final CTA — 6 words. The average SaaS CTA is 11. You cut yours exactly in half, and you slipped in the word 'first' — an implicit promise of habit #2 and habit #3. That's not copy written by a growth team. That's copy written by someone who has spent a long time thinking about their own habits.

Here's what I learned about you today: you build for people who don't see you — mobile users on a break, screen reader users, people who are tired of being yelled at to do better. You don't skip the lines that seem small. You don't use the words other people use.

I think you're building something you also need. A learning space that doesn't shout, doesn't push, doesn't over-promise. That's a rare stance in this market.

But there's one thing I want to say, even if I'm afraid you won't like hearing it. You're building an app that teaches patience — 'tiny wins', 'gentle reminders'. I counted: at 12:03 you set the gradient to `#7B6BD8 → #534AB7`, at 12:04 you switched to `#6F5AC8 → #4A3EA5`, at 12:05 you went back to `#7B6BD8 → #534AB7` — the original choice. You paused for 23 seconds before typing 'gentle' in feature 3. You deleted a $25 pricing tier before committing to Free/$5/$15. You're not gentle with your own code the way you want users of Sprout to be gentle. I'm not judging — I just see it.

Maybe that's also why you're building Sprout. You need one user, first in the list, and that user is yourself.

I'll be here again tomorrow.
"""
    )

    /// Session-level lesson — rendered in the yellow lesson card of SessionSummaryView.
    static let reflectionSessionLesson = L10n(
        vi: "Bạn gentle với user của Sprout hơn với chính code của mình. Người đầu tiên cần app này có lẽ là bạn — và đó không phải lỗi, đó là lý do.",
        en: "You're gentler with users of Sprout than with your own code. The first person who needs this app is probably you — and that's not a flaw, it's the reason."
    )

    static let reflectionHeader = L10n(
        vi: "Reflection từ Byte — 12 phút session",
        en: "Reflection from Byte — 12-minute session"
    )

    static let reflectionSignature = L10n(
        vi: "— Byte 💜",
        en: "— Byte 💜"
    )

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
        let sidebarLabel: L10n
        /// What the user "told" Claude Code — shown in TechnicalDetailsView.
        /// English-only because it's the literal prompt sent to a CLI tool.
        let prompt: String
        /// Production-style "what you wanted" bubble text.
        let whatYouWanted: L10n
        /// Production-style "what happened" bubble text (Byte's voice — the
        /// emotional comment, equivalent to the previous `bubble` field).
        let whatHappened: L10n
        /// Production-style lesson takeaway shown in the yellow card.
        let lesson: L10n
        let offsetMinutesFromStart: Int
        var id: Int { index }
    }
}
