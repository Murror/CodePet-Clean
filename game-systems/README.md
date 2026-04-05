# CodePet Game Systems — Phase 1 Prototype

## Branch Setup

Run these commands in your Cursor terminal:

```bash
# 1. Make sure main is clean
cd ~/Desktop/codepet
git stash  # if you have uncommitted changes

# 2. Create the feature branch
git checkout -b feature/game-systems

# 3. Move BE files into the project
cp game-systems/BE/GameSystems.swift Models/
cp game-systems/BE/AppState+GameSystems.swift Models/
cp game-systems/BE/GamePersistence.swift Managers/

# 4. Move FE files into the project
cp game-systems/FE/PetCareView.swift Views/Home/
cp game-systems/FE/WelcomeBackView.swift Views/Home/
cp game-systems/FE/HeartsView.swift Views/Skills/
cp game-systems/FE/CompendiumView.swift Views/Skills/
cp game-systems/FE/CosmeticShopView.swift Views/Profile/

# 5. Delete the GameSystems.swift that was accidentally added to Models/ on main
rm -f Models/GameSystems.swift  # only if the old version is still there

# 6. Add all new files to git
git add Models/GameSystems.swift Models/AppState+GameSystems.swift Managers/GamePersistence.swift
git add Views/Home/PetCareView.swift Views/Home/WelcomeBackView.swift
git add Views/Skills/HeartsView.swift Views/Skills/CompendiumView.swift
git add Views/Profile/CosmeticShopView.swift

# 7. Commit
git commit -m "feat: add game systems prototype (pet care, hearts, compendium, shop)"
```

## After copying, add files to Xcode

1. Open `codepet.xcodeproj` in Xcode
2. For each new .swift file: right-click the target folder in the navigator → "Add Files to codepet..."
3. Make sure each file has the `codepet` target checked


## File Map

### BE (Backend — Models & Logic)

| File | Location | What it does |
|------|----------|-------------|
| `GameSystems.swift` | `Models/` | All game data models: PetCare moods, HeartsSystem, IdleXP, Economy, PetFood, Compendium, Cosmetics, PetAbilities |
| `AppState+GameSystems.swift` | `Models/` | `GameState` class — ObservableObject holding all new game properties + methods (feed, hearts, coins, cosmetics) |
| `GamePersistence.swift` | `Managers/` | Save/load GameState to UserDefaults (keys prefixed `cp_game_`) |

### FE (Frontend — SwiftUI Views)

| File | Location | What it does |
|------|----------|-------------|
| `PetCareView.swift` | `Views/Home/` | Tamagotchi care screen: pet mood, energy/hunger bars, food menu, feeding animation |
| `WelcomeBackView.swift` | `Views/Home/` | Idle XP overlay shown on return: XP earned, pet tip, status changes |
| `HeartsView.swift` | `Views/Skills/` | Hearts display (5 hearts) + refill sheet, regen timer |
| `CompendiumView.swift` | `Views/Skills/` | Pokédex-style code knowledge collection with category filters |
| `CosmeticShopView.swift` | `Views/Profile/` | Pet cosmetics shop: buy, equip, rarity tiers, achievement unlocks |


## Integration Steps (after adding to Xcode)

### Step 1: Register GameState in the app

In `CodePetApp.swift`, add GameState as an environment object:

```swift
@StateObject private var gameState = GameState()

// In body, add to the environment:
.environmentObject(gameState)
```

### Step 2: Wire PetCareView into HomeView

In `HomeView.swift`, replace or add below the existing `PetAreaView5`:

```swift
PetCareView()
    .environmentObject(gameState)
```

### Step 3: Wire WelcomeBackView

In `ContentView.swift` or `MainTabView.swift`, add the overlay:

```swift
.overlay {
    if gameState.showWelcomeBack {
        WelcomeBackView()
    }
}
.onAppear {
    gameState.processReturnFromIdle(appState: appState)
}
```

### Step 4: Wire HeartsView into lessons

In `LessonModalView.swift`, add hearts display at the top:

```swift
HeartsDisplayView()
    .environmentObject(gameState)
```

And on wrong answers:

```swift
gameState.loseHeart()
```

### Step 5: Add Compendium + Shop to tabs

In `MainTabView.swift`, add new tab items or sub-views:

```swift
// In Skills tab, add a "Compendium" button that opens:
CompendiumView()

// In Profile tab, add a "Pet Shop" button that opens:
CosmeticShopView()
```

### Step 6: Award coins after lessons

In your lesson completion handler:

```swift
gameState.earnCoins(GameEconomy.coinsPerLesson)
gameState.checkCompendiumUnlocks(forLesson: lessonId)
```


## What Each System Does

### Pet Care (Tamagotchi Loop)
- **Energy** decays 2/hour while away (min 5)
- **Hunger** decays 3/hour while away (min 0)
- **Mood** auto-calculates from energy, hunger, streak, time away
- **Feeding** costs coins, restores energy + hunger
- Pet goes **asleep** after 3 days away, needs waking up

### Hearts (Duolingo-style)
- 5 hearts max, lose 1 per wrong answer
- Regenerate 1 every 30 minutes
- Can refill all for 20 coins

### Idle XP (Passive Progress)
- Earn 2 XP/hour while away (max 48 XP / 24 hours)
- Pet shows a fun coding tip on return

### Economy
- Earn coins: lessons (10), challenges (25), streaks (5/day), boss battles (50), level-ups (20)
- Spend coins: food (5-50), streak freeze (30), heart refill (20), cosmetics (40-120)

### Compendium (18 entries)
- 5 categories: Concepts, Patterns, Tools, Debugging, Trivia
- Unlocked by completing specific lessons
- Each has description + optional code example

### Cosmetics (18 items)
- 4 categories: Hats, Accessories, Backgrounds, Effects
- 4 rarities: Common (gray), Uncommon (green), Rare (purple), Legendary (gold)
- Some buyable with coins, some earned by achievements only

### Pet Abilities (24 total, 3 per character)
- Unlock at evolution tiers 2, 3, 4
- Each character has unique themed abilities
- Makes character choice meaningful for gameplay
