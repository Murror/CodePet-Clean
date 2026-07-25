# `extractDecisions` Cloud Function (Design)

_Date: 2026-07-25 · Repo: CodePet-Clean (functions) · Branch: `feat/decisions-extract` (off `feat/department-grounding`) · Sub-project 1 of "decisions memory"_

## Context

"Decisions memory" (web Phase 2): when a founder approves a deliverable, byte extracts durable decisions it locks in, merges them (topic-keyed, cap 30) into `companies/{uid}.decisions`, and later injects them into generation prompts ("honor these decisions"). Native has none of it.

The web does extract + merge + persist server-side in `/api/remember` (direct Anthropic). Native's CFs are **stateless** — they never touch Firestore; the client owns all Firestore I/O and sends context to CFs. To stay consistent, this sub-project ports ONLY the **extraction** as a stateless CF; the native client (sub-project 2) does load/merge/normalize/compose/persist in Swift.

## Goal

A deployed, stateless `extractDecisions` Cloud Function: given an approved deliverable + the decisions already on record, return the NEW/CHANGED durable decisions the deliverable locks in (empty if none). No Firestore, no merge, no persistence — the client does those.

## Non-goals

- No Firestore reads/writes in the CF (stateless — client persists).
- No merge/normalize/compose in the CF (Swift, sub-project 2).
- No roadmap/scaffold decision-grounding (separate later increment; those CFs lack a context channel).
- No chat `remember_fact` tool parity (deferred).

## Design

Mirror the `generateRoadmap` split (pure core + IO handler + index registration).

### `functions/src/extractDecisionsCore.ts` (pure, unit-tested)

Port from web `lib/ai/decisions.ts`:
- `interface ExtractedDecision { topic: string; statement: string; source?: string }`
- `interface DecisionOnRecord { topic: string; statement: string }` (what the client sends as "existing")
- `interface ApprovedDeliverable { title: string; dept: string; type: string; out: string }`
- `EXTRACT_SYSTEM` — verbatim from web `/api/remember` route (the "You extract durable company decisions…" system prompt).
- `DECISIONS_EXTRACT_SCHEMA` — verbatim from `decisions.ts` (the `{decisions: [{topic, statement, source?}]}` JSON schema).
- `buildExtractPrompt(deliverable: ApprovedDeliverable, existing: DecisionOnRecord[]): string` — verbatim from `decisions.ts` (on-record list + deliverable header + `out` clipped to `OUT_CAP = 2000`).
- `coerceDecisions(raw: unknown): { decisions: ExtractedDecision[] }` — NEW (native-side merge/cap lives in Swift, so the CF only sanitizes shape): keep items with non-empty trimmed `topic` + `statement`, trim `source` (drop if empty), never throw, `{decisions: []}` on junk. (No cap here — the client's `mergeDecisions` caps at 30.)

### `functions/src/extractDecisions.ts` (IO handler)

Mirror `generateRoadmap.ts`:
- `POST` only (405 otherwise); `verifyAuth` (401 on bad token); `checkAndIncrement` rate-limit (429).
- Model `const DECISIONS_MODEL = "claude-sonnet-5"` (light — extraction is simple; matches `companyChat`).
- Request body: `{ deliverable?: {title,dept,type,out}, existing_decisions?: [{topic,statement}] }`. Parse/validate the deliverable (need non-empty `title` + `out`, mirror web `parseDeliverable`); if invalid → `200 {decisions: []}` (fail-open, harmless — it's a fire-and-forget call).
- A `record_decisions` tool carrying `DECISIONS_EXTRACT_SCHEMA`, `tool_choice` forced, `system: EXTRACT_SYSTEM`, `messages:[{role:user, content: buildExtractPrompt(deliverable, existing)}]`, `max_tokens: 1024`.
- Return `200 coerceDecisions(toolUse.input)`. On ANY error → `200 {decisions: []}` (fail-open; the approval already happened client-side).

### `functions/src/index.ts`

```ts
import { handleExtractDecisions } from "./extractDecisions";
export const extractDecisions = onRequest(
  { cors: false, secrets: ["ANTHROPIC_API_KEY"] },
  handleExtractDecisions
);
```

## Contract (for sub-project 2 / native client)

- **POST** `https://us-central1-devpet-8f4b1.cloudfunctions.net/extractDecisions`, Firebase ID-token bearer auth.
- Request: `{ "deliverable": {"title","dept","type","out"}, "existing_decisions": [{"topic","statement"}] }`
- Response: `{ "decisions": [{"topic","statement","source"?}] }` (empty array = nothing to add). Always 200 on the happy/fail-open path; 401 (no auth) / 429 (rate limit) are the only non-200s.

## Testing (Jest, `functions/src/__tests__/extractDecisions.test.ts`)

- `buildExtractPrompt`: includes each on-record `topic: statement`; `(none yet)` when empty; includes deliverable title/dept/type + clips `out` to 2000; includes the "Extract only NEW or CHANGED" instruction.
- `coerceDecisions`: keeps valid items; drops items with empty topic/statement; trims/omits empty `source`; `{decisions: []}` on junk / non-array / missing.
- (Handler network path is not unit-tested — same convention as generateRoadmap, whose core is tested and handler is thin.)

Run: `cd functions && npx jest extractDecisions.test.ts`.

## Deploy (separate, user-confirmed)

`FUNCTIONS_DISCOVERY_TIMEOUT=180 firebase deploy --only functions:extractDecisions --project devpet-8f4b1 --force` (off-iCloud temp; re-auth `giang@murror.app`). Only after review + explicit user confirmation.

## Files

- Create: `functions/src/extractDecisionsCore.ts`, `functions/src/extractDecisions.ts`, `functions/src/__tests__/extractDecisions.test.ts`
- Modify: `functions/src/index.ts` (register the export)

## Note on branch lineage

Based on `feat/department-grounding` (grounding + grow-fix), since functions PR #7 is not yet merged — so this branch carries the grounded generateRoadmap too. The `extractDecisions` deploy is a NEW function and does not touch `generateRoadmap`.
