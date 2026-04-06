# CodePet — GPT Image Prompts for App Store Screenshots

## How to use
1. Open ChatGPT (GPT-4o with image generation)
2. Paste the **Context Block** first so GPT understands the app
3. Then paste each **Screen Prompt** one at a time
4. Upload the Byte sprite (`byte@2x.png` from Assets.xcassets) as a reference image with each prompt so GPT can match the character

---

## Context Block (paste this FIRST)

```
I'm building App Store screenshots for CodePet, a macOS desktop app where users adopt a pixel-art robot companion that guides them through learning to code. The app is built in SwiftUI.

VISUAL IDENTITY:
- Background: warm cream #FBF9F1 (not white, not gray — warm paper-like cream)
- Cards: white (#FFFFFF) with very subtle shadow (0.04 opacity, 2px y-offset, 8px blur), border-radius 16px
- Primary text: dark charcoal #2D2B26
- Secondary text: medium gray #666666
- Accent purple: #7B6BD8 (buttons, highlights, active states)
- Deep purple: #534AB7 (featured cards, marketing bars)
- Gold: #D4960A (streaks, "START HERE" badges)
- Green: #6BCB77 (completed states, success indicators)
- Light purple: #A89BF2 (secondary purple text)

THE CHARACTER — "Byte":
- A cute pixel-art robot with a purple/lavender body
- Rounded square head with two yellow antenna nubs on top
- Dark purple square eyes with white pixel highlights (like retro game characters)
- Simple curved smile
- Rectangular body with horizontal stripe segments and a darker purple belly pocket
- Small rounded purple arms and dark purple boots
- Friendly, approachable, slightly chunky proportions
- Casts a soft oval shadow below
- Always rendered with crisp pixel edges (nearest-neighbor scaling, no blur)

TYPOGRAPHY:
- System font (SF Pro / Inter) for body text
- Monospace labels (Roboto Mono) for status badges like "◆ STREAK", "◆ DAILY CHALLENGE", "START HERE"
- These mono labels are always 9px, bold, with 1px letter-spacing, uppercase

LAYOUT PATTERN:
- macOS window chrome (no title bar buttons needed, clean top edge)
- Top navigation bar (52px): "CODEPET" logo in purple left, tab items centered
- Main content on the left (takes remaining width)
- 280-300px companion panel on the right (white background, left shadow)
- The companion panel always shows: Byte's avatar with green "active" dot, a chat bubble in light purple tint, a 2×2 quick actions grid, and a chat input at the bottom

SCREENSHOT FORMAT:
- 1440 × 900 pixels (Mac App Store requirement)
- At the very bottom of each screenshot: a 72px tall deep purple (#534AB7) marketing bar with a bold white headline (22px) and a light purple subline (13px, #C5BDFF), both centered

Please generate clean, polished, production-ready UI mockups — NOT wireframes. These should look like real screenshots of a shipping macOS app. Flat design, no 3D effects, no gradients except subtle ones. Crisp edges. Professional.
```

---

## Screen 1 — Home Dashboard

```
Generate an App Store screenshot (1440×900) for the CodePet macOS app HOME SCREEN.

Layout from top to bottom:

TOP BAR: White, 52px. "CODEPET" in purple with letter-spacing on the left. Five tabs centered: Home (active — purple text, purple underline), Skills, Sessions, Insights, Profile (all gray).

MAIN CONTENT (left ~1140px):

1. Greeting: "Good morning, Alex 👋" in 28px bold. Below: "Your pet Byte is ready to code with you today." in 14px gray.

2. Three stat cards in a row (180×80px each, white, rounded 16px, subtle shadow):
   - STREAK card: "◆ STREAK" gold monospace label, large "7" in gold, "day streak 🔥" small gray
   - XP card: "◆ TOTAL XP" purple monospace, large "340" purple, "experience points" gray
   - SKILLS card: "◆ SKILLS" green monospace, large "3" green, "of 16 completed" gray

3. Pet area: Large white card (full width, 240px tall) with light purple (#F0EDF9) background. Byte the pixel-art robot centered at ~96px size (crisp pixel art, no smoothing). Below: "Byte" bold, "Level 3 · Ready to learn!" gray. Purple energy bar at 70% with "ENERGY 70%" monospace label.

4. Daily Challenge card: Deep purple (#534AB7) background, rounded 16px, purple glow shadow. Subtle decorative white circles (6% opacity) in top-right corner. "◆ DAILY CHALLENGE" in light purple monospace. "Build a function that counts vowels in a string" in 16px bold white. "+50 XP → Start Challenge" in light purple.

5. World Map row: "YOUR WORLD" monospace gray label. Four small kingdom cards (240×90px): Terminal Kingdom (purple top strip, ⌨ emoji, "✓ Complete" green), Python Plains (green strip, 🐍, "✓ Complete"), Web Wilds (orange strip, 🌐, "Locked" gray), Logic Lair (gold strip, 🧠, "Locked").

RIGHT COMPANION PANEL (300px, white, left shadow):
- Header: light purple (#F8F7FF) background. Byte avatar (44px) in purple circle with green dot. "Byte" bold, "Lvl 3 · Active" gray.
- Chat bubble: light purple tint background. "Hey! You're on a 7-day streak 🔥 Let's keep it going — your Python lesson is waiting!" in purple.
- Quick Actions: 2×2 grid — ▶ Start Lesson, 🎯 Daily Goal, 💬 Ask Byte, 📊 View Progress.
- Chat input: "Ask Byte anything..." placeholder.

BOTTOM MARKETING BAR (72px, #534AB7):
- "Meet your coding companion." — 22px bold white
- "A pet that grows as you learn — streaks, XP, and daily goals in one place." — 13px light purple
```

---

## Screen 2 — Skills Map

```
Generate an App Store screenshot (1440×900) for the CodePet macOS app SKILLS MAP screen.

TOP BAR: Same as before. "Skills" tab is now active (purple underline).

MAIN CONTENT (left ~1140px, padding 32px):

Kingdom header: "TERMINAL KINGDOM" — monospace 9px bold purple, letter-spacing.

Skill cards in a 3-column grid (gap 16px):

Row 1 — Completed skills (green accents):
- "Hello World" — white card, 3px green left border, green ✓ checkmark badge top-right, subtitle "Your first program" in gray, "COMPLETED" green monospace badge at bottom
- "Variables & Types" — same completed style, subtitle "Store and transform data"
- "Control Flow" — same completed style, subtitle "If, else, and switches"

Row 2 — Current + locked:
- "Functions" — white card with subtle purple border glow, gold "◆ START HERE" badge in monospace, subtitle "Define reusable blocks", purple progress bar at 40%, "IN PROGRESS" purple monospace label
- "Arrays & Lists" — white card, dimmed (opacity 0.5), 🔒 lock icon, "LOCKED" gray monospace
- "Objects" — same locked style

Below: "PYTHON PLAINS" kingdom header in green monospace.

Row 3 — All locked:
- "Intro to Python", "Python Functions", "Python Classes" — all locked style

RIGHT COMPANION PANEL (300px):
- Byte avatar, green dot, name
- Bubble: "Nice work finishing Control Flow! Functions are next — you'll love writing reusable code 💡"
- Quick actions grid + chat input

BOTTOM MARKETING BAR:
- "16 skills. One journey." — bold white
- "An interactive skill tree that shows exactly where you are and what's next." — light purple
```

---

## Screen 3 — Lesson in Action

```
Generate an App Store screenshot (1440×900) for the CodePet macOS app showing a LESSON IN PROGRESS.

TOP BAR: "Skills" tab active.

MAIN CONTENT: A lesson modal/sheet overlaying the skills view.

Behind the modal: faintly visible skill cards at ~15% opacity (just enough context to show this is overlaid).

The lesson modal (white, rounded 20px, strong shadow, centered, ~90% of content width):

- Breadcrumb: "Terminal Kingdom › Functions › Step 2 of 5" in 12px gray
- Title: "Writing Your First Function" — 24px bold
- Progress bar: purple fill at 40% on light track, "2/5" label
- Explanation: "A function is a reusable block of code that performs a specific task. Let's create one that greets a user by name." — 14px, line-height 1.7
- Code block (dark background #1E1E2E, rounded 12px, monospace):
  ```
  func greet(name: String) -> String {
      return "Hello, \(name)! 👋"
  }

  let message = greet(name: "Alex")
  print(message)
  ```
  With syntax highlighting: keywords (func, return, let) in purple, strings in green, function names in blue
- Quiz: "What will this code print?" — bold
- Two answer options as buttons:
  - "Hello, Alex! 👋" — green border, green tint background (correct answer selected)
  - "greet(name: Alex)" — gray border, dimmed
- "Continue →" button: purple background, white text, right-aligned at bottom

RIGHT COMPANION PANEL:
- Byte + bubble: "Functions are like recipes — you write them once and use them whenever you need! Try the quiz 🧠"
- Quick actions + chat input

BOTTOM MARKETING BAR:
- "Learn by building real things." — bold white
- "Step-by-step lessons with your pet cheering you on in real time." — light purple
```

---

## Screen 4 — Companion Panel (Hero)

```
Generate an App Store screenshot (1440×900) for the CodePet macOS app highlighting the AI COMPANION PANEL as the hero element.

TOP BAR: "Skills" tab active.

LEFT SIDE (dimmed at ~60% opacity): Simplified skills view background — a few white card outlines visible but NOT the focus. This provides context only.

RIGHT COMPANION PANEL (360px wide — slightly wider than normal, white, prominent left shadow):

Header (72px, #F8F7FF bg):
- Byte pixel-art avatar at 48px in a light purple circle, green "active" dot
- "Byte" bold 17px
- "Your Coding Companion · Active" 12px gray

Chat conversation flow:
- User message (right-aligned, light gray #F0F0F0 bubble): "How do functions work in Swift?"
- Byte reply (left-aligned, purple-tint bubble, small Byte avatar):
  "Great question! A function is like a recipe:
   1. You give it a name
   2. It takes ingredients (parameters)
   3. It produces something (return value)
   Here's a simple example:"
- Code snippet (dark bg #1E1E2E, rounded):
  ```
  func add(a: Int, b: Int) -> Int {
      return a + b
  }
  ```
  With syntax highlighting
- Byte follow-up: "Want me to break down each part? Or try writing one yourself! 🚀"

Quick Actions (2×2): ▶ Start Lesson, 🎯 Daily Goal, 💬 Explain Code, 📊 View Progress

Chat input at bottom: "Ask Byte anything..." placeholder with purple send arrow button

BOTTOM MARKETING BAR:
- "Your pet actually helps you code." — bold white
- "Ask Byte anything — get hints, explanations, and encouragement instantly." — light purple
```

---

## Screen 5 — Insights & Progress

```
Generate an App Store screenshot (1440×900) for the CodePet macOS app INSIGHTS screen.

TOP BAR: "Insights" tab active (purple underline).

MAIN CONTENT (left ~1140px, padding 32px):

Header: "Your Progress" — 28px bold. "Track your coding journey with Byte" — 14px gray.

4 stat cards in a row (equal width, 100px tall, white, rounded):
- "◆ STREAK" gold mono → "7" gold 36px bold → "days" gray
- "◆ XP EARNED" purple mono → "340" purple 36px → "total" gray
- "◆ LESSONS" green mono → "12" green 36px → "completed" gray
- "◆ TIME" orange (#F5A623) mono → "4.2h" orange 36px → "this week" gray

Weekly Activity chart card (white, full width, ~200px tall):
- "This Week" bold 16px header
- Bar chart: 7 purple bars for Mon–Sun, varying heights (Mon 45min, Tue 30, Wed 60, Thu 20, Fri 50, Sat 0, Sun 15min)
- Y-axis: minute labels. X-axis: day labels. Today's bar (Sun) has a subtle glow
- Clean, minimal chart — no gridlines, just bars and labels

Skill Progress card (white, full width, ~180px):
- "Skill Progress" bold 16px
- 4 rows with colored progress bars:
  - Terminal Kingdom: purple bar at 100%, "4/4 ✓" green text
  - Python Plains: green bar at 25%, "1/4"
  - Web Wilds: orange bar at 0%, "0/4 🔒"
  - Logic Lair: gold bar at 0%, "0/4 🔒"

RIGHT COMPANION PANEL:
- Byte + bubble: "You've been coding every day this week! 🎉 Your Python skills are really improving. Ready for Web Wilds next?"
- Quick actions + chat input

BOTTOM MARKETING BAR:
- "Watch yourself get better every day." — bold white
- "Track streaks, XP, skill progress, and weekly coding time — all in one place." — light purple
```

---

## Tips for Best Results

- **Upload the Byte sprite** (`byte@2x.png`) as a reference with each prompt — GPT will match the character design much better
- If GPT's first attempt misses the warm cream background and makes it white/gray, emphasize: "The background is warm cream #FBF9F1, like aged paper — NOT pure white"
- If the pixel art gets smoothed, add: "The robot character must have crisp pixel edges — no anti-aliasing, no blur, nearest-neighbor scaling"
- If layout is off, add: "This is a macOS desktop app at 1440×900 — NOT a mobile app. Wide, horizontal layout with a sidebar on the right"
- Generate one screen at a time for best quality
- You can ask GPT to "refine" or "adjust" after the first generation
