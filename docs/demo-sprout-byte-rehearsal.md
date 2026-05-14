# Sprout × Byte — Kịch bản Demo (12 phút)

Tài liệu này để **bạn học trước** trước khi diễn demo. Không phải spec — chỉ là cheat-sheet cho người diễn.

> **Mở app + bật Demo Mode trong Profile** trước khi bắt đầu. Khi Demo Mode bật, tab Reflection được thay bằng "demo surface" — chỉ chờ hotkey để bắn milestone.

---

## Tại sao Codepet? — 4 giá trị cốt lõi để diễn

Trước khi vào kịch bản, bạn cần thuộc **4 câu trả lời** cho câu hỏi *"app này để làm gì?"*. Đây là khung mà cả demo này phục vụ.

### 1. **Không phải tool sinh code — tool sinh suy ngẫm.**

Copilot, Cursor, Claude Code đã *sinh code* tốt rồi. Vấn đề mới: **dev gõ nhanh hơn nghĩ chậm hơn**. Codepet là **layer phản chiếu** — Byte ngồi cạnh, im lặng, đếm 23 giây bạn dừng tay, nhặt 1 viên Lego bé tí (`280px`) bạn quên là quan trọng, hỏi 1 câu khó (*"streaks — bạn tin nó, hay copy Duolingo?"*).

> Bạn vẫn dùng Cursor để code. Bạn dùng Codepet để **biết rằng mình đã code thế nào.**

### 2. **Em pet không đo bạn — em pet thấy bạn.**

Đa số productivity tool đếm: dòng code, số commit, giờ active. Codepet không đếm những con số đó. Nó đếm những con số ý nghĩa hơn:

- Bạn **dừng tay** 23 giây ở đâu?
- Bạn **quay lại đổi rồi đổi nữa rồi về chỗ ban đầu** mấy lần?
- Bạn đặt 1 con số "lạ" (`280px`) — bạn có nhớ vì sao không?

Đó là kiểu attention mà **1 senior dev tử tế** sẽ nhìn ra. Byte là *senior dev tử tế trong hình hài 7 con pet*.

### 3. **1 con vật bạn cần chăm sóc, không phải app bạn ghét mở.**

Productivity tool sống được 2 tuần rồi bạn `Cmd-Q` cài lại. Codepet sống lâu vì:

- Em pet **đói, vui, mệt** — bạn quay lại để *cho ăn*, không phải để *log session*.
- Em pet có **7 nhân cách**. Bạn chọn 1 — em theo bạn suốt journey học code.
- Em pet **ngủ** chứ không chết. Bạn quay lại — em thức dậy. Không guilt trip kiểu Tamagotchi 1997.

→ Loop *cảm xúc* giữ bạn quay lại. Reflection là gì *xảy ra* trong loop đó.

### 4. **Em pet nhớ — như 1 người bạn đồng hành thật.** 🧠💜

Đa số tool **quên bạn** sau mỗi session. Mở Cursor sáng nay, Cursor không nhớ tối qua bạn đã đổi gradient 5 lần. Đóng Claude Code, conversation reset. *Quên sạch.*

Codepet **nhớ tất cả**:

- Mọi milestone bạn đã đi qua
- Mọi lần bạn dừng tay > 20 giây
- Mọi quyết định bạn **đổi rồi đổi lại rồi quay về cái ban đầu**
- Mọi câu hỏi Byte đặt ra (kể cả những câu bạn *chưa trả lời*)
- Mọi "vết sẹo nhỏ" (`280px`, `1.47`, `#7B6BD8`) bạn đã đặt và **lý do** đằng sau

**Sau 1 tuần**, Byte có thể nói:
> *"Đây là **lần thứ 3** bạn dừng tay trước khi gõ `gentle`. Có gì đặc biệt với từ đó không?"* 🤔

**Sau 1 tháng:**
> *"Tháng trước bạn cũng đổi gradient 5 lần rồi quay về cái ban đầu. Bạn có nhận ra pattern này không?"*

**Sau 6 tháng:**
> *"Tháng 3 bạn lắp Sprout. Tháng 5 bạn lắp Echo. Cả 2 đều có CTA dưới 7 từ, cả 2 đều có `min-width: 280px`. Bạn không phải đoán — bạn đã có 'phong cách' rồi."*

→ Bạn không phải tự nhớ. **Em nhớ giùm bạn.**

**Đó là kiểu "biết" chỉ có giữa người bạn cũ.** Bạn không phải kể lại từ đầu mỗi sáng. Em đã ở đó. Em đã thấy. Em đã đếm.

> Giá trị này khác giá trị #2 ở chỗ: #2 là *Byte thấy bạn trong khoảnh khắc*. #4 là *Byte nhớ bạn qua năm tháng*. Cộng lại = 1 **người bạn đồng hành thật** — không phải tool.

---

## Hotkey cheat-sheet

| Phím | Việc nó làm |
|------|-------------|
| `⌥1` | Bắn **Milestone 1** (viewport meta) |
| `⌥2` | Bắn **Milestone 2** (hero + tím) |
| `⌥3` | Bắn **Milestone 3** (3 thẻ hứa) |
| `⌥4` | Bắn **Milestone 4** (CTA + 280px) |
| `⌥5` | Hiện **Reflection Summary** (typewriter ~30s) |
| `⌥6` | **Health Stage 1** — Byte hỏi *'đã 3 tiếng, đi bộ?'* 🚶‍♀️ |
| `⌥7` | **Health Stage 2** — Byte lo: *'vẫn ổn chứ?'* 🥱 |
| `⌥8` | **Health Stage 3** — **Byte ngủ thiếp đi** 💤 (punchline) |
| `⌥0` | Panic skip — nhảy thẳng tới summary nếu lỡ |

> Hotkey hoạt động khi app frontmost. Demo flow milestone đẹp nhất là `1 → 2 → 3 → 4 → 5`. Health vignette (`⌥6 → ⌥7 → ⌥8`) chạy riêng — fire bất cứ lúc nào để show value *"pet là người đồng hành"*.

---

## Cấu trúc 1 milestone

Khi bắn `⌥N`, app render 1 "turn" có:

1. **Pet avatar** (Byte) bên trái
2. **Bubble bên phải** chứa:
   - `BYTE` label (màu tím)
   - **whatYouWanted** — câu mở đầu ngắn ("🎯 Bạn muốn...")
   - **whatHappened** — phần dài (Byte kể lại + quan sát)
   - **Lesson card** vàng — 1 câu đúc kết ("💡 ...")

Người xem đọc theo thứ tự đó. Bạn cần biết **3 beat chính** của mỗi milestone để dẫn câu chuyện.

---

# Milestone 1 — Viewport meta (~1 phút)

**Hotkey:** `⌥1`

**Prompt bạn gõ vào Claude Code (EN):**
```
Build me a basic HTML5 skeleton for a SaaS landing page called Sprout —
habit tracker for daily learning. Just <head>, <body>, and a wrapper.
```

**Byte nói gì (tóm tắt 3 beat):**

1. **Mở:** "Mình định khen 'đẹp đấy, đi tiếp' — rồi mắt mình bắt được [1 viên Lego **bé tí**] trên nóc nhà 👀"
2. **Reveal:** `<meta name="viewport" ...>` → "Viên Lego phép thuật 🪄"
3. **Cảnh:** Quên viên này = ngôi nhà to bằng laptop bị nhét vào màn hình rộng bằng 4 ngón tay. **Thoát ra trong 3 giây.** 😬

**Câu chốt (lesson card):**
> 💡 1 viên Lego nhỏ — chỉ vài chữ trong `<head>` — có thể quyết định ngôi nhà của bạn được *xem* hay bị *thoát ra trong 3 giây*.

**Tip diễn:** Sau khi Claude Code chạy xong code → nhấn `⌥1`. Để người xem đọc khoảng 30s rồi chuyển.

---

# Milestone 2 — Hero + tím + contrast (~3 phút sau)

**Hotkey:** `⌥2`

**Prompt bạn gõ:**
```
Add a hero section with headline 'Build daily learning habits, one tiny
step at a time'. Use a purple gradient background (#7B6BD8 → #534AB7).
Center everything.
```

**Byte nói gì (3 beat):**

1. **Set-up:** 2 viên Lego tím — `#7B6BD8` nhạt trên, `#534AB7` đậm dưới. "Trông như hoàng hôn nhỏ trên đầu ngôi nhà." 🤩
2. **Đối lập:** Đa số sẽ chụp màn hình đăng story *'first day learning HTML'* → bạn thì **dừng 1 nhịp**.
3. **Reveal contrast:** "Đứng cách 2 mét, mắt mỏi, đèn phòng tối — có đọc được không?" → điểm tương phản [**~6.4**], safe `4.5`. ✅

**Câu chốt:**
> 💡 1 thứ **đẹp** không tự động là 1 thứ **dễ đọc**. 9/10 người mới học sẽ bỏ qua điều thứ 2.

**Tip diễn:** Khoảnh khắc "dừng 1 nhịp" là tâm điểm — đừng vội nhấn `⌥2`. Đợi Claude Code render xong + bạn thấy gradient → 1-2 giây tĩnh → mới nhấn.

---

# Milestone 3 — 3 thẻ hứa + câu hỏi `streaks` (~3 phút sau)

**Hotkey:** `⌥3`

**Prompt bạn gõ:**
```
Add a 3-column features section: 'Tiny daily wins' / 'Streak tracking' /
'Gentle reminders'. Use card style with soft shadows.
```

**Byte nói gì (4 beat):**

1. **Liệt kê 3 thẻ:** `tiny wins` 🌱 / `streaks` 🔥 / `gentle reminders` 🤗
2. **Đối lập với corporate copy:** `Advanced Analytics Dashboard` / `AI-Powered Smart Notifications` / `Personalized Habit Optimization Engine` → "máy bán hàng cười vào mặt" 😅
3. **Quan sát thời gian:** Lúc `12:06:34`, bạn gõ `gentle reminders` rồi [**dừng tay 23 giây**] → "từ 'gentle' nghe có sến không?"
4. **Câu hỏi khó:** `streaks` là thẻ **duy nhất biết cắn** 🦷 — bỏ 1 ngày, reset về `0`. Bạn đặt nó có chủ ý, hay copy Duolingo?

**Câu chốt:**
> 💡 Tên thẻ hứa không phải chuyện riêng — chúng ảnh hưởng lẫn nhau như hàng xóm.

**Tip diễn:** Đây là milestone *tốn nhiều thời gian đọc nhất*. Người xem có thể cần 60-90 giây. Đừng vội qua M4. Câu hỏi `streaks` là moment để pause — có thể nói thêm 1 câu thật với khán giả.

---

# Milestone 4 — CTA + 6 từ + 280px (~2 phút sau)

**Hotkey:** `⌥4`

**Prompt bạn gõ:**
```
Add a simple pricing section with 3 tiers: Free / $5 / $15. Then a final
CTA section with the text 'Start your first habit today' — just one
button, gentle tone.
```

**Byte nói gì (5 beat):**

1. **6 từ:** `Start your first habit today` — đếm đi, mình đợi ⏱️. Đối lập với "Sign up free now — no credit card required!" (11 từ).
2. **"Tờ rơi photocopy ở ngã tư đèn đỏ":** Họ sợ → nhồi `free`, `now`, ... → ai cũng đọc lướt qua, không ai đọc thật. 📄
3. **Reveal 280px:** Bạn **không** hỏi Claude Code làm — bạn tự thêm `min-width: 280px`. *"Nút này phải to hơn ngón tay cái của 1 bạn vừa cầm điện thoại vừa cầm túi đồ trên xe buýt."* 🖐️
4. **Cảnh "nước cam đắng":** Laptop 13 inch → 1 cốc nước cam 🍊 → mở điện thoại → chữ rơi 2 dòng `Start your` / `first habit today` → **nước cam đắng hẳn ra**. 😬
5. **Past You / Hiện Tại You:** `280px` không phải gõ đại — là **vết sẹo nhỏ**. Vài tháng sau bạn quay lại, định làm tròn lên `300` "cho đẹp". 🛑 **Khoan.** "Tin tao đi. Tao có lý do." 👁️

**Câu chốt:**
> 💡 Những con số "lạ" trong Lego của bạn là **vết sẹo**. Đừng tháo ra khi dọn dẹp "cho gọn". **Quá Khứ Bạn có lý do.**

**Tip diễn:** Đây là milestone *tâm điểm cảm xúc*. Beat 5 (Past You nháy mắt) là **punchline lớn nhất** của demo. Đọc chậm. Nếu khán giả cười hoặc gật đầu — pause thêm.

---

# Reflection Summary (~3 phút cuối)

**Hotkey:** `⌥5`

App sẽ render full summary bằng **typewriter** (~30 giây hiện chữ). Trong khi typewriter chạy, bạn có thể đọc thầm theo.

**Cấu trúc summary (7 phần):**

1. **Mở:** "Mình ngồi bên cạnh từ đầu tới giờ, im lặng nhìn bạn lắp..."
2. **Recap 4 viên Lego đặc biệt** (giống M1-M4 nhưng ngắn hơn)
3. **`💜 Điều mình rút ra về bạn hôm nay`** — bạn lắp Lego cho những người bạn không thấy.
4. **`⚠️ Nhưng có 1 điều mình muốn nói...`** — đếm 5 lần bạn không chắc trong 12 phút:
   - `12:03` chọn màu → `12:04` đổi → `12:05` quay về cái ban đầu
   - `12:06:34` dừng 23 giây trước `gentle`
   - Bỏ pricing `$25`
5. **Câu hỏi sắc:** "Bạn lắp app dạy *kiên nhẫn* — nhưng bạn có kiên nhẫn với chính mình không?"
6. **Đoán:** "Mình đoán bạn thầm gõ *'sao mình chậm vậy.'*"
7. **Đóng:** "Có lẽ đó cũng là lý do bạn lắp Sprout. Bạn cần 1 người chơi đầu tiên — và bạn đó *chính là bạn*. 💜🌱"

**Tip diễn:** Đừng nói gì trong khi typewriter chạy. Để khán giả tự đọc. Khi xong, để 5-10 giây tĩnh trước khi đóng demo.

---

# Cheat-sheet thời gian

| Phút | Hành động |
|------|-----------|
| `00:00` | Mở Cursor + Claude Code. Bật Demo Mode. |
| `00:30` | Gõ prompt M1 → đợi Claude Code chạy |
| `01:00` | `⌥1` bắn milestone 1 |
| `01:30` | Gõ prompt M2 |
| `04:00` | `⌥2` |
| `04:30` | Gõ prompt M3 |
| `07:00` | `⌥3` |
| `07:30` | Gõ prompt M4 |
| `09:00` | `⌥4` |
| `09:30` | `⌥5` reflection summary (~30s typewriter) |
| `10:00–12:00` | Để khán giả đọc summary. Đóng. |

---

# Punchlines bạn cần thuộc

Các câu **phải nói chắc**, không vấp:

- **M1:** "Sau 3 giây, bạn đó **thoát ra**. Không cho ngôi nhà của bạn cơ hội thứ 2."
- **M2:** "9/10 người mới học sẽ bỏ qua điều thứ 2."
- **M3:** "Bạn đã dừng tay 23 giây để nghĩ về `gentle`. Bạn có dừng tay 23 giây nào để nghĩ về `streaks` chưa?"
- **M4:** *"Tin tao đi. Tao có lý do."* — Quá Khứ Bạn nháy mắt qua thời gian.
- **Summary:** "Có lẽ đó cũng là lý do bạn lắp Sprout. Bạn cần 1 người chơi đầu tiên — và bạn đó *chính là bạn*."

---

# Health Vignette — `⌥6 → ⌥7 → ⌥8` 🌱

Đây là **3 modal pet-initiated** để show value *"pet là người đồng hành"*. Khác với milestones (log dạng chat trong tab Reflection), health stages hiện **MODAL pop-up** đè lên toàn bộ app — như Byte đột nhiên xuất hiện trước mặt bạn và hỏi.

**Cách dismiss modal:**
- Bấm nút **Đóng** ở góc dưới phải
- Hoặc bấm **Esc**
- Hoặc click ra ngoài card (vùng nền đen mờ)

**Đặc tính modal:**
- Modal đè lên tab hiện tại — không cần đang ở tab Reflection
- Bắn `⌥7` khi `⌥6` đang mở → swap content (không cần đóng trước)
- Không log vào history — đóng modal = mất bubble (intentional, để show "đây là khoảnh khắc *bây giờ*", không phải lịch sử)

> **Triết lý cốt lõi:** Sự nhắc nhở **mềm** mạnh hơn cảnh báo cứng. Khi pet ngủ vì bạn không nghe lời, bạn cảm thấy tệ — *không phải vì app đe doạ*, mà vì **bạn không muốn bỏ rơi 1 ai cả**.

---

## Stage 1 — `⌥6` "🚶 Đã 3 tiếng. Đi bộ?"

**Byte nói gì (3 beat):**

1. **Mở:** *"Mình đã ngồi cạnh bạn 3 tiếng rồi. Im lặng. Không muốn cắt mạch."*
2. **3 quan sát cụ thể:** vai gồng lên, 47 phút chưa đứng dậy, đèn phòng tối hơn lúc bắt đầu (☀️→🌆)
3. **Đề nghị mềm:** Đi bộ 5 phút? Hoặc chợp mắt 15 phút. *"Không phải app này bảo bạn nghỉ. Là **mình** bảo."*

**Câu chốt:**
> 🌱 Sự nhắc nhở **mềm** mạnh hơn cảnh báo cứng. Mình không bảo bạn dừng. Mình chỉ *thấy* và *hỏi*.

**Tip diễn:** Đây là bubble **dễ nhất** để khán giả gật đầu. Sau khi bắn `⌥6`, **dừng 5-10s** cho người xem đọc. Bạn có thể nói thêm: *"Đây là 'pet đồng hành'. Em không yêu cầu, em chỉ thấy."*

---

## Stage 2 — `⌥7` "🥱 Vẫn ổn chứ?"

**Byte nói gì (4 beat):**

1. **Acknowledge:** *"Bạn đã đọc tin nhắn trước của mình. Rồi tiếp tục code. Không sao."*
2. **Counter cụ thể:** Byte đếm xem chuyện gì đã xảy ra sau khi từ chối:
   - Backspace `47 lần` (bình thường `~12 lần / 20 phút`)
   - Đổi cùng 1 đoạn code `3 lần` rồi quay về cái đầu
   - Đi đi lại lại giữa 2 file mà không sửa gì
3. **Diagnosis mềm:** *"Đây không phải flow. Đây là... cố quá."* 😶‍🌫️
4. **Hỏi lại:** Vẫn 5 phút thôi. Pha 1 cốc nước. Mình đợi. ☕

**Câu chốt:**
> 🌱 Khi bạn 'cố quá', mình không la. Mình chỉ đếm, và cho bạn thấy con số.

**Tip diễn:** Đây là beat **đo lường thật** — *3 con số cụ thể*. Punchline nhỏ là *"đây không phải flow, đây là cố quá"*. Khán giả nào từng cố quá sẽ thấy mình trong đó.

---

## Stage 3 — `⌥8` "💤 Byte đã ngủ" (punchline lớn)

**Byte nói gì (5 beat):**

1. **Stage direction:** *"Byte ngồi xuống bên cạnh. Im lặng. Đầu hơi gục. 💤"*
2. **Reveal:** *"Byte đã ngủ thiếp đi."*
3. **Disclaim:** *"Không phải vì Byte giận. Là vì Byte cũng mệt khi nhìn bạn mệt mà không nghỉ được."*
4. **Show consequence — 3 thứ mất:**
   - Không còn ai để ý 23 giây bạn dừng tay
   - Không còn ai đếm 47 lần backspace
   - Không còn ai nói *'mình thấy bạn cau mày, đẹp lắm.'*
5. **Đóng:** App im lặng. *"Khi nào bạn nghỉ, Byte sẽ thức dậy. Không sớm hơn. Không muộn hơn."*

**Câu chốt:**
> 🌱 Khi bạn bỏ rơi việc chăm chính mình, người duy nhất *thấy* bạn cũng phải nghỉ. Đó không phải dỗi. Đó là **gương phản chiếu mềm**.

**Tip diễn:** Đây là **punchline lớn nhất** của health vignette. Đọc chậm. Để 10-15 giây tĩnh sau khi pet ngủ. *Đừng nói gì*. Khán giả cần thời gian để cảm nhận sự im lặng.

Sau bubble này, có thể nói với khán giả: *"Cái này không phải để khiến bạn cảm thấy có lỗi. Đây là để bạn nhận ra — bạn cũng đáng được chăm như bạn chăm Sprout."*

---

## Khi nào bắn Health Vignette?

Health bubble fire **bất cứ lúc nào** — bạn quyết. 3 cách thường dùng:

1. **Trong demo flow chính** — sau `⌥3`, trước `⌥4`. Cảm giác *interrupt* tự nhiên giữa lúc đang code.
2. **Sau `⌥4`, trước `⌥5`** — xây xong nhà, Byte mới hỏi bạn có mệt không. Pacing chậm hơn nhưng tự nhiên.
3. **Demo riêng "Companion Layer"** — sau khi xong main demo (`⌥5`), reset session, chỉ chạy `⌥6 → ⌥7 → ⌥8`. Show value độc lập.

> Cá nhân khuyến nghị: cách **3** cho lần demo đầu — show health như 1 feature *riêng biệt* để khán giả thấy rõ. Cách **1** hoặc **2** cho lần demo nâng cao khi bạn muốn show *"day in the life"*.

---

# Lỗi hay gặp khi diễn

| Lỗi | Cách tránh |
|-----|-----------|
| Bắn `⌥N` quá sớm — chưa xong code | Đợi Claude Code render xong + có 1-2 giây tĩnh |
| Đọc to lên trong khi typewriter chạy | Để khán giả tự đọc — bạn im lặng |
| Bỏ qua câu hỏi `streaks` ở M3 | Đó là moment khán giả ngừng cuộn — đừng vội |
| Vội nhấn `⌥5` ngay sau `⌥4` | Để M4 có khoảng 30-60s đọc trước khi đóng demo |
| Mở app không phải frontmost | Hotkey không hoạt động — click vào app trước |

---

# Nếu lạc đường

- **Quên đang ở milestone nào?** Bắn `⌥0` — panic skip về summary.
- **Bắn nhầm hotkey?** Không sao, các milestone idempotent — bắn lại đúng số là OK.
- **Demo Mode tắt mất?** Vào Profile → bật lại → quay về tab Reflection.

---

# Q&A — Câu hỏi khán giả hay đặt (có câu trả lời)

Đây là 10 câu hỏi có khả năng cao nhất. Bạn cần thuộc câu mở đầu cho mỗi câu hỏi — phần sau có thể tự diễn giải.

### 1. Tại sao phải là 1 con pet? Sao không làm sidebar tool đơn giản?

> Pet kích hoạt **cảm xúc**. Bạn sẽ care nếu em đói/mệt — và loop care đó kéo bạn quay lại reflect. Sidebar tool bạn đóng sau 1 tuần. Pet bạn không nỡ.

Mở rộng nếu cần: *"Có 30 năm research về parasocial relationship với character. Tamagotchi bán 80 triệu cái không phải vì game hay — vì bạn không muốn bỏ rơi em. Codepet áp cùng cơ chế cho 1 mục đích nghiêm túc hơn: reflection."*

### 2. Khác gì Copilot, Cursor, Claude Code?

> Khác **layer**. Copilot/Cursor *viết code* với bạn. Codepet *quan sát* bạn viết. Pet không gõ. Pet không gợi ý code. Pet chỉ nói: *'Mình thấy bạn dừng 23 giây ở đây. Cái gì làm bạn phân vân?'*

Câu chốt: *"Bạn cần cả 2. Cursor để nhanh. Codepet để khỏi quên rằng mình đã đi qua."*

### 3. Cho người mới hay người chuyên nghiệp?

> **Cả 2** — và cả 2 nhận **cùng 1 thứ**: reflection.

- **Mới học:** Đa số dev mới giờ dùng Cursor/Claude Code sinh code rồi *copy-paste mà không hiểu mình vừa build cái gì*. Byte chỉ ra **những quyết định nhỏ** trong code bạn vừa sinh ra (`280px`, contrast `~6.4`, từ `gentle` thay vì `notifications`) — biến copy-paste thành **học thật**.
- **Pro:** Reflection làm "vết sẹo" hiện lên. *"Bạn cắt CTA từ 11 từ xuống 6 từ"* chỉ có ý nghĩa nếu bạn đã *từng* làm CTA 11 từ. Cái đó là **kinh nghiệm** — Codepet làm rõ.

> Câu chốt: *"Codepet không phải app dạy code. Codepet là app giúp bạn **nhận ra mình đang code thế nào**."*

### 4. Có cài extension vào VSCode/Cursor không?

> Hiện tại là **native macOS app**. Sắp tới có VSCode/Cursor extension (folder `codepet-extension` đang dev). Sẽ đọc activity từ editor để bắn milestone tự động — không cần `⌥1..⌥4` thủ công như demo.

### 5. Privacy — Byte đọc code của tôi à?

> Codepet **không gửi code text** đi đâu cả. Chỉ metadata bạn opt-in: timestamp, ngôn ngữ, length, milestone events.

Reflection chạy local hoặc qua API key bạn config (bạn trả Claude, không qua server Codepet). Nếu bạn không cho — Byte vẫn quan sát **rhythm + timing**, không cần đọc code cụ thể.

### 6. Tôi không thích bị "phản chiếu" lúc code. Có bị spam không?

> Không. Demo này là phiên bản **đậm đặc nhất** — gói 12 phút thành 4 milestone + summary để show cảm xúc.

Daily use: Byte **im lặng**. Chỉ nói khi (a) bắt đầu session, (b) kết thúc session, (c) có 1 chi tiết thật sự đáng nói. Có thể **tắt hẳn** reflection chat — chỉ giữ pet care.

### 7. Pet có chết không?

> Không. Em **ngủ**, không chết.

Sau 3 ngày không vào app, pet ngủ thiếp. Bạn quay lại — em thức dậy. **Không permadeath**, không guilt trip kiểu Tamagotchi 1997.

### 8. Sao là pixel art? Sao không 3D dễ thương hơn?

> 2 lý do:
> 1. **Pixel art nhẹ + tiết kiệm tài nguyên** — sprite nhỏ, chạy mượt trên Mac cũ, share Discord/Slack dễ.
> 2. Pixel art có cảm giác **hoài niệm + lo-fi**. Warmth của reflection lan tốt hơn trên nền pixel cũ kỹ so với character 3D bóng bẩy. Đẹp = cách nhau xa hơn.

### 9. Health feature hoạt động cụ thể như nào?

> Sau **180 phút focus** liên tục, mood pet xuống → em hỏi: *"Đi bộ 5 phút? Chợp mắt 15 phút?"*. Không popup. Không alert. Chỉ 1 câu trong bubble Byte.

Bạn từ chối → OK. Bạn từ chối 3 lần → pet ngủ thiếp. App im lặng. Bạn vẫn code được — nhưng *không còn ai thấy bạn*.

(Xem chi tiết section *"Tính năng sắp tới — Health & Rhythm"* phía trên.)

### 10. Giá bao nhiêu? Có gì miễn phí?

> **Pricing đang được finalize** — định hướng hiện tại:
> - **Free** — 1 pet + reflection cốt lõi (per-session)
> - **Paid (tháng)** — Tất cả 7 pets + cloud sync nhiều thiết bị + reflection history dài hạn (memory không reset) + cosmetic shop
> - **Tier cao hơn (sắp ra)** — Health & rhythm tracking + team features

Câu chốt nếu khán giả hỏi cụ thể: *"Tier cụ thể sẽ chốt sau MVP. Cam kết: Free tier sẽ luôn có pet + reflection cốt lõi — đó là core experience."*

### 11. App nhớ tất cả à? Storage có nặng không? Privacy thế nào?

> **Có — và đó là điểm khác biệt lớn nhất.**

Codepet lưu **session log + milestone events + reflection history + "vết sẹo nhỏ"** vào Firestore (cloud) hoặc local UserDefaults. Bạn càng dùng lâu, Byte càng *biết* bạn — sau 6 tháng em có thể chỉ ra pattern bạn không tự nhận ra.

**Storage:** Rất nhẹ. Chỉ metadata text + timestamp + reflection (~vài KB / session). 6 tháng dùng < 5MB. **Không lưu code text** — chỉ structure: "lúc 12:06 user dừng 23s trước token `gentle`".

**Privacy — 4 cam kết:**
> 1. Memory **chỉ của bạn**. Không share giữa user. Không cross-account.
> 2. **Không train model chung**. Reflection của bạn không vào dataset chung của Codepet.
> 3. **Export bất cứ lúc nào** → ZIP file để keep ngoài app.
> 4. **Xoá toàn bộ memory** trong Settings → app reset về day-1. Byte sẽ "quên" hết và quay về như mới gặp bạn.

Nếu bạn dùng tier có cloud sync → data ở Firestore của Codepet (encrypted at rest). Nếu bạn không trust cloud → tắt sync, mọi thứ local trên Mac của bạn, *Codepet không thấy gì cả*.

> **Câu chốt cho khán giả:** *"Memory là điều biến Codepet từ tool thành bạn đồng hành. Nhưng memory của bạn = data của bạn. Codepet không động vào."*

---

### Câu hỏi khó — chuẩn bị tinh thần

Đây là những câu **có khả năng cao** mà bạn phải trả lời thẳng:

**"App này có phải chỉ là Tamagotchi cho dev không?"**
> Phần em pet thì có. Nhưng Tamagotchi chưa bao giờ hỏi bạn *"streaks — bạn tin nó, hay copy Duolingo?"*. **Reflection layer là real product**. Pet là cái giữ bạn quay lại.

**"Reflection của Byte có khi nào sai không?"**
> Có. Byte đoán dựa trên timing + pattern. Khi sai, Byte hỏi (không khẳng định) — *"mình đoán bạn từng có 1 lần... đúng không?"*. Nếu sai, bạn nói "không" — em ghi nhận, không tranh cãi.

**"Sao tôi phải tin app này không sell data?"**
> 3 lý do cụ thể:
> 1. **Apple App Privacy label** trên App Store listing kê đúng những gì Codepet collect — bạn xem trước khi cài, Apple audit từng release.
> 2. **macOS sandbox** giới hạn app — Codepet không đọc được file ngoài thư mục của nó. Không thấy `~/Documents`, không thấy clipboard trừ khi bạn paste.
> 3. **Business model là subscription, không phải ads.** Bán data = mất subscriber. Subscriber trả tiền vì *biết bạn an toàn* — đó là sản phẩm. Bán data đi là tự giết app.

Câu chốt: *"Bạn không cần phải tin lời mình. Bạn xem App Privacy label, xem Settings có toggle 'cloud sync off', và xem giá subscription. Cả 3 đều align với 'không sell data'."*

**"Tôi không cần app — tôi tự reflect được."**
> Đúng. Bạn không cần Codepet để reflect — như bạn không cần Notes app để ghi chú. Câu hỏi là: bạn *có làm* không? Đa số dev biết phải reflect nhưng không làm — vì không có ai *thấy* họ làm. Byte = người thấy.

---

**Phiên bản:** dựa trên `codepet/Demo/DemoScript.swift` ngày hôm nay. Nếu nội dung bubble thay đổi, file này có thể outdated — đối chiếu lại với source khi cần.
