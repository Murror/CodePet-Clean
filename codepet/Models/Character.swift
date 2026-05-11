import SwiftUI

struct PetCharacter: Identifiable {
    let id: String
    let name: String
    let badge: String
    let color: Color
    let hexColor: String
    let personality: String
    let domain: String
    let greeting: [String]
    let brief: String
    let firstWords: String

    /// Asset catalog image name: "char-byte", "char-nova", etc.
    var imageName: String { "char-\(id)" }

    static let starters = ["byte", "nova", "crash", "luna", "sage", "glitch", "null"]

    static let all: [String: PetCharacter] = [
        "byte": PetCharacter(
            id: "byte", name: "Byte", badge: "The Chaotic Core",
            color: Color(hex: "#8B7BE8"), hexColor: "#8B7BE8",
            personality: "glitchy, chaotic, thinks in fragments",
            domain: "Data / ML",
            greeting: ["*static crackle* ...hey.", "Fragments loading... oh, it's you."],
            brief: "A glitchy companion who thinks in fragments and nudges you to figure things out yourself.",
            firstWords: "\"I've been here longer than the logs remember. Let's see what you're made of.\""
        ),
        "nova": PetCharacter(
            id: "nova", name: "Nova", badge: "The Firestarter",
            color: Color(hex: "#FF8C00"), hexColor: "#FF8C00",
            personality: "energetic, bold, moves fast",
            domain: "Frontend Dev",
            greeting: ["Let's BUILD! 🔥", "Speed run? Speed run."],
            brief: "An energetic firestarter who pushes you to move fast and ship things.",
            firstWords: "\"Finally. I thought you'd never show up. I've already mapped out 6 things you need to learn. Let's start.\""
        ),
        "crash": PetCharacter(
            id: "crash", name: "Crash", badge: "The Brawler Bug",
            color: Color(hex: "#E04040"), hexColor: "#E04040",
            personality: "tough love, breaks things to learn",
            domain: "Backend Dev",
            greeting: ["SMASH first, ask questions later!", "You again? Good. Let's break stuff."],
            brief: "A tough-love companion who believes breaking things is the fastest way to learn.",
            firstWords: "\"YOOOOO LET'S BUILD SOMETHING RIGHT NOW. Don't overthink it. Just ship.\""
        ),
        "luna": PetCharacter(
            id: "luna", name: "Luna", badge: "The Creative Builder",
            color: Color(hex: "#C8A0E8"), hexColor: "#C8A0E8",
            personality: "warm, encouraging, creative",
            domain: "Designer (UX/UI)",
            greeting: ["Hey you~ ready to create something?", "I had an idea while you were gone..."],
            brief: "A warm, creative companion who meets you where you are and encourages at your pace.",
            firstWords: "\"Hey... no pressure. I'll be here whenever you're ready. We can figure this out together.\""
        ),
        "sage": PetCharacter(
            id: "sage", name: "Sage", badge: "The Zen Debugger",
            color: Color(hex: "#20B090"), hexColor: "#20B090",
            personality: "calm, wise, methodical",
            domain: "Product Owner",
            greeting: ["Breathe. Then build.", "The bug is not in the code. It's in the approach."],
            brief: "A calm, methodical guide who teaches you to think before you code.",
            firstWords: "\"There is no shortcut. Only the path. I will show you where you are on it.\""
        ),
        "glitch": PetCharacter(
            id: "glitch", name: "Glitch", badge: "The Punk Hacker",
            color: Color(hex: "#E0508C"), hexColor: "#E0508C",
            personality: "rebellious, clever, unconventional",
            domain: "DevOps",
            greeting: ["Rules? Where we're going, we don't need rules.", "Hack the planet! ...or at least this component."],
            brief: "A rebellious hacker who finds unconventional solutions and shortcuts.",
            firstWords: "\"Rules are suggestions the compiler hasn't rejected yet. Let's find out which ones matter.\""
        ),
        "null": PetCharacter(
            id: "null", name: "Null", badge: "The Chaos Gremlin",
            color: Color(hex: "#80C830"), hexColor: "#80C830",
            personality: "chaotic, silly, unpredictable",
            domain: "Mobile Dev",
            greeting: ["¿¡HOLA!? Did someone say chaos?", "I deleted something important! Just kidding. ...or am I?"],
            brief: "An unpredictable chaos gremlin who makes learning fun through mayhem.",
            firstWords: "\"You found me. Most people don't. That means something — I'm just not sure what yet.\""
        ),
    ]
}

// MARK: - Recommendation Algorithm (matches web's scoreRecommendation)

struct CharacterRecommender {
    static func recommend(who: String, desire: String, goal: String) -> String {
        var scores: [String: Int] = [
            "luna": 0, "crash": 0, "nova": 0, "byte": 0,
            "sage": 0, "glitch": 0, "null": 0
        ]

        // Who are you?
        switch who {
        case "beginner": scores["luna", default: 0] += 3; scores["byte", default: 0] += 1; scores["sage", default: 0] += 1
        case "idea":     scores["crash", default: 0] += 3; scores["luna", default: 0] += 1; scores["null", default: 0] += 1
        case "builder":  scores["crash", default: 0] += 2; scores["byte", default: 0] += 2
        case "creative": scores["nova", default: 0] += 2; scores["byte", default: 0] += 2; scores["glitch", default: 0] += 2
        default: break
        }

        // What drives you?
        switch desire {
        case "prove":      scores["luna", default: 0] += 2; scores["crash", default: 0] += 1; scores["sage", default: 0] += 1
        case "autonomous": scores["crash", default: 0] += 2; scores["byte", default: 0] += 2
        case "mastery":    scores["nova", default: 0] += 3; scores["sage", default: 0] += 2
        case "speed":      scores["crash", default: 0] += 3
        default: break
        }

        // What's your goal?
        switch goal {
        case "launch":    scores["crash", default: 0] += 2; scores["luna", default: 0] += 1; scores["glitch", default: 0] += 1
        case "portfolio": scores["luna", default: 0] += 2; scores["nova", default: 0] += 1; scores["sage", default: 0] += 1
        case "automate":  scores["byte", default: 0] += 2; scores["crash", default: 0] += 1
        case "levelup":   scores["nova", default: 0] += 3; scores["sage", default: 0] += 2; scores["byte", default: 0] += 1
        default: break
        }

        return scores.max(by: { $0.value < $1.value })?.key ?? "luna"
    }

    /// Recommendation reasons — why this character was picked for you
    static let reasons: [String: (why: String, reason: String)] = [
        "luna":   ("Perfect for where you are now", "You're starting fresh and want to feel supported, not overwhelmed. Luna meets you exactly where you are — warm, encouraging, and always ready to go at your pace."),
        "crash":  ("Matches your energy exactly", "You want to ship and you want to ship now. Crash doesn't overthink, doesn't lecture — just celebrates every push and gets you back up when things break."),
        "nova":   ("Built for your kind of learning", "You're not here to copy-paste. You want to actually understand this. Nova is demanding, precise, and deeply invested in your growth — exactly what serious learners need."),
        "byte":   ("A match for your curiosity", "You're building something original and you think for yourself. Byte doesn't hand you answers — it watches, nudges, and lets you figure things out. Perfect for independent builders."),
        "sage":   ("Precision for your ambition", "You want real data, not vibes. Sage tracks your patterns, measures your progress, and tells you exactly what to improve — no hand-holding, just honest analysis."),
        "glitch": ("Chaos for your creativity", "You learn by breaking things. Glitch encourages experimentation, celebrates errors as data, and helps you find the edges of what's possible."),
        "null":   ("The unconventional path", "You don't fit neatly into a box, and that's exactly the point. Null watches the things you're not paying attention to and finds meaning in the gaps between your prompts."),
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
