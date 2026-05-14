import Foundation

struct DictionaryTopic: Identifiable, Hashable {
    let id: String        // slug
    let title: L10n
    let icon: String      // SF Symbol
}

struct DictionaryTerm: Identifiable, Hashable {
    let id: String                // slug
    let topicId: String
    let title: L10n
    let shortDefinition: L10n
    let analogy: L10n              // supports inline markdown (`code`, **bold**, *italic*, [tag](anything), ~~strike~~)
    let codeExample: String?
    let whenToUse: L10n?
}

enum DictionaryContent {

    static let topics: [DictionaryTopic] = [
        .init(id: "variables",    title: L10n(vi: "Biến & Kiểu dữ liệu", en: "Variables & Types"), icon: "shippingbox.fill"),
        .init(id: "functions",    title: L10n(vi: "Hàm",                 en: "Functions"),         icon: "function"),
        .init(id: "control-flow", title: L10n(vi: "Luồng điều khiển",    en: "Control Flow"),      icon: "arrow.triangle.branch"),
        .init(id: "tools",        title: L10n(vi: "Công cụ",             en: "Tools"),             icon: "wrench.and.screwdriver.fill"),
        .init(id: "web",          title: L10n(vi: "Cơ bản về Web",       en: "Web Basics"),        icon: "globe"),
    ]

    static let terms: [DictionaryTerm] = [

        // MARK: Variables & Types
        .init(
            id: "variable", topicId: "variables",
            title: L10n(vi: "Biến", en: "Variable"),
            shortDefinition: L10n(
                vi: "Một **ô có tên** giữ một giá trị mà chương trình có thể đọc và đổi sau này.",
                en: "A **named slot** that holds a value your program can read and change later."
            ),
            analogy: L10n(
                vi: "🧱 Một viên Lego có **sticker** dán trên đầu.\n\nSticker viết `score`. Bên trong viên Lego cất con số. Sau này bạn có thể *nhìn vào* xem có gì, hoặc **thay con số mới** — sticker (tên `score`) giữ nguyên, chỉ ruột bên trong đổi.\n\nViên Lego = chỗ chứa. Sticker = tên. Con số bên trong = giá trị. 🔄",
                en: "🧱 A Lego brick with a **sticker** on top.\n\nThe sticker reads `score`. Inside the brick sits a number. Later you can *peek inside*, or **swap in a new number** — the sticker (the name `score`) stays put, only the contents change.\n\nThe brick = the slot. The sticker = the name. The number inside = the value. 🔄"
            ),
            codeExample: "var score = 0\nscore = score + 10\n// score is now 10",
            whenToUse: L10n(
                vi: "Mỗi khi **giá trị sẽ đổi** trong lúc chương trình chạy — bộ đếm, nhập liệu của người dùng, kết quả của một phép tính.",
                en: "Any time a value **will change** while your program runs — counters, user input, the result of a calculation."
            )
        ),
        .init(
            id: "constant", topicId: "variables",
            title: L10n(vi: "Hằng số", en: "Constant"),
            shortDefinition: L10n(
                vi: "Một ô có tên — **một khi đã đặt** thì không đổi được nữa.",
                en: "A named slot — **once set**, it cannot change."
            ),
            analogy: L10n(
                vi: "🧱🔒 Cũng là viên Lego có sticker. Nhưng lần này — **được dán keo cứng**.\n\nBạn bê đi đâu cũng được, nhưng *không thể* lấy con số ra khỏi viên Lego nữa. Trình biên dịch (`compiler`) chính là tuýp keo — nó sẽ hét lên nếu bạn cố gỡ.\n\nLợi ích: bạn đọc code và **biết chắc** giá trị này không bị đổi ngầm ở đâu đó.",
                en: "🧱🔒 Same Lego brick with a sticker. But this one — **glued shut**.\n\nYou can carry it around all day, but *you can't* take the number out anymore. The compiler is the glue — it'll yell if you try to pry it open.\n\nThe payoff: when you read the code, you **know for sure** this value isn't being swapped behind your back."
            ),
            codeExample: "let maxAttempts = 3\n// maxAttempts = 4   // ✗ compiler error",
            whenToUse: L10n(
                vi: "Cứ chọn **hằng số trước**. Chỉ dùng biến khi thực sự cần gán lại. Hằng số giúp code dễ đọc, dễ suy luận. ✅",
                en: "Reach for a **constant first**. Use a variable only when you actually need to reassign. Constants make code easier to reason about. ✅"
            )
        ),
        .init(
            id: "string", topicId: "variables",
            title: L10n(vi: "Chuỗi (String)", en: "String"),
            shortDefinition: L10n(
                vi: "Một đoạn **văn bản** — chữ cái, chữ số, khoảng trắng, emoji, bất cứ thứ gì viết được.",
                en: "A piece of **text** — letters, digits, spaces, emoji, anything written."
            ),
            analogy: L10n(
                vi: "🔠 Một hàng viên Lego chữ snap vào nhau:\n\n`[H][e][l][l][o]`\n\nMỗi viên = `1 ký tự`. Cả hàng = `1 chuỗi`. Bạn có thể đọc cả hàng, **đếm số viên** ([5](metric) viên), hoặc nối 2 hàng lại để tạo thành câu dài hơn.\n\nNối `[H][i]` với `[ ][A][d][a]` → `[H][i][ ][A][d][a]`. 🧩",
                en: "🔠 A row of letter-Legos snapped together:\n\n`[H][e][l][l][o]`\n\nEach brick = `1 character`. The whole row = `1 string`. You can read the row, **count the bricks** ([5](metric) here), or snap two rows into one longer sentence.\n\nSnap `[H][i]` onto `[ ][A][d][a]` → `[H][i][ ][A][d][a]`. 🧩"
            ),
            codeExample: "let greeting = \"hello\"\nlet name = \"Ada\"\nlet message = greeting + \", \" + name",
            whenToUse: nil
        ),
        .init(
            id: "number", topicId: "variables",
            title: L10n(vi: "Số", en: "Number"),
            shortDefinition: L10n(
                vi: "Một giá trị số — `nguyên` (Int) hoặc `thập phân` (Float).",
                en: "A numeric value — `whole` (Int) or `decimal` (Float)."
            ),
            analogy: L10n(
                vi: "🔢 Hai loại viên Lego số:\n\n• 🧱 **Int** — viên có in con số nguyên: `0`, `1`, `2`, `3`. Đếm táo 🍎🍎🍎.\n• 📏 **Float** — viên có thêm vạch chia li: `1.5`, `3.14`. Đo bằng thước.\n\nCùng ý tưởng, *khác độ chính xác*. Số đếm thì dùng `Int`, số đo thì dùng `Float`.",
                en: "🔢 Two kinds of number-Legos:\n\n• 🧱 **Int** — bricks stamped with whole numbers: `0`, `1`, `2`, `3`. Counting apples 🍎🍎🍎.\n• 📏 **Float** — bricks with extra tick marks: `1.5`, `3.14`. Measuring with a ruler.\n\nSame idea, *different precision*. Counting → `Int`. Measuring → `Float`."
            ),
            codeExample: "let count: Int = 7\nlet price: Double = 9.99",
            whenToUse: nil
        ),
        .init(
            id: "boolean", topicId: "variables",
            title: L10n(vi: "Boolean", en: "Boolean"),
            shortDefinition: L10n(
                vi: "Một giá trị — **chỉ** `true` hoặc `false`. Không có gì ở giữa.",
                en: "A value — **only** `true` or `false`. Nothing in between."
            ),
            analogy: L10n(
                vi: "🔛 Một viên Lego có **2 mặt**:\n\n• Lật mặt ✅ — `true`\n• Lật mặt ❌ — `false`\n\nKhông có ~~mặt thứ 3~~. Không có *nửa-bật-nửa-tắt*. Đây là kiểu dữ liệu để code đặt **câu hỏi có/không** — và trả lời dứt khoát.",
                en: "🔛 A Lego brick with **two faces**:\n\n• Flip to ✅ — `true`\n• Flip to ❌ — `false`\n\nNo ~~third face~~. No *half-on, half-off*. This is the type your code uses to ask **yes/no questions** — and get a firm answer back."
            ),
            codeExample: "let isLoggedIn = true\nif isLoggedIn { /* show dashboard */ }",
            whenToUse: L10n(
                vi: "Khi code cần đặt **câu hỏi có/không** — *\"đã đăng nhập chưa?\"*, *\"upload xong chưa?\"*.",
                en: "When your code needs a **yes/no question** — *\"is the user signed in?\"*, *\"did the upload finish?\"*."
            )
        ),
        .init(
            id: "array", topicId: "variables",
            title: L10n(vi: "Mảng (Array)", en: "Array"),
            shortDefinition: L10n(
                vi: "Một danh sách giá trị **có thứ tự**, truy cập bằng vị trí.",
                en: "An **ordered** list of values, accessed by position."
            ),
            analogy: L10n(
                vi: "📦📦📦📦 Một dãy hộp Lego đánh số:\n\n`[0]` `[1]` `[2]` `[3]`\n\nMỗi hộp giữ 1 thứ. Bạn đưa cho mảng con số `2` → mảng mở `[2]` ra → đưa cho bạn thứ bên trong. 🎁\n\nThứ tự cố định. Nếu bạn cần [3](metric) thứ và cần biết thứ nào là *thứ-nhất*, *thứ-hai*, *thứ-ba* — Array là bạn.",
                en: "📦📦📦📦 A row of numbered Lego boxes:\n\n`[0]` `[1]` `[2]` `[3]`\n\nEach box holds one thing. Hand the array the number `2` → it opens box `[2]` → hands you what's inside. 🎁\n\nOrder is fixed. If you need [3](metric) things and you care which one is *first*, *second*, *third* — Array is your friend."
            ),
            codeExample: "let colors = [\"red\", \"green\", \"blue\"]\nlet first = colors[0]   // \"red\"",
            whenToUse: L10n(
                vi: "Khi có **bộ sưu tập** các thứ giống nhau và *thứ tự quan trọng* — hàng đợi tin nhắn, danh sách công việc.",
                en: "When you have a **collection** of similar things and *order matters* — a queue of messages, a list of tasks."
            )
        ),

        // MARK: Functions
        .init(
            id: "function", topicId: "functions",
            title: L10n(vi: "Hàm (Function)", en: "Function"),
            shortDefinition: L10n(
                vi: "Một khối code **có tên**, dùng lại được. Bạn *\"gọi\"* nó để chạy khối code đó.",
                en: "A **named**, reusable block of code. You *\"call\"* it to run that block."
            ),
            analogy: L10n(
                vi: "📋 Một **tờ hướng dẫn lắp Lego** có tên `greet`.\n\nTờ hướng dẫn = `hàm`. Mỗi lần bạn *làm theo nó* = `gọi hàm`. Cùng tờ hướng dẫn, làm [100 lần](metric) — ra **cùng một mô hình** cả 100 lần.\n\n`greet()` → 🧱→🧱→🧱→🏠\n`greet()` → 🧱→🧱→🧱→🏠 (giống y hệt)\n\nViết 1 lần, dùng mãi mãi. ♻️",
                en: "📋 A **Lego instruction sheet** named `greet`.\n\nThe sheet = the `function`. Each time you *follow it* = `calling the function`. Same sheet, [100 times](metric) — gives you the **same model** all 100 times.\n\n`greet()` → 🧱→🧱→🧱→🏠\n`greet()` → 🧱→🧱→🧱→🏠 (identical)\n\nWrite once, use forever. ♻️"
            ),
            codeExample: "func greet(name: String) {\n    print(\"Hello, \\(name)\")\n}\ngreet(name: \"Ada\")",
            whenToUse: L10n(
                vi: "Khi bạn thấy mình viết **đoạn code tương tự** ở nhiều chỗ. Gói nó vào hàm, gọi từ cả hai nơi.",
                en: "Whenever you find yourself writing **similar code** in more than one place. Wrap it in a function, call it from both."
            )
        ),
        .init(
            id: "parameter", topicId: "functions",
            title: L10n(vi: "Tham số", en: "Parameter"),
            shortDefinition: L10n(
                vi: "**Đầu vào** mà hàm nhận, để mỗi lần gọi có thể làm việc với giá trị khác nhau.",
                en: "An **input** a function accepts, so each call can work with a different value."
            ),
            analogy: L10n(
                vi: "🎛️ Ô **để bạn gắn miếng Lego vào** ngay đầu tờ hướng dẫn.\n\nHàm `double(x)` nói: *\"đưa tôi một con số, tôi nhân 2 trả lại\"*.\n\n• 🧱 Gắn `3` vào → trả về `6`\n• 🧱 Gắn `7` vào → trả về `14`\n• 🧱 Gắn `100` vào → trả về `200`\n\n**Cùng cỗ máy** — đầu ra khác nhau hoàn toàn dựa vào miếng Lego bạn chọn để gắn vào. 🔄",
                en: "🎛️ A **slot at the top of the instruction sheet** for you to snap a Lego piece into.\n\nThe function `double(x)` says: *\"hand me a number, I'll multiply by 2\"*.\n\n• 🧱 Snap in `3` → returns `6`\n• 🧱 Snap in `7` → returns `14`\n• 🧱 Snap in `100` → returns `200`\n\n**Same machine** — completely different output, based on the piece you snapped in. 🔄"
            ),
            codeExample: "func double(_ x: Int) -> Int {\n    return x * 2\n}\ndouble(3)   // 6\ndouble(7)   // 14",
            whenToUse: nil
        ),
        .init(
            id: "return-value", topicId: "functions",
            title: L10n(vi: "Giá trị trả về", en: "Return value"),
            shortDefinition: L10n(
                vi: "**Kết quả** hàm đưa lại cho bạn sau khi chạy xong.",
                en: "The **result** a function hands back after it finishes."
            ),
            analogy: L10n(
                vi: "🎁 Mô hình Lego **đã lắp xong** mà tờ hướng dẫn đưa lại cho bạn.\n\nBạn đưa cho hàm `square(n)` con số `5`. Hàm chạy: `5 × 5`. Cuối cùng — *đặt vào tay bạn* con số `25`. 📦\n\n`square(5)` → ⚙️ → 🎁 `25`\n\nKhông có return value = hàm chạy xong nhưng *không đưa gì lại*. Có return value = bạn nhận được thứ gì đó để **dùng tiếp**.",
                en: "🎁 The Lego model **fully assembled** that the instruction sheet hands back to you.\n\nYou hand `square(n)` the number `5`. The function runs `5 × 5`. At the end — *places in your hand* the number `25`. 📦\n\n`square(5)` → ⚙️ → 🎁 `25`\n\nNo return value = the function ran but *handed you nothing*. With a return value = you got something **to use next**."
            ),
            codeExample: "func square(_ n: Int) -> Int {\n    return n * n\n}\nlet result = square(5)   // 25",
            whenToUse: L10n(
                vi: "Khi nơi gọi hàm **cần kết quả** của công việc — tính ra gì đó, biến đổi đầu vào, tra cứu một giá trị.",
                en: "When the caller **needs the result** — calculate something, transform input, look up a value."
            )
        ),
        .init(
            id: "pure-function", topicId: "functions",
            title: L10n(vi: "Hàm thuần (Pure function)", en: "Pure function"),
            shortDefinition: L10n(
                vi: "Hàm mà **đầu ra chỉ phụ thuộc đầu vào**, không gây ảnh hưởng nào khác bên ngoài.",
                en: "A function whose **output depends only on its inputs**, with no other effect."
            ),
            analogy: L10n(
                vi: "🤖 Một máy bán hàng tự động. Bấm `B4` → ra `🥤 Coke`. Mỗi lần. Mọi lúc.\n\n• Không đăng tweet 🐦❌\n• Không thay nhiệt độ phòng 🌡️❌\n• Không bật đèn 💡❌\n\nChỉ làm 1 việc: *nhận tín hiệu → đưa hàng*. **Tin được**. **Test được**. Cùng đầu vào → **luôn luôn** cùng đầu ra. ✨",
                en: "🤖 A vending machine. Press `B4` → out comes `🥤 Coke`. Every time. Always.\n\n• Doesn't tweet 🐦❌\n• Doesn't change the room temperature 🌡️❌\n• Doesn't flicker the lights 💡❌\n\nIt does exactly one thing: *take input → hand over goods*. **Trustable**. **Testable**. Same input → **always** same output. ✨"
            ),
            codeExample: "func add(_ a: Int, _ b: Int) -> Int {\n    return a + b\n}\n// add(2, 3) is always 5, no surprises",
            whenToUse: L10n(
                vi: "Ưu tiên **hàm thuần** cho phần logic cốt lõi. Dễ test, dễ suy luận nhất.",
                en: "Lean toward **pure functions** for core logic. Easiest to test, easiest to reason about."
            )
        ),
        .init(
            id: "side-effect", topicId: "functions",
            title: L10n(vi: "Hiệu ứng phụ (Side effect)", en: "Side effect"),
            shortDefinition: L10n(
                vi: "Bất cứ thứ gì hàm làm **ngoài việc trả giá trị** — ghi xuống đĩa, in ra màn hình, đổi biến ở chỗ khác.",
                en: "Anything a function does **beyond returning a value** — writing to disk, printing, changing a variable elsewhere."
            ),
            analogy: L10n(
                vi: "🧱 Bạn lắp xong cái nhà Lego (việc bạn muốn).\n\nNhưng trong lúc lắp:\n• 💥 Hất đổ chậu cây 🌱\n• 🔊 Phát ra tiếng `\"click click\"` to làm em mèo giật mình 🐱\n• 📝 Vẽ thêm 1 nét bẩn lên bàn\n\nNhà thì xong — nhưng *kèm theo* 3 \"chuyện không mời mà đến\". Đó là **side effect**. Không sai, nhưng phải biết để **kiểm soát**.",
                en: "🧱 You finish your Lego house (the goal).\n\nBut along the way:\n• 💥 Knocked over a plant 🌱\n• 🔊 Made a loud `\"click click\"` that startled the cat 🐱\n• 📝 Left a smudge on the table\n\nThe house is done — but *along with* 3 uninvited extras. That's a **side effect**. Not wrong, just something to **be aware of**."
            ),
            codeExample: "var total = 0\nfunc add(_ n: Int) {\n    total += n   // side effect: changes total\n}",
            whenToUse: L10n(
                vi: "Hiệu ứng phụ **không tránh khỏi** (lưu file, gọi server). Kỹ năng là **cô lập** chúng — phần lớn code thuần, 1 lớp mỏng xử lý hiệu ứng.",
                en: "Side effects are **unavoidable** (saving files, calling servers). The skill is **isolating** them — most code stays pure, a thin layer handles effects."
            )
        ),
        .init(
            id: "callback", topicId: "functions",
            title: L10n(vi: "Callback", en: "Callback"),
            shortDefinition: L10n(
                vi: "Hàm bạn **đưa cho hàm khác**, để gọi lại sau khi xong việc.",
                en: "A function you **hand to another function**, to be called later when ready."
            ),
            analogy: L10n(
                vi: "📞 Bạn đặt đồ ăn mang đi. Nhân viên hỏi: *\"số điện thoại của bạn?\"*.\n\nBạn để lại số → **đi làm việc khác** 🚶. Khi đồ xong → 🔔 *Reng!* — họ gọi bạn quay lại lấy.\n\n**Số điện thoại = callback**. Bạn không phải đứng đợi ở quầy [15 phút](metric). Bạn đưa cho họ cách *liên lạc lại*, rồi đi luôn. ⏳→🔔",
                en: "📞 You order takeout. The clerk asks: *\"your phone number?\"*.\n\nYou leave it → **walk off to do other things** 🚶. When the food's ready → 🔔 *Ring!* — they call you back.\n\n**Your phone number = the callback**. You don't have to stand at the counter for [15 minutes](metric). You hand them a *way to reach you*, then leave. ⏳→🔔"
            ),
            codeExample: "func fetchUser(then callback: (String) -> Void) {\n    // ...later...\n    callback(\"Ada\")\n}",
            whenToUse: L10n(
                vi: "Khi việc mất thời gian (network, đĩa, timer) và bạn **không muốn ngồi đợi** — đưa callback, đi làm việc khác.",
                en: "When work takes time (network, disk, timers) and you **don't want to block waiting** — hand over a callback, move on."
            )
        ),

        // MARK: Control Flow
        .init(
            id: "if-else", topicId: "control-flow",
            title: L10n(vi: "If / else", en: "If / else"),
            shortDefinition: L10n(
                vi: "**Ngã rẽ** trong code: làm việc này nếu đúng, làm việc kia nếu sai.",
                en: "A **fork** in your code: do one thing if true, another if false."
            ),
            analogy: L10n(
                vi: "🛣️ Một bảng chỉ đường ở ngã rẽ:\n\n• 🌧️ Nếu **đang mưa** → đi đường có mái che\n• ☀️ Nếu **không mưa** → đi đường ngắm cảnh\n\nChương trình đọc bảng → chọn đường → đi tiếp. Đơn giản vậy thôi. Mỗi lần gặp `if`, code dừng lại *nhìn điều kiện*, rồi mới quyết định bước tiếp theo. 🚦",
                en: "🛣️ A road sign at a fork:\n\n• 🌧️ If it's **raining** → take the covered route\n• ☀️ If it's **not** → take the scenic one\n\nThe program reads the sign → picks a path → walks on. That simple. Every time it hits an `if`, the code stops to *check the condition*, then decides the next step. 🚦"
            ),
            codeExample: "if score >= 100 {\n    print(\"You win!\")\n} else {\n    print(\"Try again\")\n}",
            whenToUse: nil
        ),
        .init(
            id: "loop", topicId: "control-flow",
            title: L10n(vi: "Vòng lặp (Loop)", en: "Loop"),
            shortDefinition: L10n(
                vi: "Khối code chạy **đi chạy lại** đến khi bạn bảo dừng.",
                en: "A code block that runs **over and over** until you say stop."
            ),
            analogy: L10n(
                vi: "🔁 Một dòng trong hướng dẫn lắp Lego ghi: *\"lặp lại bước 3 cho đến khi tường cao [10 viên](metric)\"*.\n\n🧱 → 🧱🧱 → 🧱🧱🧱 → ... → 🧱🧱🧱🧱🧱🧱🧱🧱🧱🧱 ✅\n\nMỗi vòng, bạn lắp thêm 1 viên. Vòng lặp **dừng** khi điều kiện đã thoả (đủ 10 viên). Không cần bạn copy-paste *\"lắp viên\"* 10 lần.",
                en: "🔁 A line in a Lego instruction sheet that says: *\"repeat step 3 until the wall is [10 bricks](metric) tall\"*.\n\n🧱 → 🧱🧱 → 🧱🧱🧱 → ... → 🧱🧱🧱🧱🧱🧱🧱🧱🧱🧱 ✅\n\nEach loop, you add one brick. The loop **stops** when the condition is met (10 bricks). No copy-paste of *\"snap a brick\"* ten times."
            ),
            codeExample: "for i in 1...3 {\n    print(\"Round \\(i)\")\n}\n// Round 1\n// Round 2\n// Round 3",
            whenToUse: L10n(
                vi: "Bất cứ khi nào bạn định **copy-paste đoạn code tương tự** từ 3 lần trở lên — để vòng lặp làm.",
                en: "Any time you'd otherwise **copy-paste similar code** three or more times — let the loop do it."
            )
        ),
        .init(
            id: "iteration", topicId: "control-flow",
            title: L10n(vi: "Lặp (Iteration)", en: "Iteration"),
            shortDefinition: L10n(
                vi: "**Một lần chạy** qua vòng lặp, hoặc đi qua một bộ sưu tập từng phần tử một.",
                en: "**One pass** through a loop, or going through a collection one item at a time."
            ),
            analogy: L10n(
                vi: "🧱 **Một viên Lego** được snap vào tường.\n\nLoop là *toàn bộ* việc xây tường. Iteration là *từng viên* được lắp xuống.\n\n• Iteration 1 → 🧱\n• Iteration 2 → 🧱🧱\n• Iteration 3 → 🧱🧱🧱\n• ...\n• Iteration [10](metric) → 🧱🧱🧱🧱🧱🧱🧱🧱🧱🧱 ✅\n\nMỗi vòng lặp `for` chạy = 1 iteration đã xong.",
                en: "🧱 **One Lego brick** snapped onto the wall.\n\nThe loop is the *whole* job of building the wall. An iteration is *each individual* brick going down.\n\n• Iteration 1 → 🧱\n• Iteration 2 → 🧱🧱\n• Iteration 3 → 🧱🧱🧱\n• ...\n• Iteration [10](metric) → 🧱🧱🧱🧱🧱🧱🧱🧱🧱🧱 ✅\n\nEach `for` cycle = one iteration finished."
            ),
            codeExample: "for color in [\"red\", \"green\", \"blue\"] {\n    print(color)   // one iteration per color\n}",
            whenToUse: nil
        ),
        .init(
            id: "recursion", topicId: "control-flow",
            title: L10n(vi: "Đệ quy (Recursion)", en: "Recursion"),
            shortDefinition: L10n(
                vi: "Hàm tự giải bài toán bằng cách **gọi chính nó** trên một phần nhỏ hơn.",
                en: "A function that solves a problem by **calling itself** on a smaller piece."
            ),
            analogy: L10n(
                vi: "🪆 Búp bê gỗ Nga lồng vào nhau.\n\nBạn muốn đếm tổng số búp bê:\n\n1. 🪆 Mở con ngoài. *\"1 con. Có con nhỏ hơn không?\"*\n2. 🪆 Có. Mở. *\"1 con nữa. Có nhỏ hơn không?\"*\n3. 🪆 Có. Mở. ...\n4. 🪆 Đến con cuối — *\"không mở được\"* → **dừng**.\n5. Cộng ngược lại tổng.\n\nMỗi bước **tự gọi lại chính mình** trên *phần còn lại*. Đến khi gặp **case dừng** (không mở được nữa) → trả ngược tổng lên. 🔄",
                en: "🪆 Russian nesting dolls.\n\nYou want to count them:\n\n1. 🪆 Open the outer one. *\"1 doll. Is there a smaller one inside?\"*\n2. 🪆 Yes. Open it. *\"1 more. Smaller one?\"*\n3. 🪆 Yes. Open. ...\n4. 🪆 Final one — *\"won't open\"* → **stop**.\n5. Add the count back up.\n\nEach step **calls itself** on what's *left over*. When you hit the **base case** (no more to open) → the totals add back up the chain. 🔄"
            ),
            codeExample: "func factorial(_ n: Int) -> Int {\n    if n <= 1 { return 1 }\n    return n * factorial(n - 1)\n}",
            whenToUse: L10n(
                vi: "Khi bài toán tự nhiên **chia thành phiên bản nhỏ hơn** của chính nó — duyệt cây, dữ liệu lồng nhau.",
                en: "When a problem naturally **breaks into smaller versions** of itself — tree walks, nested data."
            )
        ),
        .init(
            id: "conditional", topicId: "control-flow",
            title: L10n(vi: "Điều kiện (Conditional)", en: "Conditional"),
            shortDefinition: L10n(
                vi: "Biểu thức trả về **đúng hoặc sai** — câu hỏi mà `if` đặt ra.",
                en: "An expression that's **true or false** — the question an `if` asks."
            ),
            analogy: L10n(
                vi: "❓ Câu hỏi trên tờ hướng dẫn Lego:\n\n*\"Tường đã cao hơn [10 viên](metric) chưa?\"*\n\n• ✅ Rồi → đi tiếp sang bước **lắp mái**\n• ❌ Chưa → quay lại lắp thêm viên\n\nĐiều kiện = câu hỏi. Câu trả lời (yes/no) quyết định bước **tiếp theo**.",
                en: "❓ A question on the Lego instruction sheet:\n\n*\"Is the wall taller than [10 bricks](metric)?\"*\n\n• ✅ Yes → move on to **add the roof**\n• ❌ No → loop back to add more bricks\n\nA conditional = the question. The answer (yes/no) decides the **next step**."
            ),
            codeExample: "let isAdult = age >= 18\nif isAdult { /* show full content */ }",
            whenToUse: nil
        ),
        .init(
            id: "break-continue", topicId: "control-flow",
            title: L10n(vi: "Break / Continue", en: "Break / Continue"),
            shortDefinition: L10n(
                vi: "Hai cách đổi luồng vòng lặp: **dừng hẳn** (break) hoặc **bỏ qua sang vòng tiếp theo** (continue).",
                en: "Two ways to bend a loop: **stop entirely** (break) or **skip to the next iteration** (continue)."
            ),
            analogy: L10n(
                vi: "Bạn đang lắp tường, gặp viên Lego *bị sứt mẻ*. Hai lựa chọn:\n\n• ⏭️ **continue** — bỏ viên này, *với tay sang viên kế tiếp*, tường vẫn tiếp tục mọc lên.\n• ⏹️ **break** — **đặt cả tường xuống**, ngừng hẳn. Có thể vì bạn vừa thấy đủ rồi, hoặc gặp lỗi to.\n\n`continue` = *bỏ qua 1 viên*. `break` = *dừng cả công trình*. 🛠️",
                en: "You're building a wall and hit a *chipped brick*. Two options:\n\n• ⏭️ **continue** — skip this one, *reach for the next*, the wall keeps growing.\n• ⏹️ **break** — **put the whole wall down**, stop entirely. Maybe you've seen enough, or hit a serious problem.\n\n`continue` = *skip one brick*. `break` = *stop the whole build*. 🛠️"
            ),
            codeExample: "for n in 1...10 {\n    if n == 5 { break }     // stop the loop\n    if n % 2 == 0 { continue } // skip evens\n    print(n)   // 1, 3\n}",
            whenToUse: L10n(
                vi: "Trong vòng lặp, khi một điều kiện cụ thể có nghĩa *\"xong rồi\"* (break) hoặc *\"cái này bỏ qua\"* (continue).",
                en: "Inside loops, when a specific condition means *\"we're done\"* (break) or *\"this one doesn't count\"* (continue)."
            )
        ),

        // MARK: Tools
        .init(
            id: "git", topicId: "tools",
            title: L10n(vi: "Git", en: "Git"),
            shortDefinition: L10n(
                vi: "Công cụ **chụp ảnh** mọi thay đổi code, để bạn xem lại, hoàn tác, hoặc chia sẻ.",
                en: "A tool that **photographs** every code change, so you can review, undo, or share."
            ),
            analogy: L10n(
                vi: "📸 Một chiếc máy ảnh tự động cho công trình Lego của bạn.\n\nMỗi khi bạn lắp xong một phần — *chụp tách!* — git ghi lại 1 bức ảnh dán nhãn. Sau này:\n\n• 🕰️ Quay về *bất kỳ bức nào* — \"hồi đó mọi thứ vẫn ổn\"\n• 🔍 So sánh **2 bức** — \"đã đổi gì giữa hôm qua và hôm nay?\"\n• 🌳 Tách 2 nhánh từ 1 bức để thử 2 hướng khác nhau\n\nCông trình Lego trên bàn = code hiện tại. Album ảnh = lịch sử. 📚",
                en: "📸 An automatic camera for your Lego build.\n\nEach time you finish a section — *click!* — git saves a labeled photo. Later:\n\n• 🕰️ Walk back to *any photo* — \"back then, things worked\"\n• 🔍 Compare **two photos** — \"what changed between yesterday and today?\"\n• 🌳 Branch off from one photo to try two different directions\n\nThe Lego build on the table = your current code. The photo album = the history. 📚"
            ),
            codeExample: nil,
            whenToUse: L10n(
                vi: "Trên **mọi dự án**, từ ngày đầu. Kể cả làm một mình — git là **lưới an toàn** khi thử nghiệm đi sai. 🪂",
                en: "On **every project**, from day one. Even solo — git is your **safety net** when an experiment goes sideways. 🪂"
            )
        ),
        .init(
            id: "commit", topicId: "tools",
            title: L10n(vi: "Commit", en: "Commit"),
            shortDefinition: L10n(
                vi: "**Một bức ảnh** đã lưu trong git, kèm câu mô tả bạn đã đổi gì.",
                en: "**One saved photo** in git, with a message describing what changed."
            ),
            analogy: L10n(
                vi: "📸 Một bức ảnh có chú thích:\n\n• 📸 *\"Lắp xong tường phía Đông\"* — `12:30 hôm thứ Hai`\n• 📸 *\"Thêm mái đỏ\"* — `14:15 hôm thứ Ba`\n• 📸 *\"Sửa cửa sổ bị lệch\"* — `09:45 hôm thứ Tư`\n\nMỗi ảnh là **1 bước nhỏ** trong câu chuyện. Khi xếp lại — *cả câu chuyện* hiện ra: công trình Lego đã lớn lên thế nào. 📖\n\nCommit nhỏ + chú thích rõ = sau này dễ quay lại bất kỳ điểm nào.",
                en: "📸 A photo with a caption:\n\n• 📸 *\"Finished the east wall\"* — `12:30 Mon`\n• 📸 *\"Added the red roof\"* — `14:15 Tue`\n• 📸 *\"Fixed crooked window\"* — `09:45 Wed`\n\nEach photo = **one small step** in the story. Lined up — *the whole story* appears: how your Lego build grew. 📖\n\nSmall commits + clear captions = easy to walk back to any point later."
            ),
            codeExample: "git add file.swift\ngit commit -m \"Add greeting view\"",
            whenToUse: L10n(
                vi: "Commit **sớm, thường xuyên**. Các commit nhỏ và tập trung dễ đọc và rollback hơn ~~một commit `misc changes` khổng lồ~~.",
                en: "Commit **early, often**. Small focused commits beat ~~one giant `misc changes` commit~~ for readability and rollback."
            )
        ),
        .init(
            id: "branch", topicId: "tools",
            title: L10n(vi: "Nhánh (Branch)", en: "Branch"),
            shortDefinition: L10n(
                vi: "Phiên bản **song song** của dự án, nơi bạn làm việc mà không động đến code chính.",
                en: "A **parallel** version of your project where you work without disturbing the main code."
            ),
            analogy: L10n(
                vi: "🧱 Bạn có công trình Lego **chính** trên bàn.\n\nMuốn thử kiểu mái mới — nhưng *sợ phá hỏng cái cũ*. Giải pháp: **bê sang bàn phụ** và xây bản thứ 2.\n\n• 🏠 Bàn chính (`main`) — vẫn nguyên, vẫn chạy.\n• 🏠 Bàn phụ (`new-roof`) — chỗ bạn thử kiểu mái mới.\n\nKhi thử xong:\n• ✅ Thích → *bê mái mới qua* bàn chính (merge).\n• ❌ Không thích → ~~vứt bàn phụ~~, bàn chính chưa bao giờ bị đụng. 🧹",
                en: "🧱 You have your **main** Lego build on the table.\n\nWant to try a new roof — but *afraid of breaking the current one*. Solution: **move to a side table** and build version 2.\n\n• 🏠 Main table (`main`) — untouched, still working.\n• 🏠 Side table (`new-roof`) — where you test the new roof.\n\nWhen done:\n• ✅ Like it → *carry the roof over* to the main table (merge).\n• ❌ Don't like it → ~~throw out the side table~~, main was never touched. 🧹"
            ),
            codeExample: "git checkout -b new-feature\n// ... work, commit ...\ngit checkout main\ngit merge new-feature",
            whenToUse: L10n(
                vi: "Cho **bất kỳ thay đổi không nhỏ** — tính năng, bugfix, thử nghiệm. Giữ `main` sạch; để nhánh chứa *việc đang làm*.",
                en: "For **any non-trivial change** — feature, bugfix, experiment. Keep `main` clean; let branches hold *work-in-progress*."
            )
        ),
        .init(
            id: "pull-request", topicId: "tools",
            title: L10n(vi: "Pull request", en: "Pull request"),
            shortDefinition: L10n(
                vi: "**Đề xuất gộp** một nhánh vào nhánh khác, mở để xem xét (thường trên GitHub).",
                en: "A **proposal to merge** one branch into another, opened for review (usually on GitHub)."
            ),
            analogy: L10n(
                vi: "🤝 Bạn xây xong cái mái mới ở bàn phụ. Trước khi đặt nó lên công trình chính, bạn **mời đồng đội xem**:\n\n*\"Này, đây là cái mái tôi vừa làm — bạn thấy sao? Có gì sai không?\"* 👀\n\n• 💬 Đồng đội comment: *\"Chỗ này thiếu 1 viên\"*\n• 🔧 Bạn sửa\n• ✅ Họ duyệt → mái được lắp vào nhà chính\n\nPR = **khoảnh khắc dừng lại** trước khi merge. Mời review, chạy check tự động, **ghi lại** lý do thay đổi. 📝",
                en: "🤝 You've built the new roof on the side table. Before placing it on the main build, you **invite a teammate to look**:\n\n*\"Hey, here's the roof I made — what do you think? Anything off?\"* 👀\n\n• 💬 They comment: *\"this spot is missing a brick\"*\n• 🔧 You fix it\n• ✅ They approve → roof goes on the main house\n\nA PR = **the pause** before merging. Invite review, run automated checks, **document** why the change happened. 📝"
            ),
            codeExample: nil,
            whenToUse: L10n(
                vi: "Trên **mọi đội nhóm**, và kể cả khi solo nếu bạn muốn 1 khoảnh khắc dừng lại trước khi merge.",
                en: "On **any team**, and even solo when you want a moment of pause before merging."
            )
        ),
        .init(
            id: "terminal", topicId: "tools",
            title: L10n(vi: "Terminal", en: "Terminal"),
            shortDefinition: L10n(
                vi: "Cửa sổ văn bản nơi bạn **gõ lệnh** và máy tính chạy chúng — không cần nút bấm.",
                en: "A text window where you **type commands** and the computer runs them — no buttons needed."
            ),
            analogy: L10n(
                vi: "⌨️ Một **đường dây trực tiếp** đến máy tính.\n\nGiao diện app trực quan = bàn lễ tân. Terminal = *đi thẳng vào kho*.\n\nKém bóng bẩy hơn — nhưng bạn có thể:\n• 📜 Yêu cầu bất cứ gì (`ls`, `cd`, `grep`, ...)\n• 🤖 Viết script để máy tự làm hàng loạt\n• 🚀 Chạy nhanh hơn click chuột [10×](metric) cho việc lặp đi lặp lại\n\nKhi bạn quen rồi, terminal là *cái nhanh nhất*. ⚡",
                en: "⌨️ A **direct line** to your computer.\n\nThe pretty app UI = the lobby reception. Terminal = *walking straight into the back office*.\n\nLess polished — but you can:\n• 📜 Ask for anything (`ls`, `cd`, `grep`, ...)\n• 🤖 Write scripts to batch-run\n• 🚀 Run [10×](metric) faster than clicking for repetitive work\n\nOnce you're fluent, the terminal is *the fastest tool you've got*. ⚡"
            ),
            codeExample: "ls          # list files in current folder\ncd projects # move into the projects folder\npwd         # where am I?",
            whenToUse: L10n(
                vi: "Cho việc **lặp lại, có script được, hoặc nằm sâu quá để click** — chạy build, di chuyển nhiều file, nói chuyện với git.",
                en: "For anything **repetitive, scriptable, or buried too deep to click** — running builds, moving lots of files, talking to git."
            )
        ),
        .init(
            id: "package-manager", topicId: "tools",
            title: L10n(vi: "Trình quản lý gói (Package manager)", en: "Package manager"),
            shortDefinition: L10n(
                vi: "Công cụ **tải, cài, cập nhật** các thư viện bên thứ ba mà dự án phụ thuộc.",
                en: "A tool that **downloads, installs, updates** the third-party libraries your project depends on."
            ),
            analogy: L10n(
                vi: "📦 Một cửa hàng Lego online cho code.\n\nBạn cần cái bánh xe? *Không tự đúc từng cái* — bạn đặt **Wheel Pack v2.1** từ kho online. Cửa hàng:\n\n• 🚚 Gửi cho bạn `Wheel Pack v2.1`\n• 🔗 Tự gửi luôn các phụ kiện cần thiết (`Axle`, `Tire`, `Hub`)\n• 📋 Ghi sổ rằng dự án bạn đang dùng *những gói này, phiên bản này*\n\nNếu sau này có ai khác **mở dự án** của bạn — họ chạy 1 lệnh, cửa hàng gửi *đúng cùng bộ gói* về cho họ. ✨",
                en: "📦 An online Lego store for code.\n\nNeed a wheel? *Don't mold one yourself* — order **Wheel Pack v2.1** from the catalog. The store:\n\n• 🚚 Ships you `Wheel Pack v2.1`\n• 🔗 Auto-ships the dependencies it needs (`Axle`, `Tire`, `Hub`)\n• 📋 Logs that your project is using *these packs, these versions*\n\nIf someone else **opens your project** later — they run one command, the store ships *the exact same packs* to them. ✨"
            ),
            codeExample: "npm install react      # JavaScript\nbrew install ffmpeg    # macOS apps\nswift package add ...  # Swift",
            whenToUse: L10n(
                vi: "Trên **bất kỳ dự án nào** vượt quá 1 file. An toàn hơn ~~copy file thư viện bằng tay~~ rất nhiều.",
                en: "On **any project** beyond a single file. Far safer than ~~copying library files by hand~~."
            )
        ),

        // MARK: Web Basics
        .init(
            id: "html", topicId: "web",
            title: L10n(vi: "HTML", en: "HTML"),
            shortDefinition: L10n(
                vi: "Ngôn ngữ mô tả **cấu trúc** của trang web — tiêu đề, đoạn văn, danh sách, nút bấm.",
                en: "The language that describes the **structure** of a web page — headings, paragraphs, lists, buttons."
            ),
            analogy: L10n(
                vi: "🏗️ Khung Lego **chưa sơn** của toà nhà.\n\n• 🧱 *\"Đây là `<h1>` — tiêu đề lớn\"*\n• 🧱 *\"Đây là `<p>` — một đoạn văn\"*\n• 🧱 *\"Đây là `<button>` — chỗ bấm\"*\n\nChỉ là **cấu trúc**. Chưa có màu. Chưa có font đẹp. Chưa có hiệu ứng. Vẫn xem được — chỉ là *trần trụi*. CSS sẽ đến sau, tô màu lên cái khung này. 🎨→",
                en: "🏗️ The **unpainted** Lego skeleton of the building.\n\n• 🧱 *\"This is `<h1>` — the big heading\"*\n• 🧱 *\"This is `<p>` — a paragraph\"*\n• 🧱 *\"This is `<button>` — a place to click\"*\n\nJust the **structure**. No color yet. No nice fonts. No effects. Still readable — just *bare-bones*. CSS will come along later and paint the skeleton. 🎨→"
            ),
            codeExample: "<h1>Hello</h1>\n<p>Welcome to my page.</p>\n<button>Click me</button>",
            whenToUse: nil
        ),
        .init(
            id: "css", topicId: "web",
            title: L10n(vi: "CSS", en: "CSS"),
            shortDefinition: L10n(
                vi: "Ngôn ngữ **tô điểm** cho trang web — màu sắc, font chữ, khoảng cách, bố cục.",
                en: "The language that **styles** a web page — colors, fonts, spacing, layout."
            ),
            analogy: L10n(
                vi: "🎨 Bộ đồ trang trí cho khung Lego HTML:\n\n• 🪟 Cửa sổ trong suốt\n• 🛋️ Ghế sofa màu tím\n• 🌸 Chậu hoa cạnh cửa\n• ✨ Đèn LED viền tường\n\nCùng 1 *cái khung HTML* — sơn 2 bộ CSS khác nhau → ra **2 trang web trông khác hẳn**. Cấu trúc không đổi, vẻ ngoài đổi hoàn toàn. 🔄",
                en: "🎨 The decoration kit for the HTML skeleton:\n\n• 🪟 Clear windows\n• 🛋️ A purple sofa\n• 🌸 A flower pot by the door\n• ✨ LED strips along the walls\n\nSame *HTML frame* — apply two different CSS sets → **two pages that look completely different**. Structure stays, appearance flips. 🔄"
            ),
            codeExample: "h1 {\n    color: purple;\n    font-size: 32px;\n}",
            whenToUse: nil
        ),
        .init(
            id: "http", topicId: "web",
            title: L10n(vi: "HTTP", en: "HTTP"),
            shortDefinition: L10n(
                vi: "Giao thức trình duyệt và server dùng để **trao đổi** trang web và dữ liệu.",
                en: "The protocol browsers and servers use to **exchange** web pages and data."
            ),
            analogy: L10n(
                vi: "✉️ Dịch vụ **bưu chính** cho web.\n\nTrình duyệt → server:\n\n📤 *\"Cho tôi xin trang `/home`, làm ơn.\"* (yêu cầu)\n\nServer → trình duyệt:\n\n📥 *\"Đây trang của bạn — `200 OK`. Đọc thoải mái.\"* (trả lời)\n\nMỗi lần bạn mở 1 trang — *hàng chục phong bì* được gửi qua lại trong vài giây ⚡. HTML, CSS, ảnh, font — mỗi cái 1 phong bì.",
                en: "✉️ A **postal service** for the web.\n\nBrowser → server:\n\n📤 *\"Could I have page `/home`, please.\"* (request)\n\nServer → browser:\n\n📥 *\"Here's your page — `200 OK`. Enjoy.\"* (reply)\n\nEvery time you open a page — *dozens of envelopes* fly back and forth in a few seconds ⚡. HTML, CSS, images, fonts — each one an envelope."
            ),
            codeExample: "GET /api/users/42 HTTP/1.1\nHost: example.com\n\n200 OK\nContent-Type: application/json\n{ \"name\": \"Ada\" }",
            whenToUse: nil
        ),
        .init(
            id: "api", topicId: "web",
            title: L10n(vi: "API", en: "API"),
            shortDefinition: L10n(
                vi: "**Cách định sẵn** để 1 chương trình hỏi chương trình khác lấy dữ liệu hoặc thực hiện hành động.",
                en: "A **defined way** for one program to ask another for data or actions."
            ),
            analogy: L10n(
                vi: "🔌 Các **núm gắn** sáng màu nhô lên trên 1 viên Lego.\n\nViên Lego = một chương trình. Mặt trên có vài núm Lego đã đặt sẵn — `getUser`, `sendMessage`, `getWeather`. Bạn **chỉ được gắn** vào những núm đó. Còn lại — *đóng kín, không động vào được*.\n\n• 🌤️ Gắn vào `getWeather(\"Hanoi\")` → nhận về `{ temp: 31, sky: clear }`\n• 👤 Gắn vào `getUser(42)` → nhận về `{ name: \"Ada\" }`\n\nAPI = **các điểm gắn được**. Quy ước rõ ràng: gắn cách nào, nhận lại gì.",
                en: "🔌 The **bright studs** sticking up on a Lego brick.\n\nThe brick = one program. The top has a few pre-placed studs — `getUser`, `sendMessage`, `getWeather`. You can **only snap onto** those specific studs. The rest — *sealed shut, can't touch*.\n\n• 🌤️ Snap onto `getWeather(\"Hanoi\")` → get back `{ temp: 31, sky: clear }`\n• 👤 Snap onto `getUser(42)` → get back `{ name: \"Ada\" }`\n\nAPI = **the snap points**. Clear contract: how to snap on, what you get back."
            ),
            codeExample: "// Client → API\nGET https://api.weather.com/today?city=Hanoi\n\n// API → Client\n{ \"temp\": 31, \"sky\": \"clear\" }",
            whenToUse: L10n(
                vi: "Bất cứ khi nào **2 chương trình cần nói chuyện**. App của bạn gọi API thời tiết; thời tiết gọi API vệ tinh; cứ thế tiếp diễn.",
                en: "Whenever **two programs need to talk**. Your app calls a weather API; that calls a satellite API; turtles all the way down."
            )
        ),
        .init(
            id: "json", topicId: "web",
            title: L10n(vi: "JSON", en: "JSON"),
            shortDefinition: L10n(
                vi: "Định dạng văn bản **đơn giản** cho dữ liệu có cấu trúc — dùng khắp nơi trên web.",
                en: "A **simple** text format for structured data — used everywhere on the web."
            ),
            analogy: L10n(
                vi: "📋 Một mẫu hướng dẫn Lego **chuẩn hoá**, ai cũng đọc được.\n\n```\n{\n  \"name\": \"Ada\",\n  \"age\": 36,\n  \"skills\": [\"math\", \"coding\"]\n}\n```\n\nDù bạn ở Việt Nam, Mỹ, hay Nhật — *cùng đọc được hình dạng này*. Tên (`key`) bên trái, giá trị bên phải. Có thể lồng nhau như búp bê Nga 🪆.\n\nMọi ngôn ngữ lập trình hiện đại đều **đọc/ghi được JSON** không cần thư viện ngoài. ✨",
                en: "📋 A **standardized** Lego instruction sheet that everyone reads.\n\n```\n{\n  \"name\": \"Ada\",\n  \"age\": 36,\n  \"skills\": [\"math\", \"coding\"]\n}\n```\n\nWhether you're in Vietnam, the US, or Japan — *the same shape reads the same way*. Names (`key`) on the left, values on the right. Can nest like Russian dolls 🪆.\n\nEvery modern programming language **reads and writes JSON** out of the box. ✨"
            ),
            codeExample: "{\n  \"name\": \"Ada\",\n  \"age\": 36,\n  \"skills\": [\"math\", \"coding\"]\n}",
            whenToUse: L10n(
                vi: "Cho **hầu hết dữ liệu** trao đổi giữa client và server. Người đọc được, máy parse được.",
                en: "For **most data** exchanged between client and server. Humans read it, machines parse it."
            )
        ),
        .init(
            id: "frontend-backend", topicId: "web",
            title: L10n(vi: "Frontend vs Backend", en: "Frontend vs Backend"),
            shortDefinition: L10n(
                vi: "**Frontend** là cái người dùng nhìn thấy và bấm. **Backend** là cái chạy trên server và xử lý dữ liệu.",
                en: "**Frontend** is what the user sees and clicks. **Backend** is what runs on a server and handles data."
            ),
            analogy: L10n(
                vi: "🏰 Một toà lâu đài Lego **có 2 mặt**:\n\n• 🎨 **Frontend** — mặt tiền bóng bẩy người ta nhìn thấy. Cửa sổ, mái vàng, cờ phấp phới. *\"Wow đẹp quá!\"* 🤩\n• ⚙️ **Backend** — bên trong: bánh răng, dây cao su, động cơ. Không ai thấy, nhưng nếu hỏng — *cả lâu đài đứng im*.\n\nCái bạn bấm `[Đăng nhập]` (frontend) → gửi tin nhắn qua HTTP → backend kiểm tra mật khẩu → trả lời ✅/❌. **2 phía cùng nhau** → app hoạt động.",
                en: "🏰 A Lego castle with **two sides**:\n\n• 🎨 **Frontend** — the polished facade people see. Windows, gold roof, waving flags. *\"Wow, beautiful!\"* 🤩\n• ⚙️ **Backend** — inside: gears, rubber bands, motors. Nobody sees them, but if they break — *the whole castle freezes*.\n\nThe `[Login]` button you click (frontend) → sends a message via HTTP → backend checks the password → answers ✅/❌. **Both sides together** → the app works."
            ),
            codeExample: nil,
            whenToUse: L10n(
                vi: "Khung hữu ích trên **mọi dự án** web/app. Ranh giới rõ giúp 2 người làm song song mà *không đạp lên nhau*.",
                en: "Useful framing on **any** web/app project. Clear boundaries let two people work in parallel *without stepping on each other*."
            )
        ),
    ]

    static func terms(in topicId: String) -> [DictionaryTerm] {
        terms.filter { $0.topicId == topicId }
    }

    /// Search across both vi and en text so users find terms regardless of UI language.
    static func search(_ query: String) -> [DictionaryTerm] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return terms }
        return terms.filter {
            $0.title.vi.lowercased().contains(q)
                || $0.title.en.lowercased().contains(q)
                || $0.shortDefinition.vi.lowercased().contains(q)
                || $0.shortDefinition.en.lowercased().contains(q)
        }
    }
}
