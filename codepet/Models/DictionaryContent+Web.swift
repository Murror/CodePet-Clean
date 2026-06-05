import Foundation

extension DictionaryContent {

    static let webTerms: [DictionaryTerm] = [

        .init(
            id: "html", topicId: "web",
            title: L10n(vi: "HTML", en: "HTML"),
            cardDefinition: L10n(
                vi: "Ngôn ngữ mô tả **bộ khung** của một trang web — tiêu đề, đoạn văn, nút bấm.",
                en: "The language that lays out the **skeleton** of a web page — headings, paragraphs, buttons."
            ),
            whatItReallyMeans: L10n(
                vi: "HTML chỉ lo phần *cấu trúc*: cái này là tiêu đề lớn, cái kia là một đoạn văn, chỗ này là nút bấm. Chưa có màu, chưa có font đẹp, chưa có hiệu ứng — vẫn xem được, chỉ là trần trụi. Phần làm đẹp để CSS lo.",
                en: "HTML only handles *structure*: this is a big heading, that's a paragraph, here's a button. No colors, no nice fonts, no effects yet — still readable, just bare. The styling is CSS's job."
            ),
            diagram: nil,
            codeExample: "<h1>Hello</h1>\n<p>Welcome to my page.</p>\n<button>Click me</button>",
            whenToUse: L10n(
                vi: "Là **lớp nền của mọi trang web**. Bất cứ giao diện web nào cũng bắt đầu từ HTML.",
                en: "It's the **foundation of every web page**. Any web interface starts as HTML."
            ),
            tags: [.react], related: ["css", "frontend-backend"]
        ),

        .init(
            id: "css", topicId: "web",
            title: L10n(vi: "CSS", en: "CSS"),
            cardDefinition: L10n(
                vi: "Ngôn ngữ **làm đẹp** trang web — màu sắc, font chữ, khoảng cách, bố cục.",
                en: "The language that **styles** a web page — colors, fonts, spacing, layout."
            ),
            whatItReallyMeans: L10n(
                vi: "Nếu HTML là bộ khung nhà thì CSS là sơn, đèn và đồ nội thất. Cùng một khung HTML, đổi CSS là ra hai trang trông khác hẳn nhau. Cấu trúc giữ nguyên, vẻ ngoài thay đổi hoàn toàn.",
                en: "If HTML is the house's frame, CSS is the paint, lighting, and furniture. Same HTML frame, swap the CSS and you get two pages that look completely different. Structure stays, appearance flips."
            ),
            diagram: nil,
            codeExample: "h1 {\n    color: purple;\n    font-size: 32px;\n}",
            whenToUse: L10n(
                vi: "Mỗi khi bạn muốn một trang web **trông ra dáng** thay vì là chữ đen trên nền trắng.",
                en: "Any time you want a web page to **look designed** instead of black text on white."
            ),
            tags: [.react], related: ["html"]
        ),

        .init(
            id: "http", topicId: "web",
            title: L10n(vi: "HTTP", en: "HTTP"),
            cardDefinition: L10n(
                vi: "Bộ **quy tắc đưa thư** mà trình duyệt và máy chủ dùng để trao đổi trang web và dữ liệu.",
                en: "The **mail rules** browsers and servers use to swap web pages and data."
            ),
            whatItReallyMeans: L10n(
                vi: "Giống dịch vụ bưu chính của web. Trình duyệt gửi một *yêu cầu* — *\"cho tôi xin trang /home\"* — và máy chủ gửi lại một *câu trả lời* kèm trang đó và một mã trạng thái (`200 OK` nghĩa là ổn). Mở một trang là hàng chục lá thư bay qua lại trong vài giây.",
                en: "Like a postal service for the web. The browser sends a *request* — *\"could I have the /home page?\"* — and the server sends back a *response* with that page and a status code (`200 OK` means all good). Opening one page is dozens of letters flying back and forth in seconds."
            ),
            diagram: DiagramSpec(.requestResponse,
                [L10n(vi: "trình duyệt", en: "browser"),
                 L10n(vi: "GET /home", en: "GET /home"),
                 L10n(vi: "máy chủ", en: "server"),
                 L10n(vi: "200 OK", en: "200 OK")],
                accent: .blue,
                caption: L10n(vi: "Yêu cầu đi ra, câu trả lời đi về.",
                              en: "Request goes out, response comes back.")),
            codeExample: "GET /api/users/42 HTTP/1.1\nHost: example.com\n\n200 OK\n{ \"name\": \"Ada\" }",
            whenToUse: L10n(
                vi: "Là cách **mọi thứ trên web nói chuyện với nhau**. Hiểu nó giúp bạn gỡ lỗi mạng dễ hơn.",
                en: "It's how **everything on the web talks**. Understanding it makes network bugs far easier to debug."
            ),
            tags: [.nodeBackend, .api], related: ["api", "json"]
        ),

        .init(
            id: "api", topicId: "web",
            title: L10n(vi: "API", en: "API"),
            cardDefinition: L10n(
                vi: "Một **cách định sẵn** để chương trình này xin dữ liệu (hoặc nhờ làm việc) từ chương trình kia.",
                en: "A **defined way** for one program to ask another for data (or to do a job)."
            ),
            whatItReallyMeans: L10n(
                vi: "Một chương trình mở ra vài \"điểm gọi\" cố định, ví dụ `getWeather`. Bạn gửi yêu cầu tới đúng điểm đó và nhận lại dữ liệu theo khuôn đã thỏa thuận — còn ruột bên trong nó vẫn đóng kín. API là bản hợp đồng: gọi thế nào, nhận lại gì.",
                en: "A program exposes a few fixed \"call points\", say `getWeather`. You send a request to exactly that point and get back data in an agreed shape — while its insides stay sealed off. An API is the contract: how to call, what you get back."
            ),
            diagram: DiagramSpec(.requestResponse,
                [L10n(vi: "app của bạn", en: "your app"),
                 L10n(vi: "getWeather", en: "getWeather"),
                 L10n(vi: "API thời tiết", en: "Weather API"),
                 L10n(vi: "{ temp: 31 }", en: "{ temp: 31 }")],
                accent: .blue),
            codeExample: "GET https://api.weather.com/today?city=Hanoi\n→ { \"temp\": 31, \"sky\": \"clear\" }",
            whenToUse: L10n(
                vi: "Bất cứ khi nào **hai chương trình cần nói chuyện** — app của bạn gọi một dịch vụ bên ngoài.",
                en: "Whenever **two programs need to talk** — your app calling an outside service."
            ),
            tags: [.api, .nodeBackend], related: ["http", "json"]
        ),

        .init(
            id: "json", topicId: "web",
            title: L10n(vi: "JSON", en: "JSON"),
            cardDefinition: L10n(
                vi: "Một **định dạng chữ đơn giản** để ghi dữ liệu có cấu trúc — dùng khắp nơi trên web.",
                en: "A **simple text format** for structured data — used everywhere on the web."
            ),
            whatItReallyMeans: L10n(
                vi: "JSON viết dữ liệu thành các cặp *tên: giá trị*, dễ đọc với cả người lẫn máy: `{ \"name\": \"Ada\", \"age\": 36 }`. Có thể lồng nhau. Gần như mọi ngôn ngữ lập trình đều đọc/ghi được JSON sẵn, nên nó là cách phổ biến nhất để gửi dữ liệu giữa app và máy chủ.",
                en: "JSON writes data as *name: value* pairs that both people and machines read easily: `{ \"name\": \"Ada\", \"age\": 36 }`. It can nest. Nearly every programming language reads and writes JSON out of the box, so it's the most common way to send data between an app and a server."
            ),
            diagram: nil,
            codeExample: "{\n  \"name\": \"Ada\",\n  \"age\": 36,\n  \"skills\": [\"math\", \"coding\"]\n}",
            whenToUse: L10n(
                vi: "Cho **hầu hết dữ liệu** trao đổi giữa app và máy chủ. Người đọc được, máy hiểu được.",
                en: "For **most data** exchanged between app and server. Humans read it, machines parse it."
            ),
            tags: [.api, .nodeBackend], related: ["api", "http"]
        ),

        .init(
            id: "frontend-backend", topicId: "web",
            title: L10n(vi: "Frontend vs Backend", en: "Frontend vs Backend"),
            cardDefinition: L10n(
                vi: "**Frontend** là phần người dùng nhìn và bấm. **Backend** là phần chạy ngầm trên máy chủ, lo dữ liệu.",
                en: "**Frontend** is what users see and click. **Backend** is what runs behind the scenes on a server, handling data."
            ),
            whatItReallyMeans: L10n(
                vi: "Frontend là mặt tiền: nút bấm, màu sắc, bố cục — thứ bạn chạm vào. Backend là hậu trường: kiểm tra mật khẩu, lưu dữ liệu, tính toán — thứ không ai thấy nhưng nếu hỏng thì cả app đứng. Bạn bấm `Đăng nhập` (frontend) → nó nhờ backend kiểm tra → backend trả lời đúng/sai.",
                en: "Frontend is the storefront: buttons, colors, layout — what you touch. Backend is backstage: checking passwords, saving data, doing the math — unseen, but if it breaks the whole app freezes. You click `Login` (frontend) → it asks the backend to check → the backend answers yes/no."
            ),
            diagram: nil,
            codeExample: nil,
            whenToUse: L10n(
                vi: "Là khung tư duy hữu ích trên **mọi dự án web**. Ranh giới rõ giúp nhiều người làm song song mà không đạp lên nhau.",
                en: "A useful mental model on **any web project**. Clear boundaries let people work in parallel without stepping on each other."
            ),
            tags: [.react, .nodeBackend], related: ["html", "api"]
        ),
    ]
}
