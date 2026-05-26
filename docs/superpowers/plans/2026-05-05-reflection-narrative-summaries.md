# Reflection Narrative Summaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the technical event list in CodePet's Reflection tab with AI-generated per-turn narratives (Bạn muốn / Đã làm / Bài học), generated via a Firebase Cloud Function calling Claude Haiku.

**Architecture:** Capture layer (hooks → `events.jsonl`) is unchanged. New `TurnAssembler` groups events into `Turn`s; `NarrativeEnricher` POSTs each finished turn to a new `summarizeTurn` Firebase Cloud Function which calls Claude Haiku with tool-use enforced JSON; the response is appended to `narratives.jsonl`; `NarrativeStore` polls that file and merges by `turn_id`; the rewritten `ReflectionTab` renders the 3-section narrative with raw events hidden behind a toggle.

**Tech Stack:**
- Swift / SwiftUI / XCTest (in-app)
- Firebase Functions v2 + TypeScript + `@anthropic-ai/sdk` + Jest + Firebase emulator (Cloud Function)
- Firestore (rate limit + idempotency cache)
- Existing: Firebase Auth (anonymous + email + Google)

**Spec:** `docs/superpowers/specs/2026-05-05-reflection-narrative-summaries-design.md`

---

## File Structure

### New files (Swift)

```
codepet/Models/
  └── Turn.swift                    Turn, Narrative, TurnState, FailureReason

codepet/Managers/
  ├── TurnAssembler.swift           Pure function: [CapturedEvent] -> [Turn]
  ├── NarrativeStore.swift          Polls narratives.jsonl, exposes [String: Narrative]
  └── NarrativeEnricher.swift       Serial queue, calls API, appends to narratives.jsonl

codepet/Services/
  └── ReflectionAPIClient.swift     Firebase Functions client, ID token + POST

codepet/Views/Reflection/
  ├── NarrativeBodyView.swift       3-section narrative render
  ├── TurnLoadingStates.swift       pending / summarizing / failed views
  └── TechnicalDetailsView.swift    Collapsed raw events
```

### Modified files (Swift)

```
codepet/App/CodePetApp.swift              Inject NarrativeStore + NarrativeEnricher, .start() on launch
codepet/Views/Reflection/ReflectionTab.swift   Rewrite to use Turn list and new components
```

### New files (Cloud Function)

```
functions/
  ├── package.json
  ├── tsconfig.json
  ├── jest.config.js
  ├── .gitignore
  └── src/
      ├── index.ts                  Function exports
      ├── auth.ts                   verifyIdToken middleware
      ├── rateLimit.ts              Firestore counter
      ├── cache.ts                  Idempotency cache
      ├── anthropic.ts              Claude Haiku call + tool schema
      ├── summarizeTurn.ts          Main handler
      └── __tests__/
          ├── rateLimit.test.ts
          ├── cache.test.ts
          ├── anthropic.test.ts
          └── summarizeTurn.test.ts
```

### Modified files (project root)

```
firebase.json                       Add functions deploy config
.firebaserc                         New — pin project ID
```

---

## Task 1: Turn data model

**Files:**
- Create: `codepet/Models/Turn.swift`
- Test: `codepetTests/TurnTests.swift`

- [ ] **Step 1: Write the failing test**

Create `codepetTests/TurnTests.swift`:

```swift
import XCTest
@testable import codepet

final class TurnTests: XCTestCase {
    func testTurnIDIsDeterministic() {
        let id = Turn.makeID(sessionId: "abc123", promptISO: "2026-05-05T09:15:23Z")
        XCTAssertEqual(id, "abc123:2026-05-05T09:15:23Z")
    }

    func testNarrativeRoundTripJSON() throws {
        let n = Narrative(
            title: "Test",
            whatYouWanted: "want",
            whatHappened: "did",
            lesson: "learned",
            model: "claude-haiku-4-5-20251001",
            generatedAt: Date(timeIntervalSince1970: 0),
            schemaVersion: 1
        )
        let data = try JSONEncoder().encode(n)
        let decoded = try JSONDecoder().decode(Narrative.self, from: data)
        XCTAssertEqual(decoded.title, "Test")
        XCTAssertEqual(decoded.lesson, "learned")
    }

    func testTurnStateEquatable() {
        XCTAssertEqual(TurnState.pending, .pending)
        XCTAssertNotEqual(TurnState.failed(reason: .auth), .failed(reason: .quota))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/TurnTests`
Expected: FAIL with "Cannot find 'Turn' in scope"

- [ ] **Step 3: Write the implementation**

Create `codepet/Models/Turn.swift`:

```swift
import Foundation

struct Narrative: Codable, Hashable {
    let title: String          // ≤60 chars
    let whatYouWanted: String  // ≤240 chars
    let whatHappened: String   // ≤240 chars
    let lesson: String         // ≤240 chars or "" if none
    let model: String
    let generatedAt: Date
    let schemaVersion: Int

    enum CodingKeys: String, CodingKey {
        case title
        case whatYouWanted = "what_you_wanted"
        case whatHappened = "what_happened"
        case lesson
        case model
        case generatedAt = "generated_at"
        case schemaVersion = "schema_version"
    }
}

enum FailureReason: String, Codable, Hashable {
    case network
    case auth
    case quota
    case badResponse = "bad_response"
    case unknown
}

enum TurnState: Hashable {
    case pending           // no Stop event yet
    case summarizing       // API call in flight
    case ready             // narrative present
    case failed(reason: FailureReason)
    case pendingOrphan     // no Stop event after 30 min
}

struct Turn: Identifiable, Hashable {
    let id: String              // turn_id
    let sessionId: String
    let startedAt: Date
    let endedAt: Date?
    let prompt: String
    let rawEvents: [CapturedEvent]
    let narrative: Narrative?
    let state: TurnState

    static func makeID(sessionId: String, promptISO: String) -> String {
        "\(sessionId):\(promptISO)"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/TurnTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add codepet/Models/Turn.swift codepetTests/TurnTests.swift
git commit -m "Add Turn / Narrative data model for reflection summaries"
```

---

## Task 2: TurnAssembler

**Files:**
- Create: `codepet/Managers/TurnAssembler.swift`
- Test: `codepetTests/TurnAssemblerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `codepetTests/TurnAssemblerTests.swift`:

```swift
import XCTest
@testable import codepet

final class TurnAssemblerTests: XCTestCase {
    private let session = "session-A"

    private func makeEvent(
        time: String,
        text: String,
        sessionId: String? = nil,
        source: EventSource = .claudeCode
    ) -> CapturedEvent {
        CapturedEvent(
            time: time,
            source: source,
            text: text,
            sessionId: sessionId ?? session
        )
    }

    func testSingleTurnHappyPath() {
        // prompt + 2 tools + summary -> 1 ready-shape turn
        let prompt = AssemblerInput(
            kind: .prompt(text: "fix the bug"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let tool1 = AssemblerInput(
            kind: .tool(text: "Edit"),
            isoTime: "2026-05-05T09:00:30Z",
            sessionId: session
        )
        let tool2 = AssemblerInput(
            kind: .tool(text: "Bash"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )
        let summary = AssemblerInput(
            kind: .summary(text: "Edit foo.swift · Bash: git commit"),
            isoTime: "2026-05-05T09:02:00Z",
            sessionId: session
        )

        let turns = TurnAssembler.assemble(
            inputs: [prompt, tool1, tool2, summary],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        let t = turns[0]
        XCTAssertEqual(t.sessionId, session)
        XCTAssertEqual(t.prompt, "fix the bug")
        XCTAssertEqual(t.rawEvents.count, 2)
        XCTAssertEqual(t.state, .summarizing)  // closed but no narrative
        XCTAssertNotNil(t.endedAt)
    }

    func testTwoPromptsBackToBackFirstIsOrphan() {
        let p1 = AssemblerInput(
            kind: .prompt(text: "first"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let p2 = AssemblerInput(
            kind: .prompt(text: "second"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )
        let s2 = AssemblerInput(
            kind: .summary(text: "did stuff"),
            isoTime: "2026-05-05T09:02:00Z",
            sessionId: session
        )

        let turns = TurnAssembler.assemble(
            inputs: [p1, p2, s2],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 2)
        // Sorted by startedAt descending => second prompt first
        XCTAssertEqual(turns[0].prompt, "second")
        XCTAssertEqual(turns[1].prompt, "first")
        XCTAssertEqual(turns[1].state, .pendingOrphan)
    }

    func testPromptWithNoSummaryWithin30MinutesIsOrphan() {
        let p = AssemblerInput(
            kind: .prompt(text: "abandoned"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let now = ISO8601DateFormatter().date(from: "2026-05-05T09:35:00Z")!

        let turns = TurnAssembler.assemble(
            inputs: [p],
            now: now,
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].state, .pendingOrphan)
    }

    func testPromptWithNoSummaryWithin30MinutesIsPending() {
        let p = AssemblerInput(
            kind: .prompt(text: "still going"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let now = ISO8601DateFormatter().date(from: "2026-05-05T09:10:00Z")!

        let turns = TurnAssembler.assemble(
            inputs: [p],
            now: now,
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].state, .pending)
    }

    func testSummaryBeforePromptIsIgnored() {
        let s = AssemblerInput(
            kind: .summary(text: "lost"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let p = AssemblerInput(
            kind: .prompt(text: "first prompt"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )

        let turns = TurnAssembler.assemble(
            inputs: [s, p],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].prompt, "first prompt")
        XCTAssertEqual(turns[0].state, .pending)
    }

    func testNarrativeMergedWhenAvailable() {
        let p = AssemblerInput(
            kind: .prompt(text: "summarize me"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let s = AssemblerInput(
            kind: .summary(text: "raw"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )
        let id = Turn.makeID(sessionId: session, promptISO: "2026-05-05T09:00:00Z")
        let n = Narrative(
            title: "T",
            whatYouWanted: "w",
            whatHappened: "h",
            lesson: "l",
            model: "m",
            generatedAt: Date(),
            schemaVersion: 1
        )

        let turns = TurnAssembler.assemble(
            inputs: [p, s],
            now: Date(),
            narratives: [id: n]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertNotNil(turns[0].narrative)
        XCTAssertEqual(turns[0].state, .ready)
    }

    func testInterleavedSessionsKeptSeparate() {
        let pA = AssemblerInput(
            kind: .prompt(text: "A1"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: "A"
        )
        let pB = AssemblerInput(
            kind: .prompt(text: "B1"),
            isoTime: "2026-05-05T09:00:30Z",
            sessionId: "B"
        )
        let sA = AssemblerInput(
            kind: .summary(text: "A done"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: "A"
        )
        let sB = AssemblerInput(
            kind: .summary(text: "B done"),
            isoTime: "2026-05-05T09:01:30Z",
            sessionId: "B"
        )

        let turns = TurnAssembler.assemble(
            inputs: [pA, pB, sA, sB],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(Set(turns.map { $0.sessionId }), ["A", "B"])
        XCTAssertTrue(turns.allSatisfy { $0.state == .summarizing })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/TurnAssemblerTests`
Expected: FAIL — "Cannot find 'TurnAssembler' / 'AssemblerInput' in scope"

- [ ] **Step 3: Write the implementation**

Create `codepet/Managers/TurnAssembler.swift`:

```swift
import Foundation

/// Input to the assembler. Source events from `events.jsonl` and `narratives.jsonl`
/// are converted to this shape before assembly so the assembler stays pure.
struct AssemblerInput {
    enum Kind {
        case prompt(text: String)
        case tool(text: String)
        case summary(text: String)
    }
    let kind: Kind
    let isoTime: String           // raw ISO 8601 — used for turn_id
    let sessionId: String
}

enum TurnAssembler {

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Group inputs into Turns. Pure — no I/O.
    static func assemble(
        inputs: [AssemblerInput],
        now: Date,
        narratives: [String: Narrative]
    ) -> [Turn] {
        let sorted = inputs.sorted { lhs, rhs in
            if lhs.sessionId != rhs.sessionId { return lhs.sessionId < rhs.sessionId }
            return lhs.isoTime < rhs.isoTime
        }

        var turns: [Turn] = []
        var sessionGroups: [String: [AssemblerInput]] = [:]
        for input in sorted { sessionGroups[input.sessionId, default: []].append(input) }

        for (sessionId, events) in sessionGroups {
            turns.append(contentsOf: assembleSession(
                sessionId: sessionId,
                events: events,
                now: now,
                narratives: narratives
            ))
        }

        return turns.sorted { $0.startedAt > $1.startedAt }
    }

    private static func assembleSession(
        sessionId: String,
        events: [AssemblerInput],
        now: Date,
        narratives: [String: Narrative]
    ) -> [Turn] {
        var turns: [Turn] = []

        // Drop summary events that arrive before any prompt.
        var pendingPrompt: AssemblerInput? = nil
        var pendingTools: [AssemblerInput] = []

        func flushAsOrphan() {
            guard let prompt = pendingPrompt,
                  case .prompt(let text) = prompt.kind,
                  let started = isoFormatter.date(from: prompt.isoTime) else { return }
            turns.append(makeTurn(
                prompt: text,
                started: started,
                ended: nil,
                tools: pendingTools,
                sessionId: sessionId,
                promptISO: prompt.isoTime,
                narratives: narratives,
                forceState: .pendingOrphan
            ))
            pendingPrompt = nil
            pendingTools = []
        }

        for input in events {
            switch input.kind {
            case .prompt:
                if pendingPrompt != nil {
                    flushAsOrphan()  // previous prompt orphaned by new prompt
                }
                pendingPrompt = input
                pendingTools = []
            case .tool:
                if pendingPrompt != nil { pendingTools.append(input) }
            case .summary:
                guard let prompt = pendingPrompt,
                      case .prompt(let promptText) = prompt.kind,
                      let started = isoFormatter.date(from: prompt.isoTime),
                      let ended = isoFormatter.date(from: input.isoTime) else { continue }
                turns.append(makeTurn(
                    prompt: promptText,
                    started: started,
                    ended: ended,
                    tools: pendingTools,
                    sessionId: sessionId,
                    promptISO: prompt.isoTime,
                    narratives: narratives,
                    forceState: nil
                ))
                pendingPrompt = nil
                pendingTools = []
            }
        }

        // Trailing prompt with no summary
        if let prompt = pendingPrompt,
           case .prompt(let text) = prompt.kind,
           let started = isoFormatter.date(from: prompt.isoTime) {
            let age = now.timeIntervalSince(started)
            let state: TurnState = age > 30 * 60 ? .pendingOrphan : .pending
            turns.append(makeTurn(
                prompt: text,
                started: started,
                ended: nil,
                tools: pendingTools,
                sessionId: sessionId,
                promptISO: prompt.isoTime,
                narratives: narratives,
                forceState: state
            ))
        }

        return turns
    }

    private static func makeTurn(
        prompt: String,
        started: Date,
        ended: Date?,
        tools: [AssemblerInput],
        sessionId: String,
        promptISO: String,
        narratives: [String: Narrative],
        forceState: TurnState?
    ) -> Turn {
        let id = Turn.makeID(sessionId: sessionId, promptISO: promptISO)
        let narrative = narratives[id]

        let state: TurnState
        if let forced = forceState {
            state = forced
        } else if narrative != nil {
            state = .ready
        } else if ended != nil {
            state = .summarizing
        } else {
            state = .pending
        }

        let rawEvents: [CapturedEvent] = tools.map { input in
            let displayTime = displayHHmm(input.isoTime)
            let text: String
            if case .tool(let t) = input.kind { text = t } else { text = "" }
            return CapturedEvent(
                time: displayTime,
                source: .claudeCode,
                text: text,
                sessionId: sessionId
            )
        }

        return Turn(
            id: id,
            sessionId: sessionId,
            startedAt: started,
            endedAt: ended,
            prompt: prompt,
            rawEvents: rawEvents,
            narrative: narrative,
            state: state
        )
    }

    private static func displayHHmm(_ iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/TurnAssemblerTests`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add codepet/Managers/TurnAssembler.swift codepetTests/TurnAssemblerTests.swift
git commit -m "Add TurnAssembler — group events into Turns by session and Stop boundary"
```

---

## Task 3: NarrativeStore

**Files:**
- Create: `codepet/Managers/NarrativeStore.swift`
- Test: `codepetTests/NarrativeStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `codepetTests/NarrativeStoreTests.swift`:

```swift
import XCTest
@testable import codepet

@MainActor
final class NarrativeStoreTests: XCTestCase {
    private var tmpURL: URL!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("narrative-store-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tmpURL = dir.appendingPathComponent("narratives.jsonl")
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }

    private func append(_ line: String) {
        let data = (line + "\n").data(using: .utf8)!
        let handle = try! FileHandle(forWritingTo: tmpURL)
        defer { try? handle.close() }
        try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }

    private func sampleLine(turnId: String, title: String) -> String {
        let n: [String: Any] = [
            "turn_id": turnId,
            "session_id": "s",
            "generated_at": "2026-05-05T09:18:42Z",
            "title": title,
            "what_you_wanted": "w",
            "what_happened": "h",
            "lesson": "l",
            "model": "claude-haiku-4-5-20251001",
            "schema_version": 1
        ]
        let data = try! JSONSerialization.data(withJSONObject: n)
        return String(data: data, encoding: .utf8)!
    }

    func testReadsExistingLinesOnStart() async {
        append(sampleLine(turnId: "t1", title: "First"))
        append(sampleLine(turnId: "t2", title: "Second"))

        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.startForTesting()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.narratives.count, 2)
        XCTAssertEqual(store.narratives["t1"]?.title, "First")
        XCTAssertEqual(store.narratives["t2"]?.title, "Second")
        store.stop()
    }

    func testIncrementalReadOnNewLines() async {
        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.startForTesting()
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(store.narratives.count, 0)

        append(sampleLine(turnId: "t1", title: "Live"))
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.narratives["t1"]?.title, "Live")
        store.stop()
    }

    func testSkipsCorruptLinesAndContinues() async {
        append(sampleLine(turnId: "t1", title: "Good"))
        append("{not valid json")
        append(sampleLine(turnId: "t2", title: "AlsoGood"))

        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.startForTesting()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.narratives.count, 2)
        store.stop()
    }

    func testDuplicateTurnIDLastWriteWins() async {
        append(sampleLine(turnId: "t1", title: "First"))
        append(sampleLine(turnId: "t1", title: "Second"))

        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.startForTesting()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.narratives.count, 1)
        XCTAssertEqual(store.narratives["t1"]?.title, "Second")
        store.stop()
    }

    func testFileMissingIsCreated() async {
        try? FileManager.default.removeItem(at: tmpURL)

        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.startForTesting()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpURL.path))
        store.stop()
    }

    func testFileShrinkResetsOffset() async {
        append(sampleLine(turnId: "t1", title: "Early"))

        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.startForTesting()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(store.narratives.count, 1)

        // Truncate then write fresh content
        try? FileManager.default.removeItem(at: tmpURL)
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        append(sampleLine(turnId: "t99", title: "New"))
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(store.narratives["t99"])
        store.stop()
    }

    func testAppendNarrativeWritesToFile() async throws {
        let store = NarrativeStore(fileURL: tmpURL, pollInterval: 1.0)

        let n = Narrative(
            title: "T",
            whatYouWanted: "w",
            whatHappened: "h",
            lesson: "l",
            model: "claude-haiku-4-5-20251001",
            generatedAt: Date(timeIntervalSince1970: 0),
            schemaVersion: 1
        )
        try store.appendNarrative(turnId: "t1", sessionId: "s", narrative: n)

        let contents = try String(contentsOf: tmpURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("\"turn_id\":\"t1\""))
        XCTAssertTrue(contents.contains("\"title\":\"T\""))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/NarrativeStoreTests`
Expected: FAIL — `NarrativeStore` not defined

- [ ] **Step 3: Write the implementation**

Create `codepet/Managers/NarrativeStore.swift`:

```swift
import Foundation
import Combine
import os

/// Polls narratives.jsonl (written by NarrativeEnricher) and exposes
/// narratives keyed by turn_id. Mirrors ReflectionEventStore polling pattern.
@MainActor
final class NarrativeStore: ObservableObject {

    @Published private(set) var narratives: [String: Narrative] = [:]

    private let fileURL: URL
    private let pollInterval: TimeInterval
    private var pollTimer: Timer?
    private var readOffset: UInt64 = 0
    private var lineBuffer = ""
    private let logger = Logger(subsystem: "app.murror.codepet", category: "NarrativeStore")
    private let decoder = JSONDecoder()

    init(
        fileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codepet/narratives.jsonl"),
        pollInterval: TimeInterval = 1.5
    ) {
        self.fileURL = fileURL
        self.pollInterval = pollInterval
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func start() {
        ensureFileExists()
        readOffset = 0
        readNewLines()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readNewLines() }
        }
    }

    /// Test helper: deterministic prime + start
    func startForTesting() {
        start()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Append a narrative line. Used by NarrativeEnricher.
    func appendNarrative(turnId: String, sessionId: String, narrative: Narrative) throws {
        ensureFileExists()
        let payload = try encodeLine(turnId: turnId, sessionId: sessionId, narrative: narrative)
        let data = (payload + "\n").data(using: .utf8)!
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        // Update in-memory immediately; poll will see same line and overwrite (last-write-wins).
        narratives[turnId] = narrative
    }

    private func encodeLine(turnId: String, sessionId: String, narrative: Narrative) throws -> String {
        var dict: [String: Any] = [
            "turn_id": turnId,
            "session_id": sessionId,
            "generated_at": ISO8601DateFormatter.shared.string(from: narrative.generatedAt),
            "title": narrative.title,
            "what_you_wanted": narrative.whatYouWanted,
            "what_happened": narrative.whatHappened,
            "lesson": narrative.lesson,
            "model": narrative.model,
            "schema_version": narrative.schemaVersion
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - File I/O

    private func ensureFileExists() {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    private func currentFileSize() -> UInt64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.size] as? UInt64) ?? 0
    }

    private func readNewLines() {
        ensureFileExists()
        let size = currentFileSize()
        if size < readOffset {
            readOffset = 0
            lineBuffer = ""
        }
        guard size > readOffset else { return }

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        defer { try? handle.close() }
        do { try handle.seek(toOffset: readOffset) } catch {
            logger.warning("seek failed: \(error.localizedDescription)")
            return
        }
        guard let chunk = try? handle.readToEnd(), !chunk.isEmpty else { return }
        readOffset += UInt64(chunk.count)
        guard let text = String(data: chunk, encoding: .utf8) else { return }
        lineBuffer.append(text)

        var lines = lineBuffer.components(separatedBy: "\n")
        let trailing = lines.removeLast()
        lineBuffer = trailing

        for line in lines where !line.isEmpty {
            guard let data = line.data(using: .utf8) else { continue }
            do {
                let row = try decoder.decode(NarrativeLine.self, from: data)
                narratives[row.turn_id] = row.toNarrative()
            } catch {
                logger.warning("skipping malformed narrative line")
            }
        }
    }
}

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

private struct NarrativeLine: Decodable {
    let turn_id: String
    let session_id: String
    let generated_at: String
    let title: String
    let what_you_wanted: String
    let what_happened: String
    let lesson: String
    let model: String
    let schema_version: Int

    func toNarrative() -> Narrative {
        let date = ISO8601DateFormatter.shared.date(from: generated_at) ?? Date()
        return Narrative(
            title: title,
            whatYouWanted: what_you_wanted,
            whatHappened: what_happened,
            lesson: lesson,
            model: model,
            generatedAt: date,
            schemaVersion: schema_version
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/NarrativeStoreTests`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add codepet/Managers/NarrativeStore.swift codepetTests/NarrativeStoreTests.swift
git commit -m "Add NarrativeStore — poll narratives.jsonl, expose [turn_id: Narrative]"
```

---

## Task 4: Bootstrap Firebase Functions package

**Files:**
- Create: `firebase.json`
- Create: `.firebaserc`
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/jest.config.js`
- Create: `functions/.gitignore`
- Create: `functions/src/index.ts`

- [ ] **Step 1: Create `.firebaserc` pinning project**

Create `.firebaserc`:

```json
{
  "projects": {
    "default": "devpet-8f4b1"
  }
}
```

- [ ] **Step 2: Create `firebase.json`**

Create `firebase.json`:

```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "**/*.log",
        "**/__tests__/**"
      ],
      "predeploy": [
        "npm --prefix \"$RESOURCE_DIR\" run build"
      ]
    }
  ]
}
```

- [ ] **Step 3: Create `functions/package.json`**

Create `functions/package.json`:

```json
{
  "name": "codepet-functions",
  "version": "0.1.0",
  "description": "Firebase Cloud Functions for CodePet reflection summaries",
  "main": "lib/index.js",
  "engines": {
    "node": "20"
  },
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "test": "jest",
    "serve": "npm run build && firebase emulators:start --only functions",
    "deploy": "firebase deploy --only functions"
  },
  "dependencies": {
    "@anthropic-ai/sdk": "^0.40.0",
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^20.0.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.0",
    "typescript": "^5.4.0"
  },
  "private": true
}
```

- [ ] **Step 4: Create `functions/tsconfig.json`**

Create `functions/tsconfig.json`:

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2022",
    "lib": ["es2022"],
    "outDir": "lib",
    "strict": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "lib", "src/**/__tests__/**"]
}
```

- [ ] **Step 5: Create `functions/jest.config.js`**

Create `functions/jest.config.js`:

```javascript
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/__tests__/**/*.test.ts"],
  collectCoverageFrom: ["src/**/*.ts", "!src/**/__tests__/**"],
  testTimeout: 10000
};
```

- [ ] **Step 6: Create `functions/.gitignore`**

Create `functions/.gitignore`:

```
node_modules
lib
*.log
.env
```

- [ ] **Step 7: Create stub `functions/src/index.ts`**

Create `functions/src/index.ts`:

```typescript
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

export const summarizeTurn = onRequest({ cors: false }, async (_req, res) => {
  res.status(501).json({ error: "not_implemented" });
});
```

- [ ] **Step 8: Install deps and verify build**

Run:
```bash
cd functions && npm install && npm run build
```
Expected: build succeeds, `functions/lib/index.js` exists.

- [ ] **Step 9: Commit**

```bash
git add firebase.json .firebaserc functions/
git commit -m "Bootstrap Firebase Functions package for reflection summaries"
```

---

## Task 5: Auth middleware

**Files:**
- Create: `functions/src/auth.ts`
- Create: `functions/src/__tests__/auth.test.ts`

- [ ] **Step 1: Write failing test**

Create `functions/src/__tests__/auth.test.ts`:

```typescript
import { extractBearerToken } from "../auth";

describe("extractBearerToken", () => {
  test("returns token from Bearer header", () => {
    expect(extractBearerToken("Bearer abc.def.ghi")).toBe("abc.def.ghi");
  });

  test("returns null for missing header", () => {
    expect(extractBearerToken(undefined)).toBeNull();
  });

  test("returns null for non-Bearer scheme", () => {
    expect(extractBearerToken("Basic abc")).toBeNull();
  });

  test("returns null for empty token", () => {
    expect(extractBearerToken("Bearer ")).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- auth`
Expected: FAIL — `auth.ts` not found

- [ ] **Step 3: Write the implementation**

Create `functions/src/auth.ts`:

```typescript
import * as admin from "firebase-admin";

export function extractBearerToken(header: string | undefined): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/.exec(header);
  if (!match) return null;
  const token = match[1].trim();
  return token.length > 0 ? token : null;
}

export interface AuthResult {
  uid: string;
}

/**
 * Verifies the Authorization header on a request.
 * Returns { uid } on success, or null on failure (caller must respond 401).
 */
export async function verifyAuth(
  authHeader: string | undefined
): Promise<AuthResult | null> {
  const token = extractBearerToken(authHeader);
  if (!token) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return { uid: decoded.uid };
  } catch {
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `cd functions && npm test -- auth`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add functions/src/auth.ts functions/src/__tests__/auth.test.ts
git commit -m "Add Firebase auth middleware for summarizeTurn"
```

---

## Task 6: Rate limit module

**Files:**
- Create: `functions/src/rateLimit.ts`
- Create: `functions/src/__tests__/rateLimit.test.ts`

- [ ] **Step 1: Write failing test**

Create `functions/src/__tests__/rateLimit.test.ts`:

```typescript
import { todayKey, computeResetAt } from "../rateLimit";

describe("rateLimit helpers", () => {
  test("todayKey returns YYYY-MM-DD UTC", () => {
    const d = new Date("2026-05-05T23:59:59Z");
    expect(todayKey(d)).toBe("2026-05-05");
  });

  test("todayKey is UTC-based across timezones", () => {
    const d = new Date("2026-05-05T00:00:01Z");
    expect(todayKey(d)).toBe("2026-05-05");
  });

  test("computeResetAt returns next 00:00 UTC", () => {
    const d = new Date("2026-05-05T15:30:00Z");
    expect(computeResetAt(d).toISOString()).toBe("2026-05-06T00:00:00.000Z");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- rateLimit`
Expected: FAIL — `rateLimit.ts` not found

- [ ] **Step 3: Write the implementation**

Create `functions/src/rateLimit.ts`:

```typescript
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

export const DAILY_LIMIT = 50;

export function todayKey(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);  // YYYY-MM-DD UTC
}

export function computeResetAt(now: Date = new Date()): Date {
  const next = new Date(now);
  next.setUTCHours(0, 0, 0, 0);
  next.setUTCDate(next.getUTCDate() + 1);
  return next;
}

export interface RateLimitResult {
  allowed: boolean;
  count: number;
  limit: number;
  resetAt: Date;
}

/**
 * Atomic increment-and-check. Reads current count, increments, returns whether
 * the call is allowed. Uses Firestore transaction to avoid race conditions.
 */
export async function checkAndIncrement(
  uid: string,
  now: Date = new Date()
): Promise<RateLimitResult> {
  const db = admin.firestore();
  const ref = db.collection("usage").doc(uid);
  const key = todayKey(now);
  const resetAt = computeResetAt(now);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.exists ? snap.data() : {}) as Record<string, number>;
    const count = data[key] ?? 0;

    if (count >= DAILY_LIMIT) {
      return { allowed: false, count, limit: DAILY_LIMIT, resetAt };
    }

    tx.set(ref, { [key]: FieldValue.increment(1) }, { merge: true });
    return { allowed: true, count: count + 1, limit: DAILY_LIMIT, resetAt };
  });
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `cd functions && npm test -- rateLimit`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add functions/src/rateLimit.ts functions/src/__tests__/rateLimit.test.ts
git commit -m "Add rate limit module — 50 turns/day/uid via Firestore counter"
```

---

## Task 7: Idempotency cache module

**Files:**
- Create: `functions/src/cache.ts`
- Create: `functions/src/__tests__/cache.test.ts`

- [ ] **Step 1: Write failing test**

Create `functions/src/__tests__/cache.test.ts`:

```typescript
import { cacheKey, isCacheEntryFresh } from "../cache";

describe("cache helpers", () => {
  test("cacheKey combines uid and turn_id", () => {
    expect(cacheKey("uid1", "session:2026-05-05T09:00:00Z"))
      .toBe("uid1__session:2026-05-05T09:00:00Z");
  });

  test("isCacheEntryFresh true within 7 days", () => {
    const now = new Date("2026-05-10T00:00:00Z");
    const cached = new Date("2026-05-05T00:00:00Z");
    expect(isCacheEntryFresh(cached, now)).toBe(true);
  });

  test("isCacheEntryFresh false beyond 7 days", () => {
    const now = new Date("2026-05-13T00:00:01Z");
    const cached = new Date("2026-05-05T00:00:00Z");
    expect(isCacheEntryFresh(cached, now)).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- cache`
Expected: FAIL — `cache.ts` not found

- [ ] **Step 3: Write the implementation**

Create `functions/src/cache.ts`:

```typescript
import * as admin from "firebase-admin";

export interface CachedNarrative {
  title: string;
  what_you_wanted: string;
  what_happened: string;
  lesson: string;
  model: string;
}

const TTL_DAYS = 7;
const TTL_MS = TTL_DAYS * 24 * 60 * 60 * 1000;

export function cacheKey(uid: string, turnId: string): string {
  return `${uid}__${turnId}`;
}

export function isCacheEntryFresh(generatedAt: Date, now: Date = new Date()): boolean {
  return now.getTime() - generatedAt.getTime() < TTL_MS;
}

export async function getCached(
  uid: string,
  turnId: string,
  now: Date = new Date()
): Promise<CachedNarrative | null> {
  const db = admin.firestore();
  const ref = db.collection("narratives_cache").doc(cacheKey(uid, turnId));
  const snap = await ref.get();
  if (!snap.exists) return null;
  const data = snap.data() as { narrative: CachedNarrative; generated_at: admin.firestore.Timestamp };
  if (!isCacheEntryFresh(data.generated_at.toDate(), now)) return null;
  return data.narrative;
}

export async function putCached(
  uid: string,
  turnId: string,
  narrative: CachedNarrative
): Promise<void> {
  const db = admin.firestore();
  const ref = db.collection("narratives_cache").doc(cacheKey(uid, turnId));
  await ref.set({
    narrative,
    generated_at: admin.firestore.Timestamp.now(),
    expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + TTL_MS)
  });
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `cd functions && npm test -- cache`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add functions/src/cache.ts functions/src/__tests__/cache.test.ts
git commit -m "Add idempotency cache module — keyed by uid+turn_id, 7-day TTL"
```

---

## Task 8: Anthropic call with tool-use schema

**Files:**
- Create: `functions/src/anthropic.ts`
- Create: `functions/src/__tests__/anthropic.test.ts`

- [ ] **Step 1: Write failing test**

Create `functions/src/__tests__/anthropic.test.ts`:

```typescript
import { buildUserMessage, NARRATIVE_TOOL, SYSTEM_PROMPT } from "../anthropic";

describe("anthropic prompt builders", () => {
  test("buildUserMessage includes prompt and events", () => {
    const msg = buildUserMessage({
      prompt: "fix the bug",
      events: [
        { time: "09:00", tool: "Edit", path: "foo.swift" },
        { time: "09:01", tool: "Bash", text: "git commit" }
      ],
      raw_summary: "Edit foo.swift · Bash: git commit"
    });
    expect(msg).toContain("fix the bug");
    expect(msg).toContain("09:00");
    expect(msg).toContain("Edit");
    expect(msg).toContain("git commit");
    expect(msg).toContain("Edit foo.swift · Bash: git commit");
  });

  test("buildUserMessage truncates prompt over 8000 chars", () => {
    const huge = "x".repeat(10000);
    const msg = buildUserMessage({ prompt: huge, events: [], raw_summary: "" });
    expect(msg.length).toBeLessThan(9500);
  });

  test("buildUserMessage truncates events over 50", () => {
    const events = Array.from({ length: 100 }, (_, i) => ({
      time: "09:00",
      tool: "Edit",
      path: `f${i}.swift`
    }));
    const msg = buildUserMessage({ prompt: "p", events, raw_summary: "" });
    // Only first 50 should appear
    expect(msg).toContain("f49.swift");
    expect(msg).not.toContain("f50.swift");
  });

  test("NARRATIVE_TOOL has required fields", () => {
    expect(NARRATIVE_TOOL.name).toBe("record_narrative");
    const props = (NARRATIVE_TOOL.input_schema as any).properties;
    expect(props.title).toBeDefined();
    expect(props.what_you_wanted).toBeDefined();
    expect(props.what_happened).toBeDefined();
    expect(props.lesson).toBeDefined();
    expect((NARRATIVE_TOOL.input_schema as any).required)
      .toEqual(["title", "what_you_wanted", "what_happened", "lesson"]);
  });

  test("SYSTEM_PROMPT contains language placeholder", () => {
    expect(SYSTEM_PROMPT).toContain("<language>");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- anthropic`
Expected: FAIL — `anthropic.ts` not found

- [ ] **Step 3: Write the implementation**

Create `functions/src/anthropic.ts`:

```typescript
import Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-haiku-4-5-20251001";
export const MAX_TOKENS = 800;
const MAX_PROMPT_CHARS = 8000;
const MAX_EVENTS = 50;

export const SYSTEM_PROMPT = `Bạn là người ghi nhật ký phản tỉnh cho 1 lập trình viên đang dùng AI assistant.
Mục tiêu: biến 1 lượt làm việc kỹ thuật thành 1 entry nhật ký mà CHA MẸ
hoặc BẠN BÈ KHÔNG PHẢI DEV cũng đọc hiểu.

Quy tắc bắt buộc:
1. KHÔNG dùng tên file, tên hàm, tên class, tên CLI command. Diễn đạt bằng
   ý nghĩa: thay vì "Edit ReflectionTab.swift" → "chỉnh phần hiển thị trang
   nhật ký". Thay vì "git commit" → "lưu lại tiến độ".
2. KHÔNG sao chép nguyên văn prompt user — diễn đạt lại ý định bằng lời
   của người ngoài cuộc.
3. Bài học PHẢI cụ thể với lượt này, KHÔNG sáo rỗng. Nếu không rút ra
   được bài học rõ → trả lesson "" (empty string), KHÔNG bịa.
4. Tone: ấm áp, gọn, như 1 người bạn đang kể lại. Không dùng emoji.
5. Trả về theo schema. Title <60 ký tự. Mỗi đoạn <240 ký tự.

Ngôn ngữ output: <language>`;

export const NARRATIVE_TOOL = {
  name: "record_narrative",
  description: "Record the narrative summary of a single Claude Code turn.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "Short headline under 60 characters describing the user's intent."
      },
      what_you_wanted: {
        type: "string",
        description: "1-2 sentences describing what the user wanted (≤240 chars)."
      },
      what_happened: {
        type: "string",
        description: "2-3 sentences describing what was accomplished (≤240 chars). No technical jargon."
      },
      lesson: {
        type: "string",
        description: "1 sentence lesson specific to this turn, or empty string if no clear lesson (≤240 chars)."
      }
    },
    required: ["title", "what_you_wanted", "what_happened", "lesson"]
  }
} as const;

export interface EventForPrompt {
  time: string;
  tool: string;
  path?: string;
  text?: string;
}

export interface BuildArgs {
  prompt: string;
  events: EventForPrompt[];
  raw_summary: string;
}

export function buildUserMessage(args: BuildArgs): string {
  const promptText = args.prompt.slice(0, MAX_PROMPT_CHARS);
  const events = args.events.slice(0, MAX_EVENTS);

  const eventLines = events.length === 0
    ? "(không có thao tác đáng chú ý)"
    : events
        .map((e) => `${e.time} — ${e.tool}: ${e.path ?? e.text ?? ""}`)
        .join("\n");

  return `Đây là 1 lượt làm việc với Claude Code:

User đã gõ: "${promptText}"

Trong lượt đó, các thao tác đã xảy ra:
${eventLines}

Tóm tắt kỹ thuật ngắn (cho bạn tham khảo): ${args.raw_summary}

Hãy gọi tool record_narrative.`;
}

export interface NarrativeOutput {
  title: string;
  what_you_wanted: string;
  what_happened: string;
  lesson: string;
}

export interface CallArgs extends BuildArgs {
  language: "vi" | "en";
}

/**
 * Calls Claude Haiku with tool use enforced. Returns parsed narrative or
 * throws on malformed response / SDK error.
 */
export async function callAnthropic(
  client: Anthropic,
  args: CallArgs
): Promise<NarrativeOutput> {
  const system = SYSTEM_PROMPT.replace("<language>", args.language === "vi" ? "Tiếng Việt" : "English");
  const user = buildUserMessage(args);

  const response = await client.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: [
      { type: "text", text: system, cache_control: { type: "ephemeral" } }
    ],
    tools: [NARRATIVE_TOOL as any],
    tool_choice: { type: "tool", name: "record_narrative" },
    messages: [{ role: "user", content: user }]
  });

  for (const block of response.content) {
    if (block.type === "tool_use" && block.name === "record_narrative") {
      const input = block.input as NarrativeOutput;
      if (
        typeof input.title === "string" &&
        typeof input.what_you_wanted === "string" &&
        typeof input.what_happened === "string" &&
        typeof input.lesson === "string"
      ) {
        return input;
      }
    }
  }
  throw new Error("Anthropic response missing valid record_narrative tool use");
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd functions && npm test -- anthropic`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add functions/src/anthropic.ts functions/src/__tests__/anthropic.test.ts
git commit -m "Add Anthropic narrative tool — system prompt + tool-use schema enforcement"
```

---

## Task 9: summarizeTurn handler

**Files:**
- Create: `functions/src/summarizeTurn.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/src/__tests__/summarizeTurn.test.ts`

- [ ] **Step 1: Write failing test**

Create `functions/src/__tests__/summarizeTurn.test.ts`:

```typescript
import { validatePayload } from "../summarizeTurn";

describe("validatePayload", () => {
  const valid = {
    turn_id: "s1:2026-05-05T09:00:00Z",
    session_id: "s1",
    language: "vi" as const,
    prompt: "do thing",
    events: [],
    raw_summary: ""
  };

  test("accepts a valid payload", () => {
    expect(validatePayload(valid)).toBeNull();
  });

  test("rejects missing turn_id", () => {
    expect(validatePayload({ ...valid, turn_id: "" })).toBe("turn_id required");
  });

  test("rejects missing session_id", () => {
    expect(validatePayload({ ...valid, session_id: "" })).toBe("session_id required");
  });

  test("rejects bad language", () => {
    expect(validatePayload({ ...valid, language: "fr" as any }))
      .toBe("language must be 'vi' or 'en'");
  });

  test("rejects empty prompt", () => {
    expect(validatePayload({ ...valid, prompt: "" })).toBe("prompt required");
  });

  test("rejects non-array events", () => {
    expect(validatePayload({ ...valid, events: "x" as any }))
      .toBe("events must be an array");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npm test -- summarizeTurn`
Expected: FAIL — `summarizeTurn.ts` not found

- [ ] **Step 3: Write the handler**

Create `functions/src/summarizeTurn.ts`:

```typescript
import { Request, Response } from "firebase-functions/v2/https";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import { getCached, putCached } from "./cache";
import { callAnthropic, MODEL, EventForPrompt, NarrativeOutput } from "./anthropic";

export interface SummarizePayload {
  turn_id: string;
  session_id: string;
  language: "vi" | "en";
  prompt: string;
  events: EventForPrompt[];
  raw_summary: string;
}

export function validatePayload(body: any): string | null {
  if (!body || typeof body !== "object") return "body required";
  const b = body as Partial<SummarizePayload>;
  if (typeof b.turn_id !== "string" || b.turn_id.length === 0) return "turn_id required";
  if (typeof b.session_id !== "string" || b.session_id.length === 0) return "session_id required";
  if (b.language !== "vi" && b.language !== "en") return "language must be 'vi' or 'en'";
  if (typeof b.prompt !== "string" || b.prompt.length === 0) return "prompt required";
  if (!Array.isArray(b.events)) return "events must be an array";
  if (typeof b.raw_summary !== "string") return "raw_summary required";
  return null;
}

let _anthropic: Anthropic | null = null;
function anthropicClient(): Anthropic {
  if (!_anthropic) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
    _anthropic = new Anthropic({ apiKey });
  }
  return _anthropic;
}

export async function handleSummarizeTurn(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  const auth = await verifyAuth(req.headers.authorization);
  if (!auth) {
    res.status(401).json({ error: "invalid_token" });
    return;
  }

  const validationError = validatePayload(req.body);
  if (validationError) {
    res.status(400).json({ error: "invalid_payload", detail: validationError });
    return;
  }
  const payload = req.body as SummarizePayload;

  // Cache check first — does NOT consume rate limit.
  const cached = await getCached(auth.uid, payload.turn_id);
  if (cached) {
    res.status(200).json({
      turn_id: payload.turn_id,
      narrative: cached,
      model: cached.model,
      cache_hit: true
    });
    return;
  }

  // Rate limit check.
  const limit = await checkAndIncrement(auth.uid);
  if (!limit.allowed) {
    res.status(429).json({
      error: "daily_limit_reached",
      reset_at: limit.resetAt.toISOString(),
      limit: limit.limit
    });
    return;
  }

  // Anthropic call.
  let narrative: NarrativeOutput;
  try {
    narrative = await callAnthropic(anthropicClient(), {
      prompt: payload.prompt,
      events: payload.events,
      raw_summary: payload.raw_summary,
      language: payload.language
    });
  } catch (err) {
    logger.error("anthropic call failed", { uid: auth.uid, turn_id: payload.turn_id, err: String(err) });
    res.status(502).json({ error: "upstream_failure" });
    return;
  }

  await putCached(auth.uid, payload.turn_id, { ...narrative, model: MODEL });

  res.status(200).json({
    turn_id: payload.turn_id,
    narrative,
    model: MODEL,
    cache_hit: false
  });
}
```

- [ ] **Step 4: Wire handler into `functions/src/index.ts`**

Replace `functions/src/index.ts`:

```typescript
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { handleSummarizeTurn } from "./summarizeTurn";

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

export const summarizeTurn = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleSummarizeTurn
);
```

- [ ] **Step 5: Run tests to verify pass**

Run: `cd functions && npm test`
Expected: PASS — all suites green

- [ ] **Step 6: Verify build**

Run: `cd functions && npm run build`
Expected: build succeeds with no errors

- [ ] **Step 7: Commit**

```bash
git add functions/src/summarizeTurn.ts functions/src/index.ts functions/src/__tests__/summarizeTurn.test.ts
git commit -m "Add summarizeTurn handler — auth, cache, rate limit, Anthropic"
```

---

## Task 10: Set Anthropic secret + deploy + smoke test

This task requires user action (Firebase login + secret setup). Surface clearly.

**Files:** none changed.

- [ ] **Step 1: Confirm Firebase CLI installed and logged in**

Ask user to confirm: `firebase --version` and `firebase login` complete. If not, instruct:
```bash
npm install -g firebase-tools
firebase login
```

- [ ] **Step 2: Set the Anthropic API key as a Firebase secret**

Ask user to run (replacing `<key>`):
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```
Paste the key when prompted.

- [ ] **Step 3: Deploy the function**

Ask user to run:
```bash
firebase deploy --only functions:summarizeTurn
```
Expected: deploy succeeds; URL printed similar to `https://summarizeturn-xxxxx-uc.a.run.app`. Save URL.

- [ ] **Step 4: Smoke-test deployed function with curl**

Ask user to run (replace `<URL>` and obtain a Firebase ID token from the running app via debug log):
```bash
curl -X POST <URL> \
  -H "Authorization: Bearer <ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "turn_id": "smoke:2026-05-05T00:00:00Z",
    "session_id": "smoke",
    "language": "vi",
    "prompt": "thử xem narrative có ra không",
    "events": [],
    "raw_summary": "smoke test"
  }'
```
Expected: 200 with JSON containing `narrative.title`, `narrative.what_you_wanted`, etc.

- [ ] **Step 5: No commit** (deploy only — no source changes)

---

## Task 11: ReflectionAPIClient (Swift)

**Files:**
- Create: `codepet/Services/ReflectionAPIClient.swift`
- Test: `codepetTests/ReflectionAPIClientTests.swift`

- [ ] **Step 1: Write failing test**

Create `codepetTests/ReflectionAPIClientTests.swift`:

```swift
import XCTest
@testable import codepet

final class ReflectionAPIClientTests: XCTestCase {

    func testRequestEncodingShape() throws {
        let payload = SummarizeTurnRequest(
            turnId: "s1:2026-05-05T09:00:00Z",
            sessionId: "s1",
            language: "vi",
            prompt: "fix",
            events: [
                .init(time: "09:00", tool: "Edit", path: "foo.swift", text: nil)
            ],
            rawSummary: "Edit foo.swift"
        )
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["turn_id"] as? String, "s1:2026-05-05T09:00:00Z")
        XCTAssertEqual(json["session_id"] as? String, "s1")
        XCTAssertEqual(json["language"] as? String, "vi")
        let events = json["events"] as! [[String: Any]]
        XCTAssertEqual(events.first?["tool"] as? String, "Edit")
        XCTAssertEqual(events.first?["path"] as? String, "foo.swift")
    }

    func testResponseDecodes() throws {
        let json = """
        {
          "turn_id": "s1:2026-05-05T09:00:00Z",
          "narrative": {
            "title": "T",
            "what_you_wanted": "w",
            "what_happened": "h",
            "lesson": "l"
          },
          "model": "claude-haiku-4-5-20251001",
          "cache_hit": false
        }
        """.data(using: .utf8)!

        let resp = try JSONDecoder().decode(SummarizeTurnResponse.self, from: json)
        XCTAssertEqual(resp.narrative.title, "T")
        XCTAssertEqual(resp.model, "claude-haiku-4-5-20251001")
        XCTAssertFalse(resp.cacheHit)
    }

    func testQuotaErrorDecodes() throws {
        let json = """
        {
          "error": "daily_limit_reached",
          "reset_at": "2026-05-06T00:00:00Z",
          "limit": 50
        }
        """.data(using: .utf8)!
        let err = try JSONDecoder().decode(SummarizeTurnError.self, from: json)
        XCTAssertEqual(err.error, "daily_limit_reached")
        XCTAssertEqual(err.limit, 50)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/ReflectionAPIClientTests`
Expected: FAIL — types not defined

- [ ] **Step 3: Write the implementation**

Create `codepet/Services/ReflectionAPIClient.swift`:

```swift
import Foundation
import FirebaseAuth

// MARK: - DTOs

struct SummarizeTurnRequest: Codable {
    let turnId: String
    let sessionId: String
    let language: String       // "vi" | "en"
    let prompt: String
    let events: [EventDTO]
    let rawSummary: String

    struct EventDTO: Codable {
        let time: String       // "HH:mm"
        let tool: String
        let path: String?
        let text: String?
    }

    enum CodingKeys: String, CodingKey {
        case turnId = "turn_id"
        case sessionId = "session_id"
        case language
        case prompt
        case events
        case rawSummary = "raw_summary"
    }
}

struct SummarizeTurnResponse: Codable {
    let turnId: String
    let narrative: NarrativePayload
    let model: String
    let cacheHit: Bool

    struct NarrativePayload: Codable {
        let title: String
        let whatYouWanted: String
        let whatHappened: String
        let lesson: String

        enum CodingKeys: String, CodingKey {
            case title
            case whatYouWanted = "what_you_wanted"
            case whatHappened = "what_happened"
            case lesson
        }
    }

    enum CodingKeys: String, CodingKey {
        case turnId = "turn_id"
        case narrative
        case model
        case cacheHit = "cache_hit"
    }
}

struct SummarizeTurnError: Codable, Error {
    let error: String
    let resetAt: String?
    let limit: Int?
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case error
        case resetAt = "reset_at"
        case limit
        case detail
    }
}

// MARK: - Client

protocol ReflectionAPIClientProtocol {
    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse
}

enum ReflectionAPIError: Error {
    case notSignedIn
    case http(status: Int, body: SummarizeTurnError?)
    case malformedResponse
    case network(Error)
}

@MainActor
final class ReflectionAPIClient: ReflectionAPIClientProtocol {

    /// Replace with the deployed Cloud Function URL after Task 10.
    static let endpoint = URL(string: "https://summarizeturn-REPLACE_ME-uc.a.run.app")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        guard let user = Auth.auth().currentUser else {
            throw ReflectionAPIError.notSignedIn
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw ReflectionAPIError.network(error)
        }

        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ReflectionAPIError.malformedResponse
        }

        if http.statusCode == 200 {
            do {
                return try JSONDecoder().decode(SummarizeTurnResponse.self, from: data)
            } catch {
                throw ReflectionAPIError.malformedResponse
            }
        }

        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
    }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/ReflectionAPIClientTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Update endpoint constant with deployed URL**

After Task 10 deploy, edit `codepet/Services/ReflectionAPIClient.swift` and replace `REPLACE_ME` with the actual function ID printed by `firebase deploy`.

- [ ] **Step 6: Commit**

```bash
git add codepet/Services/ReflectionAPIClient.swift codepetTests/ReflectionAPIClientTests.swift
git commit -m "Add ReflectionAPIClient — call summarizeTurn with Firebase ID token"
```

---

## Task 12: NarrativeEnricher

**Files:**
- Create: `codepet/Managers/NarrativeEnricher.swift`
- Test: `codepetTests/NarrativeEnricherTests.swift`

- [ ] **Step 1: Write failing tests**

Create `codepetTests/NarrativeEnricherTests.swift`:

```swift
import XCTest
@testable import codepet

final class MockAPIClient: ReflectionAPIClientProtocol {
    var calls: [SummarizeTurnRequest] = []
    var response: SummarizeTurnResponse?
    var error: Error?
    var delay: TimeInterval = 0

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        calls.append(request)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let error = error { throw error }
        if let response = response { return response }
        return SummarizeTurnResponse(
            turnId: request.turnId,
            narrative: .init(title: "T", whatYouWanted: "w", whatHappened: "h", lesson: "l"),
            model: "claude-haiku-4-5-20251001",
            cacheHit: false
        )
    }
}

@MainActor
final class NarrativeEnricherTests: XCTestCase {
    var tmpURL: URL!
    var store: NarrativeStore!

    override func setUp() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("enricher-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tmpURL = dir.appendingPathComponent("narratives.jsonl")
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        store = NarrativeStore(fileURL: tmpURL, pollInterval: 0.1)
        store.start()
    }

    override func tearDown() async throws {
        store.stop()
        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }

    private func makeTurn(id: String = "s1:2026-05-05T09:00:00Z") -> Turn {
        Turn(
            id: id,
            sessionId: "s1",
            startedAt: Date(),
            endedAt: Date(),
            prompt: "do the thing",
            rawEvents: [],
            narrative: nil,
            state: .summarizing
        )
    }

    func testHappyPathPersistsNarrative() async {
        let api = MockAPIClient()
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        await enricher.enrich(turn: makeTurn())

        XCTAssertEqual(api.calls.count, 1)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNotNil(store.narratives["s1:2026-05-05T09:00:00Z"])
    }

    func testNetworkFailReturnsFailedNetwork() async {
        let api = MockAPIClient()
        api.error = ReflectionAPIError.network(URLError(.notConnectedToInternet))
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi", retryDelay: 0)

        let result = await enricher.enrich(turn: makeTurn())

        XCTAssertEqual(result, .failed(reason: .network))
        XCTAssertEqual(api.calls.count, 2)  // 1 attempt + 1 retry
    }

    func testQuotaReturnsFailedQuota() async {
        let api = MockAPIClient()
        api.error = ReflectionAPIError.http(
            status: 429,
            body: SummarizeTurnError(error: "daily_limit_reached", resetAt: "2026-05-06T00:00:00Z", limit: 50, detail: nil)
        )
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        let result = await enricher.enrich(turn: makeTurn())

        XCTAssertEqual(result, .failed(reason: .quota))
        XCTAssertEqual(api.calls.count, 1)  // no retry on quota
    }

    func testAuthErrorReturnsFailedAuth() async {
        let api = MockAPIClient()
        api.error = ReflectionAPIError.http(status: 401, body: nil)
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        let result = await enricher.enrich(turn: makeTurn())
        XCTAssertEqual(result, .failed(reason: .auth))
        XCTAssertEqual(api.calls.count, 1)
    }

    func testEnqueueProcessesSerially() async {
        let api = MockAPIClient()
        api.delay = 0.1
        let enricher = NarrativeEnricher(api: api, store: store, language: "vi")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = await enricher.enrich(turn: self.makeTurn(id: "s1:t1")) }
            group.addTask { _ = await enricher.enrich(turn: self.makeTurn(id: "s1:t2")) }
        }

        XCTAssertEqual(api.calls.count, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/NarrativeEnricherTests`
Expected: FAIL — `NarrativeEnricher` not defined

- [ ] **Step 3: Write the implementation**

Create `codepet/Managers/NarrativeEnricher.swift`:

```swift
import Foundation
import os

/// Serial enrichment worker. Calls Cloud Function for each turn and writes
/// the narrative back to NarrativeStore. Retries network failures once.
@MainActor
final class NarrativeEnricher: ObservableObject {

    private let api: ReflectionAPIClientProtocol
    private let store: NarrativeStore
    private let language: String
    private let retryDelay: TimeInterval
    private var inFlight: [String: Task<TurnState, Never>] = [:]
    private let logger = Logger(subsystem: "app.murror.codepet", category: "NarrativeEnricher")

    init(
        api: ReflectionAPIClientProtocol,
        store: NarrativeStore,
        language: String,
        retryDelay: TimeInterval = 10
    ) {
        self.api = api
        self.store = store
        self.language = language
        self.retryDelay = retryDelay
    }

    /// Enrich a single turn. Awaits completion. If a turn with the same id is
    /// already in flight, returns the same task's result.
    @discardableResult
    func enrich(turn: Turn) async -> TurnState {
        if let existing = inFlight[turn.id] {
            return await existing.value
        }
        let task = Task<TurnState, Never> { [weak self] in
            guard let self else { return .failed(reason: .unknown) }
            return await self.runEnrich(turn: turn)
        }
        inFlight[turn.id] = task
        let result = await task.value
        inFlight[turn.id] = nil
        return result
    }

    private func runEnrich(turn: Turn) async -> TurnState {
        let request = makeRequest(for: turn)
        for attempt in 0...1 {
            do {
                let response = try await api.summarizeTurn(request)
                let n = Narrative(
                    title: response.narrative.title,
                    whatYouWanted: response.narrative.whatYouWanted,
                    whatHappened: response.narrative.whatHappened,
                    lesson: response.narrative.lesson,
                    model: response.model,
                    generatedAt: Date(),
                    schemaVersion: 1
                )
                do {
                    try store.appendNarrative(turnId: turn.id, sessionId: turn.sessionId, narrative: n)
                } catch {
                    logger.error("failed to persist narrative: \(error.localizedDescription)")
                }
                return .ready
            } catch let err as ReflectionAPIError {
                switch err {
                case .notSignedIn, .http(401, _):
                    return .failed(reason: .auth)
                case .http(429, _):
                    return .failed(reason: .quota)
                case .http(400, _), .malformedResponse:
                    return .failed(reason: .badResponse)
                case .http, .network:
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    }
                    return .failed(reason: .network)
                }
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                return .failed(reason: .unknown)
            }
        }
        return .failed(reason: .unknown)
    }

    private func makeRequest(for turn: Turn) -> SummarizeTurnRequest {
        let events = turn.rawEvents.map {
            SummarizeTurnRequest.EventDTO(
                time: $0.time,
                tool: extractTool(from: $0.text),
                path: extractPath(from: $0.text),
                text: $0.text
            )
        }
        let rawSummary = events.map { "\($0.tool) \($0.path ?? $0.text ?? "")" }.joined(separator: " · ")
        return SummarizeTurnRequest(
            turnId: turn.id,
            sessionId: turn.sessionId,
            language: language,
            prompt: turn.prompt,
            events: events,
            rawSummary: rawSummary
        )
    }

    private func extractTool(from text: String) -> String {
        // text is like "Edit ReflectionTab.swift" or "Bash: git commit"
        if text.hasPrefix("Bash:") { return "Bash" }
        return text.components(separatedBy: " ").first ?? text
    }

    private func extractPath(from text: String) -> String? {
        let parts = text.components(separatedBy: " ")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: " ")
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `xcodebuild test -scheme codepet -destination 'platform=macOS' -only-testing:codepetTests/NarrativeEnricherTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add codepet/Managers/NarrativeEnricher.swift codepetTests/NarrativeEnricherTests.swift
git commit -m "Add NarrativeEnricher — serial queue, single retry on network errors"
```

---

## Task 13: Wire stores into CodePetApp

**Files:**
- Modify: `codepet/App/CodePetApp.swift`

- [ ] **Step 1: Read current `CodePetApp.swift`**

Read: `codepet/App/CodePetApp.swift` and locate where `ReflectionEventStore` is currently constructed and injected via `@StateObject` / `.environmentObject`.

- [ ] **Step 2: Add NarrativeStore + NarrativeEnricher**

Edit `codepet/App/CodePetApp.swift` — alongside the existing `reflectionStore` `@StateObject`:

```swift
@StateObject private var narrativeStore = NarrativeStore()
@StateObject private var narrativeEnricher: NarrativeEnricher = {
    let store = NarrativeStore()
    let api = ReflectionAPIClient()
    // Language wired in real time via .environmentObject; default to "vi" here, view layer overrides
    return NarrativeEnricher(api: api, store: store, language: "vi")
}()
```

(Note: The enricher and store are independent in this sketch. To share the same NarrativeStore instance, refactor as in Step 3.)

- [ ] **Step 3: Refactor for shared instances**

Replace the two-`@StateObject` initializer with a single composition root:

```swift
@StateObject private var reflectionComposition = ReflectionComposition()

// ... in body
WindowGroup {
    ContentView()
        .environmentObject(reflectionComposition.eventStore)
        .environmentObject(reflectionComposition.narrativeStore)
        .environmentObject(reflectionComposition.enricher)
        .task { reflectionComposition.start() }
}
```

Add a new file `codepet/Managers/ReflectionComposition.swift`:

```swift
import Foundation

@MainActor
final class ReflectionComposition: ObservableObject {
    let eventStore: ReflectionEventStore
    let narrativeStore: NarrativeStore
    let enricher: NarrativeEnricher

    init(language: String = "vi") {
        let events = ReflectionEventStore()
        let narratives = NarrativeStore()
        let api = ReflectionAPIClient()
        self.eventStore = events
        self.narrativeStore = narratives
        self.enricher = NarrativeEnricher(api: api, store: narratives, language: language)
    }

    func start() {
        eventStore.start()
        narrativeStore.start()
    }
}
```

- [ ] **Step 4: Verify the project compiles**

Run: `xcodebuild -scheme codepet build -destination 'platform=macOS' 2>&1 | tail -40`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add codepet/App/CodePetApp.swift codepet/Managers/ReflectionComposition.swift
git commit -m "Wire NarrativeStore and NarrativeEnricher into app composition"
```

---

## Task 14: NarrativeBodyView (3-section render)

**Files:**
- Create: `codepet/Views/Reflection/NarrativeBodyView.swift`

- [ ] **Step 1: Write the view**

Create `codepet/Views/Reflection/NarrativeBodyView.swift`:

```swift
import SwiftUI

struct NarrativeBodyView: View {
    let narrative: Narrative

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(eyebrow: "BẠN MUỐN", body: narrative.whatYouWanted)
            section(eyebrow: "ĐÃ LÀM", body: narrative.whatHappened)
            lessonCard
        }
    }

    private func section(eyebrow: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(ReflectionTheme.accent.opacity(0.6))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(ReflectionTheme.mutedText)
                Text(body)
                    .font(ReflectionTheme.serif(15))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var lessonCard: some View {
        if !narrative.lesson.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("BÀI HỌC")
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(ReflectionTheme.accent)
                Text(narrative.lesson)
                    .font(ReflectionTheme.serif(14, weight: .medium))
                    .italic()
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReflectionTheme.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReflectionTheme.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

#Preview {
    NarrativeBodyView(narrative: Narrative(
        title: "Thiết kế lại reflection thành câu chuyện",
        whatYouWanted: "Bạn muốn log Reflection đỡ kỹ thuật, dễ đọc cho người không phải dev, và có bài học rút ra sau mỗi lượt làm việc.",
        whatHappened: "Cùng AI rà spec hiện tại, chốt 7 quyết định về cách hệ thống mới sẽ hoạt động.",
        lesson: "Tách raw data và presentation giúp đỡ rối khi đổi UI sau này.",
        model: "claude-haiku-4-5-20251001",
        generatedAt: Date(),
        schemaVersion: 1
    ))
    .padding(24)
    .frame(width: 600)
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme codepet build -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add codepet/Views/Reflection/NarrativeBodyView.swift
git commit -m "Add NarrativeBodyView — 3-section render for narrative summaries"
```

---

## Task 15: TurnLoadingStates view

**Files:**
- Create: `codepet/Views/Reflection/TurnLoadingStates.swift`

- [ ] **Step 1: Write the view**

Create `codepet/Views/Reflection/TurnLoadingStates.swift`:

```swift
import SwiftUI

struct TurnLoadingStates: View {
    let state: TurnState
    var onRetry: () -> Void = {}
    var onSignIn: () -> Void = {}

    var body: some View {
        switch state {
        case .pending:
            stateRow(
                title: "Đang làm…",
                detail: "Lượt này chưa kết thúc. Câu chuyện sẽ xuất hiện khi Claude xong."
            )

        case .summarizing:
            VStack(alignment: .leading, spacing: 14) {
                skeletonLine(width: 0.85)
                skeletonLine(width: 0.7)
                skeletonLine(width: 0.6)
                Text("Đang tóm tắt câu chuyện…")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

        case .ready:
            EmptyView()  // body shown by NarrativeBodyView

        case .pendingOrphan:
            stateRow(
                title: "Phiên chưa hoàn thành",
                detail: "Lượt này không kết thúc bình thường — có thể Claude Code bị đóng giữa chừng."
            )

        case .failed(let reason):
            failedView(reason: reason)
        }
    }

    private func stateRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ReflectionTheme.serif(16, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
            Text(detail)
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func skeletonLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(ReflectionTheme.borderLight.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 14)
            .scaleEffect(x: width, y: 1, anchor: .leading)
    }

    @ViewBuilder
    private func failedView(reason: FailureReason) -> some View {
        let (title, detail, action): (String, String, () -> Void) = {
            switch reason {
            case .network:
                return ("Không tóm tắt được câu chuyện",
                        "Có vẻ mạng đang trục trặc. Bạn có thể thử lại.",
                        onRetry)
            case .quota:
                return ("Hết hạn ngạch hôm nay",
                        "Bạn đã đạt 50 câu chuyện hôm nay. Reset sau 00:00 UTC.",
                        onRetry)
            case .auth:
                return ("Cần đăng nhập lại",
                        "Phiên đăng nhập đã hết hạn.",
                        onSignIn)
            case .badResponse:
                return ("Lỗi tóm tắt",
                        "AI trả về dữ liệu lạ. Bạn có thể thử lại.",
                        onRetry)
            case .unknown:
                return ("Không tóm tắt được",
                        "Có lỗi không rõ. Bạn có thể thử lại.",
                        onRetry)
            }
        }()

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ReflectionTheme.moodAlert)
                Text(title)
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
            }
            Text(detail)
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(reason == .auth ? "Đăng nhập" : "Thử lại")
                    .font(ReflectionTheme.sans(12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ReflectionTheme.accent))
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme codepet build -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add codepet/Views/Reflection/TurnLoadingStates.swift
git commit -m "Add TurnLoadingStates view — pending, summarizing, failed, orphan"
```

---

## Task 16: TechnicalDetailsView (collapsed raw events)

**Files:**
- Create: `codepet/Views/Reflection/TechnicalDetailsView.swift`

- [ ] **Step 1: Write the view**

Create `codepet/Views/Reflection/TechnicalDetailsView.swift`:

```swift
import SwiftUI

struct TechnicalDetailsView: View {
    let prompt: String
    let events: [CapturedEvent]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                    Text("Xem chi tiết kỹ thuật (\(events.count) thao tác)")
                        .font(ReflectionTheme.sans(11, weight: .medium))
                }
                .foregroundColor(ReflectionTheme.mutedText)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    promptRow
                    Divider().background(ReflectionTheme.borderLight)
                    ForEach(events) { event in
                        eventRow(event)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReflectionTheme.cardBackground.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var promptRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROMPT")
                .font(ReflectionTheme.mono(9, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(ReflectionTheme.mutedText)
            Text(prompt)
                .font(ReflectionTheme.mono(11))
                .foregroundColor(ReflectionTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func eventRow(_ event: CapturedEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.time)
                .font(ReflectionTheme.mono(10))
                .foregroundColor(ReflectionTheme.mutedText)
                .frame(width: 44, alignment: .leading)
            Text(event.text)
                .font(ReflectionTheme.mono(11))
                .foregroundColor(ReflectionTheme.secondaryText)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme codepet build -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add codepet/Views/Reflection/TechnicalDetailsView.swift
git commit -m "Add TechnicalDetailsView — collapsed raw prompt + events list"
```

---

## Task 17: Rewrite ReflectionTab

**Files:**
- Modify: `codepet/Views/Reflection/ReflectionTab.swift`

- [ ] **Step 1: Read current `ReflectionTab.swift`**

Read the existing file. Note the structure: `sessionsSidebar` + `header` + `mainGrid` + `footer`. We replace `mainGrid` with the new components and rewrite `sessionsSidebar` to group by HÔM NAY / HÔM QUA / TUẦN NÀY.

- [ ] **Step 2: Add a Turns adapter on the EventStore**

Add this computed property near the top of `ReflectionTab`:

```swift
@EnvironmentObject var narrativeStore: NarrativeStore
@EnvironmentObject var enricher: NarrativeEnricher

private var allTurns: [Turn] {
    let inputs = reflectionStore.events.compactMap { event -> AssemblerInput? in
        guard let sessionId = event.sessionId else { return nil }
        // event.text already encodes prompt vs tool semantically.
        // We need raw ISO time — store this in CapturedEvent if not present.
        // For MVP: use event.time and today's date for time component.
        // (See Task 18 follow-up note — better path is to extend CapturedEvent
        //  with isoTime in a future cleanup. For MVP we work from event.time.)
        return AssemblerInput(
            kind: .tool(text: event.text),  // refined below per-event-type
            isoTime: synthesizeISOTime(from: event.time),
            sessionId: sessionId
        )
    }
    return TurnAssembler.assemble(
        inputs: inputs,
        now: Date(),
        narratives: narrativeStore.narratives
    )
}

private func synthesizeISOTime(from hhmm: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    let today = DateFormatter()
    today.dateFormat = "yyyy-MM-dd"
    let datePart = today.string(from: Date())
    if let date = f.date(from: "\(datePart) \(hhmm)") {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.string(from: date)
    }
    return "\(datePart)T\(hhmm):00Z"
}
```

> **Note on the temporary `synthesizeISOTime` shim:** The current `CapturedEvent` only stores display "HH:mm". The clean fix is to add an `isoTime: String` field to `CapturedEvent` and have `JSONLEvent.toCapturedEvent()` populate it. Do that as the very next step (Task 17 Step 3 below) so Turn IDs are stable across days.

- [ ] **Step 3: Add `isoTime` to CapturedEvent**

Edit `codepet/Views/Reflection/ReflectionModels.swift` — add to `CapturedEvent`:

```swift
struct CapturedEvent: Identifiable, Hashable {
    let id: UUID
    let time: String
    let isoTime: String        // NEW — full ISO 8601, used for turn_id
    let source: EventSource
    // ... rest unchanged

    init(
        id: UUID = UUID(),
        time: String,
        isoTime: String = "",   // default for back-compat
        source: EventSource,
        text: String,
        // ... rest
    ) {
        self.id = id
        self.time = time
        self.isoTime = isoTime
        // ... rest
    }
}
```

Update `codepet/Managers/ReflectionEventStore.swift` `JSONLEvent.toCapturedEvent()`:

```swift
func toCapturedEvent() -> CapturedEvent {
    CapturedEvent(
        time: Self.formatHHmm(time),
        isoTime: time,                  // NEW
        source: .claudeCode,
        text: text,
        // ... rest
    )
}
```

Also update the JSONLEvent type in ReflectionEventStore to surface the raw `type` field so we can distinguish prompt/tool/summary downstream:

```swift
private struct JSONLEvent: Decodable {
    let time: String
    let type: String          // "prompt" | "tool" | "summary"
    let session_id: String?
    let cwd: String?
    let text: String
    let tool_name: String?
    let path: String?
    // ... rest
}
```

Add a published `rawEvents` mirror so consumers can see the type:

```swift
@Published private(set) var rawJSONLEvents: [(type: String, isoTime: String, sessionId: String, text: String)] = []
```

And populate it inside `readNewLines()` alongside `events.append(raw.toCapturedEvent())`:

```swift
rawJSONLEvents.append((
    type: raw.type,
    isoTime: raw.time,
    sessionId: raw.session_id ?? "",
    text: raw.text
))
```

- [ ] **Step 4: Replace the temporary adapter with real types**

Update the `allTurns` computed property in `ReflectionTab.swift` to use `rawJSONLEvents`:

```swift
private var allTurns: [Turn] {
    let inputs: [AssemblerInput] = reflectionStore.rawJSONLEvents.compactMap { entry in
        guard !entry.sessionId.isEmpty else { return nil }
        let kind: AssemblerInput.Kind
        switch entry.type {
        case "prompt": kind = .prompt(text: entry.text)
        case "tool": kind = .tool(text: entry.text)
        case "summary": kind = .summary(text: entry.text)
        default: return nil
        }
        return AssemblerInput(kind: kind, isoTime: entry.isoTime, sessionId: entry.sessionId)
    }
    return TurnAssembler.assemble(
        inputs: inputs,
        now: Date(),
        narratives: narrativeStore.narratives
    )
}
```

Remove `synthesizeISOTime` shim.

- [ ] **Step 5: Replace sidebar with day-grouped turns**

Replace `groupedSessions()` and `sessionsSidebar` body with:

```swift
private struct TurnGroup {
    let label: String
    let turns: [Turn]
}

private func groupedTurns() -> [TurnGroup] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    let weekStart = cal.date(byAdding: .day, value: -6, to: today)!

    var todayTurns: [Turn] = []
    var yesterdayTurns: [Turn] = []
    var weekTurns: [Turn] = []
    var olderTurns: [Turn] = []

    for turn in allTurns {
        let day = cal.startOfDay(for: turn.startedAt)
        if day == today { todayTurns.append(turn) }
        else if day == yesterday { yesterdayTurns.append(turn) }
        else if day >= weekStart { weekTurns.append(turn) }
        else { olderTurns.append(turn) }
    }

    var groups: [TurnGroup] = []
    if !todayTurns.isEmpty { groups.append(.init(label: "HÔM NAY", turns: todayTurns)) }
    if !yesterdayTurns.isEmpty { groups.append(.init(label: "HÔM QUA", turns: yesterdayTurns)) }
    if !weekTurns.isEmpty { groups.append(.init(label: "TUẦN NÀY", turns: weekTurns)) }
    if !olderTurns.isEmpty { groups.append(.init(label: "CŨ HƠN", turns: olderTurns)) }
    return groups
}

@State private var selectedTurnId: String? = nil

private var selectedTurn: Turn? {
    guard let id = selectedTurnId else { return allTurns.first }
    return allTurns.first(where: { $0.id == id }) ?? allTurns.first
}

private var sessionsSidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
        HStack {
            Text("Sessions")
                .font(ReflectionTheme.serif(16, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let groups = groupedTurns()
                if groups.isEmpty {
                    Text("Chưa có lượt nào.")
                        .font(ReflectionTheme.sans(11))
                        .foregroundColor(ReflectionTheme.mutedText)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }
                ForEach(groups, id: \.label) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.label)
                            .font(ReflectionTheme.sans(10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(ReflectionTheme.mutedText)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                        ForEach(group.turns) { turn in
                            sidebarRow(turn)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color(red: 0xFD/255.0, green: 0xFC/255.0, blue: 0xF8/255.0))
}

private func sidebarRow(_ turn: Turn) -> some View {
    let isSelected = turn.id == selectedTurnId
    return Button {
        selectedTurnId = turn.id
    } label: {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(stateColor(turn.state))
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(sidebarTitle(for: turn))
                    .font(ReflectionTheme.sans(12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(timeDisplay(turn.startedAt))
                    .font(ReflectionTheme.sans(10.5))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? ReflectionTheme.accent.opacity(0.10) : Color.clear)
        )
        .padding(.horizontal, 8)
    }
    .buttonStyle(.plain)
}

private func sidebarTitle(for turn: Turn) -> String {
    if let title = turn.narrative?.title { return title }
    switch turn.state {
    case .pending, .summarizing: return "Đang tóm tắt…"
    case .pendingOrphan: return "Phiên chưa hoàn thành"
    case .failed: return "Không tóm tắt được"
    case .ready: return turn.prompt   // shouldn't happen if narrative nil
    }
}

private func stateColor(_ state: TurnState) -> Color {
    switch state {
    case .ready: return ReflectionTheme.moodCalm
    case .summarizing, .pending: return ReflectionTheme.accent
    case .failed: return ReflectionTheme.moodAlert
    case .pendingOrphan: return ReflectionTheme.mutedText
    }
}

private func timeDisplay(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}
```

- [ ] **Step 6: Replace `mainGrid` with new body**

Replace `mainGrid(for: ReflectionDay)` and the call site with:

```swift
private func turnBody(for turn: Turn) -> some View {
    VStack(alignment: .leading, spacing: 28) {
        // Header
        VStack(alignment: .leading, spacing: 8) {
            if let title = turn.narrative?.title {
                Text(title)
                    .font(ReflectionTheme.serif(22, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
            }
            HStack(spacing: 6) {
                Text(timeDisplay(turn.startedAt))
                    .font(ReflectionTheme.sans(12))
                    .foregroundColor(ReflectionTheme.mutedText)
                if let ended = turn.endedAt {
                    Text("·")
                        .foregroundColor(ReflectionTheme.mutedText)
                    Text("\(Int(ended.timeIntervalSince(turn.startedAt) / 60)) phút")
                        .font(ReflectionTheme.sans(12))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
            }
        }

        // Narrative or loading state
        if let narrative = turn.narrative {
            NarrativeBodyView(narrative: narrative)
        } else {
            TurnLoadingStates(state: turn.state, onRetry: {
                Task { await enricher.enrich(turn: turn) }
            })
        }

        // Technical details
        if !turn.rawEvents.isEmpty {
            TechnicalDetailsView(prompt: turn.prompt, events: turn.rawEvents)
        }
    }
}
```

Update `body` to use `turnBody` instead of `mainGrid`:

```swift
Group {
    if let turn = selectedTurn {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                petHeader(for: turn)
                turnBody(for: turn)
                footer
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    } else {
        emptyState
    }
}
```

Add `petHeader(for: Turn)` (replaces old `header(for:)`):

```swift
private func petHeader(for turn: Turn) -> some View {
    HStack(alignment: .center, spacing: 14) {
        PetAvatar(mood: .calm, size: 96)
        VStack(alignment: .leading, spacing: 8) {
            Text(petName)
                .font(ReflectionTheme.serif(22, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
            HStack(spacing: 6) {
                Text(dateDisplay(turn.startedAt))
                    .font(ReflectionTheme.sans(12))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
        }
        Spacer()
    }
}

private func dateDisplay(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEEE · MMMM d"
    return f.string(from: date)
}
```

- [ ] **Step 7: Trigger enrichment when a turn becomes summarizing**

At the end of `body`, add:

```swift
.onChange(of: allTurns) { turns in
    for turn in turns where turn.state == .summarizing && turn.narrative == nil {
        Task { await enricher.enrich(turn: turn) }
    }
}
```

- [ ] **Step 8: Update empty state copy**

Replace `emptyState` body text:

```swift
Text("Chưa có gì để phản tỉnh.")
    .font(ReflectionTheme.serif(20, weight: .medium))
    .foregroundColor(ReflectionTheme.primaryText)
Text("Mở Claude Code và bắt đầu code — câu chuyện sẽ tự xuất hiện ở đây sau mỗi lượt làm việc.")
    .font(ReflectionTheme.sans(13))
    .foregroundColor(ReflectionTheme.mutedText)
```

- [ ] **Step 9: Remove all old patterns + literary prompt apparatus**

Delete from `ReflectionTab.swift` the following methods and state (the entire old presentation layer except the sidebar shell + pet header which we already replaced):

```
- patternsSection(for:)
- patternRow(_:)
- trendGlyph(_:)
- inlineStats(for:)
- inlineStat(number:label:accent:)
- divider (computed property)
- reflectionSection(for:)
- reflectionActions (computed property)
- responseEditor (computed property)
- actionLabel(_:primary:)
- triggerSaveConfirmation()
- journalFilename (computed property)
- @State private var showResponseEditor
- @State private var responseText
- @State private var savedConfirmationUntil
- @State private var expandedEventId
- @State private var hoveredEventId
- @State private var hoveredSessionId
- personaTitle(for:)
- personaPromptHeadline(for:)
- personaPromptBody(for:)
- personaPromptProbe(for:)
- momentsSection(for:)
- momentRow(event:isLast:)
- header(for:)
- sessionSourceBadge(for:)
- mainGrid(for:)
- groupedSessions()
```

Note: literary reflection prompt (`reflectionSection`) is intentionally cut from MVP — it conflicted with the per-turn narrative as the primary content. Re-add in v1.1 if user feedback wants it back.

- [ ] **Step 10: Update `#Preview`**

Replace the preview at the bottom of `ReflectionTab.swift` with one that injects all three env objects:

```swift
#Preview {
    ReflectionTab()
        .environmentObject(AppState())
        .environmentObject(ReflectionEventStore())
        .environmentObject(NarrativeStore())
        .environmentObject(NarrativeEnricher(
            api: ReflectionAPIClient(),
            store: NarrativeStore(),
            language: "vi"
        ))
        .frame(width: 900, height: 800)
}
```

- [ ] **Step 11: Build and verify**

Run: `xcodebuild -scheme codepet build -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED.

- [ ] **Step 12: Commit**

```bash
git add codepet/Views/Reflection/ReflectionTab.swift codepet/Views/Reflection/ReflectionModels.swift codepet/Managers/ReflectionEventStore.swift
git commit -m "Rewrite ReflectionTab to render Turn-based narratives + collapsed details"
```

---

## Task 18: Manual end-to-end smoke

This task requires a deployed Cloud Function (Task 10) and installed Claude Code hooks (existing `scripts/install-reflection-hooks.sh`).

**Files:** none.

- [ ] **Step 1: Verify hooks installed and active**

Confirm with user:
```bash
ls -la ~/.codepet/hooks/
cat ~/.claude/settings.json | jq '.hooks'
```
Expected: 3 hook scripts present, settings.json has `UserPromptSubmit`, `PostToolUse`, `Stop` entries pointing to them.

- [ ] **Step 2: Verify CodePet build runs**

Build & run CodePet from Xcode. Open the Reflection tab; should show "Chưa có gì để phản tỉnh." (or existing turns from prior captures).

- [ ] **Step 3: Run a real Claude Code prompt**

In a separate terminal, run a Claude Code session:
```bash
cd /tmp && mkdir smoke && cd smoke && claude
```
Type a prompt like: "Tạo file hello.txt với nội dung 'xin chào'"
Wait for Claude to finish.

- [ ] **Step 4: Verify event flow**

Within ~2 seconds of Claude finishing:
```bash
tail -3 ~/Library/Containers/app.murror.codepet/Data/.codepet/events.jsonl
```
Expected: prompt + tool + summary events appear.

Within ~10 seconds of Claude finishing:
```bash
tail -1 ~/Library/Containers/app.murror.codepet/Data/.codepet/narratives.jsonl
```
Expected: narrative line with title/what_you_wanted/what_happened/lesson, in Vietnamese.

- [ ] **Step 5: Verify UI**

In CodePet Reflection tab: new turn appears in HÔM NAY with title (the AI-generated one, not the prompt). Click it. Verify:
- 3 sections render (BẠN MUỐN / ĐÃ LÀM / BÀI HỌC)
- "Xem chi tiết kỹ thuật" toggles show raw prompt + tool events
- Old technical layout (Moments column) is gone

- [ ] **Step 6: Quota smoke (optional)**

In Firestore console, manually edit `usage/<uid>/<today>` field to `49`. Run one more Claude prompt. Verify next turn shows "Hết hạn ngạch hôm nay" failed state with reset countdown.

- [ ] **Step 7: Network failure smoke**

Disable wifi. Run a Claude prompt. Verify turn shows "Không tóm tắt được câu chuyện" with [Thử lại] button. Re-enable wifi, click Thử lại. Verify narrative arrives.

- [ ] **Step 8: No commit** (manual verification only)

---

## Final Validation Checklist

After all tasks are complete:

- [ ] `xcodebuild test -scheme codepet -destination 'platform=macOS'` passes (all suites green)
- [ ] `cd functions && npm test` passes (all suites green)
- [ ] `cd functions && npm run build` produces no warnings
- [ ] `xcodebuild -scheme codepet build -destination 'platform=macOS'` passes
- [ ] Manual smoke (Task 18) all steps green
- [ ] No `Moments` column visible in Reflection tab default UI
- [ ] AI narratives in Vietnamese (when persona = vi) and contain no file/CLI names
- [ ] `narratives.jsonl` and `events.jsonl` both growing as expected
- [ ] Firestore `usage/{uid}` document increments per call
