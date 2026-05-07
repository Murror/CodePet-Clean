# Reflection Session Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-session chat in the Reflection tab where the user can ask questions about a coding session and the pet streams answers grounded in that session's full context.

**Architecture:** A new Cloud Function (`chatSession`) streams Anthropic responses as Server-Sent Events. The Swift app exposes the stream as an `AsyncThrowingStream`, persists messages locally per session, and renders a floating bubble in the session view that expands into a chat panel.

**Tech Stack:** SwiftUI, Combine, XCTest (Swift); Firebase Cloud Functions v2, Anthropic SDK, Jest (TypeScript). Wire format: SSE with `event:`/`data:` frames.

**Spec:** `docs/superpowers/specs/2026-05-07-session-chat-design.md`

---

## File Structure

**New (Swift):**
- `codepet/Models/ReflectionChat.swift` — `ChatMessage`, `SessionChatThread`
- `codepet/Managers/SessionChatStore.swift` — disk-persisted thread store
- `codepet/Views/Reflection/SessionChatController.swift` — view-model owning send/cancel/stream state
- `codepet/Views/Reflection/SessionChatPanel.swift` — expanded chat panel
- `codepet/Views/Reflection/SessionChatBubble.swift` — floating collapsed bubble

**New (TypeScript):**
- `functions/src/chat.ts` — handler, payload validation, SSE response, Anthropic streaming
- `functions/src/__tests__/chat.test.ts` — handler + helper tests

**New (tests):**
- `codepetTests/SessionChatStoreTests.swift`
- `codepetTests/SessionChatControllerTests.swift`
- `codepetTests/ReflectionCompositionChatContextTests.swift`

**Modified:**
- `codepet/Services/ReflectionAPIClient.swift` — add `ChatSessionRequest`, `ChatStreamEvent`, `chatSessionStream(_:)`
- `codepet/Managers/ReflectionComposition.swift` — add `makeChatContext(for:userBrief:)`
- `codepet/Views/Reflection/ReflectionTab.swift` — overlay bubble; inject controller
- `codepet/App/CodePetApp.swift` — instantiate + inject `SessionChatStore`
- `functions/src/index.ts` — export `chatSession`
- `codepetTests/ReflectionAPIClientTests.swift` — add SSE/streaming cases

---

## Task 1: Chat data model

**Files:**
- Create: `codepet/Models/ReflectionChat.swift`
- Test: `codepetTests/SessionChatStoreTests.swift` (new file; just add the model round-trip test for now — store tests come in Task 2)

- [ ] **Step 1.1: Write the failing model round-trip test**

Append to a new file `codepetTests/SessionChatStoreTests.swift`:

```swift
import XCTest
@testable import codepet

final class SessionChatStoreTests: XCTestCase {

    func testChatMessageRoundTripsThroughCodable() throws {
        let original = ChatMessage(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            role: .pet,
            text: "Hỏi mình về phiên này nhé.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testThreadRoundTripsThroughCodable() throws {
        let thread = SessionChatThread(
            sessionId: "s1",
            messages: [
                ChatMessage(id: UUID(), role: .user, text: "what happened?", createdAt: Date(timeIntervalSince1970: 1_700_000_001)),
                ChatMessage(id: UUID(), role: .pet, text: "Together we…", createdAt: Date(timeIntervalSince1970: 1_700_000_002))
            ],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_002)
        )
        let data = try JSONEncoder().encode(thread)
        let decoded = try JSONDecoder().decode(SessionChatThread.self, from: data)
        XCTAssertEqual(decoded.sessionId, thread.sessionId)
        XCTAssertEqual(decoded.messages, thread.messages)
        XCTAssertEqual(decoded.updatedAt, thread.updatedAt)
    }
}
```

- [ ] **Step 1.2: Run test, expect compile failure**

Run in Xcode: ⌘U on `codepetTests`.
Expected: build fails — `ChatMessage` and `SessionChatThread` undefined.

- [ ] **Step 1.3: Implement the model**

Create `codepet/Models/ReflectionChat.swift`:

```swift
import Foundation

struct ChatMessage: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    enum Role: String, Codable {
        case user
        case pet
    }
}

struct SessionChatThread: Codable, Equatable {
    let sessionId: String
    var messages: [ChatMessage]
    var updatedAt: Date
}
```

- [ ] **Step 1.4: Run test, expect pass**

⌘U. Both tests should pass.

- [ ] **Step 1.5: Commit**

```bash
git add codepet/Models/ReflectionChat.swift codepetTests/SessionChatStoreTests.swift
git commit -m "Add ChatMessage and SessionChatThread models for Reflection chat"
```

---

## Task 2: SessionChatStore

**Files:**
- Create: `codepet/Managers/SessionChatStore.swift`
- Modify: `codepetTests/SessionChatStoreTests.swift`

- [ ] **Step 2.1: Add failing store tests**

Append to `codepetTests/SessionChatStoreTests.swift` (inside the existing `final class SessionChatStoreTests`):

```swift
    private func tempFileURL(_ name: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name).json")
    }

    @MainActor
    func testAppendAndRetrieveMessagesIsolatedPerSession() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SessionChatStore(fileURL: url, saveDebounce: 0)

        let m1 = ChatMessage(id: UUID(), role: .user, text: "a", createdAt: Date())
        let m2 = ChatMessage(id: UUID(), role: .pet, text: "b", createdAt: Date())
        let m3 = ChatMessage(id: UUID(), role: .user, text: "c", createdAt: Date())

        store.append(m1, to: "s1")
        store.append(m2, to: "s1")
        store.append(m3, to: "s2")

        XCTAssertEqual(store.messages(for: "s1").map(\.text), ["a", "b"])
        XCTAssertEqual(store.messages(for: "s2").map(\.text), ["c"])
        XCTAssertEqual(store.messages(for: "s3"), [])
    }

    @MainActor
    func testPersistsAndReloadsFromDisk() throws {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let store = SessionChatStore(fileURL: url, saveDebounce: 0)
            store.append(ChatMessage(id: UUID(), role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1)), to: "s1")
            store.flushForTests()
        }

        let store2 = SessionChatStore(fileURL: url, saveDebounce: 0)
        XCTAssertEqual(store2.messages(for: "s1").map(\.text), ["hi"])
    }

    @MainActor
    func testHistorySnapshotReturnsLastNInOrder() {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SessionChatStore(fileURL: url, saveDebounce: 0)

        for i in 1...15 {
            store.append(
                ChatMessage(id: UUID(), role: i.isMultiple(of: 2) ? .pet : .user, text: "m\(i)", createdAt: Date(timeIntervalSince1970: TimeInterval(i))),
                to: "s1"
            )
        }

        let snapshot = store.historySnapshot(for: "s1", lastN: 10)
        XCTAssertEqual(snapshot.count, 10)
        XCTAssertEqual(snapshot.first?.text, "m6")
        XCTAssertEqual(snapshot.last?.text, "m15")
    }

    @MainActor
    func testCorruptFileFallsBackToEmptyStore() throws {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "not valid json".data(using: .utf8)!.write(to: url)

        let store = SessionChatStore(fileURL: url, saveDebounce: 0)
        XCTAssertEqual(store.messages(for: "s1"), [])
    }
```

- [ ] **Step 2.2: Run, expect compile failure**

⌘U. `SessionChatStore` undefined.

- [ ] **Step 2.3: Implement the store**

Create `codepet/Managers/SessionChatStore.swift`:

```swift
import Foundation
import Combine
import os

@MainActor
final class SessionChatStore: ObservableObject {

    @Published private(set) var threads: [String: SessionChatThread] = [:]

    private let fileURL: URL
    private let saveDebounce: TimeInterval
    private let logger = Logger(subsystem: "app.murror.codepet", category: "SessionChatStore")
    private var saveTask: Task<Void, Never>?
    private let ioQueue = DispatchQueue(label: "app.murror.codepet.SessionChatStore.io")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codepet/session_chats.json"),
        saveDebounce: TimeInterval = 0.2
    ) {
        self.fileURL = fileURL
        self.saveDebounce = saveDebounce

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        loadFromDisk()
    }

    // MARK: - Public API

    func messages(for sessionId: String) -> [ChatMessage] {
        threads[sessionId]?.messages ?? []
    }

    func append(_ message: ChatMessage, to sessionId: String) {
        var thread = threads[sessionId] ?? SessionChatThread(
            sessionId: sessionId,
            messages: [],
            updatedAt: message.createdAt
        )
        thread.messages.append(message)
        thread.updatedAt = message.createdAt
        threads[sessionId] = thread
        scheduleSave()
    }

    func clear(_ sessionId: String) {
        threads.removeValue(forKey: sessionId)
        scheduleSave()
    }

    /// Returns the last N messages in chronological order. Used to build the
    /// `history` field of a chat request.
    func historySnapshot(for sessionId: String, lastN: Int = 10) -> [ChatMessage] {
        let all = messages(for: sessionId)
        guard all.count > lastN else { return all }
        return Array(all.suffix(lastN))
    }

    /// Synchronously flush any pending save. For tests.
    func flushForTests() {
        saveTask?.cancel()
        saveTask = nil
        writeToDisk(threads)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode([String: SessionChatThread].self, from: data)
            self.threads = decoded
        } catch CocoaError.fileReadNoSuchFile {
            // First run; no file yet.
            self.threads = [:]
        } catch {
            logger.error("Failed to load chat threads, starting fresh: \(String(describing: error))")
            self.threads = [:]
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = threads
        let debounce = saveDebounce
        saveTask = Task { [weak self] in
            if debounce > 0 {
                try? await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
                if Task.isCancelled { return }
            }
            self?.writeToDisk(snapshot)
        }
    }

    private nonisolated func writeToDisk(_ snapshot: [String: SessionChatThread]) {
        ioQueue.sync {
            do {
                let directory = self.fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                let tmp = self.fileURL.appendingPathExtension("tmp")
                let data = try self.encoder.encode(snapshot)
                try data.write(to: tmp, options: .atomic)
                _ = try FileManager.default.replaceItemAt(self.fileURL, withItemAt: tmp)
            } catch {
                self.logger.error("Failed to save chat threads: \(String(describing: error))")
            }
        }
    }
}
```

- [ ] **Step 2.4: Run, expect pass**

⌘U. All four store tests pass.

- [ ] **Step 2.5: Commit**

```bash
git add codepet/Managers/SessionChatStore.swift codepetTests/SessionChatStoreTests.swift
git commit -m "Add SessionChatStore with disk persistence and per-session isolation"
```

---

## Task 3: Cloud Function — payload validation

**Files:**
- Create: `functions/src/chat.ts` (validation only for now)
- Create: `functions/src/__tests__/chat.test.ts`

- [ ] **Step 3.1: Write failing validation tests**

Create `functions/src/__tests__/chat.test.ts`:

```typescript
import { validateChatPayload } from "../chat";

describe("validateChatPayload", () => {
  const valid = {
    session_id: "s1",
    language: "vi",
    pet_persona: { id: "byte", name: "Byte", personality: "glitchy", domain: "Data" },
    session_context: {
      user_brief: "building a journal",
      summary: { summary: "We worked on X.", lesson: "Stay focused." },
      turns: [
        {
          prompt: "fix the layout",
          what_you_wanted: "you wanted",
          what_happened: "you did",
          lesson: "be patient",
          duration_minutes: 10,
          events: [{ time: "09:00", tool: "Edit", path: "foo.swift" }]
        }
      ]
    },
    history: [
      { role: "user", text: "hi" },
      { role: "pet", text: "hi back" }
    ],
    user_message: "what was the messy part?"
  };

  test("returns null for a valid payload", () => {
    expect(validateChatPayload(valid)).toBeNull();
  });

  test("rejects missing session_id", () => {
    const bad = { ...valid, session_id: "" };
    expect(validateChatPayload(bad)).toMatch(/session_id/);
  });

  test("rejects missing user_message", () => {
    const bad = { ...valid, user_message: "" };
    expect(validateChatPayload(bad)).toMatch(/user_message/);
  });

  test("rejects bad language", () => {
    const bad = { ...valid, language: "fr" };
    expect(validateChatPayload(bad)).toMatch(/language/);
  });

  test("rejects non-array turns", () => {
    const bad = { ...valid, session_context: { ...valid.session_context, turns: "x" as any } };
    expect(validateChatPayload(bad)).toMatch(/turns/);
  });

  test("rejects history > 20 messages", () => {
    const bad = {
      ...valid,
      history: Array.from({ length: 21 }, (_, i) => ({ role: "user" as const, text: `m${i}` }))
    };
    expect(validateChatPayload(bad)).toMatch(/history/);
  });

  test("rejects history with bad role", () => {
    const bad = { ...valid, history: [{ role: "assistant" as any, text: "x" }] };
    expect(validateChatPayload(bad)).toMatch(/role/);
  });

  test("rejects pet_persona missing fields", () => {
    const bad = { ...valid, pet_persona: { id: "byte" } as any };
    expect(validateChatPayload(bad)).toMatch(/pet_persona/);
  });

  test("accepts payload without optional fields", () => {
    const minimal = {
      session_id: "s1",
      language: "en",
      session_context: { turns: [{ prompt: "hi", events: [] }] },
      history: [],
      user_message: "what?"
    };
    expect(validateChatPayload(minimal)).toBeNull();
  });
});
```

- [ ] **Step 3.2: Run, expect failure**

```bash
cd functions && npm test -- chat.test.ts
```
Expected: cannot find module `../chat`.

- [ ] **Step 3.3: Implement the validator**

Create `functions/src/chat.ts`:

```typescript
import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import { MODEL, PERSONA_BLOCK_TEMPLATE, renderPersonaBlock, PetPersonaInput } from "./anthropic";

export interface ChatTurnContext {
  prompt: string;
  what_you_wanted?: string;
  what_happened?: string;
  lesson?: string;
  duration_minutes?: number;
  events: Array<{ time: string; tool: string; path?: string; text?: string }>;
}

export interface ChatSessionContext {
  user_brief?: string;
  summary?: { summary: string; lesson: string };
  turns: ChatTurnContext[];
}

export interface ChatHistoryMessage {
  role: "user" | "pet";
  text: string;
}

export interface ChatSessionPayload {
  session_id: string;
  language: "vi" | "en";
  pet_persona?: PetPersonaInput;
  session_context: ChatSessionContext;
  history: ChatHistoryMessage[];
  user_message: string;
}

const MAX_HISTORY_MESSAGES = 20;

export function validateChatPayload(body: any): string | null {
  if (!body || typeof body !== "object") return "body required";
  const b = body as Partial<ChatSessionPayload>;

  if (typeof b.session_id !== "string" || b.session_id.length === 0) {
    return "session_id required";
  }
  if (b.language !== "vi" && b.language !== "en") {
    return "language must be 'vi' or 'en'";
  }
  if (typeof b.user_message !== "string" || b.user_message.length === 0) {
    return "user_message required";
  }

  if (!b.session_context || typeof b.session_context !== "object") {
    return "session_context required";
  }
  const ctx = b.session_context as ChatSessionContext;
  if (!Array.isArray(ctx.turns)) return "session_context.turns must be an array";
  for (const t of ctx.turns) {
    if (typeof t !== "object" || t === null) return "each turn must be an object";
    if (typeof t.prompt !== "string") return "each turn requires prompt string";
    if (!Array.isArray(t.events)) return "each turn requires events array";
  }

  if (!Array.isArray(b.history)) return "history must be an array";
  if (b.history.length > MAX_HISTORY_MESSAGES) {
    return `history exceeds ${MAX_HISTORY_MESSAGES} messages`;
  }
  for (const m of b.history) {
    if (!m || typeof m !== "object") return "each history message must be an object";
    if (m.role !== "user" && m.role !== "pet") return "history role must be 'user' or 'pet'";
    if (typeof m.text !== "string") return "history text must be a string";
  }

  if (b.pet_persona !== undefined) {
    const p = b.pet_persona;
    if (!p || typeof p !== "object") return "pet_persona must be an object";
    if (
      typeof p.id !== "string" ||
      typeof p.name !== "string" ||
      typeof p.personality !== "string" ||
      typeof p.domain !== "string"
    ) {
      return "pet_persona requires id/name/personality/domain strings";
    }
  }

  return null;
}
```

- [ ] **Step 3.4: Run, expect pass**

```bash
cd functions && npm test -- chat.test.ts
```
Expected: all 9 tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add functions/src/chat.ts functions/src/__tests__/chat.test.ts
git commit -m "Add chatSession payload validator with tests"
```

---

## Task 4: Cloud Function — system prompt + user message builders

**Files:**
- Modify: `functions/src/chat.ts`
- Modify: `functions/src/__tests__/chat.test.ts`

- [ ] **Step 4.1: Add failing builder tests**

Append to `functions/src/__tests__/chat.test.ts`:

```typescript
import { buildChatSystemPrompt, buildChatUserMessage, buildChatMessages, CHAT_SYSTEM_PROMPT } from "../chat";

describe("buildChatSystemPrompt", () => {
  test("substitutes language and persona", () => {
    const prompt = buildChatSystemPrompt({
      language: "vi",
      petPersona: { id: "byte", name: "Byte", personality: "glitchy", domain: "Data" },
      sessionContext: { turns: [{ prompt: "fix", events: [] }] }
    });
    expect(prompt).toContain("Tiếng Việt");
    expect(prompt).toContain("Byte");
    expect(prompt).toContain("glitchy");
    expect(prompt).not.toContain("<language>");
    expect(prompt).not.toContain("<persona_block>");
  });

  test("renders user_brief when present", () => {
    const prompt = buildChatSystemPrompt({
      language: "en",
      sessionContext: {
        user_brief: "shipping a journaling app",
        turns: [{ prompt: "x", events: [] }]
      }
    });
    expect(prompt).toContain("shipping a journaling app");
  });

  test("renders session summary when present", () => {
    const prompt = buildChatSystemPrompt({
      language: "en",
      sessionContext: {
        summary: { summary: "We refactored auth.", lesson: "Small steps." },
        turns: [{ prompt: "x", events: [] }]
      }
    });
    expect(prompt).toContain("We refactored auth.");
    expect(prompt).toContain("Small steps.");
  });

  test("renders each turn with its narrative and events", () => {
    const prompt = buildChatSystemPrompt({
      language: "en",
      sessionContext: {
        turns: [
          {
            prompt: "fix the layout",
            what_you_wanted: "you wanted clean rows",
            what_happened: "we tried twice",
            lesson: "isolate the layout first",
            duration_minutes: 12,
            events: [
              { time: "09:00", tool: "Edit", path: "ReflectionTab.swift" },
              { time: "09:05", tool: "Bash", text: "swift test" }
            ]
          }
        ]
      }
    });
    expect(prompt).toContain("fix the layout");
    expect(prompt).toContain("you wanted clean rows");
    expect(prompt).toContain("we tried twice");
    expect(prompt).toContain("isolate the layout first");
    expect(prompt).toContain("ReflectionTab.swift");
    expect(prompt).toContain("swift test");
  });

  test("forbids file/jargon rules are present", () => {
    expect(CHAT_SYSTEM_PROMPT).toMatch(/file name/i);
    expect(CHAT_SYSTEM_PROMPT).toMatch(/AI|assistant/);
    expect(CHAT_SYSTEM_PROMPT).toMatch(/second person|"you"|bạn/);
  });
});

describe("buildChatMessages", () => {
  test("maps history roles and appends user_message as final user turn", () => {
    const messages = buildChatMessages({
      history: [
        { role: "user", text: "what was tricky?" },
        { role: "pet", text: "Together we kept circling…" }
      ],
      userMessage: "tell me more"
    });
    expect(messages).toEqual([
      { role: "user", content: "what was tricky?" },
      { role: "assistant", content: "Together we kept circling…" },
      { role: "user", content: "tell me more" }
    ]);
  });

  test("handles empty history", () => {
    const messages = buildChatMessages({ history: [], userMessage: "hi" });
    expect(messages).toEqual([{ role: "user", content: "hi" }]);
  });
});
```

- [ ] **Step 4.2: Run, expect compile failure**

```bash
cd functions && npm test -- chat.test.ts
```
Expected: cannot find `buildChatSystemPrompt` etc.

- [ ] **Step 4.3: Implement the builders**

Append to `functions/src/chat.ts`:

```typescript
const MAX_BRIEF_CHARS = 1200;
const MAX_PROMPT_CHARS_PER_TURN = 600;
const MAX_NARRATIVE_CHARS_PER_FIELD = 300;
const MAX_EVENTS_PER_TURN = 30;
const MAX_TURNS = 30;

export const CHAT_SYSTEM_PROMPT = `You are the user's coding companion — a pet character who watched a coding session unfold and is now chatting with the user about it.

There is no separate "AI" or "assistant" in the story. You are the sole voice talking directly to the user (the developer / "you" / "bạn") about THEIR session.

Voice rules (must follow):
1. Single-voice narration. You (the pet) are the only speaker. NEVER mention an "AI", "assistant", "Claude", "the model", or any third party.
2. Address the user in second person ("you" / "bạn"). First person ("I" / "mình") is fine when YOU (the pet) reflect on what you noticed.
3. DO NOT use file names, function names, class names, or CLI commands. Express the MEANING instead — e.g. "you adjusted how the journal page looks", not "Edit ReflectionTab.swift". Even if the user asks about a specific file in their question, answer in meaning rather than naming files back.
4. Tone: warm, concise, conversational — a small friend curled up beside the user. No emoji. No headings or bullet lists; chat replies are plain prose.
5. Stay grounded in the SESSION CONTEXT below. If the user asks something the session doesn't cover, say you don't see it in this session rather than inventing.
6. Replies are short by default — usually 1-3 sentences. Go longer only if the user explicitly asks for more detail.

<persona_block>

Output language: <language>

SESSION CONTEXT (this is the only knowledge you have about the user's session):
<session_context>`;

interface BuildSystemArgs {
  language: "vi" | "en";
  petPersona?: PetPersonaInput;
  sessionContext: ChatSessionContext;
}

export function buildChatSystemPrompt(args: BuildSystemArgs): string {
  return CHAT_SYSTEM_PROMPT
    .replace("<language>", args.language === "vi" ? "Tiếng Việt" : "English")
    .replace("<persona_block>", renderPersonaBlock(args.petPersona).trim())
    .replace("<session_context>", renderSessionContext(args.sessionContext));
}

function renderSessionContext(ctx: ChatSessionContext): string {
  const parts: string[] = [];

  const brief = (ctx.user_brief ?? "").trim();
  if (brief) {
    parts.push(`Project context the user shared with you:\n"""\n${brief.slice(0, MAX_BRIEF_CHARS)}\n"""`);
  }

  if (ctx.summary) {
    parts.push(
      `Session arc (your earlier recap to the user):\n` +
        `Summary: ${ctx.summary.summary}\n` +
        `Lesson: ${ctx.summary.lesson}`
    );
  }

  const turns = ctx.turns.slice(0, MAX_TURNS);
  const turnLines = turns.map((t, i) => {
    const dur = t.duration_minutes ? ` (~${t.duration_minutes}m)` : "";
    const what = t.what_happened
      ? `\n   What happened: ${t.what_happened.slice(0, MAX_NARRATIVE_CHARS_PER_FIELD)}`
      : "";
    const wanted = t.what_you_wanted
      ? `\n   What was wanted: ${t.what_you_wanted.slice(0, MAX_NARRATIVE_CHARS_PER_FIELD)}`
      : "";
    const lesson = t.lesson
      ? `\n   Turn lesson: ${t.lesson.slice(0, MAX_NARRATIVE_CHARS_PER_FIELD)}`
      : "";
    const events = t.events.slice(0, MAX_EVENTS_PER_TURN);
    const eventBlock = events.length === 0
      ? ""
      : "\n   Actions: " + events.map((e) => `${e.time} ${e.tool} ${e.path ?? e.text ?? ""}`.trim()).join("; ");
    return `${i + 1}. User asked: "${t.prompt.slice(0, MAX_PROMPT_CHARS_PER_TURN)}"${dur}${wanted}${what}${lesson}${eventBlock}`;
  });

  parts.push(`Turns in chronological order:\n${turnLines.join("\n\n")}`);
  return parts.join("\n\n");
}

interface BuildMessagesArgs {
  history: ChatHistoryMessage[];
  userMessage: string;
}

export interface AnthropicChatMessage {
  role: "user" | "assistant";
  content: string;
}

export function buildChatMessages(args: BuildMessagesArgs): AnthropicChatMessage[] {
  const mapped: AnthropicChatMessage[] = args.history.map((m) => ({
    role: m.role === "user" ? "user" : "assistant",
    content: m.text
  }));
  mapped.push({ role: "user", content: args.userMessage });
  return mapped;
}

export function buildChatUserMessage(args: BuildMessagesArgs): string {
  return args.userMessage;
}
```

- [ ] **Step 4.4: Run tests, expect pass**

```bash
cd functions && npm test -- chat.test.ts
```
Expected: all tests including the new builder tests pass.

- [ ] **Step 4.5: Commit**

```bash
git add functions/src/chat.ts functions/src/__tests__/chat.test.ts
git commit -m "Add chatSession system prompt + message builders"
```

---

## Task 5: Cloud Function — handler with SSE streaming

**Files:**
- Modify: `functions/src/chat.ts`
- Modify: `functions/src/__tests__/chat.test.ts`

- [ ] **Step 5.1: Write the failing handler tests**

Append to `functions/src/__tests__/chat.test.ts`:

```typescript
import { handleChatSession, __setStreamFactoryForTests, __resetStreamFactoryForTests } from "../chat";

// Verify-auth + rate-limit are mocked through the actual modules' env in a real
// test runner setup. For this plan we mock at module level.
jest.mock("../auth", () => ({
  verifyAuth: jest.fn(async (header: string | undefined) => {
    if (header === "Bearer good") return { uid: "user1" };
    return null;
  }),
  extractBearerToken: (h: string | undefined) => (h?.startsWith("Bearer ") ? h.slice(7) : null)
}));

jest.mock("../rateLimit", () => ({
  checkAndIncrement: jest.fn(async (uid: string) => ({
    allowed: uid !== "capped",
    resetAt: new Date("2026-05-08T00:00:00Z"),
    limit: 50
  }))
}));

function makeReq(overrides: any = {}): any {
  return {
    method: "POST",
    headers: { authorization: "Bearer good" },
    body: {
      session_id: "s1",
      language: "en",
      session_context: { turns: [{ prompt: "hi", events: [] }] },
      history: [],
      user_message: "what happened?"
    },
    ...overrides
  };
}

function makeRes() {
  const headers: Record<string, string> = {};
  let statusCode = 0;
  const writes: string[] = [];
  let ended = false;
  return {
    statusCode,
    headers,
    writes,
    ended: () => ended,
    setHeader(k: string, v: string) { headers[k] = v; },
    status(code: number) { statusCode = code; (this as any).statusCode = code; return this; },
    json(obj: any) { writes.push(JSON.stringify(obj)); ended = true; (this as any).statusCode = (this as any).statusCode || 200; },
    write(chunk: string) { writes.push(chunk); return true; },
    end() { ended = true; },
    flushHeaders() { /* noop */ }
  };
}

describe("handleChatSession", () => {
  beforeEach(() => __resetStreamFactoryForTests());

  test("rejects non-POST methods", async () => {
    const req = makeReq({ method: "GET" });
    const res = makeRes();
    await handleChatSession(req as any, res as any);
    expect((res as any).statusCode).toBe(405);
  });

  test("returns 401 for missing auth", async () => {
    const req = makeReq({ headers: { authorization: undefined } });
    const res = makeRes();
    await handleChatSession(req as any, res as any);
    expect((res as any).statusCode).toBe(401);
  });

  test("returns 400 for invalid payload", async () => {
    const req = makeReq({ body: { session_id: "" } });
    const res = makeRes();
    await handleChatSession(req as any, res as any);
    expect((res as any).statusCode).toBe(400);
  });

  test("returns 429 when rate-limited", async () => {
    // Force rate-limit to deny.
    const rl = require("../rateLimit");
    rl.checkAndIncrement.mockImplementationOnce(async () => ({
      allowed: false,
      resetAt: new Date("2026-05-08T00:00:00Z"),
      limit: 50
    }));
    const req = makeReq();
    const res = makeRes();
    await handleChatSession(req as any, res as any);
    expect((res as any).statusCode).toBe(429);
  });

  test("happy path streams deltas and a done frame", async () => {
    __setStreamFactoryForTests(async function* () {
      yield { type: "text", text: "Together " };
      yield { type: "text", text: "we kept " };
      yield { type: "text", text: "circling." };
      yield {
        type: "done",
        usage: { cache_read_input_tokens: 10, input_tokens: 5, output_tokens: 5 }
      };
    });

    const req = makeReq();
    const res = makeRes();
    await handleChatSession(req as any, res as any);

    expect((res as any).headers["Content-Type"]).toBe("text/event-stream");
    const body = (res as any).writes.join("");
    expect(body).toContain('event: delta\ndata: {"text":"Together "}');
    expect(body).toContain('event: delta\ndata: {"text":"we kept "}');
    expect(body).toContain('event: delta\ndata: {"text":"circling."}');
    expect(body).toContain('event: done');
    expect(body).toContain('"cache_hit":true');
  });

  test("mid-stream Anthropic error emits an error frame", async () => {
    __setStreamFactoryForTests(async function* () {
      yield { type: "text", text: "Together " };
      throw new Error("upstream blew up");
    });

    const req = makeReq();
    const res = makeRes();
    await handleChatSession(req as any, res as any);

    const body = (res as any).writes.join("");
    expect(body).toContain('event: delta\ndata: {"text":"Together "}');
    expect(body).toContain('event: error');
    expect((res as any).statusCode).toBe(200);  // headers already sent
  });
});
```

- [ ] **Step 5.2: Run, expect failure**

```bash
cd functions && npm test -- chat.test.ts
```
Expected: cannot find `handleChatSession` etc.

- [ ] **Step 5.3: Implement the handler**

Append to `functions/src/chat.ts`:

```typescript
// MARK: - Stream abstraction (testable)

type StreamEvent =
  | { type: "text"; text: string }
  | { type: "done"; usage?: { cache_read_input_tokens?: number; input_tokens?: number; output_tokens?: number } };

type StreamFactory = (args: {
  client: Anthropic;
  system: string;
  messages: AnthropicChatMessage[];
}) => AsyncIterable<StreamEvent>;

let _streamFactory: StreamFactory | null = null;

export function __setStreamFactoryForTests(factory: () => AsyncIterable<StreamEvent>) {
  _streamFactory = () => factory();
}

export function __resetStreamFactoryForTests() {
  _streamFactory = null;
}

async function* defaultStreamFactory(args: {
  client: Anthropic;
  system: string;
  messages: AnthropicChatMessage[];
}): AsyncIterable<StreamEvent> {
  const stream = args.client.messages.stream({
    model: MODEL,
    max_tokens: 600,
    system: [{ type: "text", text: args.system, cache_control: { type: "ephemeral" } }],
    messages: args.messages.map((m) => ({ role: m.role, content: m.content }))
  });

  for await (const event of stream) {
    if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
      yield { type: "text", text: event.delta.text };
    }
  }

  const final = await stream.finalMessage();
  yield {
    type: "done",
    usage: {
      cache_read_input_tokens: (final.usage as any)?.cache_read_input_tokens ?? 0,
      input_tokens: final.usage?.input_tokens ?? 0,
      output_tokens: final.usage?.output_tokens ?? 0
    }
  };
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

function writeFrame(res: Response, event: string, payload: unknown): void {
  res.write(`event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`);
}

export async function handleChatSession(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  const auth = await verifyAuth(req.headers.authorization);
  if (!auth) {
    res.status(401).json({ error: "invalid_token" });
    return;
  }

  const validationError = validateChatPayload(req.body);
  if (validationError) {
    res.status(400).json({ error: "invalid_payload", detail: validationError });
    return;
  }
  const payload = req.body as ChatSessionPayload;

  const limit = await checkAndIncrement(auth.uid);
  if (!limit.allowed) {
    res.status(429).json({
      error: "daily_limit_reached",
      reset_at: limit.resetAt.toISOString(),
      limit: limit.limit
    });
    return;
  }

  // Begin SSE response.
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.status(200);
  if (typeof (res as any).flushHeaders === "function") {
    (res as any).flushHeaders();
  }

  const system = buildChatSystemPrompt({
    language: payload.language,
    petPersona: payload.pet_persona,
    sessionContext: payload.session_context
  });
  const messages = buildChatMessages({
    history: payload.history,
    userMessage: payload.user_message
  });

  const factory: StreamFactory = _streamFactory ?? defaultStreamFactory;

  let cacheHit = false;
  try {
    for await (const event of factory({
      client: _streamFactory ? (null as any) : anthropicClient(),
      system,
      messages
    })) {
      if (event.type === "text") {
        writeFrame(res, "delta", { text: event.text });
      } else if (event.type === "done") {
        cacheHit = (event.usage?.cache_read_input_tokens ?? 0) > 0;
        writeFrame(res, "done", { model: MODEL, cache_hit: cacheHit });
      }
    }
  } catch (err) {
    logger.error("chatSession stream failed", {
      uid: auth.uid,
      session_id: payload.session_id,
      err: String(err)
    });
    writeFrame(res, "error", { error: "upstream_failure", detail: String(err) });
  } finally {
    res.end();
  }
}
```

- [ ] **Step 5.4: Run, expect pass**

```bash
cd functions && npm test -- chat.test.ts
```
Expected: all tests pass.

- [ ] **Step 5.5: Commit**

```bash
git add functions/src/chat.ts functions/src/__tests__/chat.test.ts
git commit -m "Add chatSession handler with SSE streaming and stub factory for tests"
```

---

## Task 6: Register `chatSession` export

**Files:**
- Modify: `functions/src/index.ts`

- [ ] **Step 6.1: Wire the export**

Edit `functions/src/index.ts`. After the `summarizeSession` export, add:

```typescript
import { handleChatSession } from "./chat";

export const chatSession = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleChatSession
);
```

(Combine the `import` with the existing imports at the top of the file rather than duplicating.)

- [ ] **Step 6.2: Run TypeScript build**

```bash
cd functions && npm run build
```
Expected: clean build, no errors.

- [ ] **Step 6.3: Run all function tests**

```bash
cd functions && npm test
```
Expected: all tests pass, including chat.

- [ ] **Step 6.4: Commit**

```bash
git add functions/src/index.ts
git commit -m "Register chatSession Cloud Function export"
```

---

## Task 7: Swift API client — DTOs

**Files:**
- Modify: `codepet/Services/ReflectionAPIClient.swift`
- Modify: `codepetTests/ReflectionAPIClientTests.swift`

- [ ] **Step 7.1: Add failing DTO encoding test**

Append to `codepetTests/ReflectionAPIClientTests.swift` (inside the existing class):

```swift
    func testChatSessionRequestEncodesSnakeCase() throws {
        let request = ChatSessionRequest(
            sessionId: "s1",
            language: "vi",
            petPersona: SummarizeTurnRequest.PetPersonaDTO(
                id: "byte", name: "Byte", personality: "glitchy", domain: "Data"
            ),
            sessionContext: ChatSessionRequest.SessionContextDTO(
                userBrief: "building",
                summary: ChatSessionRequest.SessionContextDTO.SummaryDTO(
                    summary: "We worked.", lesson: "Stay focused."
                ),
                turns: [
                    ChatSessionRequest.SessionContextDTO.TurnDTO(
                        prompt: "fix",
                        whatYouWanted: "you wanted",
                        whatHappened: "you did",
                        lesson: "be patient",
                        durationMinutes: 12,
                        events: [SummarizeTurnRequest.EventDTO(
                            time: "09:00", tool: "Edit", path: "foo.swift", text: nil
                        )]
                    )
                ]
            ),
            history: [
                ChatSessionRequest.ChatMessageDTO(role: "user", text: "hi"),
                ChatSessionRequest.ChatMessageDTO(role: "pet", text: "hi back")
            ],
            userMessage: "what was tricky?"
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["session_id"] as? String, "s1")
        XCTAssertEqual(json["language"] as? String, "vi")
        XCTAssertEqual(json["user_message"] as? String, "what was tricky?")

        let context = json["session_context"] as! [String: Any]
        XCTAssertEqual(context["user_brief"] as? String, "building")
        let turns = context["turns"] as! [[String: Any]]
        XCTAssertEqual(turns.first?["prompt"] as? String, "fix")
        XCTAssertEqual(turns.first?["what_you_wanted"] as? String, "you wanted")
        XCTAssertEqual(turns.first?["duration_minutes"] as? Int, 12)
        let history = json["history"] as! [[String: Any]]
        XCTAssertEqual(history.first?["role"] as? String, "user")
    }
```

- [ ] **Step 7.2: Run, expect compile failure**

⌘U. `ChatSessionRequest` undefined.

- [ ] **Step 7.3: Add DTOs**

Append to `codepet/Services/ReflectionAPIClient.swift` (after the existing session DTOs, before `// MARK: - Client`):

```swift
// MARK: - Chat DTOs

struct ChatSessionRequest: Codable {
    let sessionId: String
    let language: String
    let petPersona: SummarizeTurnRequest.PetPersonaDTO?
    let sessionContext: SessionContextDTO
    let history: [ChatMessageDTO]
    let userMessage: String

    struct SessionContextDTO: Codable {
        let userBrief: String?
        let summary: SummaryDTO?
        let turns: [TurnDTO]

        struct SummaryDTO: Codable {
            let summary: String
            let lesson: String
        }

        struct TurnDTO: Codable {
            let prompt: String
            let whatYouWanted: String?
            let whatHappened: String?
            let lesson: String?
            let durationMinutes: Int?
            let events: [SummarizeTurnRequest.EventDTO]

            enum CodingKeys: String, CodingKey {
                case prompt
                case whatYouWanted = "what_you_wanted"
                case whatHappened = "what_happened"
                case lesson
                case durationMinutes = "duration_minutes"
                case events
            }
        }

        enum CodingKeys: String, CodingKey {
            case userBrief = "user_brief"
            case summary
            case turns
        }
    }

    struct ChatMessageDTO: Codable {
        let role: String   // "user" | "pet"
        let text: String
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case language
        case petPersona = "pet_persona"
        case sessionContext = "session_context"
        case history
        case userMessage = "user_message"
    }
}

enum ChatStreamEvent: Equatable {
    case delta(String)
    case done(model: String, cacheHit: Bool)
}
```

- [ ] **Step 7.4: Run, expect pass**

⌘U. The new test passes.

- [ ] **Step 7.5: Commit**

```bash
git add codepet/Services/ReflectionAPIClient.swift codepetTests/ReflectionAPIClientTests.swift
git commit -m "Add ChatSessionRequest and ChatStreamEvent DTOs"
```

---

## Task 8: Swift API client — SSE parser unit

**Files:**
- Create: `codepet/Services/SSEParser.swift`
- Create: `codepetTests/SSEParserTests.swift`

We split the SSE parser out as its own file so it has a clear, testable boundary independent of `URLSession` plumbing.

- [ ] **Step 8.1: Write failing parser tests**

Create `codepetTests/SSEParserTests.swift`:

```swift
import XCTest
@testable import codepet

final class SSEParserTests: XCTestCase {

    func testParsesSingleDeltaFrame() {
        var parser = SSEParser()
        let frames = parser.feedLines([
            "event: delta",
            "data: {\"text\":\"hi\"}",
            ""
        ])
        XCTAssertEqual(frames, [SSEFrame(event: "delta", data: "{\"text\":\"hi\"}")])
    }

    func testIgnoresCommentsAndUnknownFields() {
        var parser = SSEParser()
        let frames = parser.feedLines([
            ": keep-alive comment",
            "id: 123",
            "event: delta",
            "data: {\"text\":\"x\"}",
            ""
        ])
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames.first?.event, "delta")
    }

    func testJoinsMultiLineData() {
        var parser = SSEParser()
        let frames = parser.feedLines([
            "event: done",
            "data: line1",
            "data: line2",
            ""
        ])
        XCTAssertEqual(frames, [SSEFrame(event: "done", data: "line1\nline2")])
    }

    func testEmitsMultipleFrames() {
        var parser = SSEParser()
        let frames = parser.feedLines([
            "event: delta",
            "data: a",
            "",
            "event: delta",
            "data: b",
            "",
            "event: done",
            "data: {}",
            ""
        ])
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames.map(\.event), ["delta", "delta", "done"])
        XCTAssertEqual(frames.map(\.data), ["a", "b", "{}"])
    }

    func testDefaultsEventToMessageWhenAbsent() {
        var parser = SSEParser()
        let frames = parser.feedLines([
            "data: hi",
            ""
        ])
        XCTAssertEqual(frames, [SSEFrame(event: "message", data: "hi")])
    }

    func testStripsLeadingSpaceAfterColon() {
        // Per the SSE spec, a single space after the colon is stripped.
        var parser = SSEParser()
        let frames = parser.feedLines([
            "event:delta",
            "data:no-space",
            ""
        ])
        XCTAssertEqual(frames, [SSEFrame(event: "delta", data: "no-space")])
    }
}
```

- [ ] **Step 8.2: Run, expect failure**

⌘U. `SSEParser`, `SSEFrame` undefined.

- [ ] **Step 8.3: Implement the parser**

Create `codepet/Services/SSEParser.swift`:

```swift
import Foundation

struct SSEFrame: Equatable {
    let event: String
    let data: String
}

/// Stateful Server-Sent Events line parser. Feed it lines (already split on
/// `\n`); it returns a list of completed frames each time a blank line
/// terminates a frame.
///
/// Implements the subset of the SSE spec we use:
/// - `event:` field (single per frame; defaults to "message")
/// - `data:` field (multiple lines joined with `\n`)
/// - blank line dispatches the accumulated frame
/// - lines starting with `:` are comments and ignored
/// - other field names (`id:`, `retry:`) are ignored
struct SSEParser {
    private var event: String = "message"
    private var dataLines: [String] = []

    mutating func feedLines<S: Sequence>(_ lines: S) -> [SSEFrame] where S.Element == String {
        var frames: [SSEFrame] = []
        for raw in lines {
            if let frame = feedLine(raw) {
                frames.append(frame)
            }
        }
        return frames
    }

    mutating func feedLine(_ line: String) -> SSEFrame? {
        if line.isEmpty {
            // Dispatch
            guard !dataLines.isEmpty || event != "message" else {
                reset()
                return nil
            }
            let frame = SSEFrame(event: event, data: dataLines.joined(separator: "\n"))
            reset()
            return frame
        }

        if line.hasPrefix(":") {
            return nil // comment
        }

        guard let colonIndex = line.firstIndex(of: ":") else {
            // No colon — treat the whole line as a field with empty value (spec).
            // We don't use any such fields, so ignore.
            return nil
        }

        let field = String(line[..<colonIndex])
        var value = String(line[line.index(after: colonIndex)...])
        if value.first == " " {
            value.removeFirst()
        }

        switch field {
        case "event":
            event = value
        case "data":
            dataLines.append(value)
        default:
            break  // ignore id, retry, unknown
        }
        return nil
    }

    private mutating func reset() {
        event = "message"
        dataLines.removeAll(keepingCapacity: true)
    }
}
```

- [ ] **Step 8.4: Run, expect pass**

⌘U. All parser tests pass.

- [ ] **Step 8.5: Commit**

```bash
git add codepet/Services/SSEParser.swift codepetTests/SSEParserTests.swift
git commit -m "Add SSE parser used by streaming chat client"
```

---

## Task 9: Swift API client — `chatSessionStream`

**Files:**
- Modify: `codepet/Services/ReflectionAPIClient.swift`
- Modify: `codepetTests/ReflectionAPIClientTests.swift`

We use `URLProtocol` to mock `URLSession` so we can drive the byte stream end-to-end.

- [ ] **Step 9.1: Add a test URLProtocol helper**

Append to `codepetTests/ReflectionAPIClientTests.swift`:

```swift
// MARK: - URLProtocol mock for SSE

final class MockURLProtocol: URLProtocol {
    static var responseStatus: Int = 200
    static var responseHeaders: [String: String] = ["Content-Type": "text/event-stream"]
    /// Each entry is a chunk delivered to the consumer. Useful for testing split-frame parsing.
    static var responseChunks: [Data] = []
    static var responseError: Error?

    static func reset() {
        responseStatus = 200
        responseHeaders = ["Content-Type": "text/event-stream"]
        responseChunks = []
        responseError = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let err = MockURLProtocol.responseError {
            client?.urlProtocol(self, didFailWithError: err)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: MockURLProtocol.responseStatus,
            httpVersion: "HTTP/1.1",
            headerFields: MockURLProtocol.responseHeaders
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in MockURLProtocol.responseChunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func mockedURLSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
```

- [ ] **Step 9.2: Add failing streaming tests**

Append to `codepetTests/ReflectionAPIClientTests.swift`:

```swift
    @MainActor
    func testChatStreamHappyPathEmitsDeltasAndDone() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseChunks = [
            "event: delta\ndata: {\"text\":\"Together \"}\n\n".data(using: .utf8)!,
            "event: delta\ndata: {\"text\":\"we kept \"}\n\n".data(using: .utf8)!,
            "event: done\ndata: {\"model\":\"claude-haiku-4-5-20251001\",\"cache_hit\":true}\n\n".data(using: .utf8)!
        ]

        let client = ReflectionAPIClient(session: mockedURLSession(), authTokenProvider: { "fake" })
        let request = makeMinimalChatRequest()
        var collected: [ChatStreamEvent] = []
        for try await ev in client.chatSessionStream(request) {
            collected.append(ev)
        }
        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0], .delta("Together "))
        XCTAssertEqual(collected[1], .delta("we kept "))
        if case let .done(model, cacheHit) = collected[2] {
            XCTAssertEqual(model, "claude-haiku-4-5-20251001")
            XCTAssertTrue(cacheHit)
        } else {
            XCTFail("expected .done")
        }
    }

    @MainActor
    func testChatStreamSplitChunkParsesCorrectly() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseChunks = [
            "event: delta\ndata: {\"text\":\"He".data(using: .utf8)!,
            "llo\"}\n\nevent: done\ndata: {\"model\":\"m\",\"cache_hit\":false}\n\n".data(using: .utf8)!
        ]
        let client = ReflectionAPIClient(session: mockedURLSession(), authTokenProvider: { "fake" })
        var collected: [ChatStreamEvent] = []
        for try await ev in client.chatSessionStream(makeMinimalChatRequest()) {
            collected.append(ev)
        }
        XCTAssertEqual(collected.first, .delta("Hello"))
    }

    @MainActor
    func testChatStream401Throws() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatus = 401
        MockURLProtocol.responseHeaders = ["Content-Type": "application/json"]
        MockURLProtocol.responseChunks = ["{\"error\":\"invalid_token\"}".data(using: .utf8)!]

        let client = ReflectionAPIClient(session: mockedURLSession(), authTokenProvider: { "fake" })
        do {
            for try await _ in client.chatSessionStream(makeMinimalChatRequest()) {}
            XCTFail("expected error")
        } catch ReflectionAPIError.http(let status, _) {
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    @MainActor
    func testChatStream429ThrowsWithBody() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseStatus = 429
        MockURLProtocol.responseHeaders = ["Content-Type": "application/json"]
        MockURLProtocol.responseChunks = [
            "{\"error\":\"daily_limit_reached\",\"reset_at\":\"2026-05-08T00:00:00Z\",\"limit\":50}".data(using: .utf8)!
        ]

        let client = ReflectionAPIClient(session: mockedURLSession(), authTokenProvider: { "fake" })
        do {
            for try await _ in client.chatSessionStream(makeMinimalChatRequest()) {}
            XCTFail("expected error")
        } catch ReflectionAPIError.http(let status, let body) {
            XCTAssertEqual(status, 429)
            XCTAssertEqual(body?.error, "daily_limit_reached")
            XCTAssertEqual(body?.limit, 50)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    @MainActor
    func testChatStreamMidStreamErrorThrows() async {
        MockURLProtocol.reset()
        MockURLProtocol.responseChunks = [
            "event: delta\ndata: {\"text\":\"hi\"}\n\nevent: error\ndata: {\"error\":\"upstream_failure\"}\n\n".data(using: .utf8)!
        ]
        let client = ReflectionAPIClient(session: mockedURLSession(), authTokenProvider: { "fake" })
        var collected: [ChatStreamEvent] = []
        do {
            for try await ev in client.chatSessionStream(makeMinimalChatRequest()) {
                collected.append(ev)
            }
            XCTFail("expected error")
        } catch ReflectionAPIError.http(let status, _) {
            XCTAssertEqual(collected, [.delta("hi")])
            XCTAssertEqual(status, 502)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    private func makeMinimalChatRequest() -> ChatSessionRequest {
        ChatSessionRequest(
            sessionId: "s1",
            language: "en",
            petPersona: nil,
            sessionContext: ChatSessionRequest.SessionContextDTO(
                userBrief: nil,
                summary: nil,
                turns: [
                    ChatSessionRequest.SessionContextDTO.TurnDTO(
                        prompt: "hi",
                        whatYouWanted: nil,
                        whatHappened: nil,
                        lesson: nil,
                        durationMinutes: nil,
                        events: []
                    )
                ]
            ),
            history: [],
            userMessage: "what?"
        )
    }
```

- [ ] **Step 9.3: Update the client to support injection + streaming**

Edit `codepet/Services/ReflectionAPIClient.swift`:

(a) **Update the protocol** — replace the protocol declaration with:

```swift
protocol ReflectionAPIClientProtocol {
    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse
    func summarizeSession(_ request: SummarizeSessionRequest) async throws -> SummarizeSessionResponse
    func chatSessionStream(_ request: ChatSessionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
}
```

(b) **Update the class init to allow injecting an auth-token provider** (so tests don't need Firebase). Replace the existing init with:

```swift
    static let endpoint = URL(string: "https://us-central1-devpet-8f4b1.cloudfunctions.net/summarizeTurn")!
    private static let sessionEndpoint = URL(string: "https://us-central1-devpet-8f4b1.cloudfunctions.net/summarizeSession")!
    private static let chatEndpoint = URL(string: "https://us-central1-devpet-8f4b1.cloudfunctions.net/chatSession")!

    private let session: URLSession
    private let authTokenProvider: () async throws -> String

    init(
        session: URLSession = .shared,
        authTokenProvider: (() async throws -> String)? = nil
    ) {
        self.session = session
        self.authTokenProvider = authTokenProvider ?? {
            guard let user = Auth.auth().currentUser else {
                throw ReflectionAPIError.notSignedIn
            }
            do {
                return try await user.getIDToken()
            } catch {
                throw ReflectionAPIError.network(error)
            }
        }
    }
```

(c) **Replace the inline auth fetches** in `summarizeTurn` and `summarizeSession`. In each, replace the `guard let user = Auth.auth().currentUser` + token block with:

```swift
        let token = try await authTokenProvider()
```

(d) **Append the new method**:

```swift
    func chatSessionStream(_ request: ChatSessionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let token = try await authTokenProvider()

                    var urlRequest = URLRequest(url: Self.chatEndpoint)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw ReflectionAPIError.malformedResponse
                    }

                    if http.statusCode != 200 {
                        // Non-streaming error body. Read fully then throw.
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                        }
                        let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: data)
                        throw ReflectionAPIError.http(status: http.statusCode, body: parsed)
                    }

                    var parser = SSEParser()
                    for try await line in bytes.lines {
                        for frame in parser.feedLines([line]) {
                            try Self.handle(frame: frame, continuation: continuation)
                        }
                    }
                    // Flush any final frame (server should always end with blank line, but be safe).
                    for frame in parser.feedLines([""]) {
                        try Self.handle(frame: frame, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func handle(
        frame: SSEFrame,
        continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation
    ) throws {
        guard let payload = frame.data.data(using: .utf8) else { return }
        switch frame.event {
        case "delta":
            struct DeltaPayload: Codable { let text: String }
            if let d = try? JSONDecoder().decode(DeltaPayload.self, from: payload) {
                continuation.yield(.delta(d.text))
            }
        case "done":
            struct DonePayload: Codable {
                let model: String
                let cacheHit: Bool
                enum CodingKeys: String, CodingKey { case model; case cacheHit = "cache_hit" }
            }
            if let d = try? JSONDecoder().decode(DonePayload.self, from: payload) {
                continuation.yield(.done(model: d.model, cacheHit: d.cacheHit))
            }
        case "error":
            let parsed = try? JSONDecoder().decode(SummarizeTurnError.self, from: payload)
            throw ReflectionAPIError.http(status: 502, body: parsed)
        default:
            break
        }
    }
```

- [ ] **Step 9.4: Run, expect pass**

⌘U. Streaming tests pass.

- [ ] **Step 9.5: Commit**

```bash
git add codepet/Services/ReflectionAPIClient.swift codepetTests/ReflectionAPIClientTests.swift
git commit -m "Add chatSessionStream with SSE parsing and URLProtocol-driven tests"
```

---

## Task 10: ReflectionComposition — `makeChatContext`

**Files:**
- Modify: `codepet/Managers/ReflectionComposition.swift`
- Create: `codepetTests/ReflectionCompositionChatContextTests.swift`

- [ ] **Step 10.1: Read the existing composition file**

Open `codepet/Managers/ReflectionComposition.swift` to learn the existing helpers (look for how `Session` and `Turn` are flattened for `summarizeSession`). The new helper should sit alongside whatever `composeReflection`/`makeSessionRequest` already lives there. If neither exists, add a fresh `enum ReflectionComposition` namespace.

- [ ] **Step 10.2: Add failing test**

Create `codepetTests/ReflectionCompositionChatContextTests.swift`:

```swift
import XCTest
@testable import codepet

final class ReflectionCompositionChatContextTests: XCTestCase {

    func testMakeChatContextFlattensSessionFields() {
        let turn = Turn.makeForTesting(
            prompt: "fix the layout",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_600),  // +10 min
            narrative: TurnNarrative(
                title: "T",
                whatYouWanted: "you wanted clean rows",
                whatHappened: "we tried twice",
                lesson: "isolate the layout first"
            ),
            rawEvents: [
                Turn.RawEvent(time: "09:00", tool: "Edit", path: "ReflectionTab.swift", text: nil),
                Turn.RawEvent(time: "09:05", tool: "Bash", path: nil, text: "swift test")
            ]
        )

        let summary = SessionSummary(
            sessionId: "s1",
            summary: "We worked through the layout together.",
            lesson: "Isolation first.",
            createdAt: Date()
        )

        let session = Session.makeForTesting(
            id: "s1",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_600),
            turns: [turn],
            summary: summary
        )

        let context = ReflectionComposition.makeChatContext(
            for: session,
            userBrief: "shipping a journaling app"
        )

        XCTAssertEqual(context.userBrief, "shipping a journaling app")
        XCTAssertEqual(context.summary?.summary, "We worked through the layout together.")
        XCTAssertEqual(context.summary?.lesson, "Isolation first.")
        XCTAssertEqual(context.turns.count, 1)
        let dto = context.turns.first!
        XCTAssertEqual(dto.prompt, "fix the layout")
        XCTAssertEqual(dto.whatYouWanted, "you wanted clean rows")
        XCTAssertEqual(dto.whatHappened, "we tried twice")
        XCTAssertEqual(dto.lesson, "isolate the layout first")
        XCTAssertEqual(dto.durationMinutes, 10)
        XCTAssertEqual(dto.events.count, 2)
        XCTAssertEqual(dto.events.first?.tool, "Edit")
    }

    func testMakeChatContextOmitsMissingFields() {
        let turn = Turn.makeForTesting(
            prompt: "x",
            startedAt: Date(),
            endedAt: nil,
            narrative: nil,
            rawEvents: []
        )
        let session = Session.makeForTesting(
            id: "s1",
            startedAt: Date(),
            endedAt: nil,
            turns: [turn],
            summary: nil
        )

        let context = ReflectionComposition.makeChatContext(for: session, userBrief: nil)
        XCTAssertNil(context.userBrief)
        XCTAssertNil(context.summary)
        XCTAssertNil(context.turns.first?.whatYouWanted)
        XCTAssertNil(context.turns.first?.durationMinutes)
    }
}
```

- [ ] **Step 10.3: Add the helper**

In `codepet/Managers/ReflectionComposition.swift` add (or extend the existing `enum ReflectionComposition` with) the static method:

```swift
extension ReflectionComposition {

    static func makeChatContext(
        for session: Session,
        userBrief: String?
    ) -> ChatSessionRequest.SessionContextDTO {
        let summaryDTO: ChatSessionRequest.SessionContextDTO.SummaryDTO? = session.summary.map {
            ChatSessionRequest.SessionContextDTO.SummaryDTO(
                summary: $0.summary,
                lesson: $0.lesson
            )
        }

        let turnDTOs: [ChatSessionRequest.SessionContextDTO.TurnDTO] = session.turns.map { turn in
            let duration: Int?
            if let ended = turn.endedAt {
                duration = Int(ended.timeIntervalSince(turn.startedAt) / 60)
            } else {
                duration = nil
            }

            let events: [SummarizeTurnRequest.EventDTO] = turn.rawEvents.map { e in
                SummarizeTurnRequest.EventDTO(
                    time: e.time,
                    tool: e.tool,
                    path: e.path,
                    text: e.text
                )
            }

            return ChatSessionRequest.SessionContextDTO.TurnDTO(
                prompt: turn.prompt,
                whatYouWanted: turn.narrative?.whatYouWanted,
                whatHappened: turn.narrative?.whatHappened,
                lesson: turn.narrative?.lesson,
                durationMinutes: duration,
                events: events
            )
        }

        return ChatSessionRequest.SessionContextDTO(
            userBrief: userBrief?.isEmpty == false ? userBrief : nil,
            summary: summaryDTO,
            turns: turnDTOs
        )
    }
}
```

If `Turn.makeForTesting` and `Session.makeForTesting` don't exist, add them as `internal` factories on the model files (we'll add real-world initializers as needed):

```swift
// In codepet/Models/Turn.swift, at the bottom:
#if DEBUG
extension Turn {
    static func makeForTesting(
        prompt: String,
        startedAt: Date,
        endedAt: Date?,
        narrative: TurnNarrative?,
        rawEvents: [RawEvent]
    ) -> Turn {
        // Use the existing initializer; fill any other required fields with neutral values.
        // (Implementer: open Turn.swift and copy the full memberwise init invocation here.)
        fatalError("implement against the real Turn initializer")
    }
}
#endif
```

> **Note for the engineer:** the `makeForTesting` helpers above are stubs. When you implement Task 10, open `codepet/Models/Turn.swift` and `Session` (in `Views/Reflection/ReflectionModels.swift`) and write the real factory bodies that match those types' initializers. They should accept only the fields the tests use and fill the rest with sensible defaults (empty arrays, `.complete` state, etc.).

- [ ] **Step 10.4: Run, expect pass**

⌘U. Composition tests pass.

- [ ] **Step 10.5: Commit**

```bash
git add codepet/Managers/ReflectionComposition.swift codepetTests/ReflectionCompositionChatContextTests.swift codepet/Models/Turn.swift codepet/Views/Reflection/ReflectionModels.swift
git commit -m "Add ReflectionComposition.makeChatContext to flatten Session for chat"
```

---

## Task 11: SessionChatController

**Files:**
- Create: `codepet/Views/Reflection/SessionChatController.swift`
- Create: `codepetTests/SessionChatControllerTests.swift`

- [ ] **Step 11.1: Add failing controller tests**

Create `codepetTests/SessionChatControllerTests.swift`:

```swift
import XCTest
@testable import codepet

final class SessionChatControllerTests: XCTestCase {

    @MainActor
    func testHappyPathPersistsUserAndPetMessages() async throws {
        let store = SessionChatStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json"),
            saveDebounce: 0
        )
        let api = StubAPI(events: [.delta("Hi "), .delta("there."), .done(model: "m", cacheHit: false)])
        let controller = SessionChatController(api: api, store: store)

        await controller.send(
            userText: "what?",
            sessionId: "s1",
            request: makeRequest()
        )

        let messages = store.messages(for: "s1")
        XCTAssertEqual(messages.map(\.role), [.user, .pet])
        XCTAssertEqual(messages[0].text, "what?")
        XCTAssertEqual(messages[1].text, "Hi there.")
        XCTAssertNil(controller.inFlightSessionId)
        XCTAssertEqual(controller.streamingText, "")
    }

    @MainActor
    func testCancelDuringStreamDoesNotPersistPetMessage() async throws {
        let store = SessionChatStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json"),
            saveDebounce: 0
        )
        let api = StubAPI(events: [.delta("partial"), .pause, .delta("more"), .done(model: "m", cacheHit: false)])
        let controller = SessionChatController(api: api, store: store)

        let sendTask = Task { @MainActor in
            await controller.send(userText: "x", sessionId: "s1", request: makeRequest())
        }
        // Wait until first delta lands.
        for _ in 0..<50 {
            if controller.streamingText.contains("partial") { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        controller.cancel()
        _ = await sendTask.value

        let messages = store.messages(for: "s1")
        XCTAssertEqual(messages.map(\.role), [.user])
        XCTAssertEqual(controller.streamingText, "")
        XCTAssertNil(controller.inFlightSessionId)
    }

    @MainActor
    func testErrorMidStreamSurfacesAndDoesNotPersistPetMessage() async {
        let store = SessionChatStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json"),
            saveDebounce: 0
        )
        let api = StubAPI(events: [.delta("hi"), .error(ReflectionAPIError.http(status: 502, body: nil))])
        let controller = SessionChatController(api: api, store: store)

        await controller.send(userText: "x", sessionId: "s1", request: makeRequest())

        XCTAssertNotNil(controller.error)
        XCTAssertEqual(store.messages(for: "s1").map(\.role), [.user])
    }

    // Helpers

    private func makeRequest() -> ChatSessionRequest {
        ChatSessionRequest(
            sessionId: "s1", language: "en", petPersona: nil,
            sessionContext: ChatSessionRequest.SessionContextDTO(
                userBrief: nil, summary: nil,
                turns: [.init(prompt: "x", whatYouWanted: nil, whatHappened: nil, lesson: nil, durationMinutes: nil, events: [])]
            ),
            history: [], userMessage: "what?"
        )
    }
}

// MARK: - Stub API

private enum StubEvent {
    case delta(String)
    case done(model: String, cacheHit: Bool)
    case error(Error)
    case pause   // 100ms pause to allow cancellation
}

private final class StubAPI: ReflectionAPIClientProtocol {
    let events: [StubEvent]
    init(events: [StubEvent]) { self.events = events }

    func summarizeTurn(_ request: SummarizeTurnRequest) async throws -> SummarizeTurnResponse {
        fatalError("not used")
    }
    func summarizeSession(_ request: SummarizeSessionRequest) async throws -> SummarizeSessionResponse {
        fatalError("not used")
    }

    func chatSessionStream(_ request: ChatSessionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for event in self.events {
                    if Task.isCancelled { break }
                    switch event {
                    case .delta(let text): continuation.yield(.delta(text))
                    case .done(let model, let cacheHit): continuation.yield(.done(model: model, cacheHit: cacheHit))
                    case .error(let err): continuation.finish(throwing: err); return
                    case .pause:
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
                continuation.finish()
            }
        }
    }
}
```

- [ ] **Step 11.2: Run, expect compile failure**

⌘U. `SessionChatController` undefined.

- [ ] **Step 11.3: Implement the controller**

Create `codepet/Views/Reflection/SessionChatController.swift`:

```swift
import Foundation
import Combine

@MainActor
final class SessionChatController: ObservableObject {

    @Published private(set) var inFlightSessionId: String?
    @Published private(set) var streamingText: String = ""
    @Published var error: ChatError?

    enum ChatError: Equatable {
        case notSignedIn
        case rateLimited(resetAt: Date?, limit: Int?)
        case networkOrServer(message: String)
    }

    private let api: ReflectionAPIClientProtocol
    private let store: SessionChatStore
    private var currentTask: Task<Void, Never>?

    init(api: ReflectionAPIClientProtocol, store: SessionChatStore) {
        self.api = api
        self.store = store
    }

    /// Send a user message and stream the pet reply for the given session.
    /// Returns when the stream completes, errors, or is cancelled.
    func send(userText: String, sessionId: String, request: ChatSessionRequest) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Append the user message immediately.
        let userMsg = ChatMessage(id: UUID(), role: .user, text: trimmed, createdAt: Date())
        store.append(userMsg, to: sessionId)

        inFlightSessionId = sessionId
        streamingText = ""
        error = nil

        let task = Task { @MainActor in
            do {
                for try await event in api.chatSessionStream(request) {
                    if Task.isCancelled { return }
                    switch event {
                    case .delta(let text):
                        streamingText += text
                    case .done:
                        let petMsg = ChatMessage(
                            id: UUID(),
                            role: .pet,
                            text: streamingText,
                            createdAt: Date()
                        )
                        if !petMsg.text.isEmpty {
                            store.append(petMsg, to: sessionId)
                        }
                    }
                }
                streamingText = ""
                inFlightSessionId = nil
            } catch let apiError as ReflectionAPIError {
                streamingText = ""
                inFlightSessionId = nil
                error = Self.map(apiError)
            } catch is CancellationError {
                streamingText = ""
                inFlightSessionId = nil
            } catch {
                streamingText = ""
                inFlightSessionId = nil
                self.error = .networkOrServer(message: String(describing: error))
            }
        }
        currentTask = task
        await task.value
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        streamingText = ""
        inFlightSessionId = nil
    }

    private static func map(_ apiError: ReflectionAPIError) -> ChatError {
        switch apiError {
        case .notSignedIn:
            return .notSignedIn
        case .http(let status, let body):
            if status == 429 {
                let resetAt = body?.resetAt.flatMap(ISO8601DateFormatter().date(from:))
                return .rateLimited(resetAt: resetAt, limit: body?.limit)
            }
            return .networkOrServer(message: body?.error ?? "HTTP \(status)")
        case .malformedResponse:
            return .networkOrServer(message: "malformed response")
        case .network(let err):
            return .networkOrServer(message: String(describing: err))
        }
    }
}
```

- [ ] **Step 11.4: Run, expect pass**

⌘U. Controller tests pass.

- [ ] **Step 11.5: Commit**

```bash
git add codepet/Views/Reflection/SessionChatController.swift codepetTests/SessionChatControllerTests.swift
git commit -m "Add SessionChatController managing send + stream + cancel state"
```

---

## Task 12: SessionChatPanel view

**Files:**
- Create: `codepet/Views/Reflection/SessionChatPanel.swift`

This task is visual — verify in SwiftUI Preview rather than via XCTest (matches existing pattern).

- [ ] **Step 12.1: Implement the panel**

Create `codepet/Views/Reflection/SessionChatPanel.swift`:

```swift
import SwiftUI

struct SessionChatPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatStore: SessionChatStore
    @EnvironmentObject var controller: SessionChatController

    let session: Session
    let onClose: () -> Void
    var onSend: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }
    private var petName: String { pet?.name ?? "Pet" }

    private var messages: [ChatMessage] { chatStore.messages(for: session.id) }
    private var isStreaming: Bool { controller.inFlightSessionId == session.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(ReflectionTheme.borderLight)
            messageList
            Divider().background(ReflectionTheme.borderLight)
            inputRow
        }
        .frame(width: 360, height: 480)
        .background(ReflectionTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReflectionTheme.borderLight, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
        .onAppear { inputFocused = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let pet = pet {
                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(pet.color.opacity(0.18)))
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(petName)
                    .font(ReflectionTheme.serif(14, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text("Ask about this session.")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ReflectionTheme.mutedText)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty && !isStreaming {
                        emptyGreetingBubble
                    }
                    ForEach(messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                    if isStreaming {
                        streamingBubble
                            .id("streaming")
                    }
                    if let error = controller.error {
                        errorRow(error)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: controller.streamingText) { _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private var emptyGreetingBubble: some View {
        bubble(role: .pet, text: greeting, isStreaming: false)
    }

    private var greeting: String {
        // Detection mirrors PersonaContent / NarrativeEnricher: language tracks Locale's preferred.
        Locale.current.identifier.hasPrefix("vi")
            ? "Hỏi mình về phiên này nhé."
            : "Ask me about this session."
    }

    private var streamingBubble: some View {
        bubble(role: .pet, text: controller.streamingText, isStreaming: true)
    }

    private func bubble(for message: ChatMessage) -> some View {
        bubble(role: message.role, text: message.text, isStreaming: false)
    }

    @ViewBuilder
    private func bubble(role: ChatMessage.Role, text: String, isStreaming: Bool) -> some View {
        let alignment: HorizontalAlignment = role == .user ? .trailing : .leading
        let bg: Color = role == .user
            ? Color.black.opacity(0.06)
            : ReflectionTheme.accent.opacity(0.12)
        HStack {
            if role == .user { Spacer(minLength: 32) }
            VStack(alignment: alignment, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(text)
                        .font(role == .user
                              ? ReflectionTheme.sans(13)
                              : ReflectionTheme.serif(13.5))
                        .foregroundColor(ReflectionTheme.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isStreaming {
                        Text("▎")
                            .font(.system(size: 13))
                            .foregroundColor(ReflectionTheme.accent)
                            .opacity(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(bg)
                )
            }
            if role == .pet { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
    }

    private func errorRow(_ error: SessionChatController.ChatError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(ReflectionTheme.moodAlert)
            Text(errorText(error))
                .font(ReflectionTheme.sans(11))
                .foregroundColor(ReflectionTheme.mutedText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func errorText(_ error: SessionChatController.ChatError) -> String {
        switch error {
        case .notSignedIn: return "Sign in to chat with your pet."
        case .rateLimited(let resetAt, _):
            if let r = resetAt {
                let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
                return "Daily limit reached. Comes back at \(f.string(from: r))."
            }
            return "You've reached today's limit."
        case .networkOrServer:
            return "Could not reach your pet — try again."
        }
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Type a question…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .focused($inputFocused)
                .font(ReflectionTheme.sans(13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.04))
                )
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(canSubmit ? ReflectionTheme.accent : ReflectionTheme.mutedText.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    private func submit() {
        guard canSubmit else { return }
        let text = draft
        draft = ""
        onSend(text)
    }
}
```

- [ ] **Step 12.2: Build the project**

```bash
xcodebuild -project codepet.xcodeproj -scheme codepet -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 12.3: Commit**

```bash
git add codepet/Views/Reflection/SessionChatPanel.swift
git commit -m "Add SessionChatPanel chat UI with streaming bubble and input"
```

---

## Task 13: SessionChatBubble view

**Files:**
- Create: `codepet/Views/Reflection/SessionChatBubble.swift`

- [ ] **Step 13.1: Implement the bubble**

Create `codepet/Views/Reflection/SessionChatBubble.swift`:

```swift
import SwiftUI

struct SessionChatBubble: View {
    @EnvironmentObject var appState: AppState

    let onTap: () -> Void

    @State private var float = false
    @State private var glow: CGFloat = 0

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let pet = pet {
                    Circle()
                        .stroke(pet.color.opacity(0.35), lineWidth: 1.5)
                        .scaleEffect(1.0 + glow * 0.18)
                        .opacity(1.0 - glow * 0.7)
                        .frame(width: 56, height: 56)

                    Image(pet.imageName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(pet.color.opacity(0.18)))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(pet.color.opacity(0.55), lineWidth: 1.5))
                        .scaleEffect(float ? 1.02 : 0.98)
                        .offset(y: float ? -2 : 2)
                        .shadow(
                            color: pet.color.opacity(float ? 0.45 : 0.3),
                            radius: float ? 10 : 6,
                            x: 0, y: float ? 5 : 3
                        )
                } else {
                    Circle()
                        .fill(ReflectionTheme.accent.opacity(0.2))
                        .frame(width: 56, height: 56)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            float = true
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            glow = 1.0
        }
    }
}
```

- [ ] **Step 13.2: Build and verify**

```bash
xcodebuild -project codepet.xcodeproj -scheme codepet -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 13.3: Commit**

```bash
git add codepet/Views/Reflection/SessionChatBubble.swift
git commit -m "Add SessionChatBubble floating pet avatar"
```

---

## Task 14: Wire bubble + panel into ReflectionTab

**Files:**
- Modify: `codepet/Views/Reflection/ReflectionTab.swift`

- [ ] **Step 14.1: Add the chat-related properties**

In `ReflectionTab`, add:

```swift
    @EnvironmentObject var chatStore: SessionChatStore
    @StateObject private var chatController: SessionChatController
    @State private var chatExpanded = false

    init() {
        // Default-init the controller with a real API client. The real app
        // re-uses one client across the reflection feature, but the chat
        // controller owns its own send pipeline so a fresh client is fine.
        let api = ReflectionAPIClient()
        let store = SessionChatStore()  // overwritten by environmentObject in body
        _chatController = StateObject(wrappedValue: SessionChatController(api: api, store: store))
    }
```

> **Note for the engineer:** the `init()` above can't actually inject the `chatStore` from the environment (init runs before the environment is set). Two clean ways to handle this:
>
> 1. **Make `SessionChatController` look up its store on demand** — change its init to take `getStore: @MainActor () -> SessionChatStore` instead of a `SessionChatStore`. Then `ReflectionTab` calls `getStore()` at send time.
> 2. **Move controller ownership up to `CodePetApp`** — instantiate it there with the real `chatStore`, inject as `@EnvironmentObject`. `ReflectionTab` becomes `@EnvironmentObject var chatController: SessionChatController`.
>
> Option 2 is simpler and matches the existing pattern (every other reflection store/enricher is owned by `CodePetApp`). **Use option 2.** Update Task 11 retroactively if needed: `SessionChatController` continues to take `store` in its init (test code already does), but in `ReflectionTab` you do not own it.

- [ ] **Step 14.2: Update `ReflectionTab` to consume controller from env**

Replace the `@StateObject private var chatController` block above with:

```swift
    @EnvironmentObject var chatStore: SessionChatStore
    @EnvironmentObject var chatController: SessionChatController
    @State private var chatExpanded = false
```

Remove the custom `init()`.

- [ ] **Step 14.3: Add the overlay**

In `ReflectionTab.body`, find the outer `HStack(alignment: .top, spacing: 0)` that contains the sidebar and the main `Group { ... }`. After the `.background(ReflectionTheme.background)` modifier and before the `.onChange(...)` modifiers, add:

```swift
        .overlay(alignment: .bottomTrailing) {
            if let session = selectedSession, !session.isWelcome {
                ZStack(alignment: .bottomTrailing) {
                    if chatExpanded {
                        SessionChatPanel(
                            session: session,
                            onClose: {
                                chatController.cancel()
                                chatExpanded = false
                            },
                            onSend: { text in
                                let request = makeChatRequest(for: session, userMessage: text)
                                Task {
                                    await chatController.send(
                                        userText: text,
                                        sessionId: session.id,
                                        request: request
                                    )
                                }
                            }
                        )
                        .padding(16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        SessionChatBubble(onTap: { chatExpanded = true })
                            .padding(16)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: chatExpanded)
            }
        }
```

- [ ] **Step 14.4: Add the request builder**

Add a helper method on `ReflectionTab` (near `currentPetPersona`):

```swift
    private func makeChatRequest(for session: Session, userMessage: String) -> ChatSessionRequest {
        let history = chatStore.historySnapshot(for: session.id, lastN: 10)
            .map { ChatSessionRequest.ChatMessageDTO(role: $0.role.rawValue, text: $0.text) }
        let context = ReflectionComposition.makeChatContext(
            for: session,
            userBrief: appState.userBrief
        )
        let language = Locale.current.identifier.hasPrefix("vi") ? "vi" : "en"
        return ChatSessionRequest(
            sessionId: session.id,
            language: language,
            petPersona: currentPetPersona(),
            sessionContext: context,
            history: history,
            userMessage: userMessage
        )
    }
```

> **Note:** if `appState.userBrief` doesn't exist yet, replace `appState.userBrief` with `nil` and add a TODO. The brief lookup is established elsewhere in the project — find the same expression already used by `summarizeSession`/`summarizeTurn` callsites and reuse it.

- [ ] **Step 14.5: Update the Preview**

In the existing `#Preview { ... }` block, before the closing `.frame(...)`, add:

```swift
        .environmentObject(SessionChatStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-chat.json")
        ))
        .environmentObject(SessionChatController(
            api: api,
            store: SessionChatStore(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-chat-2.json")
            )
        ))
```

- [ ] **Step 14.6: Build**

```bash
xcodebuild -project codepet.xcodeproj -scheme codepet -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 14.7: Commit**

```bash
git add codepet/Views/Reflection/ReflectionTab.swift
git commit -m "Wire chat bubble + panel overlay into ReflectionTab"
```

---

## Task 15: App lifecycle wiring

**Files:**
- Modify: `codepet/App/CodePetApp.swift`

- [ ] **Step 15.1: Instantiate and inject**

Open `codepet/App/CodePetApp.swift`. Find the `@StateObject` declarations for the existing reflection stores (e.g. `narrativeStore`, `summaryStore`). Add:

```swift
    @StateObject private var chatStore = SessionChatStore()
    @StateObject private var chatController: SessionChatController
```

Then in the `init()` (or wherever the existing controllers/enrichers are wired up), construct the chat controller with the same shared `ReflectionAPIClient` instance and the chat store:

```swift
        let api = ReflectionAPIClient()  // or reuse the existing instance if there is one
        let store = SessionChatStore()
        _chatStore = StateObject(wrappedValue: store)
        _chatController = StateObject(wrappedValue: SessionChatController(api: api, store: store))
```

> **Note:** if `CodePetApp.swift` already creates a `ReflectionAPIClient` once and shares it across `NarrativeEnricher` and `SessionSummaryEnricher`, reuse that instance for the chat controller too. The exact init order depends on what's already there — match the existing pattern.

In the `WindowGroup { ContentView() ... }`, add the new env objects alongside the existing ones:

```swift
                    .environmentObject(chatStore)
                    .environmentObject(chatController)
```

- [ ] **Step 15.2: Build the app**

```bash
xcodebuild -project codepet.xcodeproj -scheme codepet -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 15.3: Run all Swift tests**

⌘U on `codepetTests`. Expected: all green.

- [ ] **Step 15.4: Commit**

```bash
git add codepet/App/CodePetApp.swift
git commit -m "Wire SessionChatStore and SessionChatController into CodePetApp"
```

---

## Task 16: Deploy + manual end-to-end check

**Files:** none

- [ ] **Step 16.1: Deploy the new Cloud Function**

```bash
cd functions && npm run build && firebase deploy --only functions:chatSession
```
Expected: deploys cleanly. Note the URL it prints — it should match
`https://us-central1-devpet-8f4b1.cloudfunctions.net/chatSession`.

- [ ] **Step 16.2: Run the app**

Launch CodePet from Xcode (⌘R). Sign in. Navigate to the Reflection tab.
Pick a session that has at least one turn.

- [ ] **Step 16.3: Smoke-test the chat**

- The pet bubble appears bottom-right of the session view.
- Click it → panel expands with the empty greeting.
- Type "Mình đã làm gì trong phiên này?" (or "What did we work on in this session?") and press Return.
- Verify:
  - User message appears immediately on the right.
  - Pet bubble starts empty with a cursor and fills in word-by-word.
  - Final message has no file names or third-party "AI" references.
- Send a follow-up like "Tell me more about the tricky part" → verify the
  pet picks up context from the prior exchange.
- Close the panel → confirm the bubble re-appears.
- Re-open → confirm the prior chat history is still there.
- Force-quit Xcode and relaunch → confirm the chat history persists.
- Switch to a different session → confirm a separate empty chat appears.
- Switch back → confirm the original chat is intact.

- [ ] **Step 16.4: If anything's wrong, log a fix-up and stop**

Don't ship a half-working chat. If a bullet from 16.3 fails, capture the
specific behaviour and stop. Plan a follow-up commit. Don't push.

- [ ] **Step 16.5: Final commit (if needed)**

If the smoke test surfaced any small tweaks, commit them as separate commits with descriptive messages. There is no "wrap-up" commit for this plan.

---

## Self-review

**Spec coverage:** Walked through the spec section by section.
- Goal / non-goals → reflected in plan boundaries.
- User-facing summary → Tasks 12, 13, 14.
- Architecture (3 layers) → Tasks 3–6 (CF), 7–10 (Swift API + composition), 2/11/12/13/14/15 (UI + lifecycle).
- Data model → Task 1.
- Storage → Task 2.
- Backend `chatSession` (validation, auth, rate limit, SSE, Anthropic) → Tasks 3, 4, 5, 6.
- Swift client (DTOs, parser, stream method) → Tasks 7, 8, 9.
- Context builder → Task 10.
- Controller → Task 11.
- UI (bubble, panel) → Tasks 12, 13, 14.
- App lifecycle → Task 15.
- Tests for everything → ride along with their feature tasks.

**Placeholder check:** the only intentionally unfinished pieces are the `Turn.makeForTesting` and `Session.makeForTesting` factories in Task 10 (because their real signatures must be filled in against the real type definitions, which the engineer needs to read first), the `appState.userBrief` lookup in Task 14 (must match an existing project pattern), and the Task 15 init-order wiring (must match existing app structure). Each of these has an explicit engineer note pointing at exactly which file to read and what to do.

**Type consistency:** spot-checked that
- `ChatStreamEvent` cases are `.delta(String)` and `.done(model:cacheHit:)` everywhere.
- `ChatMessage.Role` is `.user` / `.pet` everywhere (Swift) and `"user"` / `"pet"` (TS) — the wire format uses these strings.
- `ChatSessionRequest.SessionContextDTO.SummaryDTO` keys match the TypeScript validator's accepted shape.
- `SSEFrame` has fields `event` and `data` consistently.
- `SessionChatStore.append`, `messages(for:)`, `historySnapshot(for:lastN:)`, `clear(_:)` match across uses.
