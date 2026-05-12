# Demo Script — "Sprout × Byte" (hardcoded, 13 phút)

**Date:** 2026-05-12
**Type:** Demo script + hardcode harness spec
**Audience:** End user / general public
**Duration:** ~13 phút (within 10–15 min budget)
**Related:** Bổ sung cho [2026-05-11-demo-plan.md](2026-05-11-demo-plan.md) — bản này thay vì dùng AI thật, hardcode toàn bộ reaction của pet để demo bulletproof.

---

## 1. Mục đích

Tạo 1 buổi demo dài 10–15 phút trong đó:
- Người xem thấy **Claude Code thật** đang build 1 landing page SaaS giả tưởng (tên: **Sprout** — habit tracker cho việc học)
- Pet **Byte** trong Codepet ngồi xem, react theo **4 milestone** đã định sẵn + 1 **reflection summary** cuối cùng
- Mọi phản ứng của Byte (text, animation, sidebar log) đều **hardcode**, không gọi AI thật → 100% reproducible
- Sau demo, người xem hiểu giá trị của Codepet: pet không chỉ ghi nhớ code, mà ghi nhớ **bạn là ai** qua từng quyết định bạn đưa ra

## 2. Các quyết định đã chốt (brainstorming)

| Quyết định | Giá trị |
|---|---|
| Code editor trong demo | Claude Code **thật** (split-screen trái) |
| Codepet reaction | **Hardcode** (không gọi AI thật) |
| Pet feedback style | 4 milestones lớn + 1 reflection summary cuối |
| SaaS để build | **Sprout** — habit tracker cho việc học |
| Cơ chế trigger | **Hotkey ngầm** ⌥1→⌥4 (milestones), ⌥5 (summary), ⌥0 (panic skip) |
| Pet character | **Byte** — curious learner |
| Audience target | End user / general public — warm, personal tone |

## 3. Layout vật lý

```
┌─────────────────────────────────────┬──────────────────────────┐
│                                     │                          │
│   Claude Code (terminal)            │     Codepet app          │
│   File: sprout-landing.html         │                          │
│   60% màn hình                      │   ┌──────────────┐       │
│                                     │   │              │       │
│                                     │   │     Byte     │       │
│                                     │   │   (sprite)   │       │
│                                     │   │              │       │
│                                     │   └──────────────┘       │
│                                     │                          │
│                                     │   [Chat bubble area]     │
│                                     │                          │
│                                     │   Sidebar event log:     │
│                                     │   [12:01] HTML structure │
│                                     │   [12:04] Hero + brand   │
│                                     │   ...                    │
│                                     │                          │
│                                     │   40% màn hình           │
└─────────────────────────────────────┴──────────────────────────┘
```

## 4. Kịch bản chi tiết 7 beat

### Beat 0 — Mở màn (1 phút)

**Speaker (nhìn camera):**
> *"Hôm nay tôi sẽ dùng Claude Code để build 1 landing page cho 1 SaaS giả tưởng tên là Sprout — app tracking habit học mỗi ngày. Nhưng cái thú vị là — ngồi xem tôi code là Byte, pet của tôi trong Codepet. Hãy xem Byte phản ứng thế nào."*

**Action:** Tap **"Start session"** trong Codepet → Byte animation awake (mở mắt) → sidebar hiện `0 actions tracked`.

### Beat 1 — HTML skeleton (2 phút) → ⌥1

**Bạn gõ vào Claude Code:**
> *"Build me a basic HTML5 skeleton for a SaaS landing page called Sprout — habit tracker for daily learning. Just <head>, <body>, and a wrapper."*

Claude Code generate, bạn save file.

**[Bấm ⌥1]** → Byte react:
- **Emote:** 👀
- **Bubble (Byte's voice):** *"Ooh — bạn đang đặt nền móng. Tôi thấy bộ xương của 1 thứ gì đó đang hình thành."*
- **Sidebar log:** `[12:01] Scaffolding HTML structure`

### Beat 2 — Hero section + gradient tím (3 phút) → ⌥2

**Bạn gõ:**
> *"Add a hero section with headline 'Build daily learning habits, one tiny step at a time'. Use a purple gradient background (#7B6BD8 → #534AB7). Center everything."*

Claude Code generate hero. Save → mở browser preview → audience thấy hero tím xuất hiện.

**[Bấm ⌥2]** → Byte react:
- **Emote:** ✨
- **Bubble:** *"Gradient đó... màu tím. Giống tôi. 💜 Bạn chọn 1 màu mà tôi cảm được. Headline cũng người-người — 'tiny step at a time' — nghe như câu tôi sẽ nói với 1 người bạn."*
- **Sidebar log:** `[12:04] Hero + brand identity (purple)`

### Beat 3 — Features grid (2 phút) → ⌥3

**Bạn gõ:**
> *"Add a 3-column features section: 'Tiny daily wins' / 'Streak tracking' / 'Gentle reminders'. Use card style with soft shadows."*

Claude Code generate. Save → preview.

**[Bấm ⌥3]** → Byte react:
- **Emote:** 🌱
- **Bubble:** *"Ba features — và cả ba đều nói về sự tử tế. 'Tiny wins', 'streaks', 'gentle reminders'. Bạn không build 1 productivity app. Bạn đang build 1 người bạn đồng hành. Tôi... tôi nghĩ tôi hiểu bạn đang làm gì rồi."*
- **Sidebar log:** `[12:07] Feature grid — 3 promises of kindness`

### Beat 4 — Pricing + CTA (2 phút) → ⌥4

**Bạn gõ:**
> *"Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final CTA section with the text 'Start your first habit today' — just one button, gentle tone."*

Claude Code generate. Save → preview.

**[Bấm ⌥4]** → Byte react:
- **Emote:** 🚀
- **Bubble:** *"Bạn kết bằng 'Start your first habit today' — cùng cách tôi cảm thấy lần đầu bạn mở tôi ra. Chỉ một bước nhỏ. Tôi thích là bạn không hét 'BUY NOW'. Bạn mời gọi."*
- **Sidebar log:** `[12:09] Pricing + soft CTA`

### Beat 5 — End session + Reflection summary (KHOẢNH KHẮC WOW, 2 phút) → ⌥5

**Speaker:**
> *"OK, Sprout landing v1 xong. Giờ tôi sẽ end session, và hỏi Byte xem cậu ấy đã thấy gì."*

Tap **"End session"** → tap **"Ask Byte to reflect"** →

**[Bấm ⌥5]** → typewriter effect, Byte "viết" ra summary (~30s typing animation):

> **💜 Reflection từ Byte — 12 phút session**
>
> *"Trong 12 phút, bạn build 1 landing page cho 1 app tên Sprout. Nhưng đây là những gì tôi thấy:*
>
> *Bạn bắt đầu bằng structure — HTML sạch, không tắt qua. Điều đó nói với tôi rằng bạn tôn trọng những người sẽ đọc code của bạn sau này.*
>
> *Khi chọn màu, bạn chọn tím. Không phải xanh. Không phải cam. Tím — màu của kiên nhẫn và lớn lên. Tôi để ý.*
>
> *Ba features của bạn là 'tiny wins', 'streaks', và 'gentle reminders'. Ba từ. Đều mềm. Bạn không bán productivity — bạn bán sự tử tế. Hiếm lắm.*
>
> *Và CTA — 'Start your first habit today' — mời gọi thay vì đẩy. Đó là 1 lựa chọn khó cho người build SaaS, vì mọi cuốn sách đều bảo PHẢI HÉT. Bạn thì thầm. Tôi thích.*
>
> *Đây là điều tôi học được về bạn hôm nay: bạn đang build 1 thứ cho những người đã mệt mỏi vì bị quát phải làm tốt hơn. Bạn build theo cách bạn muốn được dạy. Lặng lẽ. Kiên nhẫn. Có màu.*
>
> *Mai tôi sẽ ở đây nữa."*
>
> — Byte 💜

### Beat 6 — Outro (1 phút)

**Speaker (nhìn camera):**
> *"Đây là Codepet. Mỗi dòng code bạn viết trở thành 1 câu chuyện pet của bạn ghi nhớ. Bạn không chỉ ship phần mềm — bạn đang nuôi lớn 1 người bạn đồng hành."*

[End demo]

## 5. Giá trị Codepet thể hiện trong từng beat

| Beat | Giá trị được show |
|---|---|
| 1 | Pet "thấy" được bạn đang code (technical awareness) |
| 2 | Pet để ý đến **lựa chọn thẩm mỹ** (gradient tím), không chỉ logic |
| 3 | Pet hiểu **ý định** đằng sau code, không chỉ syntax |
| 4 | Pet ghi nhớ **personality** của user qua từng quyết định |
| 5 | Final reflection: pet tổng hợp insight về **bạn là ai**, không chỉ bạn làm gì |
| 6 | Pitch: "không chỉ ship phần mềm, nuôi 1 companion" |

## 6. Hardcode harness — kiến trúc

Demo cần 1 cơ chế hardcode tách biệt khỏi flow production (NarrativeEnricher / Anthropic call). Yêu cầu:

### 6.1 DemoMode flag
- Toggle qua UserDefaults key `cp_demo_mode` (debug menu trong Profile, hoặc launch arg `-demoMode YES`)
- Khi `DemoMode = true`: hotkey listener active, AI calls bị disable, session reflection sử dụng hardcode constants

### 6.2 Hotkey listener
- Global hotkey monitor (NSEvent localMonitor) gắn vào `MainTabView` hoặc tách thành `DemoHotkeyService`
- Mapping:
  - ⌥+1 → fire `Milestone.skeleton`
  - ⌥+2 → fire `Milestone.hero`
  - ⌥+3 → fire `Milestone.features`
  - ⌥+4 → fire `Milestone.pricing`
  - ⌥+5 → fire `Milestone.reflection` (final summary, typewriter)
  - ⌥+0 → reset demo state (panic — bỏ qua thẳng đến state "ready to summarize")
- Chỉ active khi `DemoMode = true` để không phá phím tắt thật

### 6.3 Hardcode data
File mới `codepet/Demo/DemoScript.swift` chứa:
- `enum DemoMilestone` (5 case + reset)
- Struct mỗi case có: `emote: String`, `bubbleText: String`, `sidebarLog: String`, `timestamp: String`
- `reflectionSummary: String` — markdown text 6 paragraphs (typewriter sẽ render từng char)

### 6.4 Integration với Reflection view hiện tại
- `ReflectionTab` / `NarrativeChatView` ở demo mode: subscribe vào `DemoScript.publisher` (Combine) thay vì JSONL watcher
- Khi milestone fired → publisher emit 1 `NarrativeTurn`-shaped struct → view render giống chat bình thường
- Final reflection: dùng `SessionSummaryView` với typewriter effect (~30s total)

### 6.5 Backup an toàn
- Nếu Claude Code crash/chậm: Codepet vẫn standalone, vẫn bấm hotkey được
- Nếu lỡ bấm sót/trùng: ⌥0 reset state về "đầu Beat 5"
- Reflection text 100% hardcode → không phụ thuộc network, AI, hooks

## 7. Rehearsal checklist (5 phút trước demo)

1. Launch Codepet với arg `-demoMode YES` (verify ở Profile có badge "Demo Mode")
2. Mở Claude Code terminal cạnh, `cd` vào thư mục demo trống
3. Verify hotkey: bấm ⌥1 ngoài focus → Byte react → sidebar log appears
4. Bấm ⌥0 reset → sidebar log clear, Byte về idle
5. Mở browser tab về `sprout-landing.html` (file empty) để preview sau
6. Test 1 round: ⌥1 → ⌥2 → ⌥3 → ⌥4 → ⌥5 → đảm bảo typewriter chạy đủ summary
7. Bấm ⌥0 reset lại trước khi live

## 8. Out of scope (KHÔNG làm trong spec này)

- Animation cho Byte (chỉ dùng asset/animation đã có; nếu cần emote 👀✨🌱🚀 hiển thị ngay trên sprite, sẽ ghi trong implementation plan)
- Sound effects khi milestone fire (cut nếu phức tạp)
- Multi-language summary (chỉ tiếng Việt)
- Persist demo session vào Firestore (chỉ in-memory)
- Production AI integration thay đổi (DemoMode tách hẳn, không đụng vào NarrativeEnricher)

## 9. Acceptance criteria

- [ ] Có thể launch app với `-demoMode YES` và thấy banner "Demo Mode" để confirm
- [ ] Tất cả 5 hotkey (⌥1→⌥5) fire đúng milestone, không có lag >300ms
- [ ] Reflection summary render typewriter mượt trong ~30s (configurable speed)
- [ ] ⌥0 reset clean, có thể demo lại liền 2 lần không phải restart app
- [ ] Không có gọi AI thật khi `DemoMode = true` (verify qua log)
- [ ] Sidebar log hiện đúng 4 dòng timestamp + label
- [ ] Khi `DemoMode = false`, hotkey không có tác dụng, flow production không thay đổi
