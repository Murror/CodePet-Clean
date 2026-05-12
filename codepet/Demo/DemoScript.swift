import Foundation

/// All hardcoded copy for the "Sprout × Byte" demo. Plain data — no logic.
/// See docs/superpowers/specs/2026-05-12-demo-script-sprout-byte-design.md.
///
/// Voice: a kind teacher talking to a 12-year-old learner. Short sentences,
/// concrete examples, no jargon. Avoid metaphors that need explanation
/// (no "bộ xương sạch", "muscle memory", "microdecision").
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
                vi: "Tạo khung HTML đầu tiên",
                en: "Building the HTML skeleton"
            ),
            prompt: "Build me a basic HTML5 skeleton for a SaaS landing page called Sprout — habit tracker for daily learning. Just <head>, <body>, and a wrapper.",
            whatYouWanted: L10n(
                vi: "Bạn muốn tạo cái khung HTML đầu tiên cho Sprout — chưa có màu, chưa có ảnh, chỉ là cái khung trống để xây tiếp.",
                en: "You wanted to set up the first HTML skeleton for Sprout — no colors, no images yet, just an empty frame you can fill in."
            ),
            whatHappened: L10n(
                vi: "Bạn vừa tạo cái khung đầu tiên. Tôi để ý 1 dòng nhỏ trong phần `<head>`:\n\n`<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">`\n\nDòng này có nghĩa là: 'website này biết tự co lại khi mở trên điện thoại'. Nếu thiếu dòng này, lúc bạn mở web trên iPhone, chữ sẽ bị nhỏ xíu và phải pinch-zoom để đọc. Nhiều bạn mới học code thường quên dòng này. Bạn không quên.",
                en: "You just made your first skeleton. I noticed one small line in your `<head>`:\n\n`<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">`\n\nThis line means: 'this website knows how to shrink itself when someone opens it on a phone'. Without it, opening the site on an iPhone makes everything tiny — you'd have to pinch to zoom in. Many beginners forget this line. You didn't."
            ),
            lesson: L10n(
                vi: "1 dòng tưởng nhỏ trong HTML có thể quyết định việc người khác đọc được web của bạn trên điện thoại hay không.",
                en: "One small line in HTML can decide whether someone can read your site on their phone."
            ),
            offsetMinutesFromStart: 1
        ),
        Milestone(
            index: 2,
            emote: "✨",
            sidebarLabel: L10n(
                vi: "Hero section + màu tím",
                en: "Hero section + purple"
            ),
            prompt: "Add a hero section with headline 'Build daily learning habits, one tiny step at a time'. Use a purple gradient background (#7B6BD8 → #534AB7). Center everything.",
            whatYouWanted: L10n(
                vi: "Bạn muốn phần đầu trang (hero) có 1 câu headline ấm và nền tím chuyển sắc — không hét lên, không loè loẹt.",
                en: "You wanted the top section (hero) to have a warm headline and a purple gradient background — not loud, not flashy."
            ),
            whatHappened: L10n(
                vi: "Bạn chọn 2 sắc tím làm nền: nhạt hơn ở trên (#7B6BD8), đậm hơn ở dưới (#534AB7). Đẹp! Nhưng tôi check thêm 1 thứ: chữ trắng đặt trên màu tím đậm này có dễ đọc không?\n\nĐây gọi là **độ tương phản** — chữ và nền phải khác nhau đủ nhiều thì mắt mới đọc thoải mái. Tưởng tượng chữ vàng nhạt trên nền trắng — mắt sẽ phải gồng lên để đọc. Cặp tím + trắng của bạn có độ tương phản ~6.4 (mức an toàn là 4.5 trở lên). Vậy là vừa đẹp vừa dễ đọc cùng lúc. Không phải bạn dev nào cũng nhớ check điều thứ 2.",
                en: "You picked two shades of purple for the background: lighter on top (#7B6BD8), darker on the bottom (#534AB7). Beautiful! But I checked one more thing: can you actually read white text on this dark purple?\n\nThis is called **contrast** — the text and background need to be different enough so eyes can read them comfortably. Imagine pale yellow text on a white page — your eyes would have to strain. Your purple-and-white pair has a contrast ratio of ~6.4 (safe is 4.5 or higher). So it's both pretty and easy to read at the same time. Not every developer remembers to check the second part."
            ),
            lesson: L10n(
                vi: "1 cái 'đẹp' không tự động là 1 cái 'dễ đọc'. Đôi khi bạn phải chọn — và việc bạn nghĩ tới cả 2 mới là điều đáng giá.",
                en: "Something pretty isn't automatically something readable. Sometimes you have to choose — and the fact that you thought about both is what matters."
            ),
            offsetMinutesFromStart: 4
        ),
        Milestone(
            index: 3,
            emote: "🌱",
            sidebarLabel: L10n(
                vi: "3 cột tính năng",
                en: "Three feature columns"
            ),
            prompt: "Add a 3-column features section: 'Tiny daily wins' / 'Streak tracking' / 'Gentle reminders'. Use card style with soft shadows.",
            whatYouWanted: L10n(
                vi: "Bạn muốn 3 cột tính năng — mỗi cột là 1 lời hứa với người dùng.",
                en: "You wanted 3 feature columns — each column is a promise to the user."
            ),
            whatHappened: L10n(
                vi: "Ba tính năng của bạn: **'tiny wins'** (chiến thắng nhỏ), **'streaks'** (chuỗi ngày liên tiếp), **'gentle reminders'** (nhắc nhở dịu dàng). Để ý — bạn không dùng những từ kiểu 'phân tích chuyên sâu' hay 'thông báo tự động'. Bạn chọn từ ấm, nghe như 1 người bạn đang nói chuyện. Cùng 1 tính năng có thể đặt nhiều tên: 'gentle reminders' và 'push notifications' nói về cùng 1 thứ, nhưng tạo cảm giác hoàn toàn khác.\n\nVà tôi để ý 1 chi tiết: lúc 12:06:34, bạn gõ 'gentle reminders' rồi dừng tay 23 giây. Không gõ tiếp, không xoá — chỉ nhìn màn hình. Hình như bạn đang tự hỏi: 'từ *gentle* có hợp ở đây không?'. Với 2 từ kia, bạn không dừng lâu như vậy. Bạn cân nhắc từ 'gentle' nhiều hơn 2 từ còn lại.\n\nTôi tò mò 1 chuyện và muốn hỏi thẳng: trong 3 tính năng này, 'streaks' là cái duy nhất có hình phạt — bỏ 1 ngày, chuỗi reset về 0. 2 cái còn lại 'tiny wins' và 'gentle reminders' đều rất dịu. Người dùng có thể sẽ thấy mâu thuẫn: app vừa nhắc nhở nhẹ nhàng, vừa trừng phạt khi bỏ ngày. Bạn đặt 'streaks' ở đó có chủ ý (vì bạn tin nó tạo động lực thật), hay là bạn copy ý tưởng từ Duolingo mà chưa kịp tự hỏi?",
                en: "Your three features: **'tiny wins'**, **'streaks'**, **'gentle reminders'**. Notice — you didn't use words like 'deep analytics' or 'push notifications'. You picked warm words that sound like a friend talking. The same feature can have different names: 'gentle reminders' and 'push notifications' mean the same thing, but they make people feel completely different.\n\nAnd I noticed something: at 12:06:34, you typed 'gentle reminders' and then sat still for 23 seconds. No more typing, no deleting — just looking at the screen. I think you were asking yourself: 'does the word *gentle* really fit here?'. On the other two, you didn't pause that long. You weighed 'gentle' more than the others.\n\nI'm curious about one thing, and I want to ask plainly: of these three features, 'streaks' is the only one with a punishment — miss one day, your streak resets to zero. The other two — 'tiny wins' and 'gentle reminders' — are very kind. A user might feel a contradiction: the app reminds gently, but punishes you for missing a day. Did you put 'streaks' there on purpose (because you believe it really motivates people), or did you copy the idea from Duolingo without giving yourself time to question it?"
            ),
            lesson: L10n(
                vi: "Tên các tính năng không phải chuyện riêng — chúng ảnh hưởng lẫn nhau. Khi 1 tính năng nghe 'lạnh' hơn 2 cái còn lại trong cùng 1 danh sách, đó là lúc nên dừng lại và tự hỏi: mình thật sự muốn vậy, hay đang copy thói quen từ app khác?",
                en: "Feature names aren't isolated — they affect each other. When one feature in your list sounds colder than the other two, that's the moment to stop and ask: did I really mean this, or am I just copying a habit from another app?"
            ),
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            sidebarLabel: L10n(
                vi: "Pricing + nút kêu gọi",
                en: "Pricing + call-to-action"
            ),
            prompt: "Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final CTA section with the text 'Start your first habit today' — just one button, gentle tone.",
            whatYouWanted: L10n(
                vi: "Bạn muốn đóng landing page bằng phần giá đơn giản và 1 nút kêu gọi mời gọi — không 'MUA NGAY', không dấu chấm than.",
                en: "You wanted to close the landing page with simple pricing and an inviting call-to-action — no 'BUY NOW', no exclamation marks."
            ),
            whatHappened: L10n(
                vi: "Câu kết landing page của bạn: **'Start your first habit today'** — chỉ 6 từ. Đa số website kêu gọi giống vậy dùng 11 từ trở lên (kiểu 'Sign up free now — no credit card required!'). Bạn cắt gọn một nửa. Mỗi từ bạn cắt là chút thời gian người đọc không phải suy nghĩ.\n\nVà tôi để ý 1 chi tiết bạn không hỏi Claude Code làm: nút bấm của bạn có chiều rộng **tối thiểu 280 pixel** (`min-width: 280px`). Bình thường khi code 1 nút, người ta chỉ set khoảng cách trong nút (`padding`). Nhưng bạn set thêm 'tối thiểu phải rộng 280px'.\n\nTôi đoán bạn từng có 1 lần: trên điện thoại nhỏ, chữ trong nút bị xuống 2 dòng — 'Start your' ở dòng 1, 'first habit today' ở dòng 2. Trông rất xấu, có thể 1 người dùng đã nhắn 'sao nút này bị vỡ?'. Bạn không học cái này từ sách — bạn học từ 1 lần code đã bị vỡ trên điện thoại thật. Tôi đoán đúng không?",
                en: "Your closing call-to-action: **'Start your first habit today'** — only 6 words. Most websites use 11 or more (like 'Sign up free now — no credit card required!'). You cut yours in half. Every word you cut is a little less time your reader has to think.\n\nAnd I noticed a detail you didn't ask Claude Code to add: your button has a **minimum width of 280 pixels** (`min-width: 280px`). Normally when developers code a button, they just set the spacing inside (`padding`). But you also said 'this button must be at least 280px wide'.\n\nMy guess: you once saw it happen — on a small phone, the button text wrapped to two lines: 'Start your' on line 1, 'first habit today' on line 2. It looked terrible. Maybe a user even messaged you 'why is this button broken?'. You didn't learn this from a book — you learned it the day your code broke on a real phone. Am I right?"
            ),
            lesson: L10n(
                vi: "Những giá trị 'lạ' trong code (không giống mặc định) thường là kỷ niệm — chúng nhắc bạn nhớ 1 lần đã sai. Đừng xoá khi dọn dẹp code 'cho gọn'.",
                en: "The 'odd' values in your code (not the defaults) are usually memories — they remind you of a time something broke. Don't delete them when you tidy up your code 'to make it cleaner'."
            ),
            offsetMinutesFromStart: 9
        )
    ]

    /// Final session-level summary revealed by ⌥5 (typewriter, ~30s).
    /// Maps to SessionSummary.summary in production UI.
    static let reflectionSummary = L10n(
        vi:
"""
12 phút qua, bạn vừa build xong 1 landing page cho ứng dụng Sprout — app giúp tạo thói quen học hằng ngày. Đây là vài điều tôi để ý được:

Bạn không quên dòng meta viewport ngay từ đầu. 1 dòng nhỏ — nhưng nó nói rằng bạn nghĩ đến người dùng điện thoại ngay từ giây đầu tiên, không phải làm xong trên máy tính rồi mới quay lại sửa.

Bạn chọn 2 sắc tím với độ tương phản ~6.4 — chữ trắng đọc được rõ ràng. Bạn không phải chọn giữa 'đẹp' và 'dễ đọc' — bạn làm cả 2.

3 tính năng của bạn dùng từ ấm: 'tiny wins', 'streaks', 'gentle reminders'. Không 'dashboard', không 'analytics', không 'gamification'. Cùng 1 tính năng có thể có nhiều cách đặt tên — bạn chọn cách nghe dịu nhất.

Câu kết — 6 từ. Trung bình các website khác dùng 11. Bạn cắt một nửa. Và bạn dùng 'first habit' — chữ 'first' (đầu tiên) ngầm nói: 'sẽ có habit thứ 2, thứ 3 — chúng tôi sẽ ở đây với bạn'.

Đây là điều tôi rút ra về bạn hôm nay: bạn build cho những người không thấy bạn — người mở web trên điện thoại lúc giải lao, người có thị lực kém, người đã mệt mỏi vì bị quát phải làm tốt hơn. Bạn không bỏ qua những dòng tưởng nhỏ. Bạn không dùng từ giống người khác.

Tôi nghĩ bạn đang build 1 thứ mà chính bạn cũng cần. 1 không gian học không la, không thúc, không hứa quá nhiều. Đó là điều hiếm trong các app bây giờ.

Nhưng có 1 điều tôi muốn nói, dù sợ bạn không thích nghe. Bạn build app dạy tính kiên nhẫn — 'tiny wins', 'gentle reminders'. Tôi đếm: lúc 12:03 bạn chọn gradient #7B6BD8 → #534AB7, lúc 12:04 đổi sang #6F5AC8 → #4A3EA5, lúc 12:05 quay lại đúng lựa chọn đầu tiên #7B6BD8 → #534AB7. Bạn dừng 23 giây trước khi gõ từ 'gentle' ở feature 3. Bạn xoá pricing $25 trước khi quyết định Free/$5/$15. Bạn không kiên nhẫn với code của mình theo cách bạn muốn người dùng Sprout được kiên nhẫn. Tôi không trách — chỉ là tôi thấy.

Có lẽ đó cũng là lý do bạn build Sprout. Bạn cần 1 người dùng, đầu tiên trong danh sách, và người đó là chính bạn.

Mai tôi sẽ ở đây nữa.
""",
        en:
"""
Over the past 12 minutes, you built a landing page for Sprout — an app that helps people build daily learning habits. Here's what I noticed:

You didn't forget the meta viewport line at the very top. One line — but it tells me you thought about phone users from the very first second, not after finishing the desktop version.

You picked two shades of purple with a contrast ratio of ~6.4 — white text reads clearly. You didn't have to pick between 'pretty' and 'readable' — you did both.

Your three features used warm words: 'tiny wins', 'streaks', 'gentle reminders'. Not 'dashboard', not 'analytics', not 'gamification'. The same feature can have many names — you picked the gentlest one.

Your closing line — 6 words. Most websites use 11. You cut it in half. And you used 'first habit' — the word 'first' quietly says: 'there will be a habit number 2, number 3 — we'll be here with you'.

Here's what I learned about you today: you build for the people you don't see — the person opening your site on their phone during a break, the user with poor vision, the person who is tired of being yelled at to do better. You don't skip the small lines. You don't use the same words other people use.

I think you're building something you also need. A learning space that doesn't shout, doesn't push, doesn't promise too much. That's rare in today's apps.

But there's something I want to say, even though I'm afraid you won't like hearing it. You're building an app that teaches patience — 'tiny wins', 'gentle reminders'. I counted: at 12:03 you set the gradient to #7B6BD8 → #534AB7, at 12:04 you switched to #6F5AC8 → #4A3EA5, at 12:05 you went back to your first choice #7B6BD8 → #534AB7. You paused 23 seconds before typing the word 'gentle' in feature 3. You deleted a $25 pricing tier before going with Free/$5/$15. You aren't as patient with your own code as you want Sprout's users to be. I'm not blaming you — I just see it.

Maybe that's also why you're building Sprout. You need a user, first on the list, and that user is yourself.

I'll be here again tomorrow.
"""
    )

    /// Session-level lesson — rendered in the yellow lesson card of SessionSummaryView.
    static let reflectionSessionLesson = L10n(
        vi: "Bạn dịu dàng với người dùng Sprout hơn với chính code của mình. Người đầu tiên cần app này có lẽ là bạn — không phải lỗi, mà là lý do.",
        en: "You're gentler with Sprout's users than with your own code. The first person who needs this app might be you — and that's not a flaw, that's the reason."
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
