import Foundation

/// A pet-specialized vibe-coding skill tile shown in the Tips tab.
struct TipSkillTile {
    let icon: String   // SF Symbol name
    let title: L10n
    let hint: L10n
}

/// State shown next to each setup row.
enum TipSetupState: String {
    case done, warning, missing

    /// SF Symbol for the status indicator. View layer maps to a color.
    var icon: String {
        switch self {
        case .done:    return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .missing: return "circle"
        }
    }
}

/// A pet-specialized "Your setup" row.
struct TipSetupItem {
    let title: L10n
    let status: L10n
    let state: TipSetupState
    let actionLabel: L10n?
}

/// A pet-specialized "Recommended reading" entry.
struct TipReadingItem {
    let title: L10n
    let author: String   // proper noun, language-neutral
    let kind: L10n
    let why: L10n
}

/// Per-pet content for the Tips tab. Each pet represents a discipline, and
/// the Tips section dives deep into that discipline.
///
/// Lookup pattern: `TipsContent.tipSkillsByPet[appState.activeChar] ?? defaultTiles`.
/// Pet without an entry falls back to the original default tiles in the view.
struct TipsContent {

    static let tipSkillsByPet: [String: [TipSkillTile]] = [

        // Crash — Backend Dev (tough-love hype)
        "crash": [
            TipSkillTile(
                icon: "arrow.clockwise",
                title: L10n(vi: "Endpoint idempotent", en: "Idempotent endpoints"),
                hint: L10n(
                    vi: "Làm cho POST an toàn khi retry. Mất mạng không được phép tính tiền người dùng hai lần.",
                    en: "Make POST safe to retry. Network drops shouldn't double-charge users."
                )
            ),
            TipSkillTile(
                icon: "server.rack",
                title: L10n(vi: "Transaction trong DB", en: "Database transactions"),
                hint: L10n(
                    vi: "Bọc các thao tác ghi nhiều bước. Một lỗi không được phép để lại dữ liệu nửa chừng.",
                    en: "Wrap multi-step writes. One failure shouldn't leave data half-baked."
                )
            ),
            TipSkillTile(
                icon: "clock.arrow.circlepath",
                title: L10n(vi: "Background job", en: "Background jobs"),
                hint: L10n(
                    vi: "Việc gì chậm thì cho vào queue. Để người dùng đợi là mất người dùng.",
                    en: "Anything slow goes in a queue. Block the user, lose the user."
                )
            ),
            TipSkillTile(
                icon: "gauge.high",
                title: L10n(vi: "Rate limit cho API", en: "API rate limiting"),
                hint: L10n(
                    vi: "Bảo vệ prod khỏi bị lạm dụng — và bảo vệ chính bạn khỏi script chạy loạn.",
                    en: "Protect prod from abuse — and yourself from runaway scripts."
                )
            ),
        ],

        // Nova — Frontend Dev (fiery / fast)
        "nova": [
            TipSkillTile(
                icon: "square.on.square",
                title: L10n(vi: "Ghép component", en: "Component composition"),
                hint: L10n(
                    vi: "Các mảnh nhỏ tái sử dụng được luôn thắng một component khổng lồ.",
                    en: "Small reusable pieces beat one giant component every time."
                )
            ),
            TipSkillTile(
                icon: "exclamationmark.triangle",
                title: L10n(vi: "Loading & error state", en: "Loading & error states"),
                hint: L10n(
                    vi: "Mọi call async đều cần spinner và fallback. Không có ngoại lệ.",
                    en: "Every async call needs a spinner and a fallback. No exceptions."
                )
            ),
            TipSkillTile(
                icon: "checkmark.rectangle.stack",
                title: L10n(vi: "UX kiểm tra form", en: "Form validation UX"),
                hint: L10n(
                    vi: "Hãy hữu ích, đừng khó tính. Kiểm tra trong lúc người dùng gõ, không phải khi họ submit.",
                    en: "Be helpful, not pedantic. Validate as users type, not on submit."
                )
            ),
            TipSkillTile(
                icon: "figure.walk",
                title: L10n(vi: "Cơ bản về Accessibility", en: "Accessibility basics"),
                hint: L10n(
                    vi: "Điều hướng bàn phím, độ tương phản, alt text. A11y là một phần của ship, không phải thêm thắt.",
                    en: "Keyboard nav, contrast, alt text. A11y is shipping, not extra."
                )
            ),
        ],

        // Luna — Designer / UX-UI (warm / creative)
        "luna": [
            TipSkillTile(
                icon: "ruler",
                title: L10n(vi: "Khoảng cách & nhịp", en: "Spacing & rhythm"),
                hint: L10n(
                    vi: "Chọn thang 4 hoặc 8 px. Dùng khắp nơi. Sự nhất quán là lòng tốt vô hình.",
                    en: "Pick a 4 or 8 px scale. Use it everywhere. Consistency is invisible kindness."
                )
            ),
            TipSkillTile(
                icon: "textformat.size",
                title: L10n(vi: "Hệ phân cấp font chữ", en: "Type hierarchy"),
                hint: L10n(
                    vi: "Tối đa ba size trong một màn hình. To, vừa, nhỏ. Vậy thôi.",
                    en: "Three sizes max in one screen. Big, medium, small. That's it."
                )
            ),
            TipSkillTile(
                icon: "circle.lefthalf.filled",
                title: L10n(vi: "Độ tương phản màu", en: "Color contrast"),
                hint: L10n(
                    vi: "Chữ thân bài cần tương phản 4.5:1 với nền. Đo đi, đừng nhìn bằng mắt.",
                    en: "Body text needs 4.5:1 against background. Test it, don't eyeball it."
                )
            ),
            TipSkillTile(
                icon: "tray",
                title: L10n(vi: "Trạng thái rỗng", en: "Empty states"),
                hint: L10n(
                    vi: "Mọi danh sách đều có lúc bằng không. Hãy thiết kế view đó kỹ như view có đầy đủ.",
                    en: "Every list has zero. Design that view as carefully as the full one."
                )
            ),
        ],

        // Sage — Product Owner (zen / methodical)
        "sage": [
            TipSkillTile(
                icon: "checkmark.seal",
                title: L10n(vi: "Định nghĩa \"xong\", không phải tính năng", en: "Define done, not features"),
                hint: L10n(
                    vi: "\"Xong\" là kiểm chứng được. \"Tính năng\" là mơ ước. Hãy spec phần bằng chứng, không phải phần việc.",
                    en: "Done is testable. 'Feature' is wishful. Spec the proof, not the work."
                )
            ),
            TipSkillTile(
                icon: "person.text.rectangle",
                title: L10n(vi: "User story", en: "User stories"),
                hint: L10n(
                    vi: "Là [ai], tôi [muốn] để [kết quả]. Thiếu chữ \"để\" là chỗ scope bị trôi.",
                    en: "As a [who], I [want] so I [outcome]. Missing the 'so' is where scope drifts."
                )
            ),
            TipSkillTile(
                icon: "scissors",
                title: L10n(vi: "Cắt scope, không cắt chất lượng", en: "Cut scope, not quality"),
                hint: L10n(
                    vi: "Khi bị ép, bỏ tính năng. Chất lượng là không thương lượng.",
                    en: "When pressed, drop features. Quality is non-negotiable."
                )
            ),
            TipSkillTile(
                icon: "person.3",
                title: L10n(vi: "Sắp xếp các bên liên quan", en: "Stakeholder triage"),
                hint: L10n(
                    vi: "Biết ai quyết, ai khuyên, ai chỉ được báo. Đừng lẫn lộn ba bên này.",
                    en: "Know who decides, who advises, who's just informed. Don't confuse the three."
                )
            ),
        ],

        // Glitch — DevOps (punk / rebel)
        "glitch": [
            TipSkillTile(
                icon: "doc.text.below.ecg",
                title: L10n(vi: "Hạ tầng dạng code", en: "Infra as code"),
                hint: L10n(
                    vi: "Nếu không tái tạo được từ một repo thì đó không phải hạ tầng. Đó là một điều ước.",
                    en: "If it can't be reproduced from a repo, it's not infrastructure. It's a wish."
                )
            ),
            TipSkillTile(
                icon: "arrow.triangle.2.circlepath",
                title: L10n(vi: "Pipeline CI/CD", en: "CI/CD pipelines"),
                hint: L10n(
                    vi: "Đỏ trên main = không gì khác được đi tiếp đến khi xanh trở lại. Không ngoại lệ.",
                    en: "Red on main = nothing else moves until it's green. No exceptions."
                )
            ),
            TipSkillTile(
                icon: "list.bullet.indent",
                title: L10n(vi: "Log > metric > alert", en: "Logs > metrics > alerts"),
                hint: L10n(
                    vi: "Log mọi thứ, đo điều quan trọng, chỉ alert khi cần đánh thức ai đó.",
                    en: "Log everything, measure what matters, alert only on what wakes someone."
                )
            ),
            TipSkillTile(
                icon: "exclamationmark.triangle.fill",
                title: L10n(vi: "Diễn tập phục hồi sự cố", en: "Disaster recovery drills"),
                hint: L10n(
                    vi: "Prod sẽ hỏng. Tập dượt bây giờ hoặc hoảng loạn sau. Chọn một.",
                    en: "Prod will fail. Practice it now or panic later. Pick one."
                )
            ),
        ],

        // Byte — Data / ML (glitchy / fragments)
        "byte": [
            TipSkillTile(
                icon: "square.grid.3x3",
                title: L10n(vi: "Chất lượng dữ liệu trước", en: "Data quality first"),
                hint: L10n(
                    vi: "Rác vào, rác ra. 80% công sức cho dữ liệu, 20% cho model.",
                    en: "Garbage in, garbage out. 80% of effort goes on data, 20% on the model."
                )
            ),
            TipSkillTile(
                icon: "chart.line.uptrend.xyaxis",
                title: L10n(vi: "Kỷ luật train / val / test", en: "Train / val / test discipline"),
                hint: L10n(
                    vi: "Ba bộ. Đừng đụng vào test cho đến cuối. Đụng sớm là gian lận.",
                    en: "Three sets. Never touch test until the end. Touching it early is cheating."
                )
            ),
            TipSkillTile(
                icon: "chart.bar.xaxis",
                title: L10n(vi: "Đánh giá vượt qua accuracy", en: "Eval beyond accuracy"),
                hint: L10n(
                    vi: "Accuracy nói dối trên dữ liệu mất cân bằng. Dùng precision, recall, F1, AUC.",
                    en: "Accuracy lies on imbalanced data. Use precision, recall, F1, AUC."
                )
            ),
            TipSkillTile(
                icon: "drop.fill",
                title: L10n(vi: "Pipeline đặc trưng", en: "Feature pipelines"),
                hint: L10n(
                    vi: "Nếu không tái tạo được feature, bạn không tái tạo được kết quả.",
                    en: "If you can't reproduce features, you can't reproduce results."
                )
            ),
        ],

        // Null — Mobile Dev (chaotic / silly)
        "null": [
            TipSkillTile(
                icon: "battery.50",
                title: L10n(vi: "Ý thức về pin & mạng", en: "Battery & network awareness"),
                hint: L10n(
                    vi: "Tác vụ nền ngốn pin người dùng. Call mạng ngốn niềm tin. Cả hai = gỡ app.",
                    en: "Background tasks drain users. Network calls drain trust. Both = uninstall."
                )
            ),
            TipSkillTile(
                icon: "bell.badge",
                title: L10n(vi: "Phép tắc push notification", en: "Push notification etiquette"),
                hint: L10n(
                    vi: "Chỉ ping khi liên quan đến HỌ. Ping marketing = tắt thông báo.",
                    en: "Notify only when it's about THEM. Marketing pings = settings off."
                )
            ),
            TipSkillTile(
                icon: "wifi.slash",
                title: L10n(vi: "Pattern offline-first", en: "Offline-first patterns"),
                hint: L10n(
                    vi: "Giả định mạng đã mất. Thiết kế cho nó. Online chỉ là cộng thêm.",
                    en: "Assume the network is gone. Design for it. Online is a bonus."
                )
            ),
            TipSkillTile(
                icon: "shippingbox",
                title: L10n(vi: "Kỷ luật kích thước app", en: "App size discipline"),
                hint: L10n(
                    vi: "Mỗi MB là rào cản tải về. Bớt asset, lazy-load, ship gọn.",
                    en: "Every MB is a download barrier. Strip assets, lazy-load, ship lean."
                )
            ),
        ],
    ]

    // MARK: - Setup section per pet

    static let tipSetupByPet: [String: [TipSetupItem]] = [
        "crash": [
            TipSetupItem(
                title: L10n(vi: "Database Postgres", en: "Postgres database"),
                status: L10n(vi: "Đã kết nối · schema prod đồng bộ", en: "Connected · prod schema synced"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Lớp cache Redis", en: "Redis cache layer"),
                status: L10n(vi: "Tỉ lệ hit 47% — cần kiểm tra", en: "Hit ratio 47% — investigate"),
                state: .warning, actionLabel: L10n(vi: "Tinh chỉnh", en: "Tune")
            ),
            TipSetupItem(
                title: L10n(vi: "Queue cho job nền", en: "Background job queue"),
                status: L10n(vi: "Chưa cấu hình — đang block-and-wait", en: "Not configured — block-and-wait"),
                state: .missing, actionLabel: L10n(vi: "Cài đặt", en: "Set up")
            ),
            TipSetupItem(
                title: L10n(vi: "Giám sát API", en: "API monitoring"),
                status: L10n(vi: "Chưa nối dashboard latency", en: "No latency dashboard wired"),
                state: .missing, actionLabel: L10n(vi: "Nối ngay", en: "Wire it")
            ),
        ],
        "nova": [
            TipSetupItem(
                title: L10n(vi: "Storybook", en: "Storybook"),
                status: L10n(vi: "Đang chạy · đã ghi nhận 4 component", en: "Running · 4 components catalogued"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Lighthouse CI", en: "Lighthouse CI"),
                status: L10n(vi: "LCP 3.2s — vượt ngưỡng", en: "LCP 3.2s — over budget"),
                state: .warning, actionLabel: L10n(vi: "Tối ưu", en: "Optimize")
            ),
            TipSetupItem(
                title: L10n(vi: "Bộ test hồi quy hình ảnh", en: "Visual regression suite"),
                status: L10n(vi: "Chưa có ảnh baseline", en: "No screenshot baseline"),
                state: .missing, actionLabel: L10n(vi: "Chụp", en: "Capture")
            ),
            TipSetupItem(
                title: L10n(vi: "Bundle analyzer", en: "Bundle analyzer"),
                status: L10n(vi: "Lần chạy gần nhất: chưa từng", en: "Last run: never"),
                state: .missing, actionLabel: L10n(vi: "Chạy ngay", en: "Run now")
            ),
        ],
        "luna": [
            TipSetupItem(
                title: L10n(vi: "Thư viện Figma", en: "Figma library"),
                status: L10n(vi: "Đã liên kết · 47 component", en: "Linked · 47 components"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Xuất design token", en: "Design tokens export"),
                status: L10n(vi: "Lệch · 3 token bị trôi", en: "Out of sync · 3 tokens drifted"),
                state: .warning, actionLabel: L10n(vi: "Đồng bộ lại", en: "Re-sync")
            ),
            TipSetupItem(
                title: L10n(vi: "Kiểm tra Accessibility", en: "Accessibility audit"),
                status: L10n(vi: "Chu kỳ này chưa check WCAG", en: "No WCAG check this cycle"),
                state: .missing, actionLabel: L10n(vi: "Kiểm tra", en: "Audit")
            ),
            TipSetupItem(
                title: L10n(vi: "Hướng dẫn giọng điệu thương hiệu", en: "Brand voice guide"),
                status: L10n(vi: "Doc về tone chưa được viết", en: "Tone doc not written"),
                state: .missing, actionLabel: L10n(vi: "Phác thảo", en: "Draft")
            ),
        ],
        "sage": [
            TipSetupItem(
                title: L10n(vi: "Doc đặc tả sản phẩm", en: "Product spec doc"),
                status: L10n(vi: "Đã liên kết · cập nhật hôm qua", en: "Linked · last updated yesterday"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Metric ngôi sao Bắc Đẩu", en: "North-star metric"),
                status: L10n(vi: "Đã định nghĩa nhưng chưa đo", en: "Defined but not instrumented"),
                state: .warning, actionLabel: L10n(vi: "Đo lường", en: "Instrument")
            ),
            TipSetupItem(
                title: L10n(vi: "Nhật ký nghiên cứu người dùng", en: "User research log"),
                status: L10n(vi: "0 phỏng vấn quý này", en: "0 interviews this quarter"),
                state: .missing, actionLabel: L10n(vi: "Lên lịch", en: "Schedule")
            ),
            TipSetupItem(
                title: L10n(vi: "Snapshot roadmap", en: "Roadmap snapshot"),
                status: L10n(vi: "Chưa có bản công khai", en: "No public version"),
                state: .missing, actionLabel: L10n(vi: "Công bố", en: "Publish")
            ),
        ],
        "glitch": [
            TipSetupItem(
                title: L10n(vi: "Trạng thái Terraform", en: "Terraform state"),
                status: L10n(vi: "Backend S3 · đã khoá", en: "S3 backend · locked"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Pipeline CI", en: "CI pipeline"),
                status: L10n(vi: "Trung bình 14m — vượt mức 10m", en: "Avg 14m — over 10m budget"),
                state: .warning, actionLabel: L10n(vi: "Profile", en: "Profile")
            ),
            TipSetupItem(
                title: L10n(vi: "Runbook on-call", en: "On-call runbook"),
                status: L10n(vi: "Trống · không có kịch bản sự cố", en: "Empty · no incident playbook"),
                state: .missing, actionLabel: L10n(vi: "Viết", en: "Write")
            ),
            TipSetupItem(
                title: L10n(vi: "Lịch diễn tập chaos", en: "Chaos drill schedule"),
                status: L10n(vi: "Diễn tập gần nhất: chưa từng", en: "Last drill: never"),
                state: .missing, actionLabel: L10n(vi: "Lên kế hoạch", en: "Plan")
            ),
        ],
        "byte": [
            TipSetupItem(
                title: L10n(vi: "Theo dõi thí nghiệm", en: "Experiment tracker"),
                status: L10n(vi: "MLflow · ghi nhận 23 lần chạy", en: "MLflow · 23 runs logged"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Versioning dữ liệu", en: "Data versioning"),
                status: L10n(vi: "DVC cũ · commit gần nhất 9 ngày trước", en: "DVC stale · last commit 9d ago"),
                state: .warning, actionLabel: L10n(vi: "Snapshot lại", en: "Re-snapshot")
            ),
            TipSetupItem(
                title: L10n(vi: "Feature store", en: "Feature store"),
                status: L10n(vi: "Feature bị tính lại theo từng notebook", en: "Features re-derived per notebook"),
                state: .missing, actionLabel: L10n(vi: "Tập trung hoá", en: "Centralize")
            ),
            TipSetupItem(
                title: L10n(vi: "Giám sát model", en: "Model monitoring"),
                status: L10n(vi: "Chưa có alert về drift trên prod", en: "No drift alerts in prod"),
                state: .missing, actionLabel: L10n(vi: "Nối alert", en: "Wire alerts")
            ),
        ],
        "null": [
            TipSetupItem(
                title: L10n(vi: "Crashlytics", en: "Crashlytics"),
                status: L10n(vi: "Đã kết nối · 99.7% không crash", en: "Connected · 99.7% crash-free"),
                state: .done, actionLabel: nil
            ),
            TipSetupItem(
                title: L10n(vi: "Ngân sách kích thước app", en: "App size budget"),
                status: L10n(vi: "82MB — vượt ngân sách 8MB", en: "82MB — 8MB over budget"),
                state: .warning, actionLabel: L10n(vi: "Cắt giảm", en: "Trim")
            ),
            TipSetupItem(
                title: L10n(vi: "Audit tác vụ nền", en: "Background task audit"),
                status: L10n(vi: "Chưa đo mức tiêu hao", en: "No drain measurement"),
                state: .missing, actionLabel: L10n(vi: "Đo lường", en: "Measure")
            ),
            TipSetupItem(
                title: L10n(vi: "Lớp cache offline", en: "Offline cache layer"),
                status: L10n(vi: "Chiến lược cache còn trống", en: "Empty cache strategy"),
                state: .missing, actionLabel: L10n(vi: "Định nghĩa", en: "Define")
            ),
        ],
    ]

    // MARK: - Reading section per pet

    static let tipReadingByPet: [String: [TipReadingItem]] = [
        "crash": [
            TipReadingItem(
                title: L10n(vi: "Designing Data-Intensive Applications", en: "Designing Data-Intensive Applications"),
                author: "Martin Kleppmann",
                kind: L10n(vi: "Sách · 624 trang", en: "Book · 624 pages"),
                why: L10n(
                    vi: "Chương 5–7 về replication & consistency là nền tảng mọi backend đứng trên đó.",
                    en: "Chapters 5–7 on replication & consistency are the foundation every backend ships on."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "The Twelve-Factor App", en: "The Twelve-Factor App"),
                author: "12factor.net",
                kind: L10n(vi: "Bài luận · 30 phút", en: "Essay · 30 min"),
                why: L10n(
                    vi: "Kỷ luật vận hành đứng vững qua mọi stack. Đọc lại mỗi năm một lần.",
                    en: "Operational discipline that holds up across every stack. Re-read once a year."
                )
            ),
        ],
        "nova": [
            TipReadingItem(
                title: L10n(vi: "Refactoring UI", en: "Refactoring UI"),
                author: "Steve Schoger & Adam Wathan",
                kind: L10n(vi: "Sách · 220 trang", en: "Book · 220 pages"),
                why: L10n(
                    vi: "Gu thẩm mỹ thực tiễn cho engineer. Giải quyết 90% các khoảnh khắc \"sao UI mình trông kỳ vậy\".",
                    en: "Practical taste for engineers. Solves 90% of 'why does my UI look off' moments."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "Inclusive Components", en: "Inclusive Components"),
                author: "Heydon Pickering",
                kind: L10n(vi: "Loạt bài · 12 bài luận", en: "Series · 12 essays"),
                why: L10n(
                    vi: "Accessible từ gốc. Mỗi bài luận là một component được làm đúng từ đầu đến cuối.",
                    en: "Accessible by default. Each essay is one component done right end-to-end."
                )
            ),
        ],
        "luna": [
            TipReadingItem(
                title: L10n(vi: "The Design of Everyday Things", en: "The Design of Everyday Things"),
                author: "Don Norman",
                kind: L10n(vi: "Sách · 368 trang", en: "Book · 368 pages"),
                why: L10n(
                    vi: "Affordance và signifier — ngôn ngữ giải thích vì sao một thứ thấy đúng hay sai.",
                    en: "Affordances and signifiers — the language of why things feel right or wrong."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "The Humane Interface", en: "The Humane Interface"),
                author: "Jef Raskin",
                kind: L10n(vi: "Sách · 256 trang", en: "Book · 256 pages"),
                why: L10n(
                    vi: "Cognetics — thiết kế cho sự chú ý của con người, không chỉ cho mắt. Đáng ngạc nhiên là vẫn còn rất hợp thời.",
                    en: "Cognetics — design for human attention, not just human eyes. Surprisingly current."
                )
            ),
        ],
        "sage": [
            TipReadingItem(
                title: L10n(vi: "Inspired", en: "Inspired"),
                author: "Marty Cagan",
                kind: L10n(vi: "Sách · 368 trang", en: "Book · 368 pages"),
                why: L10n(
                    vi: "Cách các đội sản phẩm thực sự giỏi quyết định xây cái gì. Kinh thánh chống lại nhà-máy-tính-năng.",
                    en: "How great product teams really decide what to build. The anti-feature-factory bible."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "Continuous Discovery Habits", en: "Continuous Discovery Habits"),
                author: "Teresa Torres",
                kind: L10n(vi: "Sách · 240 trang", en: "Book · 240 pages"),
                why: L10n(
                    vi: "Biến discovery thành thói quen tuần, không phải sự kiện quý. Khung làm việc cụ thể.",
                    en: "Make discovery a weekly habit, not a quarterly event. Concrete framework."
                )
            ),
        ],
        "glitch": [
            TipReadingItem(
                title: L10n(vi: "Site Reliability Engineering", en: "Site Reliability Engineering"),
                author: "Google SRE Team",
                kind: L10n(vi: "Sách · 528 trang", en: "Book · 528 pages"),
                why: L10n(
                    vi: "Kinh thánh SRE. Đọc trước phần error budget và toil. Phần còn lại đọc lướt sau.",
                    en: "The SRE bible. Skip to error budgets and toil first. Skim the rest later."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "The Phoenix Project", en: "The Phoenix Project"),
                author: "Kim, Behr & Spafford",
                kind: L10n(vi: "Tiểu thuyết · 432 trang", en: "Novel · 432 pages"),
                why: L10n(
                    vi: "DevOps kể dưới dạng câu chuyện. Đọc một lần, bạn sẽ nhận ra cùng mẫu hình ở mọi công ty.",
                    en: "DevOps as a story. Read it once and you'll spot the pattern in every org."
                )
            ),
        ],
        "byte": [
            TipReadingItem(
                title: L10n(vi: "Designing Machine Learning Systems", en: "Designing Machine Learning Systems"),
                author: "Chip Huyen",
                kind: L10n(vi: "Sách · 386 trang", en: "Book · 386 pages"),
                why: L10n(
                    vi: "ML đầu cuối trong production. Bao trùm phần các khoá học bỏ qua — drift, monitoring, ops.",
                    en: "End-to-end ML in production. Covers what courses skip — drift, monitoring, ops."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "Hidden Technical Debt in ML Systems", en: "Hidden Technical Debt in ML Systems"),
                author: "Sculley et al.",
                kind: L10n(vi: "Bài báo · 9 trang", en: "Paper · 9 pages"),
                why: L10n(
                    vi: "Đọc lại mỗi sáu tháng. Mỗi lần một phần khác lại bắt đầu thấm.",
                    en: "Re-read every six months. Each time another section starts to land."
                )
            ),
        ],
        "null": [
            TipReadingItem(
                title: L10n(vi: "iOS App Architecture", en: "iOS App Architecture"),
                author: "Chris Eidhof et al.",
                kind: L10n(vi: "Sách · 232 trang", en: "Book · 232 pages"),
                why: L10n(
                    vi: "Các pattern sống sót qua app 5+ năm. MVVM, coordinator, DI trong thực tế.",
                    en: "Patterns that survive 5+ year apps. MVVM, coordinators, DI in real practice."
                )
            ),
            TipReadingItem(
                title: L10n(vi: "Mobile UX Guidelines", en: "Mobile UX Guidelines"),
                author: "Nielsen Norman Group",
                kind: L10n(vi: "Loạt bài · ~20 bài luận", en: "Series · ~20 essays"),
                why: L10n(
                    vi: "Vùng chạm, cử chỉ, accessibility trên màn hình nhỏ. Tài liệu tham khảo nên bookmark.",
                    en: "Touch targets, gestures, accessibility on small screens. Bookmarkable reference."
                )
            ),
        ],
    ]

    // MARK: - Pet note bottom (1 string per pet)

    static let tipPetNoteByPet: [String: L10n] = [
        "crash":  L10n(
            vi: "Hôm qua bắt được hai endpoint không có idempotency key. Hôm nay chưa cắn ta, nhưng đến lúc scale lên là cắn. Đáng dành 30 phút dọn lại.",
            en: "Caught two endpoints without idempotency keys yesterday. Won't bite us today, will bite us at scale. Worth a 30-min sweep."
        ),
        "nova":   L10n(
            vi: "Tuần này hai component ship đi mà không có loading state. Người dùng thấy màn hình trắng một nhịp trước khi nội dung hiện. Mỗi cái sửa nhanh thôi.",
            en: "Two components shipped without loading states this week. Users see blank screens for a beat before content. Quick wins on each."
        ),
        "luna":   L10n(
            vi: "Tôi thích empty state mới trên dashboard. Còn nút reset CTA trong settings — màu, độ đậm, vị trí đều đang nói 'đừng chạm tôi'. Đáng để xem lại một lượt.",
            en: "I love the new empty state on the dashboard. The reset CTA in settings, though — color, weight, position all say 'don't tap me.' Worth a pass."
        ),
        "sage":   L10n(
            vi: "Ba trong năm thứ 'phải có' gần nhất không ship được, mà cũng không ai thấy thiếu. Đáng để retro xem tiêu chuẩn ấy được đặt thế nào — và bởi ai.",
            en: "Three of the last five 'must-haves' didn't ship and weren't missed. Worth a retro on how the bar gets set — and by whom."
        ),
        "glitch": L10n(
            vi: "Tuần này ba lần deploy cần chạm tay. Đó là ba bug đang chờ trong khoảng cách giữa 'chạy trên staging' và 'chạy trên prod'.",
            en: "Three deploys this week needed manual touch. That's three bugs waiting in the gap between 'works on staging' and 'works on prod'."
        ),
        "byte":   L10n(
            vi: "Tuần này hai notebook ship đi mà không cố định seed. Kết quả không tái tạo được. Phát hiện của bạn-trong-quá-khứ đã chết cho đến khi bạn chạy lại được.",
            en: "Two notebooks shipped without a fixed seed this week. Results aren't reproducible. Past-you's findings are dead until you can re-run them."
        ),
        "null":   L10n(
            vi: "Tuần này xin quyền push ngay lần mở app đầu tiên — tỉ lệ đồng ý 11%. Thử đợi đến khi đã chứng minh giá trị; thường lên 4 lần.",
            en: "Push permission asked on first launch this week — consent rate 11%. Try waiting until value is proven; usually 4× lift."
        ),
    ]
}
