# Typed Deliverables — runTask structured payload (CF, A1)

_Date: 2026-07-25 · Repo: CodePet-Clean (functions) · Branch: `feat/typed-deliverables` (off `feat/decisions-extract`) · Increment A (typed viewers), sub-project 1 of 2_

## Context

Native flattens every deliverable to one markdown `MarkdownView` (biggest parity gap, library w14 @ 22%). Web renders ~12 typed viewers from per-kind structured payloads. The native `runTask` CF today returns a flat `{kind, title, body}` (markdown) via a single `record_deliverable` tool — so the structured data never leaves the CF. Typed viewers therefore need a CF change (this sub-project) + native payloads/viewers (A2).

Slice 1 covers **4 kinds** (checklist, doc, plan, dms) — pure payloads, no code-owned transform (sheet/site deferred).

## Goal

`runTask` returns, for the 4 slice-1 kinds, a structured `payload` alongside the existing `{kind, title, body}` — so native can render a typed viewer, while `body` (markdown) remains for fallback + all other kinds. Backward-compatible: existing callers/clients that read only `{kind,title,body}` are unaffected.

## Non-goals

- No change to which kind the model picks (it still self-selects; native tasks carry no kind).
- No structured payloads for the other 7 kinds this slice (text/other/post/email/legal/calendar/screens/sheet/site keep `body` markdown only).
- No two-call/kind-first flow — one model call, one tool.

## Design (mirror the generateRoadmap split: core + handler)

### `runTaskCore.ts`

- **Add per-kind payload field descriptions to the `record_deliverable` tool.** The tool's `input_schema` gains an optional `payload` object whose properties are the union of the 4 slice-1 kinds' fields (all optional; `additionalProperties: true` so future kinds don't break):
  - `items: [{t, done}]` (checklist)
  - `call: string`, `sections: [{h, p}]`, `next: [string]` (doc; `title` reuses the top-level title)
  - `goal, steps: [string], changes: [{area, edit}], verify: [string], risks: string` (plan)
  - `messages: [{name, note, msg}]` (dms)
  Each with the exact description text ported from web `deliverableSchemas.ts` (CHECKLIST/DOC/PLAN/DMS schemas).
- **Extend `buildRunTaskPrompt`**: after the existing "written as markdown in the body" instruction, append a per-kind structured guide (ported from web `DELIVERABLE_INSTRUCTIONS` for checklist/doc/plan/dms) telling the model: *always* write the markdown `body`; AND, if the chosen kind is checklist/doc/plan/dms, ALSO fill `payload` with that kind's fields (listed). Leave `payload` empty for other kinds.
- **`coerceDeliverable`**: keep the current `{kind, title, body}` logic (body still required — fallback). Then, when `kind ∈ {checklist, doc, plan, dms}`, sanitize the raw payload into a clean per-kind object and attach it as `payload`; if the payload is missing or lacks the kind's required fields, omit `payload` entirely (native falls back to `body`). New return type: `Deliverable { kind, title, body, payload?: DeliverablePayload }`. Add pure per-kind coercers (`coerceChecklist`/`coerceDoc`/`coercePlan`/`coerceDms`) — never throw, drop malformed items, clip strings.

### `runTask.ts` (handler)

- Point the tool at the extended `input_schema` (payload added).
- `res.json(coerceDeliverable(block.input, taskTitle))` — now includes `payload` when present. No other handler change; still one model call, `tool_choice: record_deliverable`, fail-open to a null→400/empty as today.

## Contract (for A2 / native)

Response `{ kind, title, body, payload? }` where `payload` (present only for the 4 kinds) is one of:
- checklist: `{ items: [{ t, done }] }`
- doc: `{ call, sections: [{ h, p }], next: [string] }`
- plan: `{ goal, steps: [string], changes: [{ area, edit }], verify: [string], risks }`
- dms: `{ messages: [{ name, note, msg }] }`
`body` (markdown) is ALWAYS present — native renders the typed viewer when `payload` decodes, else `MarkdownView(body)`.

## Testing (Jest, `runTask.test.ts`)

- `buildRunTaskPrompt` includes the per-kind structured guide (mentions checklist items / doc call+sections / plan goal+changes / dms messages) and still requires the markdown body.
- `coerceDeliverable`:
  - flat input (no payload) → `{kind,title,body}`, `payload` undefined (backward-compat, e.g. a `post`/`text` kind).
  - checklist payload with 5 items → `payload.items` sanitized (drops an item missing `t`); `body` still carried.
  - doc/plan/dms happy-path → typed payload attached.
  - malformed payload (wrong types) for a structured kind → `payload` omitted, `body` retained (fail-open).
- Existing runTask tests still pass.

Run: `cd functions && npx jest runTask.test.ts`.

## Deploy (separate, user-confirmed)

`firebase deploy --only functions:runTask --project devpet-8f4b1` (off-iCloud temp; re-auth). runTask is already live; this is an additive, backward-compatible update. Only after review + confirmation.

## Files

- Modify: `functions/src/runTaskCore.ts` (tool payload schema, prompt guide, coerce + per-kind coercers, Deliverable type), `functions/src/runTask.ts` (tool input_schema), `functions/src/__tests__/runTask.test.ts`.
