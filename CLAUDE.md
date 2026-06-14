# Codepet — Project Instructions

## What is Codepet?
Codepet is an AI coding companion app where users adopt pixel-art characters that guide them through learning to code. 8 characters, 16 skills, one journey. Built by MURROR (murror.app).

## Tech Stack
- **Platform:** macOS (SwiftUI, minimum macOS 13+)
- **Language:** Swift
- **Auth:** Firebase Authentication (Email/Password, Google Sign-In, Anonymous)
- **Database:** Firestore (cloud sync for user progress)
- **Architecture:** MVVM with @EnvironmentObject (AppState, AuthManager)
- **Assets:** Pixel-art sprites and logos, rendered with `.interpolation(.none)` for crisp scaling
- **Bundle ID:** app.murror.codepet (also persists as com.murror.codepet in UserDefaults)

## Project Structure
```
CodePet-Clean/                  # ← Single source of truth (Xcode + Cursor + Git)
├── codepet.xcodeproj           # Xcode project file
├── codepet/                    # All Swift source files
│   ├── App/
│   │   ├── CodePetApp.swift    # @main, Firebase init, environment objects
│   │   └── ContentView.swift   # 4-state router: splash → auth → onboarding → main
│   ├── Models/
│   │   ├── AppState.swift      # All user state, auto-saves to UserDefaults
│   │   ├── AppState+GameSystems.swift  # GameState class (pet care, hearts, coins, cosmetics)
│   │   ├── GameSystems.swift   # Game data models (PetCare, HeartsSystem, Economy, etc.)
│   │   ├── Character.swift     # PetCharacter model, 8 starters, Color(hex:) extension
│   │   ├── SkillData.swift     # Skill tree definitions (4 tiers, 4 kingdoms)
│   │   └── LessonContent.swift # Lesson content data (8 lessons)
│   ├── Managers/
│   │   ├── AuthManager.swift   # Firebase auth (email, Google, anonymous)
│   │   ├── PersistenceManager.swift  # UserDefaults save/load
│   │   ├── GamePersistence.swift     # GameState save/load (cp_game_ keys)
│   │   ├── SoundManager.swift  # Sound effects
│   │   └── ThemeManager.swift  # Theme/appearance (purple palette)
│   ├── Services/
│   │   └── CloudSyncService.swift  # Firestore read/write (full implementation)
│   ├── Views/
│   │   ├── SplashView.swift    # Splash screen (pixel-art logo, character animations)
│   │   ├── MainTabView.swift   # Tab navigation + GameHUDBar (hearts, coins, streak)
│   │   ├── Onboarding/
│   │   │   ├── OnboardingFlow.swift      # Full onboarding (age gate → questions → character select)
│   │   │   └── ReturningSignInView.swift # Sign-in for returning users
│   │   ├── Home/               # Home tab (dashboard, world map, kingdoms, pet care)
│   │   ├── Skills/             # Skills tab (lessons, companion AI panel, compendium)
│   │   ├── Sessions/           # Coding sessions (practice challenges)
│   │   ├── Insights/           # Progress insights (pixel art icons)
│   │   └── Profile/            # Profile & settings (cosmetic shop, sign-out)
│   ├── Notification/           # Local notifications
│   ├── Menu Bar/               # macOS menu bar integration
│   └── Assets.xcassets/        # All image assets including kingdom PNGs
├── codepetTests/               # Unit tests
├── game-systems/               # Game system specs & prototypes (reference only)
├── design-assets/              # Pixel art source PNGs (1280×800 kingdoms)
└── CLAUDE.md                   # This file
```

**IMPORTANT:** CodePet-Clean is the single source of truth. Both Xcode and Cursor work on the same files here. Do NOT edit ~/Desktop/codepet separately — it is deprecated.

## App Flow
1. **Splash** → user taps "Meet Your Pet →"
2. **New user** (`onboardingComplete == false`) → OnboardingFlow:
   - Age Gate (age selection → sign-in/sign-up or skip)
   - 6 onboarding questions (who, drives, goal, experience, daily goal, character recommendation)
   - Interests selection
   - First Words with chosen character
   - → Main App
3. **Returning user, signed out** (`onboardingComplete == true`, `currentUser == nil`) → ReturningSignInView
4. **Returning user, signed in** → Main App directly

## Design System
- **Background colors:** `#F5F3FA` (pale purple - splash), `#F7F5FC` (onboarding)
- **Primary dark:** `#2D2B26`
- **Accent purple:** `#7B6BD8`, `#534AB7`
- **Logo colors:** K=#2D2664 (outline), S=#1E1848 (shadow), F=#8B7BE8 (fill), L=#A89BF2 (light)
- **Pixel art:** Always use `.interpolation(.none)` and `Image.NEAREST` for scaling
- **App icon:** `codepet-official-logo.png` — C at 55% width × 63% height, white background

## Characters (8 starters)
byte, nova, crash, luna, sage, glitch, zero, null

## Important Files
- `codepet-official-logo.png` — Final app icon (do not modify)
- `codepet-text-original.png` — Original text logo (848x221, do not modify)
- `AppIcon.appiconset/` — All macOS icon sizes generated from official logo

## Key Rules
- Never modify `codepet-official-logo.png` or `codepet-text-original.png` without explicit approval
- Always use NEAREST neighbor scaling for pixel art (never bilinear/bicubic)
- Firebase auth state changes must NOT disrupt the onboarding flow (see `isOnboarding` guard in ContentView)
- UserDefaults keys are prefixed with `cp_` (e.g., `cp_onboardingComplete`)
- Cloud sync saves to Firestore under `users/{uid}`

---

# Workspaces

This project is managed across 5 separate workspaces. Each workspace has a specific purpose. Never mix concerns across workspaces.

## 1. Codepet macOS app
**Purpose:** All development work on the native macOS SwiftUI app.
**Scope:** SwiftUI views, models, managers, services, assets, Firebase integration, UI/UX changes, bug fixes, and feature development.
**Key files:** Everything under `codepet/` in the Xcode project.
**When to use:** Writing code, fixing bugs, designing screens, adjusting animations, updating assets.

## 2. Codepet macOS app — App Store
**Purpose:** App Store listing, metadata, screenshots, and submission.
**Scope:** App Store Connect configuration, app description, keywords, screenshots, privacy policy, age rating, pricing, and review responses.
**When to use:** Preparing or updating the App Store listing, responding to reviews, updating metadata.

## 3. Codepet macOS app — TestFlight
**Purpose:** Beta testing and distribution.
**Scope:** TestFlight builds, tester management, beta feedback, build versioning, provisioning profiles, and testing notes.
**When to use:** Uploading builds, managing testers, reviewing crash reports, writing test notes.

## 4. Codepet macOS app — GitHub
**Purpose:** Source control, collaboration, and CI/CD.
**Scope:** Git commits, branches, pull requests, issues, GitHub Actions, and code reviews.
**When to use:** Committing code, creating PRs, managing issues, setting up workflows.

## 5. Codepet multi agent
**Purpose:** Multi-agent system design and coordination.
**Scope:** Creating and coordinating AI agents across different roles — Marketing, Business, QA, Backend (BE), and Frontend (FE). Agent definitions, workflows, inter-agent communication, and task delegation.
**When to use:** Designing agent roles, building agent workflows, testing multi-agent coordination, defining agent responsibilities.

---

# Daily Summary Format

When summarizing work at the end of a session, use this format:

**Codepet macOS app**
- [bullet points of work done]

**Codepet macOS app — App Store**
- [bullet points or "No work today"]

**Codepet macOS app — TestFlight**
- [bullet points or "No work today"]

**Codepet macOS app — GitHub**
- [bullet points or "No work today"]

**Codepet multi agent**
- [bullet points or "No work today"]

---

# Game Systems Reference

## Architecture
- **GameState** (defined in `AppState+GameSystems.swift`): ObservableObject holding pet care, hearts, coins, cosmetics
- **GameSystems.swift**: Data models (PetCare moods, HeartsSystem, Economy rates, PetFood, Compendium entries, Cosmetics)
- **GamePersistence.swift**: Save/load GameState to UserDefaults (keys prefixed `cp_game_`)
- **AppState.swift**: Core user state (completedLessons, streak, level, selectedTab, pendingKingdomId)
- Views use both: `@EnvironmentObject var appState: AppState` + `@EnvironmentObject var gameState: GameState`

## Economy
- Hearts: 5 max, lose 1 per wrong answer, regen 1 every 30 min, refill all for 20 coins
- Coins earned: lessons (10), challenges (25), streaks (5/day), boss battles (50), level-ups (20)
- Coins spent: food (5-50), streak freeze (30), heart refill (20), cosmetics (40-120)
- Pet energy decays 2/hr away (min 5), hunger decays 3/hr away (min 0)
- Pet goes asleep after 3 days away