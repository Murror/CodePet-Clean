# Reflection Session Chat — Design

**Date:** 2026-05-07
**Author:** dominich
**Status:** Approved (brainstorm)

## Goal

In the Reflection tab, let the user open a chat with their pet about the
currently selected coding session and ask anything — getting answers grounded
in that session's full context (turns, narratives, raw events, summary). The
pet replies in the same single-voice narrative style used elsewhere in
Reflection (no file names, no jargon, no third-party "AI" references).

## Non-goals

- Cross-session search or retrieval.
- Cloud sync of chat history (local only).
- Image/file attachments.
- Editing or deleting individual messages.
- A chat thread on the Welcome session.
- A user-facing toggle between strict and direct voice.

## User-facing summary

A small floating pet avatar (56×56) sits at the bottom-right of the session
detail area. Tapping it expands a ~360×480 chat panel showing prior messages
and a text input. The thread is per-session: switching sessions in the sidebar
swaps the visible thread. Replies stream in word-by-word.

The chat is hidden on the Welcome session.

## Architecture

Three layers, mirroring the existing per-turn / per-session summarization
flow:

1. **Cloud Function `chatSession`** — Firebase HTTPS function, same auth +
   rate limit as `summarizeTurn` / `summarizeSession`. Streams Anthropic
   responses back to the client as Server-Sent Events.
2. **Swift API client** — new method on `ReflectionAPIClient` returning an
   `AsyncThrowingStream` of stream events.
3. **Local persistence + UI** — `SessionChatStore` (JSON on disk, keyed by
   `sessionId`) plus two views: `SessionChatBubble` (collapsed) and
   `SessionChatPanel` (expanded).

```
┌───────────────────────┐    SSE     ┌──────────────────────┐
│ SessionChatPanel      │  ◀─────── │ chatSession (CF)      │
│ ┌───────────────────┐ │            │  → Anthropic stream   │
│ │ ScrollView (msgs) │ │            └──────────────────────┘
│ │  + streaming bub. │ │                     ▲
│ └───────────────────┘ │                     │ POST { context, history,
│ ┌───────────────────┐ │                     │        user_message }
│ │ TextField         │─┼─────────────────────┘
│ └───────────────────┘ │
└──────────┬────────────┘
           │ append on .done
           ▼
   SessionChatStore (JSON)
```

## Decisions made during brainstorm

| Choice | Selected | Why |
|---|---|---|
| Placement | Floating bubble in session corner | Keeps the journal layout pure; chat is opt-in. |
| AI context | Full session detail (turns + raw events + narratives + summary + user_brief) | Lets the pet answer specific questions, not just abstract recap ones. |
| Persistence | Local only (JSON in Application Support) | No cloud sync needed for v1; matches `NarrativeStore` / `SessionSummaryStore` precedent. |
| Voice | Same strict pet voice as narratives | Keeps the journal's tone consistent. The user asked for this even knowing it limits specificity. |
| Streaming | Yes (SSE → `AsyncThrowingStream`) | First-token latency matters for chat; reuses Anthropic SDK streaming. |

## Data model

New file: `codepet/Models/ReflectionChat.swift`

```swift
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    enum Role: String, Codable { case user, pet }
}

struct SessionChatThread: Codable {
    let sessionId: String
    var messages: [ChatMessage]
    var updatedAt: Date
}
```

### Lifecycle

- A thread is created on the user's first message. There is no thread until
  one exists.
- Threads are never garbage-collected — chat history is the user's record.
- If a thread exists for a session whose underlying events are no longer
  present, the panel still renders the thread but disables the input and
  shows a "session no longer available" notice. (Edge case; not expected to
  happen in v1 since sessions are append-only.)
- Errors do not produce persisted messages.
- Mid-stream cancellation does not produce a persisted pet message.
- Persisting happens only on the `.done` stream event.

## Storage

`codepet/Managers/SessionChatStore.swift` — `@MainActor`
`ObservableObject`. Mirrors `SessionSummaryStore`.

- `@Published var threads: [String: SessionChatThread] = [:]`
- API:
  - `messages(for sessionId: String) -> [ChatMessage]`
  - `append(_ message: ChatMessage, to sessionId: String)`
  - `historySnapshot(for sessionId: String, lastN: Int = 10) -> [ChatMessage]`
    — used to build the request payload.
  - `clear(_ sessionId: String)` (not exposed in UI for v1, but available).
- Disk format: a single JSON file at
  `~/.codepet/session_chats.json` — matches the existing convention used
  by `NarrativeStore` / `SessionSummaryStore` (which use the same
  directory for their JSONL files). Unlike those stores, this file has
  no external writer (no Claude Code hook produces it), so we use a
  single rewriteable JSON object rather than JSONL polling.
- Save is debounced (200 ms) and runs synchronously on the main actor
  with file I/O dispatched to a background `DispatchQueue`.
- Load happens once on init, synchronously.
- Atomic writes (write to `*.tmp`, then `rename`).

## Backend — `chatSession` Cloud Function

New files:
- `functions/src/chat.ts` — handler + payload validation + Anthropic call.
- `functions/src/index.ts` — register `export const chatSession = onRequest(...)`.

### Request

```ts
{
  session_id: string,
  language: "vi" | "en",
  pet_persona?: { id, name, personality, domain },
  session_context: {
    user_brief?: string,
    summary?: { summary: string, lesson: string },
    turns: Array<{
      prompt: string,
      what_you_wanted?: string,
      what_happened?: string,
      lesson?: string,
      duration_minutes?: number,
      events: Array<{
        time: string, tool: string, path?: string, text?: string
      }>
    }>
  },
  history: Array<{ role: "user" | "pet", text: string }>,  // last 10, truncated client-side
  user_message: string
}
```

### Validation

Rejects with HTTP 400 (`{error:"invalid_payload", detail:"…"}`) on:
- missing or empty `session_id`, `user_message`
- `language` not in `{vi, en}`
- non-array `session_context.turns`
- `history` length > 20 (defensive — client truncates to 10)
- `pet_persona` present but missing required string fields
- request body > 64 KB (Express limit; configured explicitly).

### Auth + rate limit

Same shape as existing endpoints:
- `verifyAuth(req.headers.authorization)` → 401 on failure.
- `checkAndIncrement(uid)` → 429 with `{reset_at, limit}` on cap.
- These checks run **before** the response stream starts. Once the first
  byte of the SSE body is written, errors travel through the stream as
  `event: error` frames; HTTP status is already 200.

### Response (SSE stream)

`Content-Type: text/event-stream`, `Cache-Control: no-cache`,
`Connection: keep-alive`. Frames separated by a blank line.

```
event: delta
data: {"text":"Together "}

event: delta
data: {"text":"we kept "}

event: done
data: {"model":"claude-haiku-4-5-20251001","cache_hit":true}
```

Error frame (mid-stream upstream failure):

```
event: error
data: {"error":"upstream_failure","detail":"…"}
```

### Anthropic call

- SDK: `client.messages.stream({...})`, iterate `.on('text', delta => res.write(...))`.
- Model: `claude-haiku-4-5-20251001`.
- `max_tokens: 600`.
- **System prompt** (cached with `cache_control: { type: "ephemeral" }`):
  - Voice rules, copied/adapted from `SESSION_SYSTEM_PROMPT` (single voice,
    second person, no third-party references, no file names, no CLI).
  - Persona block from `PERSONA_BLOCK_TEMPLATE`.
  - **Full session context rendered as text** — the largest part, but
    stable across follow-up messages in the same session. Cache hit on
    every follow-up.
- **Messages**: prior `history` mapped to `[{role: "user"|"assistant",
  content}]`, then the new `user_message` as the final user turn.
- No tool use — chat reply is plain text.
- `cache_hit` in the `done` frame is taken from the SDK response's usage
  block (`cache_read_input_tokens > 0`).

### Why send full context every time

Cloud Functions are stateless. Storing context server-side would mean a
DB write per session, which we don't need: prompt caching (5-min TTL)
makes the second-and-onward messages cheap, and clients pay full cost
only on the first message of a session burst.

## Swift client

`codepet/Services/ReflectionAPIClient.swift` — extend, do not rewrite.

### New DTOs

```swift
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
        struct SummaryDTO: Codable { let summary, lesson: String }
        struct TurnDTO: Codable {
            let prompt: String
            let whatYouWanted, whatHappened, lesson: String?
            let durationMinutes: Int?
            let events: [SummarizeTurnRequest.EventDTO]
        }
    }
    struct ChatMessageDTO: Codable { let role, text: String }
}

enum ChatStreamEvent {
    case delta(String)
    case done(model: String, cacheHit: Bool)
}
```

`Codable` keys snake_case via existing pattern (`CodingKeys` enums).

### New protocol method

```swift
func chatSessionStream(_ request: ChatSessionRequest)
    -> AsyncThrowingStream<ChatStreamEvent, Error>
```

### Implementation outline

- Build the `URLRequest` with `Authorization: Bearer <id_token>`,
  `Accept: text/event-stream`.
- Use `URLSession.shared.bytes(for: urlRequest)` to get an async byte
  stream.
- 401/429 are still detected by reading the HTTP status from the response
  on the first byte — for those, no SSE body is expected; throw
  `ReflectionAPIError.http(status:body:)` immediately.
- For 200, parse SSE line by line:
  - Lines starting with `event:` set the next event type.
  - Lines starting with `data:` accumulate the JSON payload (single-line
    in our wire format, but the parser tolerates multi-line per spec).
  - A blank line dispatches the accumulated frame.
- Map frames to `ChatStreamEvent`:
  - `event: delta` → `.delta(text)`
  - `event: done` → `.done(model, cacheHit)` then finish the stream.
  - `event: error` → throw `ReflectionAPIError.http(status: 502, body:
    parsed)` (or a new dedicated case if needed).
- Cancellation: cancelling the consuming `Task` cancels the underlying
  `URLSessionTask` and tears down the stream cleanly.

### Context builder

Add to `ReflectionComposition.swift` (alongside `composeReflection`):

```swift
func makeChatContext(
    for session: Session,
    userBrief: String?
) -> ChatSessionRequest.SessionContextDTO
```

This is the **only** place that flattens a `Session` into the wire
shape. Views never construct `SessionContextDTO` directly.

## UI

### `SessionChatBubble`

- File: `codepet/Views/Reflection/SessionChatBubble.swift`.
- 56×56 circular pet avatar (`pet.imageName` with `.interpolation(.none)`,
  glow ring matching `SessionSummaryView`).
- Anchored bottom-right of the session content area via
  `.overlay(alignment: .bottomTrailing)` on `ReflectionTab`'s scroll view.
- 16pt inset from the trailing/bottom edges.
- Hidden when `selectedSession == nil` or `selectedSession.isWelcome`.
- Tap toggles the expanded panel. Bubble and panel are mutually
  exclusive — the panel replaces the bubble in the same anchor.

V1 explicitly does not add cross-session unread indicators in the sidebar
(see "Cancellation / navigation" below for what happens when the user
switches sessions mid-stream).

### `SessionChatPanel`

- File: `codepet/Views/Reflection/SessionChatPanel.swift`.
- 360×480 card, anchored same corner as the bubble, with a soft shadow,
  `ReflectionTheme.cardBackground`, 16pt rounded corners.
- Header: pet name + "Ask about this session." + close button (×).
  Tapping × collapses to the bubble.
- Body: `ScrollView` + `ScrollViewReader` keyed on the last message's id.
  - User messages: right-aligned, muted gray bubble, sans font.
  - Pet messages: left-aligned, accent-tinted bubble, serif font (matches
    narrative styling).
  - Streaming pet message: same styling, with a soft cursor caret at the
    end while `isStreaming`.
  - Auto-scroll pins to bottom **only if** the user is within ~40pt of
    the bottom (avoids yanking when reading older messages).
- Input row: `TextField` (multiline-capable, max 8 lines visible) + a
  send button (↵). Submit on Return; ⇧+Return inserts a newline.
- Empty state: a single deterministic greeting bubble from the pet (no
  API call). Strings: vi `"Hỏi mình về phiên này nhé."`,
  en `"Ask me about this session."`.

### Send flow

`SessionChatController` (a `@StateObject` view-model owned by
`ReflectionTab`):

```swift
@MainActor
final class SessionChatController: ObservableObject {
    @Published var inFlightSessionId: String?
    @Published var streamingText: String = ""
    @Published var error: ChatErrorState?

    func send(userText: String, session: Session, ...) async
    func cancel()
}
```

State transitions during a send:
1. User taps send. Controller appends a `user` message to the store
   immediately.
2. Controller sets `inFlightSessionId = session.id`,
   `streamingText = ""`. Panel renders an empty pet bubble bound to
   `streamingText`.
3. Controller iterates the `AsyncThrowingStream`:
   - `.delta(text)` → `streamingText += text` (triggers re-layout).
   - `.done(model, cacheHit)` → append a `pet` message with the final
     `streamingText` to the store, clear `streamingText`,
     `inFlightSessionId = nil`.
4. Cancellation (the only user-triggered cancel path is closing the panel
   while the pet is streaming for the *currently visible* session, OR
   the user starting a fresh send before the previous one completes —
   v1 disables the send button while streaming, so the latter does not
   apply):
   - Cancel the `Task`, drop `streamingText`, `inFlightSessionId = nil`.
   - No persistence.
5. Errors: clear `streamingText`, set `error`, `inFlightSessionId = nil`.
   Show inline retry UI on the failed user message.

### Cancellation / navigation

The send is owned by `SessionChatController` and tagged with the
`sessionId` it started for. If the user clicks a different session in the
sidebar while a stream is in flight:

- The stream keeps running and persists the pet reply to **its original
  session's thread** on `.done`.
- The visible panel switches to the new session's thread immediately;
  the new session has no in-flight state.
- Returning to the original session later shows the persisted reply at
  the bottom of the thread. No sidebar badge in v1.

If the user closes the panel (× button) while a stream is in flight for
the currently visible session, the stream is cancelled and no pet
message is persisted (matches step 4 above).

### Error handling

| Condition | UI |
|---|---|
| 401 (not signed in) | Inline notice: "Sign in to chat with your pet." with a sign-in button (links to existing auth flow). |
| 429 (rate limit) | Inline notice: "You've reached today's limit. Comes back at <reset_at>." |
| Network / 5xx / mid-stream `event: error` | Inline retry button on the failed user message: "Could not reach your pet — try again." |
| User cancellation | No error UI; the user message stays, no pet reply. |

Error messages are **not** persisted as pet messages.

## App lifecycle wiring

`codepet/App/CodePetApp.swift`:
- Instantiate `let chatStore = SessionChatStore()` once.
- Inject as `.environmentObject(chatStore)` alongside the other reflection
  stores.

No changes to `MainTabView` or any other tab. The chat is entirely
contained in `ReflectionTab`.

## Testing

### Swift (`codepetTests/`)

`SessionChatStoreTests`:
- Append + persist round-trip (write → load fresh store → same data).
- Per-session isolation (messages in session A do not appear in session B).
- `historySnapshot(lastN:)` returns last N in chronological order.
- Atomic write recovers from a partially written file (corrupt JSON →
  fresh empty store, log the error).

`ReflectionAPIClientTests` (extend existing file):
- Happy path: stream with two deltas + one done event → controller
  receives `[.delta, .delta, .done]`.
- Split chunk: a single delta arriving across two byte reads is parsed
  correctly.
- 401: error thrown before any event is emitted.
- 429: `ReflectionAPIError.http` carries the parsed `reset_at`.
- Mid-stream `event: error`: stream throws, no `.done` emitted.
- Cancellation: cancelling the task tears down the URLSession task.

### TypeScript (`functions/src/__tests__/`)

`chat.test.ts`:
- Validation: missing `session_id`, bad `language`, oversize `history` →
  400 with the right `detail`.
- Auth: missing/invalid token → 401.
- Rate limit: at-cap → 429 with `reset_at`.
- Happy path with stubbed Anthropic SDK: emits ordered deltas + done.
- Mid-stream Anthropic error: emits `event: error` and closes with HTTP
  status 200 (since headers were already sent).

## Files added / changed

**New:**
- `codepet/Models/ReflectionChat.swift`
- `codepet/Managers/SessionChatStore.swift`
- `codepet/Views/Reflection/SessionChatBubble.swift`
- `codepet/Views/Reflection/SessionChatPanel.swift`
- `codepet/Views/Reflection/SessionChatController.swift`
- `functions/src/chat.ts`
- `functions/src/__tests__/chat.test.ts`
- `codepetTests/SessionChatStoreTests.swift`

**Modified:**
- `codepet/Services/ReflectionAPIClient.swift` (add DTOs + stream method)
- `codepet/Managers/ReflectionComposition.swift` (add `makeChatContext`)
- `codepet/Views/Reflection/ReflectionTab.swift` (overlay bubble; inject
  controller)
- `codepet/App/CodePetApp.swift` (instantiate + inject `SessionChatStore`)
- `functions/src/index.ts` (register `chatSession` export)
- `codepetTests/ReflectionAPIClientTests.swift` (add streaming cases)

## Open questions

None remaining from the brainstorm. Anything that surfaces during
implementation (e.g., a specific SSE corner case) should be raised
inline and resolved in the plan rather than blocking on a spec update.
