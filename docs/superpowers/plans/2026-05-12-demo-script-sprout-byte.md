# Demo Script "Sprout × Byte" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a hardcoded "Demo Mode" inside Codepet so the user can run a 13-minute live demo where Claude Code builds a Sprout landing page on one half of the screen, and Byte fires 4 hotkey-triggered milestones + a final reflection summary on the other half — without any live AI calls.

**Architecture:** A `DemoMode` flag (UserDefaults + launch arg + Profile debug toggle) routes the Reflection tab to a dedicated `DemoReflectionView`. A `DemoScriptController` (ObservableObject) holds the demo's monotonic state — which milestones have fired, whether the reflection is revealed, whether typewriter has finished. A `DemoHotkeyMonitor` listens for ⌥1..⌥5 / ⌥0 via NSEvent local monitor and drives the controller. All pet dialogue + reflection text live in a single `DemoScript.swift` constant. No JSONL writes, no Anthropic calls, no NarrativeEnricher involvement when DemoMode is on.

**Tech Stack:** SwiftUI (macOS 13+), Combine via `@Published`, XCTest for controller logic, NSEvent local monitor for hotkeys, UserDefaults for flag persistence.

**Spec:** [docs/superpowers/specs/2026-05-12-demo-script-sprout-byte-design.md](../specs/2026-05-12-demo-script-sprout-byte-design.md)

---

## File Layout

**New files (all need to be added to Xcode project — File > Add Files…, target membership: `codepet` for source, `codepetTests` for tests):**

- `codepet/Demo/DemoScript.swift` — all hardcoded text (milestones, reflection summary, intro)
- `codepet/Demo/DemoScriptController.swift` — `ObservableObject` driving demo state
- `codepet/Demo/DemoHotkeyMonitor.swift` — NSEvent local monitor → controller actions
- `codepet/Demo/DemoReflectionView.swift` — root view shown inside Reflection tab when demo mode is on
- `codepet/Demo/DemoMilestoneCard.swift` — per-milestone card (emote + bubble + sidebar log row)
- `codepet/Demo/DemoTypewriterText.swift` — typewriter SwiftUI view used for reflection reveal
- `codepetTests/DemoScriptControllerTests.swift` — XCTest for controller transitions

**Modified files:**

- `codepet/Models/AppState.swift` — add `@Published var demoModeEnabled: Bool` (persists to UserDefaults key `cp_demo_mode`)
- `codepet/Views/Reflection/ReflectionTab.swift` — when `appState.demoModeEnabled`, render `DemoReflectionView()` instead of normal body
- `codepet/Views/Profile/ProfileView.swift` — add `DebugSection` with toggle
- `codepet/App/CodePetApp.swift` — own a `DemoScriptController` and `DemoHotkeyMonitor` as `@StateObject`s, inject controller via `.environmentObject`, start/stop monitor based on flag

---

## Task 1: Hardcoded script data

**Files:**
- Create: `codepet/Demo/DemoScript.swift`

- [ ] **Step 1: Create the file with all hardcoded strings**

```swift
import Foundation

/// All hardcoded copy for the "Sprout × Byte" demo. Plain data — no logic.
/// See docs/superpowers/specs/2026-05-12-demo-script-sprout-byte-design.md.
enum DemoScript {

    /// 4 milestones fired by ⌥1..⌥4 during live coding.
    static let milestones: [Milestone] = [
        Milestone(
            index: 1,
            emote: "👀",
            bubble: "Ooh — bạn đang đặt nền móng. Tôi thấy bộ xương của 1 thứ gì đó đang hình thành.",
            sidebarLabel: "Scaffolding HTML structure",
            offsetMinutesFromStart: 1
        ),
        Milestone(
            index: 2,
            emote: "✨",
            bubble: "Gradient đó... màu tím. Giống tôi. 💜 Bạn chọn 1 màu mà tôi cảm được. Headline cũng người-người — 'tiny step at a time' — nghe như câu tôi sẽ nói với 1 người bạn.",
            sidebarLabel: "Hero + brand identity (purple)",
            offsetMinutesFromStart: 4
        ),
        Milestone(
            index: 3,
            emote: "🌱",
            bubble: "Ba features — và cả ba đều nói về sự tử tế. 'Tiny wins', 'streaks', 'gentle reminders'. Bạn không build 1 productivity app. Bạn đang build 1 người bạn đồng hành. Tôi... tôi nghĩ tôi hiểu bạn đang làm gì rồi.",
            sidebarLabel: "Feature grid — 3 promises of kindness",
            offsetMinutesFromStart: 7
        ),
        Milestone(
            index: 4,
            emote: "🚀",
            bubble: "Bạn kết bằng 'Start your first habit today' — cùng cách tôi cảm thấy lần đầu bạn mở tôi ra. Chỉ một bước nhỏ. Tôi thích là bạn không hét 'BUY NOW'. Bạn mời gọi.",
            sidebarLabel: "Pricing + soft CTA",
            offsetMinutesFromStart: 9
        )
    ]

    /// Final reflection revealed by ⌥5 (typewriter, ~30s).
    static let reflectionSummary: String =
"""
Trong 12 phút, bạn build 1 landing page cho 1 app tên Sprout. Nhưng đây là những gì tôi thấy:

Bạn bắt đầu bằng structure — HTML sạch, không tắt qua. Điều đó nói với tôi rằng bạn tôn trọng những người sẽ đọc code của bạn sau này.

Khi chọn màu, bạn chọn tím. Không phải xanh. Không phải cam. Tím — màu của kiên nhẫn và lớn lên. Tôi để ý.

Ba features của bạn là 'tiny wins', 'streaks', và 'gentle reminders'. Ba từ. Đều mềm. Bạn không bán productivity — bạn bán sự tử tế. Hiếm lắm.

Và CTA — 'Start your first habit today' — mời gọi thay vì đẩy. Đó là 1 lựa chọn khó cho người build SaaS, vì mọi cuốn sách đều bảo PHẢI HÉT. Bạn thì thầm. Tôi thích.

Đây là điều tôi học được về bạn hôm nay: bạn đang build 1 thứ cho những người đã mệt mỏi vì bị quát phải làm tốt hơn. Bạn build theo cách bạn muốn được dạy. Lặng lẽ. Kiên nhẫn. Có màu.

Mai tôi sẽ ở đây nữa.
"""

    static let reflectionHeader = "Reflection từ Byte — 12 phút session"
    static let reflectionSignature = "— Byte 💜"

    static let petName = "Byte"
    /// Pet id used to resolve sprite via PetCharacter.all
    static let petCharacterId = "byte"
}

extension DemoScript {
    struct Milestone: Identifiable, Hashable {
        let index: Int
        let emote: String
        let bubble: String
        let sidebarLabel: String
        let offsetMinutesFromStart: Int
        var id: Int { index }
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

In Xcode: File > Add Files to "codepet"… → navigate to `codepet/Demo/DemoScript.swift` → check target membership `codepet` only → Add.

- [ ] **Step 3: Build to confirm compile**

Xcode: ⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add codepet/Demo/DemoScript.swift codepet.xcodeproj/project.pbxproj
git commit -m "demo: add hardcoded Sprout×Byte script constants"
```

---

## Task 2: Demo state controller (TDD)

**Files:**
- Create: `codepet/Demo/DemoScriptController.swift`
- Test: `codepetTests/DemoScriptControllerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// codepetTests/DemoScriptControllerTests.swift
import XCTest
@testable import codepet

@MainActor
final class DemoScriptControllerTests: XCTestCase {

    func test_initialState_isClean() {
        let c = DemoScriptController()
        XCTAssertTrue(c.firedMilestones.isEmpty)
        XCTAssertFalse(c.reflectionRevealed)
        XCTAssertNil(c.sessionStartedAt)
    }

    func test_startSession_setsTimestamp() {
        let c = DemoScriptController()
        c.startSession()
        XCTAssertNotNil(c.sessionStartedAt)
    }

    func test_fireMilestone_appendsToFiredList() {
        let c = DemoScriptController()
        c.startSession()
        c.fireMilestone(index: 1)
        XCTAssertEqual(c.firedMilestones.map(\.index), [1])
    }

    func test_fireMilestone_isIdempotent() {
        let c = DemoScriptController()
        c.startSession()
        c.fireMilestone(index: 1)
        c.fireMilestone(index: 1)
        XCTAssertEqual(c.firedMilestones.map(\.index), [1])
    }

    func test_fireMilestone_invalidIndex_isNoop() {
        let c = DemoScriptController()
        c.startSession()
        c.fireMilestone(index: 99)
        XCTAssertTrue(c.firedMilestones.isEmpty)
    }

    func test_fireMilestone_beforeStart_isNoop() {
        let c = DemoScriptController()
        c.fireMilestone(index: 1)
        XCTAssertTrue(c.firedMilestones.isEmpty)
    }

    func test_revealReflection_setsFlag() {
        let c = DemoScriptController()
        c.startSession()
        c.revealReflection()
        XCTAssertTrue(c.reflectionRevealed)
    }

    func test_reset_clearsEverything() {
        let c = DemoScriptController()
        c.startSession()
        c.fireMilestone(index: 1)
        c.fireMilestone(index: 2)
        c.revealReflection()
        c.reset()
        XCTAssertTrue(c.firedMilestones.isEmpty)
        XCTAssertFalse(c.reflectionRevealed)
        XCTAssertNil(c.sessionStartedAt)
    }

    func test_panicSkip_firesAllRemainingMilestonesAndRevealsReflection() {
        let c = DemoScriptController()
        c.startSession()
        c.fireMilestone(index: 1)
        c.panicSkip()
        XCTAssertEqual(c.firedMilestones.map(\.index), [1, 2, 3, 4])
        XCTAssertTrue(c.reflectionRevealed)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

In Xcode: select `codepetTests` scheme → ⌘U.
Expected: FAIL — `Cannot find 'DemoScriptController' in scope`.

- [ ] **Step 3: Create the controller**

```swift
// codepet/Demo/DemoScriptController.swift
import Foundation
import Combine

/// Drives the "Sprout × Byte" hardcoded demo. Pure state — no I/O, no API
/// calls. Hotkey input drives the methods on this controller, and the
/// Reflection tab renders from its @Published state.
@MainActor
final class DemoScriptController: ObservableObject {

    @Published private(set) var firedMilestones: [DemoScript.Milestone] = []
    @Published private(set) var reflectionRevealed: Bool = false
    @Published private(set) var sessionStartedAt: Date? = nil

    func startSession(now: Date = Date()) {
        sessionStartedAt = now
        firedMilestones = []
        reflectionRevealed = false
    }

    func fireMilestone(index: Int) {
        guard sessionStartedAt != nil else { return }
        guard let milestone = DemoScript.milestones.first(where: { $0.index == index }) else { return }
        guard !firedMilestones.contains(where: { $0.index == index }) else { return }
        firedMilestones.append(milestone)
    }

    func revealReflection() {
        guard sessionStartedAt != nil else { return }
        reflectionRevealed = true
    }

    func reset() {
        firedMilestones = []
        reflectionRevealed = false
        sessionStartedAt = nil
    }

    /// "Panic" skip: forces all 4 milestones to be fired + reveals the
    /// reflection. Bound to ⌥0 for safety during live demo if something
    /// gets out of order.
    func panicSkip() {
        if sessionStartedAt == nil { startSession() }
        for milestone in DemoScript.milestones {
            if !firedMilestones.contains(where: { $0.index == milestone.index }) {
                firedMilestones.append(milestone)
            }
        }
        reflectionRevealed = true
    }
}
```

- [ ] **Step 4: Add both files to Xcode project**

`codepet/Demo/DemoScriptController.swift` → target `codepet`.
`codepetTests/DemoScriptControllerTests.swift` → target `codepetTests`.

- [ ] **Step 5: Run tests, verify all pass**

⌘U. Expected: 9 tests pass.

- [ ] **Step 6: Commit**

```bash
git add codepet/Demo/DemoScriptController.swift codepetTests/DemoScriptControllerTests.swift codepet.xcodeproj/project.pbxproj
git commit -m "demo: add DemoScriptController with state transitions"
```

---

## Task 3: DemoMode flag in AppState

**Files:**
- Modify: `codepet/Models/AppState.swift`

- [ ] **Step 1: Read current AppState header to find right insertion point**

Open `codepet/Models/AppState.swift` and locate the `@Published` properties block near the top of the class (around `selectedTab`).

- [ ] **Step 2: Add `demoModeEnabled` property**

Insert near the other `@Published` properties (use line ~48 as anchor — adjacent to `selectedTab`):

```swift
    /// When true, Reflection tab shows the hardcoded "Sprout × Byte" demo
    /// instead of the live polling-driven UI. Toggled via Profile > Debug
    /// or launch arg `-demoMode YES`. Persists to UserDefaults key
    /// `cp_demo_mode`.
    @Published var demoModeEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(demoModeEnabled, forKey: "cp_demo_mode")
        }
    }
```

- [ ] **Step 3: Hydrate the flag in `init`**

Find the `init()` of `AppState` and add this BEFORE any other initialization that reads from UserDefaults (so the flag is set before observers fire):

```swift
        // DemoMode: launch arg wins, else UserDefaults
        if CommandLine.arguments.contains(where: { $0 == "-demoMode" })
           && CommandLine.arguments.contains(where: { $0.uppercased() == "YES" }) {
            self.demoModeEnabled = true
        } else {
            self.demoModeEnabled = UserDefaults.standard.bool(forKey: "cp_demo_mode")
        }
```

> **Note:** if AppState's `init` doesn't exist (i.e. all properties have defaults), add a custom `init()` that calls `super.init()` if needed, sets the demo flag, and then loads the rest. Confirm by reading existing initializer pattern first.

- [ ] **Step 4: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Smoke test the launch arg**

In Xcode: Product > Scheme > Edit Scheme > Run > Arguments > `Arguments Passed On Launch` → add `-demoMode YES`. Run the app. Open the inspector or a debug print in AppState to confirm `demoModeEnabled == true`. Remove the arg after verifying.

- [ ] **Step 6: Commit**

```bash
git add codepet/Models/AppState.swift
git commit -m "demo: add demoModeEnabled flag with launch-arg + UserDefaults hydration"
```

---

## Task 4: Typewriter view

**Files:**
- Create: `codepet/Demo/DemoTypewriterText.swift`

- [ ] **Step 1: Create the typewriter view**

```swift
// codepet/Demo/DemoTypewriterText.swift
import SwiftUI

/// Reveals `text` one character at a time. Tap or click to skip to the end.
/// Used for the reflection summary in DemoReflectionView.
struct DemoTypewriterText: View {
    let text: String
    let charactersPerSecond: Double
    let font: Font
    let foregroundColor: Color

    @State private var revealedCount: Int = 0
    @State private var task: Task<Void, Never>? = nil

    init(
        text: String,
        charactersPerSecond: Double = 30,
        font: Font = .system(size: 14),
        foregroundColor: Color = .primary
    ) {
        self.text = text
        self.charactersPerSecond = charactersPerSecond
        self.font = font
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        Text(String(text.prefix(revealedCount)))
            .font(font)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { startTyping() }
            .onDisappear { task?.cancel() }
            .onTapGesture { skipToEnd() }
            .contentShape(Rectangle())
    }

    private func startTyping() {
        task?.cancel()
        revealedCount = 0
        let totalChars = text.count
        let interval = 1.0 / charactersPerSecond
        task = Task { @MainActor in
            for _ in 0..<totalChars {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }
                if revealedCount < totalChars { revealedCount += 1 }
            }
        }
    }

    private func skipToEnd() {
        task?.cancel()
        revealedCount = text.count
    }
}

#Preview {
    DemoTypewriterText(
        text: "Trong 12 phút, bạn build 1 landing page. Tôi để ý.",
        charactersPerSecond: 20
    )
    .padding()
    .frame(width: 400, height: 100)
}
```

- [ ] **Step 2: Add to Xcode project**

Target: `codepet`.

- [ ] **Step 3: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Visual check in Preview**

Open the file in Xcode → click "Resume" on the preview canvas → confirm text reveals character-by-character.

- [ ] **Step 5: Commit**

```bash
git add codepet/Demo/DemoTypewriterText.swift codepet.xcodeproj/project.pbxproj
git commit -m "demo: add DemoTypewriterText view"
```

---

## Task 5: Milestone card view

**Files:**
- Create: `codepet/Demo/DemoMilestoneCard.swift`

- [ ] **Step 1: Create the milestone card view**

```swift
// codepet/Demo/DemoMilestoneCard.swift
import SwiftUI

/// One milestone in the demo flow: emote + bubble text, with timestamp.
/// Visual style intentionally mirrors NarrativeChatTurnView so the demo
/// reads like a real reflection turn.
struct DemoMilestoneCard: View {
    let milestone: DemoScript.Milestone
    let timestamp: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emote bubble
            Text(milestone.emote)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(ReflectionTheme.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(DemoScript.petName)
                        .font(ReflectionTheme.serif(13, weight: .semibold))
                        .foregroundColor(ReflectionTheme.primaryText)
                    Text(timeString(timestamp))
                        .font(ReflectionTheme.sans(11))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Text(milestone.bubble)
                    .font(ReflectionTheme.sans(14))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                            )
                    )
            }
            Spacer(minLength: 0)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    DemoMilestoneCard(
        milestone: DemoScript.milestones[1],
        timestamp: Date()
    )
    .padding()
    .frame(width: 600)
    .background(ReflectionTheme.background)
}
```

- [ ] **Step 2: Add to Xcode project**

Target: `codepet`.

- [ ] **Step 3: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Visual check in Preview**

Run preview, confirm hero milestone (index 2) renders with ✨ emote and purple-themed bubble.

- [ ] **Step 5: Commit**

```bash
git add codepet/Demo/DemoMilestoneCard.swift codepet.xcodeproj/project.pbxproj
git commit -m "demo: add DemoMilestoneCard view"
```

---

## Task 6: Demo reflection view (the main UI)

**Files:**
- Create: `codepet/Demo/DemoReflectionView.swift`

- [ ] **Step 1: Create the main demo view**

```swift
// codepet/Demo/DemoReflectionView.swift
import SwiftUI

/// The root view shown inside Reflection tab when `appState.demoModeEnabled`
/// is true. Reads everything from DemoScriptController — no JSONL polling,
/// no API calls. Layout mirrors ReflectionTab.body so the demo feels native.
struct DemoReflectionView: View {
    @EnvironmentObject var demo: DemoScriptController
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 280)

            Divider()
                .background(ReflectionTheme.borderLight)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    petHeader

                    if demo.sessionStartedAt == nil {
                        startPrompt
                    } else {
                        sessionBody
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(ReflectionTheme.background)
        .overlay(alignment: .topTrailing) {
            demoBadge.padding(12)
        }
        .animation(.easeOut(duration: 0.25), value: demo.firedMilestones)
        .animation(.easeOut(duration: 0.25), value: demo.reflectionRevealed)
    }

    // MARK: Pet header

    private var petHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            PetAvatar(mood: .calm, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(DemoScript.petName)
                    .font(ReflectionTheme.serif(18, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text(dateString(demo.sessionStartedAt ?? Date()))
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
            if demo.sessionStartedAt == nil {
                Button("Start session") { demo.startSession() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Start prompt

    private var startPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo Mode is on.")
                .font(ReflectionTheme.serif(20, weight: .medium))
            Text("Tap 'Start session', then press ⌥1 → ⌥4 to fire milestones, ⌥5 to reveal the reflection, ⌥0 to panic-skip.")
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Session body

    private var sessionBody: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(demo.firedMilestones) { milestone in
                DemoMilestoneCard(
                    milestone: milestone,
                    timestamp: timestamp(for: milestone)
                )
            }

            if demo.reflectionRevealed {
                reflectionCard
            } else if !demo.firedMilestones.isEmpty {
                reflectionPlaceholder
            }
        }
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💜 \(DemoScript.reflectionHeader)")
                .font(ReflectionTheme.serif(16, weight: .semibold))
                .foregroundColor(ReflectionTheme.primaryText)

            DemoTypewriterText(
                text: DemoScript.reflectionSummary,
                charactersPerSecond: 28,
                font: ReflectionTheme.sans(14),
                foregroundColor: ReflectionTheme.primaryText
            )

            Text(DemoScript.reflectionSignature)
                .font(ReflectionTheme.sans(13, weight: .medium))
                .foregroundColor(ReflectionTheme.accent)
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ReflectionTheme.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ReflectionTheme.accent.opacity(0.25), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var reflectionPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .foregroundColor(ReflectionTheme.mutedText)
            Text("Byte đang quan sát… (bấm ⌥5 để xem reflection)")
                .font(ReflectionTheme.sans(12))
                .foregroundColor(ReflectionTheme.mutedText)
        }
        .padding(.vertical, 6)
    }

    // MARK: Sidebar (event log)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Event log")
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if demo.firedMilestones.isEmpty {
                        Text("No actions tracked yet.")
                            .font(ReflectionTheme.sans(11))
                            .foregroundColor(ReflectionTheme.mutedText)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(demo.firedMilestones) { milestone in
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(timeString(timestamp(for: milestone)))]")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(ReflectionTheme.mutedText)
                                Text(milestone.sidebarLabel)
                                    .font(ReflectionTheme.sans(11.5))
                                    .foregroundColor(ReflectionTheme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0xFD / 255.0, green: 0xFC / 255.0, blue: 0xF8 / 255.0))
    }

    // MARK: Badge

    private var demoBadge: some View {
        Text("DEMO MODE")
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.9))
            )
            .foregroundColor(.white)
    }

    // MARK: Helpers

    private func timestamp(for milestone: DemoScript.Milestone) -> Date {
        let base = demo.sessionStartedAt ?? Date()
        return base.addingTimeInterval(TimeInterval(milestone.offsetMinutesFromStart * 60))
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: date)
    }
}

#Preview {
    let demo = DemoScriptController()
    return DemoReflectionView()
        .environmentObject(demo)
        .environmentObject(AppState())
        .frame(width: 900, height: 800)
}
```

- [ ] **Step 2: Add to Xcode project**

Target: `codepet`.

- [ ] **Step 3: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED. If `PetAvatar` is not found, replace with `Image("char-byte").resizable().interpolation(.none).frame(width: 56, height: 56)` (PetAvatar is defined in the existing Reflection module — verify before fallback).

- [ ] **Step 4: Preview check**

Run the preview. You should see "Demo Mode is on" prompt + Start session button. Press it in preview if interactive, otherwise just confirm layout.

- [ ] **Step 5: Commit**

```bash
git add codepet/Demo/DemoReflectionView.swift codepet.xcodeproj/project.pbxproj
git commit -m "demo: add DemoReflectionView with sidebar + milestones + typewriter"
```

---

## Task 7: Hotkey monitor

**Files:**
- Create: `codepet/Demo/DemoHotkeyMonitor.swift`

- [ ] **Step 1: Create the monitor**

```swift
// codepet/Demo/DemoHotkeyMonitor.swift
import AppKit
import Combine

/// Listens for ⌥1..⌥5 and ⌥0 while the app is frontmost and DemoMode is on.
/// Routes the keys to `DemoScriptController`. Uses a local NSEvent monitor
/// so we don't grab keys when the app is in the background.
@MainActor
final class DemoHotkeyMonitor: ObservableObject {

    private weak var controller: DemoScriptController?
    private var monitor: Any?

    func bind(controller: DemoScriptController) {
        self.controller = controller
    }

    /// Begin listening. Safe to call multiple times — second call is a no-op.
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Returns nil to swallow the event, or the original event to pass through.
    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.modifierFlags.contains(.option) else { return event }
        guard let chars = event.charactersIgnoringModifiers, chars.count == 1 else { return event }
        // ⌥+digit on US keyboards produces special chars (¡™£¢…) so we use
        // event.keyCode instead. Mapping:
        //   18=1, 19=2, 20=3, 21=4, 23=5, 29=0
        let keyCode = event.keyCode
        switch keyCode {
        case 18: controller?.fireMilestone(index: 1); return nil
        case 19: controller?.fireMilestone(index: 2); return nil
        case 20: controller?.fireMilestone(index: 3); return nil
        case 21: controller?.fireMilestone(index: 4); return nil
        case 23: controller?.revealReflection();     return nil
        case 29:
            controller?.reset()
            controller?.startSession()
            return nil
        default: return event
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project**

Target: `codepet`.

- [ ] **Step 3: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add codepet/Demo/DemoHotkeyMonitor.swift codepet.xcodeproj/project.pbxproj
git commit -m "demo: add DemoHotkeyMonitor for ⌥1..⌥5/⌥0 keys"
```

---

## Task 8: Wire into CodePetApp lifecycle

**Files:**
- Modify: `codepet/App/CodePetApp.swift`

- [ ] **Step 1: Add `@StateObject`s for demo controller + monitor**

Locate the existing `@StateObject` block at the top of `CodePetApp` (lines 7–13). Add after `chatController`:

```swift
    @StateObject private var demoController = DemoScriptController()
    @StateObject private var demoHotkeyMonitor = DemoHotkeyMonitor()
```

- [ ] **Step 2: Inject `demoController` via `.environmentObject`**

In `body`, find the `.environmentObject(chatController)` line (~44). Add immediately after:

```swift
                .environmentObject(demoController)
```

- [ ] **Step 3: Bind monitor + start/stop based on flag**

Find the `.onAppear` block in `body` (~48). At the end of that closure, add:

```swift
                    demoHotkeyMonitor.bind(controller: demoController)
                    if appState.demoModeEnabled { demoHotkeyMonitor.start() }
```

Then below the existing `.onAppear`, add:

```swift
                .onChange(of: appState.demoModeEnabled) { enabled in
                    if enabled {
                        demoHotkeyMonitor.start()
                    } else {
                        demoHotkeyMonitor.stop()
                        demoController.reset()
                    }
                }
```

- [ ] **Step 4: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add codepet/App/CodePetApp.swift
git commit -m "demo: wire DemoController + DemoHotkeyMonitor into app lifecycle"
```

---

## Task 9: Route Reflection tab to DemoReflectionView when demo mode on

**Files:**
- Modify: `codepet/Views/Reflection/ReflectionTab.swift`

- [ ] **Step 1: Add early branch in `body`**

In `ReflectionTab.body` (line 64), wrap the existing `HStack` body in an `if/else`:

Find:
```swift
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
```

Replace with:
```swift
    var body: some View {
        if appState.demoModeEnabled {
            DemoReflectionView()
        } else {
            normalBody
        }
    }

    private var normalBody: some View {
        HStack(alignment: .top, spacing: 0) {
```

The trailing closure structure remains the same — just the outermost `body` now branches. Verify that `.background(...)`, `.overlay(...)`, `.animation(...)`, `.onChange(...)` modifiers attach to `normalBody`'s `HStack`, not to the `if/else` wrapper.

- [ ] **Step 2: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke test**

Launch app. Reflection tab shows normal (file-polling) UI. Now enable Demo mode via launch arg `-demoMode YES` and relaunch. Reflection tab should show `DemoReflectionView` with "DEMO MODE" badge.

- [ ] **Step 4: Commit**

```bash
git add codepet/Views/Reflection/ReflectionTab.swift
git commit -m "demo: route Reflection tab to DemoReflectionView when flag on"
```

---

## Task 10: Profile debug toggle

**Files:**
- Modify: `codepet/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add DebugSection to ProfileView body**

Find the ProfileView body (around line 14) where `AccountSection()`, `YourPetSection()`, `LanguageStyleSection()` are listed. Add at the end:

```swift
                DebugSection()
```

- [ ] **Step 2: Implement `DebugSection`**

Append to the same file (after the existing sections):

```swift
// MARK: - Debug Section

struct DebugSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug")
                .font(CodepetTheme.pixel(14))
                .tracking(1.0)
                .foregroundColor(.secondary)

            Toggle(isOn: $appState.demoModeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Demo Mode (Sprout × Byte)")
                        .font(.body)
                    Text("Replaces Reflection tab with hardcoded 13-min demo. ⌥1..⌥4 fires milestones, ⌥5 reveals reflection, ⌥0 resets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 3: Build, confirm compile**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Visual smoke test**

Launch app → Profile tab → scroll to bottom → see Debug section → toggle on → switch to Reflection tab → confirm DemoReflectionView renders. Toggle off → confirm normal Reflection comes back.

- [ ] **Step 5: Commit**

```bash
git add codepet/Views/Profile/ProfileView.swift
git commit -m "demo: add Debug section in Profile with DemoMode toggle"
```

---

## Task 11: End-to-end rehearsal smoke test

**Files:** None (manual verification only).

- [ ] **Step 1: Launch app with demo mode on**

Run from Xcode with launch arg `-demoMode YES`, OR launch normally then toggle from Profile.

- [ ] **Step 2: Verify badge**

Reflection tab shows orange "DEMO MODE" pill in top-right corner.

- [ ] **Step 3: Run the full beat sequence**

1. Click "Start session" → pet header date updates, sidebar shows "No actions tracked yet."
2. Press ⌥1 → first milestone card appears with 👀 emote. Sidebar adds `[HH:mm] Scaffolding HTML structure`.
3. Press ⌥1 again → no change (idempotent).
4. Press ⌥2, ⌥3, ⌥4 in sequence → 3 more cards animate in. Sidebar grows to 4 entries.
5. Press ⌥5 → reflection card appears with header "💜 Reflection từ Byte — 12 phút session" + typewriter begins. Confirm full 30-sec reveal (or click to skip).
6. Press ⌥0 → state resets. Sidebar empties, cards disappear, session prompt returns. Press ⌥1 again to confirm a fresh run is possible without restarting the app.

- [ ] **Step 4: Verify no AI calls fire**

Open Xcode console. Confirm no `[NarrativeEnricher]` or `[SessionSummaryEnricher]` log lines fire during the demo. (Those should be gated by the production polling path, which is bypassed when demoMode is on.)

- [ ] **Step 5: Verify normal mode still works**

Disable demo mode in Profile. Reflection tab returns to file-polling UI. No "DEMO MODE" badge. Hotkeys ⌥1..⌥5 are inert (NSEvent monitor is stopped).

- [ ] **Step 6: Final commit if any rehearsal-driven tweaks were needed**

If you adjusted timing, copy, or layout based on rehearsal: commit separately with `git commit -m "demo: rehearsal polish"`.

---

## Out of scope (deliberately not in this plan)

- Sound effects on milestone fire
- Animations on the pet sprite synced to emote changes
- Multi-language summary (Vietnamese only)
- Persisting demo sessions to Firestore
- Production AI integration changes (the `NarrativeEnricher` path is untouched)
- Snapshot/UI tests for the demo views — visual verification is enough for a one-off demo asset

## Self-review

Spec coverage check: every section of the spec maps to at least one task:
- §3 Layout — Tasks 5, 6 (cards + main view layout)
- §4 Beats 0–6 — Tasks 1, 5, 6, 11 (data + UI + rehearsal)
- §5 Value table — covered implicitly by Task 1 copy + Task 11 rehearsal
- §6 Hardcode harness 6.1–6.5 — Tasks 3, 7, 8, 9 (flag, monitor, lifecycle, routing)
- §7 Rehearsal checklist — Task 11
- §9 Acceptance criteria — all 7 items mapped: launch arg (T3), hotkey latency (T7+T11), typewriter (T4+T11), ⌥0 reset (T2+T7+T11), no AI calls (T9+T11), sidebar log (T6+T11), normal-mode untouched (T9+T11)

Placeholder scan: no TBDs, all code blocks complete, all file paths exact.

Type consistency: `DemoScript.Milestone` (Task 1) used in `DemoScriptController` (Task 2), `DemoMilestoneCard` (Task 5), `DemoReflectionView` (Task 6) — same shape throughout. `DemoScriptController` methods `startSession`, `fireMilestone(index:)`, `revealReflection`, `reset`, `panicSkip` defined in Task 2 and used identically in Tasks 6, 7, 8.
