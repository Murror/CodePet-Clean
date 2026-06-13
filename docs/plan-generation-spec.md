# Project Health — Plan Generation Pipeline (Spec)

Status: **proposed** · Owner: TBD · Last updated: 2026-06-13

Turn Project Health checks from a self-marked checklist into **detailed,
project-specific action plans** generated per section, delivered through the
existing guidance pipeline. Designed so a paywall can be layered on later
(server-enforced), but ships free first to validate demand.

---

## 1. Background — the pipeline we extend

Daily guidance today:

```
GuidanceEnricher (@MainActor)  →  ReflectionAPIClient.fetchGuidance
     ↓ writes                          ↓ POST + Bearer <FirebaseIDToken>
TipsState.currentGuidance         generateGuidance (onRequest, cors:false,
     ↓ persists                         secret ANTHROPIC_API_KEY)
TipsPersistence (cp_tips_ keys)        ↓ verifyAuth → checkAndIncrement(uid)
                                       ↓ Anthropic messages.create,
                                         forced tool_use "record_guidance",
                                         system prompt cache_control: ephemeral
                                       ← GuidanceOutput JSON
```

Facts that shape this design:

- **Auth + rate limit are reusable.** `verifyAuth(authorization)` and
  `checkAndIncrement(uid)` (`DAILY_LIMIT = 100_000`, returns 429 on exceed).
- **Model:** `claude-haiku-4-5-20251001`, forced single-tool output, system
  prompt cached (`cache_control: ephemeral`). Plans want richer output — model
  tier is a deliberate knob (§7).
- **Server cache pattern exists** (`functions/src/cache.ts`, `narratives_cache`,
  7-day TTL). Guidance itself isn't server-cached; it's once/day client-side via
  `TipsState.isFresh`. Plans **should** be server-cached.
- **Daily guidance = one pet-voiced focus across all projects.** Plans are the
  opposite: **per-project, per-section, on-demand, multi-step, neutral-voiced**
  (Project Health uses a neutral voice, no pet character). Hence a *sibling*
  endpoint, not a new parameter on `generateGuidance`.

---

## 2. Server — new `generatePlan` Cloud Function

New file `functions/src/generatePlan.ts`, exported from `index.ts` with the same
options as the others:

```ts
export const generatePlan = onRequest(
  { cors: false, secrets: ["ANTHROPIC_API_KEY"] },
  handleGeneratePlan
);
```

Reuses `verifyAuth` + `checkAndIncrement` verbatim. Handler outline mirrors
`handleGenerateGuidance`: method check → auth → validate payload → rate limit →
(cache lookup §6) → Anthropic call → respond.

### Request — `GeneratePlanInput`

```ts
interface GeneratePlanInput {
  language: "vi" | "en";
  project: {
    name: string;
    stage: "idea" | "building" | "launch" | "growth";
    brief: string;
    tags: string[];      // ProjectTag rawValues
    domains: string[];   // ProjectDomain rawValues
  };
  section: {
    rule_id: string;     // e.g. "biz_problem_validated"
    title: string;       // resolved, language-specific
    pillar: "engineering" | "business" | "growth";
    current_state: "missing" | "passed" | "attested";
  };
  recent_narratives?: NarrativeSummaryInput[];  // optional personalization (reuse DTO)
  // NOTE: no `tier` field — the server resolves entitlement itself (§4).
}
```

### Output — forced `record_plan` tool

```ts
const PLAN_TOOL = {
  name: "record_plan",
  description: "Record a concrete, ordered action plan for one Project Health section.",
  input_schema: {
    type: "object",
    properties: {
      summary:    { type: "string" },                 // 1–2 sentences: what & why
      steps: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title:     { type: "string" },
            detail:    { type: "string" },            // the how-to (gated for free tier)
            done_when: { type: "string" }             // observable completion signal
          },
          required: ["title", "detail", "done_when"]
        }
      },
      pitfalls:   { type: "array", items: { type: "string" } },
      est_effort: { type: "string" }                  // "~1 day", "30 min"
    },
    required: ["summary", "steps", "est_effort"]
  }
};
// messages.create({ model, tools: [PLAN_TOOL], tool_choice: {type:"tool", name:"record_plan"} })
```

### Prompt differences from guidance

- **Drop `renderPersonaBlock`** — neutral instructional voice, no pet character.
- **Keep** the age-12 readability rules (every technical term explained inline)
  and the "reference real files/tools/patterns from their data" specificity.
- Put project `stage` + `section.current_state` in the user message so the plan
  is concrete: *"You're a SwiftUI finance app at the idea stage with no
  validated problem — here is the 6-step plan to validate it."*

### Response payload

```ts
interface GeneratePlanOutput {
  plan: {
    summary: string;
    steps: { title: string; detail: string; done_when: string }[];
    pitfalls: string[];
    est_effort: string;
  };
  tier: "preview" | "full";   // what the server actually returned (§4)
  locked_step_count: number;  // steps whose `detail` was withheld (0 for full)
  model: string;
  generated_at: string;
}
```

---

## 3. Client — `PlanEnricher` + DTOs (mirrors `GuidanceEnricher`)

- **DTOs** in `ReflectionAPIClient.swift`: `GeneratePlanRequest` /
  `GeneratePlanResponse` (Codable, snake_case `CodingKeys` like the existing
  ones). Add `fetchPlan(_:)` to `ReflectionAPIClientProtocol` and implement by
  copying `fetchGuidance` against a new `planEndpoint` URL.
- **`PlanEnricher`** (`@MainActor ObservableObject`): `func fetchPlan(for section:,
  project:, ...) async`, with the same loading / error / double-fetch-guard shape
  as `GuidanceEnricher`.
- **Model** `SectionPlan: Codable, Equatable`:

```swift
struct SectionPlan: Codable, Equatable {
    struct Step: Codable, Equatable {
        let title: String
        let detail: String?      // nil = locked (free tier)
        let doneWhen: String
    }
    let summary: String
    let steps: [Step]
    let pitfalls: [String]
    let estEffort: String
    let tier: String             // "preview" | "full"
    let lockedStepCount: Int
    let generatedAt: Date
}
```

---

## 4. Paywall — server-enforced (critical)

A client-side "show the valuable half" wall is trivially bypassed: if the client
receives the full plan and hides half, the locked half is still readable in the
network response. Therefore:

- The **server** resolves entitlement from Firestore (`entitlements/{uid}`,
  written by a future RevenueCat webhook) and **returns only what the tier
  allows**:
  - **free / preview:** `summary` + every step's `title` + `done_when`, but
    `detail` only on the **first step**; the rest have `detail = null`. Set
    `locked_step_count` accordingly.
  - **Pro / full:** every step with full `detail`.
  - Locked content never leaves the server.
- A server flag **`PLAN_GATING_ENABLED` (default OFF)** ships plans free to
  validate demand, then flips to enforce gating — matches the build order (§8).
- The client reads entitlement only to render the "Unlock full plan" CTA — never
  as the security boundary.

This reframes the original "show half" idea into **"preview the structure"**:
free users see the whole plan's shape (summary + all step titles), paid users get
the turn-by-turn detail. Generous, not baity.

---

## 5. UI hook — `ProjectFolderView`

- Each health row gains a **"Get plan" / "View plan"** affordance, beside
  "Mark done" / "Learn more". For self-attested items this is the upgrade from
  "tick a box yourself" to "here's exactly how."
- Tapping calls `PlanEnricher.fetchPlan` → renders an **inline expandable panel**
  under the row: `summary`, numbered `steps` (title · detail · done-when),
  `pitfalls`, `est_effort`.
- **Free tier:** locked steps render as blurred rows + a single
  "Unlock full plan (N more steps)" CTA driven by `locked_step_count`.
- Neutral voice throughout — consistent with the rest of Project Health.

---

## 6. Caching — two layers

- **Client:** `TipsState.plansByKey: [String: SectionPlan]`, persisted via a new
  `cp_tips_plans` key in `TipsPersistence` (same pattern as `currentGuidance`).
  **Cache key = `projectPath + ruleId + stage`** — changing stage regenerates
  (plans are stage-specific); revisiting the tab does not. Plus a manual
  **"Regenerate"** action.
- **Server:** reuse the `cache.ts` pattern with a new `plans_cache` collection,
  keyed by `uid + projectHash + ruleId + stage + language + tier`, ~30-day TTL.
  Plans are stable and expensive — this saves real cost on repeat views.

Unlike daily guidance, plans **do not expire daily**. They're invalidated by a
stage/brief change or an explicit regenerate.

---

## 7. Open decisions

- **Model tier.** Guidance uses Haiku 4.5. For *paid* plans, quality matters
  more — use **Sonnet 4.6** for full plans (and optionally Haiku for the free
  preview), exposed as a per-tier knob in `generatePlan.ts`. A generic-filler
  paid plan is a refund.
- **Rate-limit weighting.** Plans are heavier than daily guidance. Either count
  toward the shared `DAILY_LIMIT` or give plan-gen its own smaller cap so a loop
  can't burn budget.
- **Personalization depth.** Whether to always send `recent_narratives` (richer,
  more tokens) or only for the active project.

---

## 8. Build order

1. **Server** — `generatePlan` function + `record_plan` tool, no gating, full
   plan, Sonnet. Deploy.
2. **Client** — DTOs + `fetchPlan` + `PlanEnricher` + `SectionPlan` + persistence.
3. **UI** — "Get plan" → inline panel (full, free). **Ship and measure** whether
   users open and act on plans.
4. **Later** — server entitlement gate + preview truncation +
   RevenueCat webhook + "Unlock" CTA.

Steps 1–3 are the **validation slice**; step 4 is the **monetization slice**,
built only once demand is proven.

---

## 9. Reused vs. new

| Reused (no change)                          | New                                  |
| ------------------------------------------- | ------------------------------------ |
| `verifyAuth`, `checkAndIncrement`           | `generatePlan.ts` + `record_plan`    |
| `onRequest` opts (cors, secret)             | `GeneratePlan{Request,Response}` DTOs|
| `cache.ts` pattern, Firestore              | `plans_cache` collection             |
| Anthropic client, `MODEL` constant          | `PlanEnricher`, `SectionPlan`        |
| `ReflectionAPIClient` transport / Bearer    | `planEndpoint`, `fetchPlan`          |
| `TipsPersistence` save/load pattern         | `cp_tips_plans` key, `plansByKey`    |
| `ProjectFolderView` row layout              | "Get plan" panel + locked-step CTA   |
| —                                           | `entitlements/{uid}`, `PLAN_GATING_ENABLED` |
