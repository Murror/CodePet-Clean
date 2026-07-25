# `extractDecisions` Cloud Function — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A deployed, stateless `extractDecisions` CF that returns the new/changed durable decisions an approved deliverable locks in.

**Architecture:** Mirror `generateRoadmap` (pure `*Core.ts` + IO handler + `index.ts` registration). Stateless — no Firestore; the native client sends `existing_decisions` and persists the result. Ports the extraction system prompt, prompt builder, and schema verbatim from the web app.

**Tech Stack:** TypeScript, Firebase Cloud Functions (Node 22), Jest, Anthropic SDK.

## Global Constraints

- Repo `CodePet-Clean`, branch `feat/decisions-extract`. Work in `functions/`.
- Verbatim ports come from web `"/Users/williamdominich/Desktop/Codepet v1.2/lib/ai/decisions.ts"` and `".../app/api/remember/route.ts"` — copy the prompt/schema strings exactly.
- Stateless: NO Firestore, NO merge, NO cap in the CF. `coerceDecisions` only sanitizes shape.
- Model: `claude-sonnet-5` (light). Auth via `./auth` `verifyAuth`; rate-limit via `./rateLimit` `checkAndIncrement` — same as `generateRoadmap.ts`.
- Fail-open: any error / invalid input → `200 {decisions: []}` (fire-and-forget call).
- Test: `cd functions && npx jest extractDecisions.test.ts`. Full suite: `cd functions && npm test`.

---

### Task 1: `extractDecisionsCore.ts` (pure) + tests

**Files:**
- Create: `functions/src/extractDecisionsCore.ts`
- Test: `functions/src/__tests__/extractDecisions.test.ts`

**Interfaces:**
- Produces: `ExtractedDecision`, `DecisionOnRecord`, `ApprovedDeliverable`, `EXTRACT_SYSTEM`, `DECISIONS_EXTRACT_SCHEMA`, `buildExtractPrompt(deliverable, existing)`, `coerceDecisions(raw)`. Consumed by Task 2.

- [ ] **Step 1: Create `functions/src/extractDecisionsCore.ts`**

```ts
// Pure logic for the extractDecisions CF — no firebase/express/anthropic imports, so it
// unit-tests without the Cloud-Functions module tree. Ported from the web app's
// lib/ai/decisions.ts (schema + prompt) and app/api/remember/route.ts (system prompt).
// Stateless: the native client sends existing decisions and does the merge/persist.

export interface ExtractedDecision {
  topic: string;
  statement: string;
  source?: string;
}

/** What the client sends as "already on record" (no timestamp needed for the prompt). */
export interface DecisionOnRecord {
  topic: string;
  statement: string;
}

/** The approved deliverable's high-signal fields, passed to extraction. */
export interface ApprovedDeliverable {
  title: string;
  dept: string;
  type: string;
  out: string;
}

export const EXTRACT_SYSTEM = `You extract durable company decisions from a deliverable a founder just approved. A decision is an explicit, lasting choice — about pricing, positioning, naming, target audience, tech, brand voice, or scope — that should constrain the company's future work.

Only extract decisions that are EXPLICIT and durable. Ignore transient details, task lists, examples, and anything speculative or clearly a draft. Reuse an existing topic when the deliverable CHANGES a decision already on record; never re-emit an unchanged one. If the deliverable locks in no clear new decision, return an empty list. Prefer few, high-confidence decisions over many shaky ones.`;

export const DECISIONS_EXTRACT_SCHEMA: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  properties: {
    decisions: {
      type: "array",
      description:
        "New or changed durable decisions this deliverable locks in. Empty array if none.",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          topic: {
            type: "string",
            description:
              "A short lowercase key for the decision area, e.g. pricing, positioning, naming, audience, tech, brand-voice, scope. Reuse an existing topic when the deliverable changes it.",
          },
          statement: {
            type: "string",
            description: 'One concrete sentence stating the decision (e.g. "Plus tier is $4/mo").',
          },
          source: {
            type: "string",
            description: "Where it came from — usually the deliverable title and department.",
          },
        },
        required: ["topic", "statement"],
      },
    },
  },
  required: ["decisions"],
};

const OUT_CAP = 2000;

export function buildExtractPrompt(deliverable: ApprovedDeliverable, existing: DecisionOnRecord[]): string {
  const onRecord = existing.length
    ? existing.map((d) => `- ${d.topic}: ${d.statement}`).join("\n")
    : "(none yet)";
  const out = deliverable.out.trim().replace(/\s+/g, " ").slice(0, OUT_CAP);
  return [
    "Decisions already on record (reuse a topic only if this deliverable CHANGES it; do not repeat unchanged ones):",
    onRecord,
    "",
    "The founder just approved this deliverable:",
    `Title: ${deliverable.title}`,
    `Department: ${deliverable.dept}`,
    `Type: ${deliverable.type}`,
    "---",
    out,
    "---",
    "Extract only NEW or CHANGED durable decisions it locks in. If there are none, return an empty list.",
  ].join("\n");
}

const clip = (v: unknown, n: number) => (typeof v === "string" ? v.trim().slice(0, n) : "");

/** Sanitize the model's tool output to a clean ExtractedDecision[]. Never throws. No cap
 *  or merge — the native client's mergeDecisions handles supersede + the 30 cap. */
export function coerceDecisions(raw: unknown): { decisions: ExtractedDecision[] } {
  const inArr =
    raw && Array.isArray((raw as { decisions?: unknown }).decisions)
      ? ((raw as { decisions: unknown[] }).decisions as unknown[])
      : [];
  const decisions: ExtractedDecision[] = [];
  for (const d of inArr) {
    if (!d || typeof d !== "object") continue;
    const rec = d as { topic?: unknown; statement?: unknown; source?: unknown };
    const topic = clip(rec.topic, 60);
    const statement = clip(rec.statement, 300);
    if (!topic || !statement) continue;
    const source = clip(rec.source, 200);
    decisions.push(source ? { topic, statement, source } : { topic, statement });
  }
  return { decisions };
}
```

- [ ] **Step 2: Write the tests**

Create `functions/src/__tests__/extractDecisions.test.ts`:

```ts
import { buildExtractPrompt, coerceDecisions } from "../extractDecisionsCore";

describe("buildExtractPrompt", () => {
  const deliverable = { title: "Pricing page", dept: "fin", type: "doc", out: "Plus tier is $4/mo." };
  it("lists on-record decisions and the deliverable, with the extract instruction", () => {
    const p = buildExtractPrompt(deliverable, [{ topic: "naming", statement: "App is called Codepet" }]);
    expect(p).toContain("- naming: App is called Codepet");
    expect(p).toContain("Title: Pricing page");
    expect(p).toContain("Department: fin");
    expect(p).toContain("Extract only NEW or CHANGED");
  });
  it("shows (none yet) when there are no existing decisions", () => {
    expect(buildExtractPrompt(deliverable, [])).toContain("(none yet)");
  });
  it("clips the deliverable body to 2000 chars", () => {
    const big = { ...deliverable, out: "x".repeat(5000) };
    const p = buildExtractPrompt(big, []);
    expect(p).toContain("x".repeat(2000));
    expect(p).not.toContain("x".repeat(2001));
  });
});

describe("coerceDecisions", () => {
  it("keeps valid items and trims", () => {
    const out = coerceDecisions({ decisions: [{ topic: " pricing ", statement: " $4/mo ", source: " Pricing page " }] });
    expect(out.decisions).toEqual([{ topic: "pricing", statement: "$4/mo", source: "Pricing page" }]);
  });
  it("drops items missing topic or statement, omits empty source", () => {
    const out = coerceDecisions({ decisions: [
      { topic: "", statement: "x" },
      { topic: "y" },
      { topic: "naming", statement: "Codepet", source: "" },
    ] });
    expect(out.decisions).toEqual([{ topic: "naming", statement: "Codepet" }]);
  });
  it("returns empty on junk / non-array / missing", () => {
    expect(coerceDecisions(null).decisions).toEqual([]);
    expect(coerceDecisions({}).decisions).toEqual([]);
    expect(coerceDecisions({ decisions: "nope" }).decisions).toEqual([]);
  });
});
```

- [ ] **Step 3: Run tests → pass**

Run: `cd functions && npx jest extractDecisions.test.ts`
Expected: PASS (pure module; implemented in Step 1).

- [ ] **Step 4: Commit**

```bash
git add functions/src/extractDecisionsCore.ts functions/src/__tests__/extractDecisions.test.ts
git commit -m "feat: extractDecisionsCore — extract prompt + schema + coerce (ported)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `extractDecisions` handler + registration

**Files:**
- Create: `functions/src/extractDecisions.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: Task 1's core; `./auth` `verifyAuth`; `./rateLimit` `checkAndIncrement`.
- Produces: `handleExtractDecisions`; the `extractDecisions` onRequest export.

- [ ] **Step 1: Create `functions/src/extractDecisions.ts`**

```ts
import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import {
  buildExtractPrompt,
  coerceDecisions,
  DECISIONS_EXTRACT_SCHEMA,
  EXTRACT_SYSTEM,
  ApprovedDeliverable,
  DecisionOnRecord,
} from "./extractDecisionsCore";

// Light model — extraction is simple; matches companyChat's tier.
const DECISIONS_MODEL = "claude-sonnet-5";

const RECORD_TOOL = {
  name: "record_decisions",
  description: "Record the durable decisions this approved deliverable locks in.",
  input_schema: DECISIONS_EXTRACT_SCHEMA,
} as const;

let _client: Anthropic | null = null;
function client(): Anthropic {
  if (!_client) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
    _client = new Anthropic({ apiKey });
  }
  return _client;
}

interface ExtractRequestBody {
  deliverable?: { title?: unknown; dept?: unknown; type?: unknown; out?: unknown };
  existing_decisions?: unknown;
}

const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");

function parseDeliverable(body: ExtractRequestBody): ApprovedDeliverable | null {
  const d = body.deliverable;
  if (!d || typeof d !== "object") return null;
  const title = str(d.title);
  const out = str(d.out);
  if (!title || !out) return null; // need a title + content to extract anything
  return { title, dept: str(d.dept), type: str(d.type), out };
}

function parseExisting(body: ExtractRequestBody): DecisionOnRecord[] {
  const arr = Array.isArray(body.existing_decisions) ? body.existing_decisions : [];
  const out: DecisionOnRecord[] = [];
  for (const e of arr) {
    if (!e || typeof e !== "object") continue;
    const rec = e as { topic?: unknown; statement?: unknown };
    const topic = str(rec.topic);
    const statement = str(rec.statement);
    if (topic && statement) out.push({ topic, statement });
  }
  return out;
}

export async function handleExtractDecisions(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  const auth = await verifyAuth(req.headers.authorization);
  if (!auth) { res.status(401).json({ error: "invalid_token" }); return; }

  const body = (req.body ?? {}) as ExtractRequestBody;
  const deliverable = parseDeliverable(body);
  // Fire-and-forget call: invalid input is harmless — nothing to extract.
  if (!deliverable) { res.status(200).json({ decisions: [] }); return; }

  const limit = await checkAndIncrement(auth.uid);
  if (!limit.allowed) {
    res.status(429).json({ error: "daily_limit_reached", reset_at: limit.resetAt.toISOString(), limit: limit.limit });
    return;
  }

  try {
    const response = await client().messages.create({
      model: DECISIONS_MODEL,
      max_tokens: 1024,
      system: EXTRACT_SYSTEM,
      tools: [RECORD_TOOL as any],
      tool_choice: { type: "tool", name: "record_decisions" },
      messages: [{ role: "user", content: buildExtractPrompt(deliverable, parseExisting(body)) }],
    });
    const block = response.content.find((b) => b.type === "tool_use") as any;
    res.status(200).json(coerceDecisions(block?.input));
  } catch (err) {
    logger.error("extractDecisions failed", { uid: auth.uid, err: String(err) });
    res.status(200).json({ decisions: [] }); // fail-open — approval already happened client-side
  }
}
```

(If `verifyAuth`/`checkAndIncrement` signatures differ from this, read `functions/src/generateRoadmap.ts` — this handler mirrors it exactly — and match them.)

- [ ] **Step 2: Register in `functions/src/index.ts`**

Add the import next to the other handler imports (near `import { handleGenerateRoadmap } from "./generateRoadmap";`):

```ts
import { handleExtractDecisions } from "./extractDecisions";
```

Add the export next to the other `onRequest` exports (after the `generateRoadmap` export block):

```ts
export const extractDecisions = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleExtractDecisions
);
```

- [ ] **Step 3: Type-check + full suite**

Run: `cd functions && npx tsc --noEmit && npm test`
Expected: `tsc` clean; entire Jest suite green (the new core tests + all existing).

- [ ] **Step 4: Commit**

```bash
git add functions/src/extractDecisions.ts functions/src/index.ts
git commit -m "feat: extractDecisions CF handler + registration (stateless, fail-open)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Post-implementation: Deploy (separate, user-confirmed)

After review + explicit user approval, deploy the NEW function only (does not touch generateRoadmap):
`FUNCTIONS_DISCOVERY_TIMEOUT=180 firebase deploy --only functions:extractDecisions --project devpet-8f4b1 --force` (off-iCloud temp; `firebase login --reauth` as giang@murror.app first).
Sanity: `firebase functions:list` shows `extractDecisions`; a POST with a sample deliverable returns a `{decisions:[...]}` shape.

## Self-Review

**Spec coverage:** core (types/system/prompt/schema/coerce) → Task 1; handler (auth/rate-limit/model/tool/fail-open) + registration → Task 2; deploy → post-impl. ✓
**Placeholder scan:** full code in every step; ports are reproduced inline (verified against the web source paths). ✓
**Type consistency:** `ApprovedDeliverable`/`DecisionOnRecord`/`coerceDecisions`/`buildExtractPrompt`/`DECISIONS_EXTRACT_SCHEMA`/`EXTRACT_SYSTEM` defined in Task 1, imported in Task 2. Handler mirrors `generateRoadmap.ts` verbatim in structure. ✓
**Stateless:** no Firestore import anywhere; `existing_decisions` comes from the request; output is extract-only (no merge/cap). ✓
