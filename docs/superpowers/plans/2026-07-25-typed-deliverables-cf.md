# Typed Deliverables — runTask CF (A1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox (`- [ ]`) steps.

**Goal:** `runTask` returns a structured `payload` for 4 kinds (checklist, doc, plan, dms) alongside the existing `{kind,title,body}` markdown — backward-compatible.

**Architecture:** Extend the single `record_deliverable` tool with an optional `payload` object (union of the 4 kinds' fields); the model still self-picks the kind and always writes the markdown `body`, and additionally fills `payload` for the 4 structured kinds. `coerceDeliverable` sanitizes the payload per-kind and attaches it (or omits → native falls back to `body`). Pure logic in `runTaskCore.ts`, tool schema in `runTask.ts`.

**Tech Stack:** TypeScript, Firebase Cloud Functions, Jest, Anthropic SDK.

## Global Constraints

- Repo CodePet-Clean, branch `feat/typed-deliverables`. Work in `functions/`.
- Backward-compatible: `{kind,title,body}` unchanged and always present; `payload` is additive/optional. Existing clients (and the decisions extractor which reads `body`) are unaffected.
- Only the 4 slice-1 kinds get payloads; all others (text/post/email/legal/calendar/screens/sheet/site/other) return `body` markdown only, no payload.
- One model call, `tool_choice` forced to `record_deliverable` (unchanged flow). Fail-open unchanged.
- Payload field descriptions + prompt guide are ported from web `/Users/williamdominich/Desktop/Codepet v1.2/lib/ai/deliverableSchemas.ts` (CHECKLIST_SCHEMA:376-399, DOC_SCHEMA:452-490, PLAN_SCHEMA:405-447, DMS_SCHEMA:295-328; DELIVERABLE_INSTRUCTIONS:508/519/522/523).
- Test: `cd functions && npx jest runTask.test.ts`. Full suite: `cd functions && npm test`.

---

### Task 1: `runTaskCore.ts` — payload types, coercers, coerce + prompt guide

**Files:** Modify `functions/src/runTaskCore.ts`; Test `functions/src/__tests__/runTask.test.ts`

**Interfaces:**
- Produces: `Deliverable { kind, title, body, payload?: DeliverablePayload }`; per-kind payload interfaces; `coerceDeliverable` now attaches payload for the 4 kinds. Consumed by the handler + native A2.

- [ ] **Step 1: Add payload types + per-kind coercers**

In `functions/src/runTaskCore.ts`, add (after the `Deliverable` interface):

```ts
export interface ChecklistItem { t: string; done: boolean; }
export interface ChecklistPayload { items: ChecklistItem[]; }
export interface DocSection { h: string; p: string; }
export interface DocPayload { call: string; sections: DocSection[]; next: string[]; }
export interface PlanChange { area: string; edit: string; }
export interface PlanPayload { goal: string; steps: string[]; changes: PlanChange[]; verify: string[]; risks: string; }
export interface DmMessage { name: string; note: string; msg: string; }
export interface DmsPayload { messages: DmMessage[]; }
export type DeliverablePayload = ChecklistPayload | DocPayload | PlanPayload | DmsPayload;

const STRUCTURED_KINDS = new Set(["checklist", "doc", "plan", "dms"]);
const s = (v: unknown, n = 600) => (typeof v === "string" ? v.trim().slice(0, n) : "");
const strArr = (v: unknown, n = 12, len = 400): string[] =>
  Array.isArray(v) ? v.map((x) => s(x, len)).filter(Boolean).slice(0, n) : [];

/** Sanitize the raw payload for a kind; null if it lacks the kind's required content. */
export function coercePayload(kind: string, raw: unknown): DeliverablePayload | null {
  const r = (raw ?? {}) as Record<string, unknown>;
  if (kind === "checklist") {
    const items = (Array.isArray(r.items) ? r.items : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { t: s(o.t, 300), done: o.done === true }; })
      .filter((it) => it.t).slice(0, 7);
    return items.length ? { items } : null;
  }
  if (kind === "doc") {
    const call = s(r.call, 600);
    const sections = (Array.isArray(r.sections) ? r.sections : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { h: s(o.h, 120), p: s(o.p, 1200) }; })
      .filter((x) => x.h && x.p).slice(0, 6);
    const next = strArr(r.next, 3, 200);
    return call && sections.length ? { call, sections, next } : null;
  }
  if (kind === "plan") {
    const goal = s(r.goal, 300);
    const steps = strArr(r.steps, 6, 300);
    const changes = (Array.isArray(r.changes) ? r.changes : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { area: s(o.area, 120), edit: s(o.edit, 400) }; })
      .filter((x) => x.area && x.edit).slice(0, 8);
    const verify = strArr(r.verify, 6, 300);
    const risks = s(r.risks, 300);
    return goal && steps.length && changes.length ? { goal, steps, changes, verify, risks } : null;
  }
  if (kind === "dms") {
    const messages = (Array.isArray(r.messages) ? r.messages : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { name: s(o.name, 80), note: s(o.note, 200), msg: s(o.msg, 1200) }; })
      .filter((x) => x.name && x.msg).slice(0, 4);
    return messages.length ? { messages } : null;
  }
  return null;
}
```

- [ ] **Step 2: Extend `Deliverable` + `coerceDeliverable`**

Change the `Deliverable` interface to add `payload?: DeliverablePayload;`. At the end of `coerceDeliverable`, replace `return { kind, title, body };` with:

```ts
  if (STRUCTURED_KINDS.has(kind)) {
    const payload = coercePayload(kind, (raw as Record<string, unknown>)?.payload);
    if (payload) return { kind, title, body, payload };
  }
  return { kind, title, body };
```

- [ ] **Step 3: Extend `buildRunTaskPrompt` with the per-kind structured guide**

In `buildRunTaskPrompt`, after the existing final instruction string (the one ending "...do not invent facts about them.") and before `vi`, append this block (port the guide text verbatim from web DELIVERABLE_INSTRUCTIONS):

```ts
    "\n\nALWAYS write the markdown `body`. If (and only if) the kind you chose is checklist, doc, plan, or dms, ALSO fill `payload` with that kind's structured fields (leave `payload` empty for any other kind):\n" +
    "- checklist: Build a concrete setup/launch checklist — exactly 5-7 actionable steps in order (`items[].t`), each with `done` true only for obvious already-satisfied prerequisites.\n" +
    "- doc: `call` = the decision/recommendation in 1-2 sentences up front; `sections[]` = 2-5 labeled {h,p} reasoning blocks (why it's right, tradeoffs, what's out); `next[]` = 1-3 next actions.\n" +
    "- plan: an HONEST code-change plan — `goal` (one line), `steps[]` (3-5 ordered), `changes[]` = {area, edit} in plain terms (no fabricated file paths), `verify[]` (future-tense checks), `risks` (one line). Never claim it shipped.\n" +
    "- dms: exactly 4 personalized 1:1 outreach `messages[]` = {name (persona placeholder), note (why a strong target), msg (warm specific DM)}."
```

- [ ] **Step 4: Tests**

Add to `functions/src/__tests__/runTask.test.ts`:

```ts
import { coercePayload } from "../runTaskCore";
// ... within existing imports of coerceDeliverable/buildRunTaskPrompt ...

describe("coerceDeliverable payload", () => {
  it("attaches a sanitized checklist payload and keeps body", () => {
    const out = coerceDeliverable({ kind: "checklist", title: "T", body: "md",
      payload: { items: [{ t: "Step 1", done: false }, { t: "", done: true }, { t: "Step 2", done: true }] } }, "task");
    expect(out!.kind).toBe("checklist");
    expect(out!.body).toBe("md");
    expect((out as any).payload.items).toEqual([{ t: "Step 1", done: false }, { t: "Step 2", done: true }]);
  });
  it("omits payload for a non-structured kind (backward-compat)", () => {
    const out = coerceDeliverable({ kind: "post", title: "T", body: "md", payload: { foo: 1 } }, "task");
    expect((out as any).payload).toBeUndefined();
    expect(out).toEqual({ kind: "post", title: "T", body: "md" });
  });
  it("omits payload when a structured kind's required fields are missing (fail-open to body)", () => {
    const out = coerceDeliverable({ kind: "doc", title: "T", body: "md", payload: { sections: [] } }, "task");
    expect((out as any).payload).toBeUndefined();
    expect(out!.body).toBe("md");
  });
});
describe("coercePayload", () => {
  it("plan requires goal+steps+changes", () => {
    expect(coercePayload("plan", { goal: "g", steps: ["a"], changes: [{ area: "x", edit: "y" }], verify: [], risks: "" }))
      .toEqual({ goal: "g", steps: ["a"], changes: [{ area: "x", edit: "y" }], verify: [], risks: "" });
    expect(coercePayload("plan", { goal: "g", steps: [], changes: [] })).toBeNull();
  });
  it("dms keeps up to 4 valid messages", () => {
    const p: any = coercePayload("dms", { messages: [{ name: "A", note: "n", msg: "m" }, { name: "", note: "", msg: "" }] });
    expect(p.messages).toHaveLength(1);
  });
});

describe("buildRunTaskPrompt structured guide", () => {
  it("mentions the per-kind payload guide", () => {
    const p = buildRunTaskPrompt({ companionId: "byte", language: "en", context: "", taskTitle: "T", taskDetail: "" });
    expect(p).toContain("ALSO fill `payload`");
    expect(p).toMatch(/checklist:.*items/);
    expect(p).toMatch(/dms:.*messages/);
  });
});
```

- [ ] **Step 5: Run tests → pass**

Run: `cd functions && npx jest runTask.test.ts` → PASS (new + existing).

- [ ] **Step 6: Commit**

```bash
git add functions/src/runTaskCore.ts functions/src/__tests__/runTask.test.ts
git commit -m "feat: runTask per-kind payload coercers (checklist/doc/plan/dms) + prompt guide

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `runTask.ts` — add `payload` to the record tool

**Files:** Modify `functions/src/runTask.ts`

**Interfaces:** Consumes Task 1 (coerce already handles payload). Produces the tool schema the model fills.

- [ ] **Step 1: Add `payload` to `RECORD_TOOL.input_schema.properties`**

In `functions/src/runTask.ts`, extend the `RECORD_TOOL` `input_schema.properties` (keep `kind`/`title`/`body` and `required: ["kind","title","body"]` unchanged — payload is optional) by adding:

```ts
      payload: {
        type: "object",
        additionalProperties: true,
        description: "Structured fields for the chosen kind. Fill ONLY the fields for that kind (see the per-kind guide in the prompt); omit for kinds without a structured form.",
        properties: {
          items: { type: "array", description: "checklist: 5-7 ordered steps.",
            items: { type: "object", additionalProperties: false, properties: { t: { type: "string" }, done: { type: "boolean" } }, required: ["t", "done"] } },
          call: { type: "string", description: "doc: the decision up front (1-2 sentences)." },
          sections: { type: "array", description: "doc/legal: labeled {h,p} blocks.",
            items: { type: "object", additionalProperties: false, properties: { h: { type: "string" }, p: { type: "string" } }, required: ["h", "p"] } },
          next: { type: "array", description: "doc: 1-3 next actions.", items: { type: "string" } },
          goal: { type: "string", description: "plan: one-line goal." },
          steps: { type: "array", description: "plan: 3-5 ordered approach steps.", items: { type: "string" } },
          changes: { type: "array", description: "plan: areas touched.",
            items: { type: "object", additionalProperties: false, properties: { area: { type: "string" }, edit: { type: "string" } }, required: ["area", "edit"] } },
          verify: { type: "array", description: "plan: future-tense verification checks.", items: { type: "string" } },
          risks: { type: "string", description: "plan: one-line main risk." },
          messages: { type: "array", description: "dms: exactly 4 persona DMs.",
            items: { type: "object", additionalProperties: false, properties: { name: { type: "string" }, note: { type: "string" }, msg: { type: "string" } }, required: ["name", "note", "msg"] } },
        },
      },
```

(No other handler change — `coerceDeliverable(block.input, taskTitle)` already reads `block.input.payload`.)

- [ ] **Step 2: Type-check + full suite**

Run: `cd functions && npx tsc --noEmit && npm test` → tsc clean; whole Jest suite green.

- [ ] **Step 3: Commit**

```bash
git add functions/src/runTask.ts
git commit -m "feat: runTask record tool accepts structured payload (4 kinds)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Post-implementation: Deploy (separate, user-confirmed)

`FUNCTIONS_DISCOVERY_TIMEOUT=180 firebase deploy --only functions:runTask --project devpet-8f4b1 --force` (off-iCloud temp; `firebase login --reauth` as giang@murror.app). Additive/backward-compatible. After review + confirmation.

## Self-Review

**Spec coverage:** payload types+coercers (T1), coerce+prompt (T1), tool schema (T2), deploy (post). ✓
**Placeholder scan:** full code; port strings inlined from the cited web lines. ✓
**Type consistency:** `Deliverable.payload?` + per-kind interfaces (T1) consumed by handler (unchanged) and native A2; `coercePayload` used in `coerceDeliverable`. Backward-compat asserted by the "post/omit" tests. ✓
