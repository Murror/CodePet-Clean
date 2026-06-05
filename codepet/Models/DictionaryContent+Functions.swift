import Foundation

extension DictionaryContent {

    static let functionsTerms: [DictionaryTerm] = [

        .init(
            id: "function", topicId: "functions",
            title: L10n(vi: "Hàm (Function)", en: "Function"),
            cardDefinition: L10n(
                vi: "Một **cái máy có tên**: bạn đưa đầu vào, nó trả lại kết quả.",
                en: "A **named machine**: you give it an input, it hands back a result."
            ),
            whatItReallyMeans: L10n(
                vi: "Bạn viết các bước **một lần** rồi đặt tên cho chúng. Sau này chỉ cần *gọi* cái tên đó là các bước chạy lại — với đầu vào khác nhau mỗi lần. Viết một lần, dùng mãi mãi.",
                en: "You write the steps **once** and give them a name. Later you just *call* that name to run the steps again — with a different input each time. Write it once, use it forever."
            ),
            diagram: DiagramSpec(.beforeAfter,
                [L10n(vi: "đầu vào", en: "input"), L10n(vi: "double()", en: "double()"), L10n(vi: "kết quả", en: "result")],
                accent: .pink),
            codeExample: "func double(_ x: Int) -> Int {\n    return x * 2\n}\ndouble(7)   // 14",
            whenToUse: L10n(
                vi: "Mỗi khi bạn thấy mình viết **đoạn code giống nhau** ở nhiều chỗ — gói nó vào một hàm.",
                en: "Whenever you catch yourself writing **the same code** in more than one place — wrap it in a function."
            ),
            tags: [], related: ["parameter", "return-value", "pure-function"]
        ),

        .init(
            id: "parameter", topicId: "functions",
            title: L10n(vi: "Tham số", en: "Parameter"),
            cardDefinition: L10n(
                vi: "Một **chỗ trống ở đầu vào** của hàm, để mỗi lần gọi bạn đưa vào một giá trị khác.",
                en: "An **input slot** on a function, so each call can hand it a different value."
            ),
            whatItReallyMeans: L10n(
                vi: "Cái máy `double(x)` nói: *\"đưa tôi một con số, tôi nhân đôi rồi trả lại\"*. Cái `x` chính là chỗ trống — bạn nhét `3` vào thì ra `6`, nhét `7` vào thì ra `14`. Cùng một máy, đầu ra khác nhau tùy thứ bạn bỏ vào.",
                en: "The machine `double(x)` says: *\"hand me a number, I'll double it and give it back\"*. That `x` is the slot — drop in `3` and you get `6`, drop in `7` and you get `14`. Same machine, different output depending on what you feed it."
            ),
            diagram: DiagramSpec(.beforeAfter,
                [L10n(vi: "3", en: "3"), L10n(vi: "double(x)", en: "double(x)"), L10n(vi: "6", en: "6")],
                accent: .pink,
                caption: L10n(vi: "Đổi đầu vào → đổi đầu ra.", en: "Change the input → change the output.")),
            codeExample: "func double(_ x: Int) -> Int {\n    return x * 2\n}\ndouble(3)   // 6",
            whenToUse: L10n(
                vi: "Khi một hàm cần làm việc với **giá trị khác nhau** mỗi lần gọi.",
                en: "When a function needs to work with **different values** on each call."
            ),
            tags: [], related: ["function", "return-value"]
        ),

        .init(
            id: "return-value", topicId: "functions",
            title: L10n(vi: "Giá trị trả về", en: "Return value"),
            cardDefinition: L10n(
                vi: "**Kết quả** mà hàm đưa lại cho bạn sau khi chạy xong.",
                en: "The **result** a function hands back after it finishes."
            ),
            whatItReallyMeans: L10n(
                vi: "Bạn đưa cho `square(5)` con số 5; nó tính `5 × 5` rồi *đặt vào tay bạn* con số 25 để bạn dùng tiếp. Hàm không có giá trị trả về thì chạy xong mà không đưa lại gì; có giá trị trả về thì bạn nhận được thứ gì đó để làm việc tiếp.",
                en: "You give `square(5)` the number 5; it computes `5 × 5` and *places 25 in your hand* to use next. A function with no return value runs and hands back nothing; one with a return value gives you something to keep working with."
            ),
            diagram: DiagramSpec(.beforeAfter,
                [L10n(vi: "5", en: "5"), L10n(vi: "square(n)", en: "square(n)"), L10n(vi: "25", en: "25")],
                accent: .teal),
            codeExample: "func square(_ n: Int) -> Int {\n    return n * n\n}\nlet result = square(5)   // 25",
            whenToUse: L10n(
                vi: "Khi nơi gọi hàm **cần kết quả** — tính ra gì đó, biến đổi đầu vào, tra một giá trị.",
                en: "When the caller **needs the result** — to compute something, transform input, or look a value up."
            ),
            tags: [], related: ["function", "parameter"]
        ),

        .init(
            id: "pure-function", topicId: "functions",
            title: L10n(vi: "Hàm thuần (Pure function)", en: "Pure function"),
            cardDefinition: L10n(
                vi: "Một hàm mà **cùng đầu vào thì luôn cho cùng đầu ra**, và không động chạm gì khác bên ngoài.",
                en: "A function where **the same input always gives the same output**, and it touches nothing else."
            ),
            whatItReallyMeans: L10n(
                vi: "Giống một cái máy bán nước: bấm `B4` là ra Coke, lần nào cũng vậy. Nó không đăng tweet, không bật đèn, không đổi gì ở nơi khác. Vì đoán trước được, loại hàm này **dễ kiểm thử và dễ tin** nhất.",
                en: "Like a vending machine: press `B4`, out comes Coke, every single time. It doesn't tweet, flip a light, or change anything elsewhere. Because it's predictable, this kind of function is the **easiest to test and trust**."
            ),
            diagram: DiagramSpec(.beforeAfter,
                [L10n(vi: "B4", en: "B4"), L10n(vi: "máy bán", en: "vending"), L10n(vi: "🥤 Coke", en: "🥤 Coke")],
                accent: .teal,
                caption: L10n(vi: "Cùng đầu vào → luôn cùng đầu ra.", en: "Same input → always the same output.")),
            codeExample: "func add(_ a: Int, _ b: Int) -> Int {\n    return a + b\n}\n// add(2, 3) is always 5",
            whenToUse: L10n(
                vi: "Ưu tiên hàm thuần cho **phần logic cốt lõi** — dễ test, dễ suy luận nhất.",
                en: "Prefer pure functions for **core logic** — easiest to test, easiest to reason about."
            ),
            tags: [], related: ["function", "side-effect"]
        ),

        .init(
            id: "side-effect", topicId: "functions",
            title: L10n(vi: "Hiệu ứng phụ (Side effect)", en: "Side effect"),
            cardDefinition: L10n(
                vi: "Bất cứ gì hàm làm **ngoài việc trả kết quả** — ghi ra file, in màn hình, đổi một thứ ở nơi khác.",
                en: "Anything a function does **besides returning a result** — writing a file, printing, changing something elsewhere."
            ),
            whatItReallyMeans: L10n(
                vi: "Bạn nhờ hàm tính một con số (việc chính), nhưng trên đường đi nó còn ghi vào nhật ký, gửi một email, hay đổi một biến dùng chung. Những việc \"kèm theo\" đó là hiệu ứng phụ — không sai, nhưng cần biết để **kiểm soát**.",
                en: "You ask a function to compute a number (the main job), but along the way it also writes to a log, sends an email, or changes a shared variable. Those \"extra\" actions are side effects — not wrong, but worth being aware of so you can **keep them in check**."
            ),
            diagram: nil,
            codeExample: "var total = 0\nfunc add(_ n: Int) {\n    total += n   // side effect: changes total\n}",
            whenToUse: L10n(
                vi: "Hiệu ứng phụ là **không tránh khỏi** (lưu file, gọi server). Kỹ năng là **cô lập** chúng vào một lớp mỏng, phần còn lại giữ thuần.",
                en: "Side effects are **unavoidable** (saving files, calling servers). The skill is to **isolate** them in a thin layer and keep the rest pure."
            ),
            tags: [], related: ["pure-function", "function"]
        ),

        .init(
            id: "callback", topicId: "functions",
            title: L10n(vi: "Callback", en: "Callback"),
            cardDefinition: L10n(
                vi: "Một hàm bạn **đưa cho hàm khác**, dặn *\"xong việc thì gọi cái này\"*.",
                en: "A function you **hand to another function**, saying *\"call this when you're done.\"*"
            ),
            whatItReallyMeans: L10n(
                vi: "Giống khi đặt đồ ăn rồi để lại số điện thoại: bạn không đứng đợi ở quầy, mà đi làm việc khác; xong món, người ta **gọi lại** cho bạn. Số điện thoại đó chính là callback — một cách để được báo khi việc (thường mất thời gian) đã hoàn tất.",
                en: "Like ordering takeout and leaving your phone number: you don't wait at the counter, you go do other things; when the food's ready, they **call you back**. That phone number is the callback — a way to be notified when some (usually slow) job finishes."
            ),
            diagram: nil,
            codeExample: "func fetchUser(then callback: (String) -> Void) {\n    // ...later...\n    callback(\"Ada\")\n}",
            whenToUse: L10n(
                vi: "Khi việc mất thời gian (mạng, đĩa, hẹn giờ) và bạn **không muốn ngồi đợi** — đưa callback rồi làm việc khác.",
                en: "When work takes time (network, disk, timers) and you **don't want to sit waiting** — hand over a callback and move on."
            ),
            tags: [], related: ["function"]
        ),
    ]
}
