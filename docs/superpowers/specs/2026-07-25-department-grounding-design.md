# Department Grounding in `generateRoadmap` CF (Design)

_Date: 2026-07-25 · Repo: CodePet-Clean (functions) · Branch: `feat/department-grounding` (off `feat/project-health-reflection-sync`)_

## Context

The web reference grounds roadmap/task generation in a per-department catalog
(`lib/ai/departments.ts` → `DEPARTMENT_FOUNDATIONS` + `departmentBlock(k, stage)`),
injected server-side inside `/api/scaffold`. The deployed `generateRoadmap` Cloud
Function (which the native app actually calls) has **none** of this: it builds a
generic phase-based prompt and, in `coerceRoadmap`, silently defaults any
invalid/missing department to `"ops"` — bloating Operations and making other
departments read as falsely dormant downstream.

Verified facts:
- Native `brief.stage` values (`OnboardingContent.stages`) are exactly the web
  `OB_STAGES` strings (`"Just an idea", "Prototype", "Private beta", "Public beta",
  "Launched", "Growing"`), so `departmentBlock(k, brief.stage)` will match the right
  `stageFocus`.
- `enrichBrief`/`generateRoadmap` are deployed and live on `devpet-8f4b1`.
- Native renders `task.dept` only via `DepartmentCatalog.find(t.dept)?.name`
  (nil-safe) and filters `$0.dept == key`; an empty-string dept matches no
  department, shows no label, and inflates nothing. So an "unassigned" dept needs
  **zero native changes**.

## Goal

Make `generateRoadmap` produce **stage-grounded, correctly-attributed** tasks:
each of the 8 departments carries its real mandate/skills/stage-focus/antipatterns
into the prompt (so the model picks the right owning department and stage-fit
work), and untaggable tasks are left **unassigned** instead of dumped into `ops`.

## Non-goals (explicitly deferred — the "full" option was not chosen)

- No explicit active/dormant decision from the model; native keeps its current
  "zero tasks → later" heuristic.
- No dept-grouped output rearchitecture (the flat phase/deps `RoadmapTask` shape
  stays; `scaffoldRoadmap.ts` is left untouched).
- No native code changes (verify-only).
- No prompt-caching work this round.

## Design

### Change 1 — Port the grounding catalog into the functions repo

Create `functions/src/departments.ts` as a **verbatim port** of the web
`lib/ai/departments.ts`: the `DepartmentFoundation` interface, the full
`DEPARTMENT_FOUNDATIONS` record (8 departments), `departmentBlock(k, stage)`, and
`departmentBrief(k)`. Static curated data + pure helpers, no imports. Also add a
`DEPARTMENT_NAMES: Record<string, string>` map (eng→"Engineering", design→"Design",
mkt→"Marketing", sales→"Sales", support→"Support", fin→"Finance", ops→"Operations",
legal→"Legal") for the prompt's human labels (matches native `Department` names).

### Change 2 — Inject grounding into `buildRoadmapPrompt`

In `functions/src/generateRoadmapCore.ts`, `buildRoadmapPrompt` gains a departments
block built from the brief's stage. After the existing brief `lines`, append:

```
Departments (grounded for the founder's current stage — use these to choose each
task's owning department and to keep tasks stage-appropriate):

- eng (Engineering):
<departmentBlock("eng", stage)>

- design (Design):
<departmentBlock("design", stage)>
… all 8 …
```

Built by iterating the 8 `DEPT_KEYS` (stable order eng, design, mkt, sales, support,
fin, ops, legal), using `DEPARTMENT_NAMES[k]` and `departmentBlock(k, brief.stage ?? "")`.
`departmentBlock` fails open to `""` on unknown key/stage, so a missing stage just
omits the focus line — never throws.

Tighten the existing per-task `dept` instruction to reference the grounding: replace
"a `dept` — the single owning department, exactly one of …" with wording that says
to choose the owning department **using the department grounding above**, still
constrained to the 8 keys. Keep the rest of the prompt (phases, chaining, `who`,
`deps`) unchanged.

Import `departmentBlock` + `DEPARTMENT_NAMES` from `./departments`.

### Change 3 — Stop defaulting invalid/missing dept to `ops`

In `coerceRoadmap` (`generateRoadmapCore.ts:128`), change:

```ts
const dept = typeof t.dept === "string" && DEPT_KEYS.has(t.dept) ? t.dept : "ops";
```

to leave it **unassigned**:

```ts
const dept = typeof t.dept === "string" && DEPT_KEYS.has(t.dept) ? t.dept : "";
```

`RoadmapTask.dept` stays `string` (type/schema unchanged). Native treats `""` as
unassigned (verified nil-safe). With Change 2 in place, valid depts should be the
norm; `""` is the honest fallback for the rare miss, not a silent Operations dump.

### Data flow (unchanged shape)

`handleGenerateRoadmap` → `buildRoadmapPrompt({language, brief})` [now grounded] →
Anthropic `record_roadmap` tool → `coerceRoadmap(input)` [unassigned fallback] →
`{tasks}` JSON → native `CompanyData.fetchRoadmap` (no change).

## Testing (Jest, `functions/src/__tests__/generateRoadmap.test.ts`)

- **Update** the existing test `"keeps a valid dept and defaults an invalid/missing
  one to ops"` → invalid/missing dept now yields `""` (not `"ops"`). Rename to
  `"keeps a valid dept and leaves an invalid/missing one unassigned"`; assert
  `dept === ""` for the invalid and missing cases, and the valid case still `=== "eng"`.
- **Add** `buildRoadmapPrompt` grounding tests: for `brief.stage = "Prototype"`, the
  prompt contains a known department mandate substring (e.g. part of eng's mandate)
  AND the eng `stageFocus["Prototype"]` focus line; for an unknown stage, it still
  builds without throwing and includes the mandate but no focus line.
- **Add** a `departments.ts` unit test: `departmentBlock("eng", "Prototype")` contains
  "Mandate:", "Core skills:", the Prototype focus, and "Avoid:"; `departmentBlock("bogus", "x") === ""`.
- Existing coerce/slug/phase tests must still pass unchanged.

Run: `cd functions && npm test` (Jest). No Xcode involved.

## Deploy

One scoped Cloud Functions deploy (per RELEASE/handoff pattern, off-iCloud temp to
avoid the FS hang), **only after explicit user confirmation** (live backend on
`devpet-8f4b1`; requires `firebase login --reauth` as `giang@murror.app`):

```
FUNCTIONS_DISCOVERY_TIMEOUT=180 firebase deploy \
  --only functions:generateRoadmap --project devpet-8f4b1 --force
```

Post-deploy sanity: complete native onboarding for a test brief and confirm the
Overview roadmap tasks carry sensible departments (not all ops) and read
stage-appropriately.

## Files touched

- Create: `functions/src/departments.ts` (ported catalog + helpers + names)
- Modify: `functions/src/generateRoadmapCore.ts` (`buildRoadmapPrompt` grounding; `coerceRoadmap` fallback)
- Test: `functions/src/__tests__/generateRoadmap.test.ts` (update ops test; add grounding tests) + optionally `functions/src/__tests__/departments.test.ts`
- No native changes (verify-only).

## Risks / notes

- Prompt grows by the 8 grounding blocks; `max_tokens` output is unchanged (3000).
  Opus input cost rises modestly — acceptable, matches web behavior; caching deferred.
- `generateRoadmap.ts` `RECORD_TOOL` dept description still lists the 8 keys — no
  schema change needed since we keep `dept: string` and only change the coerce fallback.
- Native `""`-dept safety was verified against `DepartmentCatalog.find`, `summaries`,
  `TasksView`, `RoadmapMapView`, `DepartmentDetailView`; re-confirm during the plan.
