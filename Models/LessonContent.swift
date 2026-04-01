import SwiftUI

// MARK: - Lesson Data Model

struct Lesson: Identifiable, Equatable {
    let id: String          // matches Skill.id
    let skillName: String
    let teacher: String     // character id ("nova", "crash", etc.)
    let duration: String    // "3 min", "5 min"
    let steps: [LessonStep]

    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id
    }
}

enum LessonStepType {
    case briefing
    case learn
    case applyIt       // multiple-choice quiz
    case fieldMission  // scenario-based quiz
    case summary
}

struct LessonStep: Identifiable {
    let id = UUID()
    let type: LessonStepType
    let title: String
    let content: LessonStepContent
}

struct QuizOption: Identifiable {
    let id: String      // "a", "b", "c", "d"
    let text: String
    let correct: Bool
}

enum LessonStepContent {
    case briefing(characterIntro: String, bodyText: String, hook: String)
    case learn(concept: String, coreExplanation: String, badExample: ExamplePair?, goodExample: ExamplePair?, insight: String)
    case applyIt(instruction: String, originalPrompt: String, options: [QuizOption], correctFeedback: String, wrongFeedback: String)
    case fieldMission(scenario: String, task: String, options: [QuizOption], correctFeedback: String, wrongFeedback: String)
    case summary(recap: [String], xpReward: Int, badge: String?)
}

struct ExamplePair {
    let label: String
    let text: String
}

// MARK: - All Lessons

struct LessonLibrary {

    static let all: [String: Lesson] = [

        // ═══════════════════════════════════════
        // TIER 1 — Foundations / The Molten Forge
        // ═══════════════════════════════════════

        "prompt-clarity": Lesson(
            id: "prompt-clarity",
            skillName: "Prompt Clarity",
            teacher: "nova",
            duration: "3 min",
            steps: [
                LessonStep(type: .briefing, title: "Why Prompts Matter", content: .briefing(
                    characterIntro: "Hey, I'm Nova. Most people talk to AI like they're texting a friend — vague, messy, hoping it reads their mind. That's why you get random stuff back. Today I'll show you the difference between a lazy prompt and a clear one.",
                    bodyText: "Every time you ask AI to build something, the quality of what you get back depends almost entirely on how you asked. A vague prompt gives you a generic result. A specific prompt gives you exactly what you need.",
                    hook: "After this lesson, your prompts will work on the first try — not the fifth."
                )),
                LessonStep(type: .learn, title: "The 3 Parts of a Clear Prompt", content: .learn(
                    concept: "CORE CONCEPT",
                    coreExplanation: "Every good prompt has 3 parts: CONTEXT (what tech you're using), TASK (what you want built), and CONSTRAINTS (what to avoid or include).",
                    badExample: ExamplePair(label: "VAGUE PROMPT", text: "Make me a button"),
                    goodExample: ExamplePair(label: "CLEAR PROMPT", text: "Using React and Tailwind CSS, create a primary action button component with hover and disabled states. Use rounded-lg, bg-blue-600, and text-white. Include an onClick prop."),
                    insight: "See the difference? The good prompt tells AI exactly what framework, what styles, and what behavior to include. No guessing needed."
                )),
                LessonStep(type: .applyIt, title: "Fix This Prompt", content: .applyIt(
                    instruction: "This prompt is too vague. Pick the version that adds the right details.",
                    originalPrompt: "Add a login form to my page",
                    options: [
                        QuizOption(id: "a", text: "Add a really good login form with nice styling to my website page please", correct: false),
                        QuizOption(id: "b", text: "I need a login form. Make it look modern and professional. Add some animations too.", correct: false),
                        QuizOption(id: "c", text: "Using Next.js and Tailwind, add a login form to app/login/page.tsx with email and password fields, a submit button, and client-side validation. Use the existing color tokens from globals.css.", correct: true),
                        QuizOption(id: "d", text: "Create login form with React", correct: false),
                    ],
                    correctFeedback: "Exactly! You specified the framework (Next.js + Tailwind), the file location, the fields, and even referenced existing styles. That's a prompt that works on the first try.",
                    wrongFeedback: "Not quite. That prompt is still missing key details — what framework? What file? What fields? The AI will have to guess, and it'll guess wrong."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "Your friend wants to build a personal portfolio site. They're using React with CSS modules. They need a hero section with their name, title, and a call-to-action button.",
                    task: "Which prompt would you give to the AI?",
                    options: [
                        QuizOption(id: "a", text: "Build a hero section for a portfolio", correct: false),
                        QuizOption(id: "b", text: "In my React portfolio project using CSS modules, create a Hero component in src/components/Hero.jsx. It should display a name (h1), job title (h2), and a 'View My Work' button that scrolls to the projects section. Use the existing color variables from styles/variables.module.css.", correct: true),
                        QuizOption(id: "c", text: "Make a beautiful hero section with animations and gradients for a portfolio website", correct: false),
                    ],
                    correctFeedback: "Perfect! You nailed all three parts — context (React + CSS modules), task (Hero component with specific elements), and constraints (existing color variables). Nova would be proud.",
                    wrongFeedback: "Almost! Remember the 3 parts: Context (what tech), Task (what specifically to build), Constraints (what to use/avoid). Try to include all three."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Always include Context, Task, and Constraints", "Be specific about tech, styles, and behavior", "The clearer you are, the fewer retries you need"],
                    xpReward: 25,
                    badge: "Prompt Apprentice"
                ))
            ]
        ),

        "error-reading": Lesson(
            id: "error-reading",
            skillName: "Error Reading",
            teacher: "crash",
            duration: "4 min",
            steps: [
                LessonStep(type: .briefing, title: "Errors Are Clues", content: .briefing(
                    characterIntro: "SMASH! Oh hey. I'm Crash. Most people see an error and panic. But errors are just the computer telling you exactly what went wrong. Today you'll learn to read them like a detective.",
                    bodyText: "Error messages have a structure: the TYPE tells you what category of problem, the MESSAGE tells you what happened, and the LOCATION tells you where.",
                    hook: "After this, you'll never just paste an error and say 'fix it' again."
                )),
                LessonStep(type: .learn, title: "Anatomy of an Error", content: .learn(
                    concept: "READING ERRORS",
                    coreExplanation: "Every error has 3 parts: TYPE (SyntaxError, TypeError, etc.), MESSAGE (what went wrong), and STACK TRACE (where it happened). Read bottom-to-top for the root cause.",
                    badExample: ExamplePair(label: "PANIC MODE", text: "\"I got an error, can you fix my code?\""),
                    goodExample: ExamplePair(label: "DETECTIVE MODE", text: "\"I got a TypeError: Cannot read property 'map' of undefined on line 42 of ProductList.jsx. The data array might not be loaded yet.\""),
                    insight: "When you describe the error clearly, AI can solve it in one shot instead of asking 5 follow-up questions."
                )),
                LessonStep(type: .applyIt, title: "Read This Error", content: .applyIt(
                    instruction: "Look at this error and pick what's actually wrong:",
                    originalPrompt: "Module not found: Can't resolve './components/Header' in '/src/pages'",
                    options: [
                        QuizOption(id: "a", text: "The Header component has a bug in its code", correct: false),
                        QuizOption(id: "b", text: "The file path './components/Header' doesn't exist from the /src/pages folder", correct: true),
                        QuizOption(id: "c", text: "React is not installed properly", correct: false),
                        QuizOption(id: "d", text: "The project needs to be rebuilt from scratch", correct: false),
                    ],
                    correctFeedback: "You got it! 'Module not found' + 'Can't resolve' = the file path is wrong. The fix is either: move the file, or fix the import path. No need to rebuild anything.",
                    wrongFeedback: "Look again at the key words: 'Module not found' and 'Can't resolve'. This isn't about broken code — it's about a wrong file path. The file simply doesn't exist where the import says it should."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "You're building a to-do app and you see this error:\nTypeError: todos.filter is not a function\n    at TodoList (src/TodoList.jsx:8:24)",
                    task: "What would you do?",
                    options: [
                        QuizOption(id: "a", text: "Check line 8 of TodoList.jsx — 'todos' is probably not an array. Add console.log(typeof todos) to verify, then ensure it's initialized as an array.", correct: true),
                        QuizOption(id: "b", text: "Delete TodoList.jsx and ask AI to rewrite it", correct: false),
                        QuizOption(id: "c", text: "Install a different todo library", correct: false),
                    ],
                    correctFeedback: "Exactly! 'not a function' means you're calling .filter() on something that isn't an array. Check the type, find where it's set, fix the initialization. Clean debugging!",
                    wrongFeedback: "Think about what 'not a function' means — .filter() only works on arrays. So 'todos' isn't an array. You need to find out why and fix it at the source."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Read errors bottom-to-top for root cause", "Identify Type, Message, and Location", "Include error details when asking AI for help"],
                    xpReward: 25,
                    badge: "Bug Spotter"
                ))
            ]
        ),

        "tool-basics": Lesson(
            id: "tool-basics",
            skillName: "Tool Basics",
            teacher: "sage",
            duration: "3 min",
            steps: [
                LessonStep(type: .briefing, title: "The Right Tool", content: .briefing(
                    characterIntro: "Breathe. Then build. I'm Sage. Today we discuss something fundamental — not all AI tools are the same, and using the wrong one wastes your time.",
                    bodyText: "ChatGPT, Claude, Cursor, v0, Copilot — each excels at different things. Knowing which to reach for is itself a skill.",
                    hook: "After this lesson, you'll stop using a hammer when you need a screwdriver."
                )),
                LessonStep(type: .learn, title: "When to Use What", content: .learn(
                    concept: "TOOL SELECTION",
                    coreExplanation: "Chat AIs (ChatGPT, Claude) are best for planning, explaining, and brainstorming. Code AIs (Cursor, Copilot) are best for writing and editing code in context. Builder AIs (v0, Bolt) are best for generating full UI components quickly.",
                    badExample: ExamplePair(label: "WRONG TOOL", text: "Using ChatGPT to edit 50 files in your codebase"),
                    goodExample: ExamplePair(label: "RIGHT TOOL", text: "Using Cursor to edit files (it sees your whole project) and Claude to plan the architecture first"),
                    insight: "The best builders use 2-3 tools together. Plan in chat, build in code AI, generate UI in builders."
                )),
                LessonStep(type: .applyIt, title: "Match the Task", content: .applyIt(
                    instruction: "You need to plan the database schema for your new app. Which tool should you use?",
                    originalPrompt: "Plan a database schema for a recipe sharing app",
                    options: [
                        QuizOption(id: "a", text: "Cursor — open a new file and start typing table names", correct: false),
                        QuizOption(id: "b", text: "v0 by Vercel — generate a database UI", correct: false),
                        QuizOption(id: "c", text: "Claude or ChatGPT — brainstorm and plan the schema in a conversation", correct: true),
                        QuizOption(id: "d", text: "GitHub Copilot — let it autocomplete your schema", correct: false),
                    ],
                    correctFeedback: "Chat AIs are perfect for planning! They can discuss trade-offs, suggest schema designs, and help you think through relationships before you write any code.",
                    wrongFeedback: "Planning tasks are best done in conversation. Code editors are for writing code, not for brainstorming architecture decisions. Try a Chat AI first."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "You have a React project and need to: 1) Add a new feature across 5 files, 2) Generate a new landing page component, 3) Debug why a test is failing.",
                    task: "What's the best tool workflow?",
                    options: [
                        QuizOption(id: "a", text: "Use ChatGPT for everything — paste code back and forth", correct: false),
                        QuizOption(id: "b", text: "Use Cursor for the multi-file feature + debugging (it sees your project), and v0 for the landing page (quick UI generation)", correct: true),
                        QuizOption(id: "c", text: "Use v0 for everything — it can generate any code", correct: false),
                    ],
                    correctFeedback: "You're thinking like a pro! Cursor for context-heavy coding, v0 for quick UI generation. Using the right tool for each task saves hours.",
                    wrongFeedback: "Think about what each tool is best at. Multi-file edits need a tool that sees your whole project. UI generation needs a tool designed for that."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Chat AIs for planning and explaining", "Code AIs for writing and editing in context", "Builder AIs for rapid UI generation", "Combine tools for best results"],
                    xpReward: 25,
                    badge: "Tool Scout"
                ))
            ]
        ),

        "code-judgment": Lesson(
            id: "code-judgment",
            skillName: "Code Judgment",
            teacher: "glitch",
            duration: "4 min",
            steps: [
                LessonStep(type: .briefing, title: "Trust But Verify", content: .briefing(
                    characterIntro: "Rules? Where we're going, we don't need— actually wait, this one's important. I'm Glitch. AI writes code fast, but fast doesn't mean correct. You need to know when to trust it and when to say 'try again'.",
                    bodyText: "AI-generated code can look perfect but have subtle bugs, security holes, or bad patterns. Your job isn't to write every line — it's to be the quality inspector.",
                    hook: "After this, you'll spot the difference between code that works and code that's actually good."
                )),
                LessonStep(type: .learn, title: "Red Flags in AI Code", content: .learn(
                    concept: "CODE REVIEW",
                    coreExplanation: "Watch for: hardcoded values, missing error handling, no input validation, outdated patterns, and 'it works but I don't understand why' code. If you can't explain what code does, don't ship it.",
                    badExample: ExamplePair(label: "BLIND TRUST", text: "\"AI wrote it, ship it!\" → You just deployed a function that crashes on empty arrays."),
                    goodExample: ExamplePair(label: "SMART REVIEW", text: "\"This looks right, but what happens if the array is empty? Let me add a check.\" → You caught a bug before users did."),
                    insight: "The #1 rule: if AI generates code you don't understand, ask it to explain before you use it."
                )),
                LessonStep(type: .applyIt, title: "Spot the Issue", content: .applyIt(
                    instruction: "AI generated this function. What's the main problem?",
                    originalPrompt: "function getUser(id) {\n  const user = users.find(u => u.id === id);\n  return user.name;\n}",
                    options: [
                        QuizOption(id: "a", text: "The function name should be camelCase — it's fine otherwise", correct: false),
                        QuizOption(id: "b", text: "users.find() can return undefined if no match, so user.name will crash", correct: true),
                        QuizOption(id: "c", text: "It should use filter() instead of find()", correct: false),
                        QuizOption(id: "d", text: "The arrow function syntax is wrong", correct: false),
                    ],
                    correctFeedback: "Exactly! If no user matches the id, find() returns undefined. Then accessing .name on undefined throws a TypeError. The fix: add a null check or use optional chaining (user?.name).",
                    wrongFeedback: "Look at what happens when find() doesn't find a matching user — it returns undefined. Then what happens when you call .name on undefined?"
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "AI generated an API endpoint that fetches user data and returns it directly. There's no try/catch, no input validation, and no rate limiting.",
                    task: "What's the most critical issue to fix first?",
                    options: [
                        QuizOption(id: "a", text: "Add a try/catch for error handling — if the database call fails, the server crashes", correct: true),
                        QuizOption(id: "b", text: "Add rate limiting first — someone might abuse it", correct: false),
                        QuizOption(id: "c", text: "Add input validation — the user ID might be invalid", correct: false),
                    ],
                    correctFeedback: "Right! Error handling is the most critical. Without try/catch, a single failed database call can crash your entire server. Rate limiting and validation are important too, but crash prevention comes first.",
                    wrongFeedback: "All three are important, but think about what causes the worst outcome. A crashed server affects ALL users, not just one."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Never ship code you don't understand", "Check for edge cases and error handling", "Ask AI to explain unclear code", "You're the quality inspector, not just a copy-paster"],
                    xpReward: 25,
                    badge: "Code Judge"
                ))
            ]
        ),

        // ═══════════════════════════════════════
        // TIER 2 — Context & Structure / The Frozen Spire
        // ═══════════════════════════════════════

        "context-setting": Lesson(
            id: "context-setting",
            skillName: "Context Setting",
            teacher: "luna",
            duration: "4 min",
            steps: [
                LessonStep(type: .briefing, title: "Context Is Everything", content: .briefing(
                    characterIntro: "Hey you~ I'm Luna. Imagine someone walks up and says 'make it blue.' Blue what? Which shade? That's what it's like when you give AI a task without context.",
                    bodyText: "Context is the background information AI needs before it can help you well. Your tech stack, project structure, what you've already tried, and what you're building toward.",
                    hook: "After this, your AI conversations will feel like talking to a teammate who actually knows your project."
                )),
                LessonStep(type: .learn, title: "The Context Sandwich", content: .learn(
                    concept: "SETTING CONTEXT",
                    coreExplanation: "Start every AI conversation with a Context Block: PROJECT (what you're building), STACK (technologies), CURRENT STATE (what exists), and ASK (what you need next). This front-loading saves dozens of back-and-forth messages.",
                    badExample: ExamplePair(label: "NO CONTEXT", text: "Add a search bar to my app"),
                    goodExample: ExamplePair(label: "WITH CONTEXT", text: "I'm building a recipe app with React and Supabase. I have a /recipes page that lists cards. Add a search bar above the grid that filters recipes by title in real-time. Use the existing RecipeCard component."),
                    insight: "A 30-second context block saves 10 minutes of 'what framework?' and 'where does this go?' questions."
                )),
                LessonStep(type: .applyIt, title: "Add the Context", content: .applyIt(
                    instruction: "Someone wrote this prompt. Which version adds proper context?",
                    originalPrompt: "Fix the login bug",
                    options: [
                        QuizOption(id: "a", text: "Fix the login bug please, it's broken", correct: false),
                        QuizOption(id: "b", text: "In my Next.js app using NextAuth, the login form submits but redirects to /api/auth/error instead of /dashboard. I'm using the Credentials provider with a PostgreSQL database. The console shows 'Invalid callback URL'. My next-auth config is in app/api/auth/[...nextauth]/route.ts.", correct: true),
                        QuizOption(id: "c", text: "My login doesn't work. I'm using React. Can you fix it?", correct: false),
                    ],
                    correctFeedback: "Perfect! You included the framework, the exact error behavior, the auth setup, and the file location. AI can pinpoint the issue immediately.",
                    wrongFeedback: "A good context includes: what framework, what specific behavior you see, what you expected, and where the relevant code lives."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "You're starting a new AI chat session to add a dark mode toggle to your app. You're using React, Tailwind, and a ThemeContext that already exists in src/context/ThemeContext.tsx.",
                    task: "What's the best way to start the conversation?",
                    options: [
                        QuizOption(id: "a", text: "Add dark mode to my app", correct: false),
                        QuizOption(id: "b", text: "I need a dark mode toggle. My app uses React + Tailwind. I already have a ThemeContext in src/context/ThemeContext.tsx that provides isDark and toggleTheme. Add a toggle button to the existing Navbar component in src/components/Navbar.tsx that uses this context.", correct: true),
                        QuizOption(id: "c", text: "Can you help me with dark mode? I use Tailwind CSS.", correct: false),
                    ],
                    correctFeedback: "Excellent! By mentioning the existing ThemeContext and exact file paths, AI will use what you already have instead of creating something new from scratch.",
                    wrongFeedback: "When you have existing code, tell AI about it! Otherwise it might create a whole new theme system instead of using what you already built."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Always start with a Context Block", "Include: Project, Stack, State, Ask", "30 seconds of context saves 10 minutes of back-and-forth"],
                    xpReward: 30,
                    badge: "Context Crafter"
                ))
            ]
        ),

        "rules-files": Lesson(
            id: "rules-files",
            skillName: "AI Rules Files",
            teacher: "sage",
            duration: "4 min",
            steps: [
                LessonStep(type: .briefing, title: "Your AI Playbook", content: .briefing(
                    characterIntro: "Every time you start a new AI session, you re-explain your conventions. What a waste. I'm Sage. Today I'll show you how to write rules once and have AI follow them forever.",
                    bodyText: "Rules files (.cursorrules, .clinerules, CLAUDE.md) are instructions that get automatically loaded into your AI tool. They tell AI your coding style, project conventions, and things to always/never do.",
                    hook: "After this, your AI will write code your way without being told twice."
                )),
                LessonStep(type: .learn, title: "Writing Good Rules", content: .learn(
                    concept: "AI RULES",
                    coreExplanation: "A good rules file has: STYLE (naming conventions, formatting), PATTERNS (how you structure components, handle errors), CONSTRAINTS (what to never use), and CONTEXT (project description, key files).",
                    badExample: ExamplePair(label: "NO RULES", text: "AI uses camelCase in your snake_case project, adds console.logs everywhere, and picks random libraries."),
                    goodExample: ExamplePair(label: "WITH RULES", text: "// .cursorrules\n- Use snake_case for variables\n- Never use console.log (use logger)\n- Always handle errors with try/catch\n- Components go in /src/components/"),
                    insight: "Your rules file is like onboarding a new developer. Write it once, and every AI session starts aligned with your project."
                )),
                LessonStep(type: .applyIt, title: "Pick the Best Rule", content: .applyIt(
                    instruction: "Which of these is the most useful rule for a .cursorrules file?",
                    originalPrompt: "Your project uses TypeScript strict mode and Tailwind CSS",
                    options: [
                        QuizOption(id: "a", text: "Write good code", correct: false),
                        QuizOption(id: "b", text: "Always use TypeScript strict mode. Never use 'any' type. Use Tailwind utility classes only — no inline styles or CSS files.", correct: true),
                        QuizOption(id: "c", text: "Make sure the code is nice and clean", correct: false),
                        QuizOption(id: "d", text: "Use best practices", correct: false),
                    ],
                    correctFeedback: "Specific rules work! 'Never use any type' and 'no inline styles' are concrete instructions AI can actually follow. Vague rules like 'write good code' mean nothing.",
                    wrongFeedback: "Rules need to be specific and actionable. AI can't interpret 'good code' — but it CAN follow 'never use any type' and 'use Tailwind only'."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "You notice AI keeps generating components with inline styles even though your project uses Tailwind. It also keeps adding console.log statements.",
                    task: "What rule would you add to prevent this?",
                    options: [
                        QuizOption(id: "a", text: "Please don't use inline styles or console.log if possible", correct: false),
                        QuizOption(id: "b", text: "NEVER use inline styles — use Tailwind utility classes exclusively. NEVER use console.log — use the logger utility from src/lib/logger.ts instead.", correct: true),
                        QuizOption(id: "c", text: "Use better styling practices", correct: false),
                    ],
                    correctFeedback: "Strong rules! Using 'NEVER' makes it absolute, and pointing to the logger utility gives AI a concrete alternative. This will actually change AI's behavior.",
                    wrongFeedback: "Rules need to be absolute and specific. 'If possible' gives AI wiggle room. Tell it exactly what NOT to do and what to do instead."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Rules files auto-load your conventions into AI", "Include: Style, Patterns, Constraints, Context", "Write once, benefit every session"],
                    xpReward: 30,
                    badge: "Rule Maker"
                ))
            ]
        ),

        "documentation": Lesson(
            id: "documentation",
            skillName: "Documentation",
            teacher: "luna",
            duration: "3 min",
            steps: [
                LessonStep(type: .briefing, title: "Docs That Work", content: .briefing(
                    characterIntro: "I had an idea while you were gone... what if your docs helped both you AND your AI? I'm Luna, and today we'll write documentation that makes AI smarter about your project.",
                    bodyText: "Good documentation isn't just for humans anymore. When AI can read your docs, it understands your project better and writes more accurate code.",
                    hook: "After this, your README will be a superpower — for you and your AI."
                )),
                LessonStep(type: .learn, title: "AI-Friendly Docs", content: .learn(
                    concept: "DOCUMENTATION",
                    coreExplanation: "Write docs that answer: What does this project do? How is it structured? What are the key conventions? What's the current state? AI tools read your README, comments, and doc files to understand context.",
                    badExample: ExamplePair(label: "USELESS README", text: "# My App\nA cool app.\n\n## Install\nnpm install"),
                    goodExample: ExamplePair(label: "AI-FRIENDLY README", text: "# RecipeApp\nA recipe sharing app (React + Supabase)\n\n## Structure\n/src/components - UI components\n/src/hooks - Custom hooks\n/src/lib - Supabase client, utils\n\n## Key Patterns\n- Server components by default\n- Client components marked with 'use client'"),
                    insight: "Your docs are context that loads automatically. The better they are, the better AI performs."
                )),
                LessonStep(type: .applyIt, title: "Documentation in Practice", content: .applyIt(
                    instruction: "Which README section would help AI the most when adding a new feature?",
                    originalPrompt: "You're asking AI to add a favorites feature to your recipe app",
                    options: [
                        QuizOption(id: "a", text: "A section listing the app's color palette", correct: false),
                        QuizOption(id: "b", text: "A section describing file structure and key patterns (where components go, how state is managed, naming conventions)", correct: true),
                        QuizOption(id: "c", text: "A section with the app's deployment instructions", correct: false),
                    ],
                    correctFeedback: "File structure and patterns! When AI knows where components go and how state works, it creates features that fit naturally into your existing codebase.",
                    wrongFeedback: "Think about what AI needs to know to add a feature: where to put files, how to structure components, and what patterns to follow."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "You have a README that just says '# TodoApp - A todo list app. npm start to run.' Every time you ask AI to add a feature, it creates files in the wrong places and uses different patterns.",
                    task: "What would you add to the README first?",
                    options: [
                        QuizOption(id: "a", text: "A fancy ASCII art logo and license section", correct: false),
                        QuizOption(id: "b", text: "A file structure section showing where components, hooks, and utilities live, plus key patterns like 'use Zustand for state' and 'components in PascalCase'", correct: true),
                        QuizOption(id: "c", text: "A list of every npm package installed", correct: false),
                    ],
                    correctFeedback: "That's exactly what AI needs! A file structure map and key patterns will immediately improve how AI generates code for your project.",
                    wrongFeedback: "Focus on what helps AI write correct code: where files go and what patterns to use. A package list or logo doesn't help with that."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Docs serve both humans and AI", "Include structure, stack, and patterns", "Better docs = better AI output"],
                    xpReward: 30,
                    badge: "Doc Writer"
                ))
            ]
        ),

        "file-structure": Lesson(
            id: "file-structure",
            skillName: "Project Structure",
            teacher: "sage",
            duration: "3 min",
            steps: [
                LessonStep(type: .briefing, title: "Organized = Powerful", content: .briefing(
                    characterIntro: "The bug is not in the code. It's in the structure. I'm Sage. If your project is a mess, AI will be confused too. Let's fix that.",
                    bodyText: "How you organize files directly affects how well AI can help you. A clear structure means AI finds the right files, understands relationships, and makes accurate changes.",
                    hook: "After this, your project will be navigable by both humans and AI."
                )),
                LessonStep(type: .learn, title: "Structure Patterns", content: .learn(
                    concept: "FILE ORGANIZATION",
                    coreExplanation: "Group by feature (not by type). Keep related files together. Use consistent naming. Have a clear entry point. AI tools like Cursor read your file tree to understand your project.",
                    badExample: ExamplePair(label: "MESSY STRUCTURE", text: "/components (30 random files)\n/utils (everything dumped here)\n/pages (mixed concerns)"),
                    goodExample: ExamplePair(label: "CLEAN STRUCTURE", text: "/features/auth (login, signup, hooks)\n/features/recipes (list, detail, hooks)\n/shared/ui (button, card, modal)\n/shared/lib (api, utils)"),
                    insight: "When AI sees /features/auth/useLogin.ts, it instantly knows what that file does and where related code lives."
                )),
                LessonStep(type: .applyIt, title: "Reorganize This", content: .applyIt(
                    instruction: "You have files scattered everywhere. Which organization is best?",
                    originalPrompt: "Files: Button.tsx, LoginPage.tsx, useAuth.ts, api.ts, SignupPage.tsx, Card.tsx, RecipeList.tsx, useRecipes.ts",
                    options: [
                        QuizOption(id: "a", text: "/components (all .tsx files)\n/hooks (all hooks)\n/utils (api.ts)", correct: false),
                        QuizOption(id: "b", text: "/features/auth (LoginPage, SignupPage, useAuth)\n/features/recipes (RecipeList, useRecipes)\n/shared/ui (Button, Card)\n/shared/lib (api)", correct: true),
                        QuizOption(id: "c", text: "Keep all files in the root directory — flat is simple", correct: false),
                    ],
                    correctFeedback: "Feature-based grouping! Auth files together, recipe files together, and shared UI in its own folder. AI tools navigate this structure effortlessly.",
                    wrongFeedback: "Grouping by file type (all components together, all hooks together) separates related code. Feature-based grouping keeps related files together."
                )),
                LessonStep(type: .fieldMission, title: "Real World Challenge", content: .fieldMission(
                    scenario: "You're asking AI to add a 'favorites' feature. Your project groups by type: /components, /hooks, /pages. AI puts the FavoriteButton in /components but doesn't know about the existing HeartIcon in /assets or the useFavorites hook in /hooks.",
                    task: "How would restructuring help?",
                    options: [
                        QuizOption(id: "a", text: "It wouldn't help — AI should search harder", correct: false),
                        QuizOption(id: "b", text: "A /features/favorites folder with FavoriteButton, useFavorites, and HeartIcon together would let AI see all related code at once", correct: true),
                        QuizOption(id: "c", text: "Add more comments to each file explaining what it relates to", correct: false),
                    ],
                    correctFeedback: "When related files live together, AI doesn't need to search across folders. It sees the whole feature in one place and makes accurate changes.",
                    wrongFeedback: "The issue is that related files are scattered. When AI only sees one folder at a time, it misses connections. Feature folders solve this."
                )),
                LessonStep(type: .summary, title: "Lesson Complete!", content: .summary(
                    recap: ["Group by feature, not by file type", "Consistent naming helps AI navigate", "Clear structure = better AI assistance"],
                    xpReward: 30,
                    badge: "Architect"
                ))
            ]
        ),

        // Tier 3 & 4 stubs — unlocked later
        "tool-switching": stubLesson(id: "tool-switching", name: "Tool Switching", teacher: "glitch", xp: 35),
        "scope-mgmt": stubLesson(id: "scope-mgmt", name: "Scope Mgmt", teacher: "crash", xp: 35),
        "design-system": stubLesson(id: "design-system", name: "Design System", teacher: "luna", xp: 35),
        "iteration": stubLesson(id: "iteration", name: "Prompt Iteration", teacher: "nova", xp: 35),
        "personas": stubLesson(id: "personas", name: "User Personas", teacher: "luna", xp: 40),
        "context-windows": stubLesson(id: "context-windows", name: "Context Windows", teacher: "sage", xp: 40),
        "architecture": stubLesson(id: "architecture", name: "AI Architecture", teacher: "sage", xp: 40),
        "second-brain": stubLesson(id: "second-brain", name: "Second Brain", teacher: "glitch", xp: 40),
    ]

    // Stub generator for higher-tier lessons
    private static func stubLesson(id: String, name: String, teacher: String, xp: Int) -> Lesson {
        Lesson(
            id: id,
            skillName: name,
            teacher: teacher,
            duration: "5 min",
            steps: [
                LessonStep(type: .briefing, title: "Coming Soon", content: .briefing(
                    characterIntro: "This lesson is being crafted...",
                    bodyText: "\(name) will be available when you reach this tier. Keep learning!",
                    hook: "Unlock this by completing previous lessons."
                )),
                LessonStep(type: .summary, title: "Preview Complete", content: .summary(
                    recap: ["Complete earlier lessons to unlock \(name)"],
                    xpReward: xp,
                    badge: nil
                ))
            ]
        )
    }
}
