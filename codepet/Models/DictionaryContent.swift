import Foundation

struct DictionaryTopic: Identifiable, Hashable {
    let id: String        // slug
    let title: String
    let icon: String      // SF Symbol
}

struct DictionaryTerm: Identifiable, Hashable {
    let id: String                // slug
    let topicId: String
    let title: String
    let shortDefinition: String
    let analogy: String
    let codeExample: String?
    let whenToUse: String?
}

enum DictionaryContent {

    static let topics: [DictionaryTopic] = [
        .init(id: "variables",    title: "Variables & Types", icon: "shippingbox.fill"),
        .init(id: "functions",    title: "Functions",         icon: "function"),
        .init(id: "control-flow", title: "Control Flow",      icon: "arrow.triangle.branch"),
        .init(id: "tools",        title: "Tools",             icon: "wrench.and.screwdriver.fill"),
        .init(id: "web",          title: "Web Basics",        icon: "globe"),
    ]

    static let terms: [DictionaryTerm] = [

        // MARK: Variables & Types
        .init(
            id: "variable", topicId: "variables",
            title: "Variable",
            shortDefinition: "A named slot that holds a value your program can read and change later.",
            analogy: "Think of a labeled jar. You stick a sticky note on it that says \"score\", drop a number in, and later you can look inside or swap in a new number — the jar (name) stays, the contents change.",
            codeExample: "var score = 0\nscore = score + 10\n// score is now 10",
            whenToUse: "Use a variable any time a value will change while your program runs — counters, user input, the result of a calculation."
        ),
        .init(
            id: "constant", topicId: "variables",
            title: "Constant",
            shortDefinition: "A named value that, once set, cannot be changed.",
            analogy: "Like the freezing point of water. Once you've decided 0°C is freezing, you don't get to redefine it halfway through a recipe.",
            codeExample: "let maxAttempts = 3\n// maxAttempts = 4   // ✗ compiler error",
            whenToUse: "Reach for a constant first. Use a variable only when you actually need to reassign. Constants make code easier to reason about."
        ),
        .init(
            id: "string", topicId: "variables",
            title: "String",
            shortDefinition: "A piece of text — letters, digits, spaces, emoji, anything written.",
            analogy: "A string is a row of beads on a wire. Each bead is one character; the wire keeps them in order. You can read the row, count the beads, or stitch two strings together.",
            codeExample: "let greeting = \"hello\"\nlet name = \"Ada\"\nlet message = greeting + \", \" + name",
            whenToUse: nil
        ),
        .init(
            id: "number", topicId: "variables",
            title: "Number",
            shortDefinition: "A numeric value — whole numbers (integers) or with a decimal point (floats).",
            analogy: "Integers are like counting apples: 0, 1, 2, 3. Floats are like measuring with a ruler: 1.5 cm, 3.14 cm. Same idea, different precision.",
            codeExample: "let count: Int = 7\nlet price: Double = 9.99",
            whenToUse: nil
        ),
        .init(
            id: "boolean", topicId: "variables",
            title: "Boolean",
            shortDefinition: "A value that is either true or false. Nothing in between.",
            analogy: "A light switch. It's on or it's off — never half-on. Booleans answer yes/no questions in your code.",
            codeExample: "let isLoggedIn = true\nif isLoggedIn { /* show dashboard */ }",
            whenToUse: "Whenever your code needs to ask a yes/no question — \"is the user signed in?\", \"did the upload finish?\"."
        ),
        .init(
            id: "array", topicId: "variables",
            title: "Array",
            shortDefinition: "An ordered list of values, accessed by position.",
            analogy: "A row of numbered lockers. Locker 0, locker 1, locker 2. You hand a number to the array and it gives you what's inside that locker.",
            codeExample: "let colors = [\"red\", \"green\", \"blue\"]\nlet first = colors[0]   // \"red\"",
            whenToUse: "When you have a collection of similar things and order matters — a queue of messages, a list of tasks."
        ),

        // MARK: Functions
        .init(
            id: "function", topicId: "functions",
            title: "Function",
            shortDefinition: "A reusable block of code with a name. You \"call\" it to run that block.",
            analogy: "A recipe in a cookbook. The recipe is the function; cooking from it is calling it. You can follow the same recipe a hundred times to get the same dish.",
            codeExample: "func greet(name: String) {\n    print(\"Hello, \\(name)\")\n}\ngreet(name: \"Ada\")",
            whenToUse: "Whenever you find yourself writing similar code in more than one place. Wrap it in a function and call it from both."
        ),
        .init(
            id: "parameter", topicId: "functions",
            title: "Parameter",
            shortDefinition: "An input a function accepts so it can work with different values each call.",
            analogy: "A coffee machine has a \"strength\" knob. The machine is the function; the knob position is a parameter. Same machine, different output depending on the knob.",
            codeExample: "func double(_ x: Int) -> Int {\n    return x * 2\n}\ndouble(3)   // 6\ndouble(7)   // 14",
            whenToUse: nil
        ),
        .init(
            id: "return-value", topicId: "functions",
            title: "Return value",
            shortDefinition: "The result a function hands back after it finishes running.",
            analogy: "You hand the librarian a request slip; they hand you back a book. The book is the return value of their \"fetch\" function.",
            codeExample: "func square(_ n: Int) -> Int {\n    return n * n\n}\nlet result = square(5)   // 25",
            whenToUse: "When the caller needs the result of the work — calculate something, transform input, look up a value."
        ),
        .init(
            id: "pure-function", topicId: "functions",
            title: "Pure function",
            shortDefinition: "A function whose output depends only on its inputs, with no other effect on the world.",
            analogy: "A vending machine that always gives you a Coke when you press B4. Same button, same Coke, every time. It doesn't tweet about it, doesn't change the temperature of the room — it just hands over the Coke.",
            codeExample: "func add(_ a: Int, _ b: Int) -> Int {\n    return a + b\n}\n// add(2, 3) is always 5, no surprises",
            whenToUse: "Lean toward pure functions for the core logic of your app. They're the easiest pieces to test and the easiest to reason about."
        ),
        .init(
            id: "side-effect", topicId: "functions",
            title: "Side effect",
            shortDefinition: "Anything a function does beyond returning a value — writing to disk, printing, changing a variable elsewhere.",
            analogy: "You asked the dishwasher to wash dishes (the job you wanted). On the way, it also splashed water on the floor (the side effect). The splash wasn't the goal but it happened.",
            codeExample: "var total = 0\nfunc add(_ n: Int) {\n    total += n   // side effect: changes total\n}",
            whenToUse: "Side effects are unavoidable (saving files, talking to servers). The skill is keeping them isolated — most of your code stays pure, a thin layer handles effects."
        ),
        .init(
            id: "callback", topicId: "functions",
            title: "Callback",
            shortDefinition: "A function you pass to another function, to be called later when something is ready.",
            analogy: "You order takeout and leave your phone number. The restaurant doesn't make you wait at the counter — they ring you when it's ready. Your phone number is the callback.",
            codeExample: "func fetchUser(then callback: (String) -> Void) {\n    // ...later...\n    callback(\"Ada\")\n}",
            whenToUse: "When some work takes time (network, disk, timers) and you don't want to block waiting — hand over a callback and move on."
        ),

        // MARK: Control Flow
        .init(
            id: "if-else", topicId: "control-flow",
            title: "If / else",
            shortDefinition: "A branch in your code: do one thing if a condition is true, another if it's false.",
            analogy: "A road sign at a fork: \"if it's raining, take the covered route; else take the scenic one.\" Your program reads the sign and picks a path.",
            codeExample: "if score >= 100 {\n    print(\"You win!\")\n} else {\n    print(\"Try again\")\n}",
            whenToUse: nil
        ),
        .init(
            id: "loop", topicId: "control-flow",
            title: "Loop",
            shortDefinition: "A block of code that runs over and over until you tell it to stop.",
            analogy: "A washing machine cycle. \"Tumble, rinse, repeat until the timer hits zero.\" The loop is the cycle; the timer is the stop condition.",
            codeExample: "for i in 1...3 {\n    print(\"Round \\(i)\")\n}\n// Round 1\n// Round 2\n// Round 3",
            whenToUse: "Any time you'd otherwise copy-paste similar code three or more times — let the loop do the repeating."
        ),
        .init(
            id: "iteration", topicId: "control-flow",
            title: "Iteration",
            shortDefinition: "One pass through a loop, or the act of going through a collection one item at a time.",
            analogy: "Reading a book page by page. Each turn of a page is one iteration. By the end you've iterated over all the pages.",
            codeExample: "for color in [\"red\", \"green\", \"blue\"] {\n    print(color)   // one iteration per color\n}",
            whenToUse: nil
        ),
        .init(
            id: "recursion", topicId: "control-flow",
            title: "Recursion",
            shortDefinition: "A function that solves a problem by calling itself on a smaller piece of the same problem.",
            analogy: "Russian nesting dolls. To count them, you open the outer doll and ask the same question of the smaller doll inside — until you reach a doll that doesn't open.",
            codeExample: "func factorial(_ n: Int) -> Int {\n    if n <= 1 { return 1 }\n    return n * factorial(n - 1)\n}",
            whenToUse: "When a problem breaks naturally into smaller versions of itself — tree walks, nested data, certain math puzzles."
        ),
        .init(
            id: "conditional", topicId: "control-flow",
            title: "Conditional",
            shortDefinition: "An expression that evaluates to true or false — the question an if-statement asks.",
            analogy: "The question on a quiz: \"Is the answer greater than 10?\" The answer (yes/no) decides what happens next.",
            codeExample: "let isAdult = age >= 18\nif isAdult { /* show full content */ }",
            whenToUse: nil
        ),
        .init(
            id: "break-continue", topicId: "control-flow",
            title: "Break / Continue",
            shortDefinition: "Two ways to change how a loop runs: stop entirely (break) or skip to the next iteration (continue).",
            analogy: "You're sorting a pile of mail. `continue` is throwing one envelope into recycling and reaching for the next. `break` is putting the whole pile down because you spotted what you were looking for.",
            codeExample: "for n in 1...10 {\n    if n == 5 { break }     // stop the loop\n    if n % 2 == 0 { continue } // skip evens\n    print(n)   // 1, 3\n}",
            whenToUse: "Inside loops, when a specific condition means \"we're done\" (break) or \"this one doesn't matter\" (continue)."
        ),

        // MARK: Tools
        .init(
            id: "git", topicId: "tools",
            title: "Git",
            shortDefinition: "A tool that tracks every change you make to your code, so you can review, undo, or share work.",
            analogy: "A time machine with a notebook. Every save is a labeled snapshot of your project; you can walk back to any snapshot, or look at what changed between two.",
            codeExample: nil,
            whenToUse: "On every project, from day one. Even solo work — git is your safety net when an experiment goes sideways."
        ),
        .init(
            id: "commit", topicId: "tools",
            title: "Commit",
            shortDefinition: "One saved snapshot in git, with a message describing what you changed.",
            analogy: "A diary entry, but for code. Each entry is dated, signed, and titled — \"Fixed the login bug.\" Together, the entries tell the story of how the project grew.",
            codeExample: "git add file.swift\ngit commit -m \"Add greeting view\"",
            whenToUse: "Commit early, commit often. Small, focused commits are easier to read and easier to roll back than one giant \"misc changes\"."
        ),
        .init(
            id: "branch", topicId: "tools",
            title: "Branch",
            shortDefinition: "A parallel version of your project where you can work without disturbing the main code.",
            analogy: "A river that splits into two channels for a while, then rejoins downstream. You can paddle around in your channel experimenting; the main flow keeps moving without you.",
            codeExample: "git checkout -b new-feature\n// ... work, commit ...\ngit checkout main\ngit merge new-feature",
            whenToUse: "For any non-trivial change — a feature, a bugfix, an experiment. Keep `main` clean; let branches hold work-in-progress."
        ),
        .init(
            id: "pull-request", topicId: "tools",
            title: "Pull request",
            shortDefinition: "A proposal to merge one branch into another, opened on a platform like GitHub for review.",
            analogy: "Submitting a change for your editor to review before it goes into the magazine. \"Here's what I want to add — what do you think?\"",
            codeExample: nil,
            whenToUse: "On any team, and even solo when you want a moment of pause before merging. PRs invite review, run automated checks, and document why a change happened."
        ),
        .init(
            id: "terminal", topicId: "tools",
            title: "Terminal",
            shortDefinition: "A text window where you type commands and the computer runs them, no buttons involved.",
            analogy: "A direct phone line to your computer. Less polished than the visual app, but you can ask for anything — and scripts can call too.",
            codeExample: "ls          # list files in current folder\ncd projects # move into the projects folder\npwd         # where am I?",
            whenToUse: "For anything repetitive, scriptable, or buried too deep for a click — running builds, moving lots of files, talking to git or package managers."
        ),
        .init(
            id: "package-manager", topicId: "tools",
            title: "Package manager",
            shortDefinition: "A tool that downloads, installs, and updates third-party libraries your project depends on.",
            analogy: "An app store for code. You write \"I want Library X version 2.1\" in a file; the package manager fetches it and keeps track of every other library it needs to work.",
            codeExample: "npm install react      # JavaScript\nbrew install ffmpeg    # macOS apps\nswift package add ...  # Swift",
            whenToUse: "On any project beyond a single file. Letting a package manager handle dependencies is far safer than copying library files by hand."
        ),

        // MARK: Web Basics
        .init(
            id: "html", topicId: "web",
            title: "HTML",
            shortDefinition: "The language that describes the structure of a web page — headings, paragraphs, lists, buttons.",
            analogy: "The bones of a building. HTML says \"here's the lobby, here's the staircase, here's a row of windows.\" It's structure, not paint.",
            codeExample: "<h1>Hello</h1>\n<p>Welcome to my page.</p>\n<button>Click me</button>",
            whenToUse: nil
        ),
        .init(
            id: "css", topicId: "web",
            title: "CSS",
            shortDefinition: "The language that styles a web page — colors, fonts, spacing, layout.",
            analogy: "The paint, wallpaper, and furniture for HTML's bones. The structure is the same; CSS decides what it looks like.",
            codeExample: "h1 {\n    color: purple;\n    font-size: 32px;\n}",
            whenToUse: nil
        ),
        .init(
            id: "http", topicId: "web",
            title: "HTTP",
            shortDefinition: "The protocol browsers and servers use to ask for and deliver web pages and data.",
            analogy: "An envelope-based postal service for the web. The browser sends a request envelope (\"please send me /home\"), the server sends a reply envelope back (\"here's the page\").",
            codeExample: "GET /api/users/42 HTTP/1.1\nHost: example.com\n\n200 OK\nContent-Type: application/json\n{ \"name\": \"Ada\" }",
            whenToUse: nil
        ),
        .init(
            id: "api", topicId: "web",
            title: "API",
            shortDefinition: "A defined way for one program to ask another program for data or actions.",
            analogy: "The drive-through speaker at a fast-food place. You can't walk into the kitchen, but the menu and the speaker tell you exactly what you can order and how to ask.",
            codeExample: "// Client → API\nGET https://api.weather.com/today?city=Hanoi\n\n// API → Client\n{ \"temp\": 31, \"sky\": \"clear\" }",
            whenToUse: "Whenever two programs need to talk. Your app calls the weather company's API; the weather company calls a satellite's API; turtles all the way down."
        ),
        .init(
            id: "json", topicId: "web",
            title: "JSON",
            shortDefinition: "A simple text format for structured data — used everywhere on the web.",
            analogy: "A standardized form, like a passport. Anyone, anywhere, can read it because the layout is agreed in advance. Names, lists, numbers, nested groups — all on the page in the same shape.",
            codeExample: "{\n  \"name\": \"Ada\",\n  \"age\": 36,\n  \"skills\": [\"math\", \"coding\"]\n}",
            whenToUse: "For most data exchanged between client and server. JSON is readable by humans and parseable by every modern language out of the box."
        ),
        .init(
            id: "frontend-backend", topicId: "web",
            title: "Frontend vs Backend",
            shortDefinition: "Frontend is what the user sees and clicks; backend is what runs on a server and handles data.",
            analogy: "A restaurant. The dining room (frontend) is where guests sit and order. The kitchen (backend) is where the cooking and storage happens. Waiters carry messages between them.",
            codeExample: nil,
            whenToUse: "Useful framing on any web or app project. Clear backend/frontend boundaries let two people work in parallel without stepping on each other."
        ),
    ]

    static func terms(in topicId: String) -> [DictionaryTerm] {
        terms.filter { $0.topicId == topicId }
    }

    static func search(_ query: String) -> [DictionaryTerm] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return terms }
        return terms.filter {
            $0.title.lowercased().contains(q)
                || $0.shortDefinition.lowercased().contains(q)
        }
    }
}
