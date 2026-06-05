import Foundation

extension DictionaryContent {

    static let toolsTerms: [DictionaryTerm] = [

        .init(
            id: "git", topicId: "tools",
            title: L10n(vi: "Git", en: "Git"),
            cardDefinition: L10n(
                vi: "Công cụ **chụp ảnh** mọi thay đổi code, để bạn xem lại, hoàn tác hoặc chia sẻ.",
                en: "A tool that **snapshots** every code change, so you can review, undo, or share."
            ),
            whatItReallyMeans: L10n(
                vi: "Mỗi lần bạn lưu một bước, git ghi lại một bức ảnh của toàn bộ dự án kèm lời ghi chú. Chuỗi ảnh đó là **lịch sử** — bạn quay về bất kỳ điểm nào, so sánh hai điểm, hay tách nhánh để thử hướng mới mà không sợ hỏng bản chính.",
                en: "Each time you save a step, git records a photo of the whole project with a note. That chain of photos is your **history** — go back to any point, compare two of them, or branch off to try a new direction without risking the main copy."
            ),
            diagram: DiagramSpec(.timeline,
                [L10n(vi: "khởi tạo", en: "init"),
                 L10n(vi: "thêm view", en: "add view"),
                 L10n(vi: "sửa lỗi", en: "fix bug")],
                accent: .gold,
                caption: L10n(vi: "Mỗi điểm là một bản lưu bạn có thể quay lại.",
                              en: "Each dot is a save you can return to.")),
            codeExample: "git add file.swift\ngit commit -m \"Add greeting view\"",
            whenToUse: L10n(
                vi: "Trên **mọi dự án**, từ ngày đầu. Kể cả làm một mình — git là lưới an toàn khi thử nghiệm đi sai.",
                en: "On **every project**, from day one. Even solo — git is your safety net when an experiment goes sideways."
            ),
            tags: [], related: ["commit", "branch", "pull-request"]
        ),

        .init(
            id: "commit", topicId: "tools",
            title: L10n(vi: "Commit", en: "Commit"),
            cardDefinition: L10n(
                vi: "**Một bản lưu** trong git, kèm câu mô tả bạn vừa đổi gì.",
                en: "**One saved snapshot** in git, with a note describing what changed."
            ),
            whatItReallyMeans: L10n(
                vi: "Mỗi commit là một bức ảnh có chú thích: *\"xây xong tường phía Đông\"*, *\"thêm mái đỏ\"*. Xếp các commit lại, bạn thấy cả câu chuyện dự án lớn lên thế nào. Commit nhỏ và chú thích rõ giúp sau này dễ quay về đúng điểm cần.",
                en: "Each commit is a captioned photo: *\"finished the east wall\"*, *\"added the red roof\"*. Line the commits up and you see the whole story of how the project grew. Small commits with clear notes make it easy to walk back to the exact point you need."
            ),
            diagram: DiagramSpec(.timeline,
                [L10n(vi: "tường Đông", en: "east wall"),
                 L10n(vi: "mái đỏ", en: "red roof"),
                 L10n(vi: "sửa cửa", en: "fix window")],
                accent: .gold),
            codeExample: "git add file.swift\ngit commit -m \"Add greeting view\"",
            whenToUse: L10n(
                vi: "Commit **sớm và thường xuyên**. Nhiều commit nhỏ dễ đọc và dễ hoàn tác hơn một commit khổng lồ.",
                en: "Commit **early and often**. Many small commits are easier to read and undo than one giant one."
            ),
            tags: [], related: ["git", "branch"]
        ),

        .init(
            id: "branch", topicId: "tools",
            title: L10n(vi: "Nhánh (Branch)", en: "Branch"),
            cardDefinition: L10n(
                vi: "Một **bản song song** của dự án, nơi bạn thử việc mới mà không đụng tới bản chính.",
                en: "A **parallel copy** of the project where you try new work without touching the main one."
            ),
            whatItReallyMeans: L10n(
                vi: "Muốn thử một ý mới mà sợ làm hỏng cái đang chạy? Tạo một nhánh — như chép dự án sang một bàn phụ để nghịch. Bản chính (`main`) vẫn nguyên. Thích thì *gộp* nhánh trở lại; không thích thì bỏ đi, bản chính chưa từng bị đụng.",
                en: "Want to try a new idea but afraid of breaking what works? Make a branch — like copying the project to a side table to tinker. The main copy (`main`) stays untouched. Like it? *Merge* the branch back. Don't? Toss it, and main was never disturbed."
            ),
            diagram: DiagramSpec(.timeline,
                [L10n(vi: "main", en: "main"),
                 L10n(vi: "nhánh mới", en: "new branch"),
                 L10n(vi: "gộp lại", en: "merge back")],
                accent: .purple),
            codeExample: "git checkout -b new-feature\n// ... work, commit ...\ngit checkout main\ngit merge new-feature",
            whenToUse: L10n(
                vi: "Cho **bất kỳ thay đổi không nhỏ** — tính năng, sửa lỗi, thử nghiệm. Giữ `main` luôn sạch.",
                en: "For **any non-trivial change** — feature, bugfix, experiment. Keep `main` clean at all times."
            ),
            tags: [], related: ["git", "commit", "pull-request"]
        ),

        .init(
            id: "pull-request", topicId: "tools",
            title: L10n(vi: "Pull request", en: "Pull request"),
            cardDefinition: L10n(
                vi: "Một **lời đề nghị gộp** một nhánh vào nhánh khác, mở ra để mọi người xem trước.",
                en: "A **proposal to merge** one branch into another, opened up for people to review first."
            ),
            whatItReallyMeans: L10n(
                vi: "Trước khi đặt phần mới vào bản chính, bạn mời đồng đội xem: *\"đây là thứ tôi vừa làm, ổn không?\"*. Họ góp ý, bạn sửa, máy chạy kiểm tra tự động — rồi mới gộp. Đó là một khoảnh khắc dừng lại có chủ đích để **bắt lỗi sớm**.",
                en: "Before placing the new work into the main copy, you invite teammates to look: *\"here's what I made — does it look right?\"*. They comment, you fix, automated checks run — then it merges. It's a deliberate pause to **catch problems early**."
            ),
            diagram: DiagramSpec(.timeline,
                [L10n(vi: "đề xuất", en: "propose"),
                 L10n(vi: "xem xét", en: "review"),
                 L10n(vi: "gộp", en: "merge")],
                accent: .teal),
            codeExample: nil,
            whenToUse: L10n(
                vi: "Trên **mọi đội nhóm**, và cả khi làm một mình nếu muốn một khoảnh khắc dừng trước khi gộp.",
                en: "On **any team**, and even solo when you want a moment of pause before merging."
            ),
            tags: [], related: ["branch", "git"]
        ),

        .init(
            id: "terminal", topicId: "tools",
            title: L10n(vi: "Terminal", en: "Terminal"),
            cardDefinition: L10n(
                vi: "Một cửa sổ nơi bạn **gõ lệnh chữ** và máy tính chạy chúng — không cần nút bấm.",
                en: "A window where you **type text commands** and the computer runs them — no buttons needed."
            ),
            whatItReallyMeans: L10n(
                vi: "Giao diện app bóng bẩy là bàn lễ tân; terminal là đi thẳng vào trong. Kém màu mè hơn, nhưng bạn ra lệnh trực tiếp, viết kịch bản để máy làm hàng loạt, và làm những việc lặp đi lặp lại nhanh hơn nhiều so với click chuột.",
                en: "The pretty app UI is the front desk; the terminal is walking straight into the back. Less flashy, but you give orders directly, write scripts to do things in bulk, and run repetitive tasks far faster than clicking."
            ),
            diagram: nil,
            codeExample: "ls          # list files here\ncd projects # go into projects/\npwd         # where am I?",
            whenToUse: L10n(
                vi: "Cho việc **lặp lại, viết được kịch bản, hoặc nằm sâu quá để click** — chạy build, di chuyển nhiều file, nói chuyện với git.",
                en: "For anything **repetitive, scriptable, or buried too deep to click** — running builds, moving many files, talking to git."
            ),
            tags: [], related: ["git", "package-manager"]
        ),

        .init(
            id: "package-manager", topicId: "tools",
            title: L10n(vi: "Trình quản lý gói (Package manager)", en: "Package manager"),
            cardDefinition: L10n(
                vi: "Công cụ **tải và cập nhật** các thư viện của người khác mà dự án bạn cần dùng.",
                en: "A tool that **downloads and updates** the other people's libraries your project relies on."
            ),
            whatItReallyMeans: L10n(
                vi: "Cần một tính năng có sẵn? Thay vì tự viết lại, bạn *đặt* nó từ một kho online bằng một lệnh. Trình quản lý gói tải nó về, kéo theo những thứ nó cần, và ghi sổ đúng phiên bản — nên người khác mở dự án của bạn sẽ nhận lại y hệt bộ thư viện đó.",
                en: "Need a ready-made feature? Instead of rewriting it, you *order* it from an online catalog with one command. The package manager downloads it, pulls in whatever it depends on, and records the exact versions — so anyone else who opens your project gets the very same set of libraries."
            ),
            diagram: nil,
            codeExample: "npm install react      # JavaScript\nbrew install ffmpeg    # macOS apps\nswift package add ...  # Swift",
            whenToUse: L10n(
                vi: "Trên **bất kỳ dự án nào** lớn hơn một file. An toàn hơn nhiều so với chép thư viện bằng tay.",
                en: "On **any project** beyond a single file. Far safer than copying library files by hand."
            ),
            tags: [], related: ["terminal"]
        ),
    ]
}
