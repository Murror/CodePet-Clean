# Reflection Narrative Summaries

**Date:** 2026-05-05
**Status:** Spec — pending implementation plan
**Supersedes presentation layer of:** `2026-05-04-claude-code-reflection-logging-design.md` (capture layer kept)

## Problem

CodePet's Reflection tab currently shows raw technical events as logged by Claude Code hooks: `Edit ReflectionTab.swift`, `Bash: git commit -m '...'`, and verbatim user prompts. This reads like a developer activity log, not a reflection journal.

The user wants Reflection entries to:
1. **Read like a journal**, in language a non-developer (parent, friend) could understand.
2. **Summarize each turn** (one user prompt + Claude's response) into a coherent story instead of a stream of tool calls.
3. **Include a lesson** rooted in what actually happened in that turn.

## Non-goals

- Not changing the capture layer. Hooks still write `events.jsonl` exactly as today.
- Not editing narratives by hand inside the app. AI output is immutable; "Write a response" already exists for personal notes.
- Not streaming narrative tokens to the UI. The 5–10s wait is acceptable.
- Not syncing narratives across devices. Local-first.
- Pattern-of-the-day, multi-project filter, retry-on-relogin, "regenerate in new language" — all v1.1.

## Architecture

```
┌──────────────────┐  events.jsonl    ┌────────────────────────┐
│  Claude Code     │ ───────────────> │ ~/.codepet/            │
│  (hooks)         │  (unchanged)     │   events.jsonl         │
└──────────────────┘                  └────────────────────────┘
                                                  │ poll 1.5s
                                                  v
                                      ┌────────────────────────┐
                                      │  ReflectionEventStore  │
                                      │  (existing)            │
                                      └────────┬───────────────┘
                                               │ TurnAssembler
                                               │ "turn ended" signal
                                               v
                                      ┌────────────────────────┐
                                      │  NarrativeEnricher     │  NEW
                                      │  (serial queue,        │
                                      │   API call per turn)   │
                                      └────────┬───────────────┘
                                               │ POST + Firebase ID token
                                               v
                                      ┌────────────────────────┐
                                      │ Firebase Cloud Func    │  NEW
                                      │  summarizeTurn         │
                                      │  (auth, rate limit,    │
                                      │   idempotency cache)   │
                                      └────────┬───────────────┘
                                               │ Anthropic SDK
                                               v
                                      ┌────────────────────────┐
                                      │  Claude Haiku 4.5      │
                                      │  (tool-use enforced    │
                                      │   JSON schema)         │
                                      └────────┬───────────────┘
                                               │ Narrative JSON
                                               v
                              ~/.codepet/narratives.jsonl  NEW
                                               │ poll 1.5s
                                               v
                                      ┌────────────────────────┐
                                      │  NarrativeStore        │  NEW
                                      │  (read + merge with    │
                                      │   events by turn_id)   │
                                      └────────┬───────────────┘
                                               │
                                               v
                                      ┌────────────────────────┐
                                      │  ReflectionTab UI      │
                                      │  (rewritten render)    │
                                      └────────────────────────┘
```

Two flows that meet at the UI:

1. **Capture** (existing): hooks → `events.jsonl` → `ReflectionEventStore`.
2. **Enrich** (new): turn ended → `NarrativeEnricher` → Cloud Function → Anthropic → `narratives.jsonl` → `NarrativeStore`.
3. **Render** (rewritten): UI groups events into `Turn`s and joins each with its narrative by `turn_id`.

Hooks know nothing about AI. The Cloud Function knows nothing about UI. The UI only renders `Turn`s with state `pending` / `summarizing` / `ready` / `failed`. Each component is testable independently.

## Data model

### Turn

```swift
struct Turn: Identifiable {
    let id: String              // turn_id, deterministic
    let sessionId: String
    let startedAt: Date         // = prompt event time
    let endedAt: Date?          // = summary event time, nil while in-flight
    let prompt: String          // raw user prompt (kept for "Xem chi tiết kỹ thuật")
    let rawEvents: [CapturedEvent]
    let narrative: Narrative?   // nil until enricher writes one
    let state: TurnState
}

enum TurnState {
    case pending           // no summary event yet — Claude still working
    case summarizing       // summary received, API call in flight
    case ready             // narrative present
    case failed(reason: FailureReason)
    case pendingOrphan     // prompt with no summary after 30 min
}

enum FailureReason: String {
    case network           // offline / timeout
    case auth              // 401
    case quota             // 429 daily limit
    case badResponse       // malformed JSON despite tool use
    case unknown
}
```

### Narrative

```swift
struct Narrative: Codable {
    let title: String          // ≤60 chars, sidebar headline
    let whatYouWanted: String  // ≤240 chars
    let whatHappened: String   // ≤240 chars
    let lesson: String         // ≤240 chars or "" when not extractable
    let model: String          // e.g. "claude-haiku-4-5"
    let generatedAt: Date
    let schemaVersion: Int     // 1
}
```

### Turn ID scheme

```
turn_id = "<session_id>:<prompt_iso_time>"
```

Deterministic — recoverable from events alone, no UUID needed. Stable across app restarts.

## Files

### `~/.codepet/events.jsonl` (existing — unchanged)

Hooks continue to append per the existing spec. App reads via existing `ReflectionEventStore`.

### `~/.codepet/narratives.jsonl` (new)

Append-only. One JSON object per line.

```json
{
  "turn_id": "abc123:2026-05-05T09:15:23Z",
  "session_id": "abc123",
  "generated_at": "2026-05-05T09:18:42Z",
  "title": "Thiết kế lại reflection thành câu chuyện",
  "what_you_wanted": "Bạn muốn log Reflection đỡ kỹ thuật, dễ đọc cho người không phải dev, và có bài học rút ra sau mỗi lượt làm việc.",
  "what_happened": "Cùng AI rà spec hiện tại, chốt 7 quyết định về cách hệ thống mới sẽ hoạt động: per-turn entry, app gọi Claude API, auto-summarize ngay, format 3 phần, ẩn moments mặc định, lesson + pattern hôm nay, dùng Firebase proxy.",
  "lesson": "Khi yêu cầu thay đổi cách hiển thị, tách rạch raw data và presentation giúp đỡ rối khi đổi UI sau này.",
  "model": "claude-haiku-4-5",
  "schema_version": 1
}
```

### Container path

App is sandboxed. Same path convention as `events.jsonl`:

```
~/Library/Containers/app.murror.codepet/Data/.codepet/narratives.jsonl
```

## TurnAssembler (new, in-app)

Pure function over `[CapturedEvent]` → `[Turn]`.

Algorithm:

1. Sort events by `(session_id, time)`.
2. Walk events; each `prompt` event opens a new turn.
3. All `tool` events with same `session_id` between this prompt and the next `summary` event belong to this turn.
4. `summary` event of the same `session_id` closes the turn (sets `endedAt`, transitions out of `pending`).
5. Prompt with no closing summary after 30 minutes (wall clock) → `pendingOrphan`.

Edge handling:

- Two prompts back-to-back, no summary between them → first prompt closed by second prompt arrival (treat second prompt as implicit summary boundary; first turn marked `pendingOrphan`).
- Summary event arriving before any prompt → ignore.
- Multiple sessions interleaved → grouped by `session_id` correctly because turn_id includes session.

Returns turns sorted by `startedAt` descending.

## NarrativeEnricher (new, in-app)

Serial queue — at most one in-flight API call.

Inputs:
- New turns transitioning to `ready-to-summarize` (have summary, no narrative).
- Failed turns being retried.

Algorithm:

```
on app launch:
  1. wait for ReflectionEventStore + NarrativeStore to prime
  2. compute turns missing narratives, limit to 10 most recent
  3. enqueue them
  4. start serial worker

on new summary event:
  enqueue corresponding turn (only if no narrative exists)

worker loop:
  for each enqueued turn:
    transition turn to .summarizing (publish)
    POST to Cloud Function with turn payload
    on 200:
      append response to narratives.jsonl
      NarrativeStore picks it up on next poll
      transition to .ready
    on 401: mark .failed(.auth), continue
    on 429: mark .failed(.quota), pause queue until reset_at
    on 502 / network: retry once after 10s
                       if still fails, mark .failed(.network)
    on 200 with malformed JSON: mark .failed(.badResponse)
```

Retry on launch handles offline-then-back-online without explicit reachability code. App launch is the natural retry point.

## NarrativeStore (new, in-app)

Mirrors `ReflectionEventStore` pattern: poll the JSONL file every 1.5s, parse new lines, expose via `@Published`.

```swift
@MainActor
final class NarrativeStore: ObservableObject {
    @Published private(set) var narratives: [String: Narrative] = [:]  // turn_id → Narrative

    private let logURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codepet/narratives.jsonl")
    // same polling, offset, lineBuffer, ensureFileExists pattern as ReflectionEventStore
}
```

Dedupe: when reading, last-write-wins on `turn_id` collision (handles 2-instance race).

## Cloud Function: `summarizeTurn`

Stack: Firebase Functions v2, TypeScript, `@anthropic-ai/sdk`.

### Endpoint

```
POST https://us-central1-<project>.cloudfunctions.net/summarizeTurn
Headers:
  Authorization: Bearer <Firebase ID token>
  Content-Type: application/json
```

### Request

```json
{
  "turn_id": "abc123:2026-05-05T09:15:23Z",
  "session_id": "abc123",
  "language": "vi",  // "vi" | "en" — mapped from appState.languagePersona
  "prompt": "user prompt verbatim",
  "events": [
    { "time": "09:15:45", "tool": "Edit", "path": "ReflectionTab.swift" },
    { "time": "09:16:02", "tool": "Bash", "text": "git commit -m '...'" }
  ],
  "raw_summary": "Edit ReflectionTab.swift · Bash: git commit -m '...'"
}
```

### Response (200)

```json
{
  "turn_id": "abc123:2026-05-05T09:15:23Z",
  "narrative": {
    "title": "...",
    "what_you_wanted": "...",
    "what_happened": "...",
    "lesson": "..."
  },
  "model": "claude-haiku-4-5",
  "cache_hit": false
}
```

### Errors

| Code | Body | App handling |
|------|------|--------------|
| 401 | `{ "error": "invalid_token" }` | Force re-login; mark turn `.failed(.auth)` |
| 429 | `{ "error": "daily_limit_reached", "reset_at": "2026-05-06T00:00:00Z" }` | Mark `.failed(.quota)`; pause queue until reset_at |
| 502 | `{ "error": "upstream_failure" }` | Retry once after 10s, then `.failed(.network)` |
| 400 | `{ "error": "invalid_payload", "detail": "..." }` | Log; do not retry; `.failed(.badResponse)` |

### Auth

Verify Firebase ID token → extract `uid`. Anonymous Firebase users are accepted (they still have a uid).

### Rate limit

- 50 turns / day / uid
- Stored in Firestore `usage/{uid}` document with field `{YYYY-MM-DD}: <count>`
- Atomic increment via FieldValue.increment(1)
- 51st call returns 429 with `reset_at` = next 00:00 UTC

### Idempotency cache

- Firestore `narratives_cache/{uid}/{turn_id}` stores prior response with TTL field set to 7 days
- On request: check cache first; if hit, return cached response with `cache_hit: true`, do NOT call Anthropic, do NOT increment rate limit
- Solves duplicate enqueue + 2-instance race

### Input truncation (cost guard)

- `prompt` truncated to 8000 chars
- `events` truncated to 50 entries
- App still shows raw events from local file regardless

### Anthropic call

- Model: `claude-haiku-4-5-20251001` (pinned ID; latest Haiku as of spec date)
- Tool use with single tool `record_narrative` whose schema enforces required fields `title`, `what_you_wanted`, `what_happened`, `lesson`. Empty string allowed for `lesson`.
- `max_tokens: 800`
- System prompt is fixed (below). User message is built per request.
- Use prompt caching on the system prompt (it is identical for every call).

### System prompt (fixed)

```
Bạn là người ghi nhật ký phản tỉnh cho 1 lập trình viên đang dùng AI assistant.
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

Ngôn ngữ output: <language>
```

(`<language>` substituted from request: `vi` or `en`. App pulls from `appState.languagePersona`.)

### User message template

```
Đây là 1 lượt làm việc với Claude Code:

User đã gõ: "<prompt>"

Trong lượt đó, các thao tác đã xảy ra:
<events as bulleted "HH:MM — <tool>: <path-or-text>">

Tóm tắt kỹ thuật ngắn (cho bạn tham khảo): <raw_summary>

Hãy gọi tool record_narrative.
```

### Telemetry

Each call writes to Firestore `function_logs/` (TTL 30 days):

```
{
  uid_hash: <sha256(uid)>,
  turn_id,
  model,
  input_tokens,
  output_tokens,
  latency_ms,
  cache_hit,
  error_code  // null on success
}
```

Used to monitor cost and quality.

## UI redesign

### Layout

```
┌─────────────┬──────────────────────────────────────────────────┐
│             │  Pet avatar    Tên pet                           │
│ Sessions    │                Hôm nay · Thứ Hai 5/5             │
│  ─────────  │                Source: Claude Code               │
│ HÔM NAY     │                                                  │
│ ● Thiết kế..│  ──────────────────────────────────────────────  │
│ ● Sửa onboar│                                                  │
│ ● Cài hooks │  Thiết kế lại reflection thành câu chuyện       │
│             │  09:15 · 18 phút                                 │
│ HÔM QUA     │                                                  │
│ ○ Spec lang │  ┃ BẠN MUỐN                                     │
│ ○ Refactor  │  ┃ Bạn muốn log Reflection đỡ kỹ thuật...       │
│             │                                                  │
│ TUẦN NÀY    │  ┃ ĐÃ LÀM                                       │
│ ○ ...       │  ┃ Cùng AI rà spec hiện tại, chốt 7 quyết định  │
│             │                                                  │
│             │  ╭─ BÀI HỌC ───────────────────────────────╮     │
│             │  │ Tách raw data và presentation giúp đỡ rối│     │
│             │  ╰──────────────────────────────────────────╯     │
│             │                                                  │
│             │  ▸ Xem chi tiết kỹ thuật (8 thao tác)           │
│             │                                                  │
│             │  ──────────────────────────────────────────────  │
│             │  Reflection literary prompt (existing)           │
└─────────────┴──────────────────────────────────────────────────┘
```

### Changes vs current `ReflectionTab.swift`

| Section | Current | New |
|---------|---------|-----|
| Sidebar row title | `personaTitle(session)` (literary headline) | `narrative.title` per turn |
| Sidebar grouping | "Today (live)" | HÔM NAY / HÔM QUA / TUẦN NÀY by `startedAt` |
| Header right side | Source badge | Source badge (unchanged for MVP — Pattern hôm nay deferred to v1.1) |
| Center column | `momentsSection` (raw events list, prominent) | `NarrativeBodyView` (3 sections) |
| Raw events visibility | Always shown | Hidden behind "▸ Xem chi tiết kỹ thuật" toggle |
| Right column | `patternsSection` + `reflectionSection` | `patternsSection` removed; `reflectionSection` moved below body |
| Empty state copy | "Nothing captured yet" | "Chưa có gì để phản tỉnh. Mở Claude Code và bắt đầu code — câu chuyện sẽ tự xuất hiện." |

### Per-turn UI states

| `state` | Sidebar row | Body |
|--------|-------------|------|
| `pending` | "Đang làm..." italic | "Đang làm..." + pulse dots |
| `summarizing` | Spinner + raw summary text | Skeleton placeholders for 3 sections |
| `ready` | `narrative.title` | Full 3-section narrative + collapsed details |
| `failed(.network)` | "Không tóm tắt được" | "Không tóm tắt được câu chuyện. [Thử lại]" + raw events |
| `failed(.quota)` | "Hết hạn ngạch hôm nay" | Message + reset_at countdown + raw events |
| `failed(.auth)` | "Cần đăng nhập lại" | Message + sign-in CTA |
| `failed(.badResponse)` | "Lỗi tóm tắt" | "[Thử lại]" + raw events |
| `pendingOrphan` | "Phiên chưa hoàn thành" italic | "Phiên này chưa kết thúc. Có thể Claude Code bị đóng giữa chừng." |

### New / changed files

```
codepet/Managers/
  ├── NarrativeEnricher.swift     NEW   queue + API + retry
  └── NarrativeStore.swift         NEW   read narratives.jsonl, merge

codepet/Models/
  └── Turn.swift                   NEW   Turn, Narrative, TurnState, FailureReason
                                         + TurnAssembler (free function)

codepet/Services/
  └── ReflectionAPIClient.swift    NEW   Firebase Functions client wrapper

codepet/Views/Reflection/
  ├── ReflectionTab.swift          REWRITE  uses Turn list, new sidebar grouping
  ├── NarrativeBodyView.swift      NEW   3-section body
  ├── TurnLoadingStates.swift      NEW   pending/summarizing/failed views
  └── TechnicalDetailsView.swift   NEW   collapsed raw events list

codepet/App/
  └── CodePetApp.swift             EDIT  inject NarrativeStore, NarrativeEnricher

functions/                         NEW   Firebase Functions root (separate package)
  ├── package.json
  ├── tsconfig.json
  └── src/
      ├── index.ts                       function exports
      └── summarizeTurn.ts               handler

firebase.json                      EDIT  add functions section
```

## Edge cases

| # | Case | Handling |
|---|------|----------|
| 1 | Offline when turn ends | `.failed(.network)`. Retried at next launch (queue scans missing narratives). |
| 2 | App not running when turn ends | Hook still writes events. App launch scans for turns missing narratives, enqueues up to 10 most recent. |
| 3 | Many turns queued | Serial queue (1 in-flight at a time). Sidebar shows skeleton for queued turns. |
| 4 | User signs out mid-summarization | API returns 401 → `.failed(.auth)`. On re-login, retried at next launch (MVP). |
| 5 | Anthropic returns malformed JSON | Tool-use schema enforced. Defensive: if missing required field, function returns 502; app retries once then `.failed(.badResponse)`. |
| 6 | Anonymous Firebase user | Accepted. Same uid-based rate limit as signed-in. |
| 7 | Rate limit hit | 429 → `.failed(.quota)`. Queue paused until `reset_at`. After reset, retry on launch. |
| 8 | Turn never closes (no Stop event after 30 min) | `.pendingOrphan`. No API call. Sidebar shows "Phiên chưa hoàn thành". |
| 9 | App killed mid-API-call | Narrative not yet appended. Next launch re-queues. Cloud Function returns cached response (idempotency cache by turn_id). |
| 10 | Files grow unbounded | MVP limit: app keeps last 500 turns in memory. Files keep appending. v1.1 daily rotation. |
| 11 | Two CodePet instances | Both poll same files; both call API. Cloud Function dedupes via idempotency cache (1 real Anthropic call). NarrativeStore last-write-wins on dupes. |
| 12 | Corrupt line in narratives.jsonl | Skip with warning, advance offset. Affected turn → `.failed(.badResponse)` → user retries. |
| 13 | User changes language persona mid-stream | Existing narratives keep their language (immutable). New turns use new language. |
| 14 | Cost runaway (1000-event turn) | Function truncates: prompt > 8000 chars, events > 50 entries. UI still shows full raw events from local file. |
| 15 | Pattern-of-day with too few narratives | Out of MVP scope. v1.1 will require ≥3 narratives before generating. |

## Testing strategy

### Swift unit tests

- `TurnAssembler`
  - Single-turn happy path
  - Two prompts back-to-back, no summary between → first marked orphan
  - Summary before any prompt → ignored
  - Multi-session interleaved → grouped correctly
  - Prompt with no summary, time elapsed > 30 min → `pendingOrphan`
- `NarrativeStore`
  - Prime existing narratives on launch
  - Incremental read of new lines
  - Corrupt line skipped, offset advances
  - Dedupe: same turn_id appearing twice → second wins
  - File missing → created
  - File shrinks → reset offset
- `NarrativeEnricher`
  - Queue serializes (no parallel calls)
  - Network fail → retry once after 10s, then `.failed(.network)`
  - 429 → pause queue until reset_at
  - On launch, scans missing narratives, enqueues up to 10 most recent

### Cloud Function tests (Firebase emulator)

- Auth: missing/invalid token → 401
- Rate limit: 51st call same UTC day → 429 with correct `reset_at`
- Idempotency cache: 2 calls same turn_id → 1 Anthropic call, both responses identical, second has `cache_hit: true`
- Truncation: 10000-char prompt accepted, no crash; events array > 50 truncated
- Anthropic mock 5xx → 502 returned

### Anthropic prompt quality (manual)

- 5 fixture turns sourced from real `events.jsonl` of the dev session
- Manual review checklist per fixture:
  - title ≤ 60 chars and meaningful
  - `what_happened` contains zero file/function names
  - `lesson` is specific to the turn (or empty if turn was trivial)
- Acceptance: 4/5 pass; ≤1 may have empty lesson

### End-to-end manual

1. Install hooks → run a real Claude Code prompt → wait ≤15s → narrative appears in CodePet.
2. Disable wifi → run a prompt → turn `failed` → enable wifi → restart app → retried automatically.
3. Run 51 prompts → 51st turn `failed(.quota)` with countdown.

## Cut from MVP (v1.1 candidates)

- **Pattern hôm nay** header pill (cross-turn aggregation + 2nd Cloud Function endpoint)
- Auto-retry on user re-login (MVP retries only on app launch)
- "Regenerate in new language" turn action
- Multi-project filter in sidebar (by `cwd`)
- File rotation for `events.jsonl` and `narratives.jsonl`
- Streaming Anthropic response into UI

## Out of scope (not planned)

- User editing narratives inline — narratives are AI artifacts; "Write a response" is the channel for personal additions
- Cross-device sync of narratives — local-first is the design intent
- Notifications when narrative becomes ready — intrusive UX

## Cost projection

Per turn:
- Input ≈ 1k tokens (cached system prompt + ~500 user)
- Output ≈ 400 tokens
- Haiku 4.5: ~$0.001/turn

At rate-limit ceiling (50/day):
- $0.05 per active user per day
- 1000 daily active users → $50/day → $1500/month

Idempotency cache reduces this when re-queues happen. Telemetry will refine this estimate.
