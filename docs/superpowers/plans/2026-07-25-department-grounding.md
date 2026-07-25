# Department Grounding in `generateRoadmap` CF — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ground `generateRoadmap`'s prompt in per-department mandate/skills/stage-focus/antipatterns and stop defaulting untaggable tasks to `ops` (leave them unassigned).

**Architecture:** Port the web's static department catalog into the functions repo, inject a stage-aware grounding block into the roadmap prompt, and change one coerce fallback. Pure TypeScript in `functions/src`; unit-tested with Jest. No native changes. Output shape (flat `RoadmapTask`, `dept: string`) is unchanged.

**Tech Stack:** TypeScript, Firebase Cloud Functions (Node 22), Jest. Anthropic SDK (unchanged).

## Global Constraints

- Repo: `CodePet-Clean`, branch `feat/department-grounding` (off `feat/project-health-reflection-sync`). All work here.
- Source of truth for the port: web `"/Users/williamdominich/Desktop/Codepet v1.2/lib/ai/departments.ts"` — copy VERBATIM (do not paraphrase the mandates/skills/foci).
- `RoadmapTask.dept` stays type `string` (no nullable, no schema change to `RECORD_TOOL`). Unassigned = `""`.
- 8 department keys, stable order: `eng, design, mkt, sales, support, fin, ops, legal` (the existing `DEPT_KEYS` Set insertion order).
- Stage strings are the web `OB_STAGES` (`"Just an idea", "Prototype", "Private beta", "Public beta", "Launched", "Growing"`); `departmentBlock` fails open to `""` for unknown key/stage — never throw.
- No native changes (verify-only). No deploy inside these tasks — deploy is a separate, user-confirmed step after review.
- Test command: `cd functions && npm test` (Jest). Run focused: `cd functions && npx jest <file>`.

---

### Task 1: Port the department catalog into the functions repo

**Files:**
- Create: `functions/src/departments.ts`
- Test: `functions/src/__tests__/departments.test.ts`

**Interfaces:**
- Produces: `DEPARTMENT_FOUNDATIONS: Record<string, DepartmentFoundation>`, `departmentBlock(k: string, stage: string): string`, `departmentBrief(k?: string | null): string`, `DEPARTMENT_NAMES: Record<string, string>`. Consumed by Task 2.

- [ ] **Step 1: Create `functions/src/departments.ts` by verbatim copy + names map**

Copy the ENTIRE contents of web `"/Users/williamdominich/Desktop/Codepet v1.2/lib/ai/departments.ts"` (the header comment, `DepartmentFoundation` interface, the full `DEPARTMENT_FOUNDATIONS` record for all 8 departments, `departmentBlock`, and `departmentBrief`) into `functions/src/departments.ts` UNCHANGED. Read the web file in full first and reproduce it exactly (all 8 departments' mandate/skills/stageFocus/antipatterns).

Then append this names map at the end of the file:

```ts
/** Human display names for the 8 department keys (matches native `Department`). */
export const DEPARTMENT_NAMES: Record<string, string> = {
  eng: "Engineering",
  design: "Design",
  mkt: "Marketing",
  sales: "Sales",
  support: "Support",
  fin: "Finance",
  ops: "Operations",
  legal: "Legal",
};
```

- [ ] **Step 2: Write the failing tests**

Create `functions/src/__tests__/departments.test.ts`:

```ts
import { departmentBlock, departmentBrief, DEPARTMENT_FOUNDATIONS, DEPARTMENT_NAMES } from "../departments";

describe("departmentBlock", () => {
  it("includes mandate, skills, the stage focus, and antipatterns for a known key+stage", () => {
    const b = departmentBlock("eng", "Prototype");
    expect(b).toContain("Mandate:");
    expect(b).toContain("Core skills:");
    expect(b).toContain(DEPARTMENT_FOUNDATIONS.eng.stageFocus["Prototype"]);
    expect(b).toContain("Avoid:");
  });
  it("omits the focus line for an unknown stage but still returns mandate", () => {
    const b = departmentBlock("eng", "NoSuchStage");
    expect(b).toContain("Mandate:");
    expect(b).not.toContain('Focus at the "NoSuchStage"');
  });
  it("returns empty string for an unknown department key", () => {
    expect(departmentBlock("bogus", "Prototype")).toBe("");
  });
});

describe("catalog shape", () => {
  it("has all 8 departments with names", () => {
    for (const k of ["eng", "design", "mkt", "sales", "support", "fin", "ops", "legal"]) {
      expect(DEPARTMENT_FOUNDATIONS[k]).toBeTruthy();
      expect(DEPARTMENT_NAMES[k]).toBeTruthy();
    }
  });
  it("departmentBrief fails open on null", () => {
    expect(departmentBrief(null)).toBe("");
    expect(departmentBrief("eng")).toContain("Mandate:");
  });
});
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd functions && npx jest departments.test.ts`
Expected: PASS (the port already implements `departmentBlock`/`departmentBrief`, so these pass immediately — this task is a verbatim port, verified by the tests). If any FAIL, the copy diverged from the source — re-copy verbatim.

- [ ] **Step 4: Commit**

```bash
git add functions/src/departments.ts functions/src/__tests__/departments.test.ts
git commit -m "feat: port DEPARTMENT_FOUNDATIONS catalog into functions repo

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Inject stage-grounding into `buildRoadmapPrompt`

**Files:**
- Modify: `functions/src/generateRoadmapCore.ts` (`buildRoadmapPrompt`)
- Test: `functions/src/__tests__/generateRoadmap.test.ts`

**Interfaces:**
- Consumes: `departmentBlock`, `DEPARTMENT_NAMES` (Task 1), existing `DEPT_KEYS`.
- Produces: `buildRoadmapPrompt` output now contains the grounding block; signature unchanged.

- [ ] **Step 1: Write the failing tests**

Add to `functions/src/__tests__/generateRoadmap.test.ts` inside the `describe("buildRoadmapPrompt", …)` block:

```ts
  it("injects department grounding with the stage focus", () => {
    const p = buildRoadmapPrompt({ language: "en", brief: { projectName: "Codepet", stage: "Prototype" } });
    expect(p).toContain("Engineering");                 // department name label
    expect(p).toContain("Mandate:");                    // grounding block present
    expect(p).toContain('Focus at the "Prototype" stage'); // stage-specific focus line
  });
  it("still builds (no throw) when stage is unknown/missing", () => {
    const p = buildRoadmapPrompt({ language: "en", brief: { projectName: "Codepet" } });
    expect(p).toContain("Mandate:");                    // grounding still present
    expect(p).not.toContain("Focus at the");            // no stage focus without a stage
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && npx jest generateRoadmap.test.ts -t "injects department grounding"`
Expected: FAIL — the current prompt has no "Mandate:"/grounding.

- [ ] **Step 3: Add the import**

At the top of `functions/src/generateRoadmapCore.ts` (after the file header comment, before the `ROADMAP_PHASES` const), add:

```ts
import { departmentBlock, DEPARTMENT_NAMES } from "./departments";
```

- [ ] **Step 4: Replace `buildRoadmapPrompt` with the grounded version**

Replace the whole `buildRoadmapPrompt` function with:

```ts
export function buildRoadmapPrompt(args: { language: string; brief: RoadmapBrief }): string {
  const { language, brief } = args;
  const stage = clip(brief?.stage, 40);
  const lines = [
    `Product: ${clip(brief?.projectName, 120) || "(unnamed)"}${brief?.oneLiner ? " — " + clip(brief.oneLiner, 300) : ""}`,
    brief?.summary ? `Summary: ${clip(brief.summary, 400)}` : null,
    brief?.audience ? `Audience: ${clip(brief.audience, 200)}` : null,
    stage ? `Stage: ${stage}` : null,
    Array.isArray(brief?.categories) && brief.categories.length
      ? `Categories: ${brief.categories.slice(0, 10).map((c) => clip(c, 40)).join(", ")}`
      : null,
  ].filter(Boolean);

  const grounding = Array.from(DEPT_KEYS)
    .map((k) => `- ${k} (${DEPARTMENT_NAMES[k] ?? k}):\n${departmentBlock(k, stage)}`)
    .join("\n\n");

  const vi = language === "vi"
    ? "\n\nWrite every task title and detail in natural, fluent Vietnamese."
    : "";

  return (
    "You are planning a solo founder's whole company roadmap, grounded ONLY in what the founder told you below — do not invent a different product, and do not invent facts they did not give you.\n\n" +
    lines.join("\n") +
    "\n\nDepartments (grounded for the founder's current stage — use these to choose each task's owning department and to keep every task stage-appropriate):\n\n" +
    grounding +
    "\n\nGenerate 2-4 concrete tasks for EACH of the six phases — find, foundation, build, ship, launch, grow — covering the founder's whole journey from validating the idea through launch and into running & growing the company. The 'grow' phase (shown to the founder as 'Run & Grow') is post-launch: retention, referrals, growth metrics, user-retention playbooks, content/distribution channels. " +
    "For each task give: a short imperative title, a 1-2 sentence detail, a `phase` (exactly one of find, foundation, build, ship, launch, grow), a `who` of exactly 'you' (needs the founder's own judgment, identity, or decisions), 'does' (the companion can produce it autonomously), or 'draft' (the companion drafts it and the founder finalizes), a `dept` — the single owning department, chosen using the department grounding above, exactly one of eng, design, mkt, sales, support, fin, ops, legal — and `deps`: the exact TITLES of any prerequisite tasks from this same list (an empty array if it's an entry point with no prerequisite). " +
    "CHAIN THE PHASES: only 'find'-phase tasks may have empty deps (they are the entry points). EVERY task in foundation, build, ship, launch, or grow MUST list at least one prerequisite from an EARLIER phase in its deps, so the roadmap is one connected chain and nothing in a later phase is workable before its earlier phases are done." +
    vi
  );
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd functions && npx jest generateRoadmap.test.ts`
Expected: the two new grounding tests PASS, and the pre-existing `buildRoadmapPrompt` tests (`"mentions the project and all five phases"`, `"adds a Vietnamese instruction only for vi"`, `"does not invent facts"`) STILL PASS (phases still listed; grounding-only stage line "Focus at the …" does not contain the word "Vietnamese"; "do not invent" still present).

- [ ] **Step 6: Commit**

```bash
git add functions/src/generateRoadmapCore.ts functions/src/__tests__/generateRoadmap.test.ts
git commit -m "feat: inject stage-grounded department block into roadmap prompt

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Leave invalid/missing dept unassigned instead of `ops`

**Files:**
- Modify: `functions/src/generateRoadmapCore.ts` (`coerceRoadmap`, the `dept` fallback ~line 128)
- Test: `functions/src/__tests__/generateRoadmap.test.ts` (update the existing ops test)

**Interfaces:**
- Consumes: nothing new.
- Produces: `coerceRoadmap` output tasks have `dept === ""` when the model's dept is invalid/missing (was `"ops"`).

- [ ] **Step 1: Update the existing test to the new contract**

In `functions/src/__tests__/generateRoadmap.test.ts`, find the test titled
`"keeps a valid dept and defaults an invalid/missing one to ops"` and replace it with:

```ts
  it("keeps a valid dept and leaves an invalid/missing one unassigned", () => {
    const out = coerceRoadmap({
      tasks: [
        { phase: "find", title: "A", detail: "", dept: "eng" },
        { phase: "find", title: "B", detail: "", dept: "not-a-dept" },
        { phase: "find", title: "C", detail: "" },
      ],
    });
    expect(out.tasks.find((t) => t.title === "A")!.dept).toBe("eng");
    expect(out.tasks.find((t) => t.title === "B")!.dept).toBe(""); // invalid → unassigned
    expect(out.tasks.find((t) => t.title === "C")!.dept).toBe(""); // missing → unassigned
  });
```

(Keep the exact input shape the original test used if it differs — only the two `toBe("ops")` expectations change to `toBe("")` and the title changes. Read the original test first and preserve its input tasks.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npx jest generateRoadmap.test.ts -t "leaves an invalid/missing one unassigned"`
Expected: FAIL — current code yields `"ops"`, test expects `""`.

- [ ] **Step 3: Change the fallback**

In `functions/src/generateRoadmapCore.ts`, in `coerceRoadmap`, change:

```ts
    const dept = typeof t.dept === "string" && DEPT_KEYS.has(t.dept) ? t.dept : "ops";
```

to:

```ts
    const dept = typeof t.dept === "string" && DEPT_KEYS.has(t.dept) ? t.dept : "";
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd functions && npx jest generateRoadmap.test.ts`
Expected: the updated ops→unassigned test PASSES; all other coerce/slug/phase tests still pass.

- [ ] **Step 5: Full functions test run**

Run: `cd functions && npm test`
Expected: entire Jest suite green (no regressions in other functions' tests).

- [ ] **Step 6: Verify native tolerates `""` dept (no code change)**

Read (do not edit) native `~/Documents/codepet-rebuild-wt/codepet/Models/Department.swift` (`find`, `summaries`), `codepet/Views/Tasks/TasksView.swift:88`, `codepet/Views/Overview/RoadmapMapView.swift:204`. Confirm each uses `DepartmentCatalog.find(dept)?.name` (nil-safe) or `dept == key` filters, so `""` shows no label and inflates no department. Note the confirmation in the commit body. If any site force-unwraps or renders `dept` raw, STOP and report — that would need a follow-up native task (out of this plan's scope).

- [ ] **Step 7: Commit**

```bash
git add functions/src/generateRoadmapCore.ts functions/src/__tests__/generateRoadmap.test.ts
git commit -m "fix: leave invalid/missing roadmap dept unassigned, not ops

Native verified nil-safe for empty dept (find()?.name / dept==key filters).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Post-implementation: Deploy (separate, user-confirmed)

NOT part of the subagent tasks. After the branch is reviewed and the user approves:

1. `firebase login --reauth` as `giang@murror.app` (interactive — user runs it).
2. Scoped deploy (off-iCloud temp per handoff to avoid the FS hang):
   `FUNCTIONS_DISCOVERY_TIMEOUT=180 firebase deploy --only functions:generateRoadmap --project devpet-8f4b1 --force`
3. Sanity: run native onboarding for a test brief; confirm Overview roadmap tasks carry sensible, varied departments (not all ops) and read stage-appropriately.

## Self-Review

**Spec coverage:**
- Spec Change 1 (port catalog + names) → Task 1. ✓
- Spec Change 2 (grounding in prompt) → Task 2. ✓
- Spec Change 3 (unassigned fallback) → Task 3. ✓
- Tests (departments, grounding-in-prompt, ops→unassigned) → Tasks 1/2/3. ✓
- Native verify-only → Task 3 Step 6. ✓
- Deploy gated on user confirmation → Post-implementation section (not a task). ✓
- Non-goals (active/dormant, dept-grouped, caching, native code) → absent from tasks. ✓

**Placeholder scan:** Task 1's catalog is a verbatim copy from a named source file (not a placeholder — the data is external and DRY-copied); all code changes in Tasks 2-3 show full code. No TBD/TODO.

**Type consistency:** `departmentBlock`/`DEPARTMENT_NAMES` defined in Task 1, imported+used in Task 2. `dept` stays `string` throughout (Task 3 uses `""`, not null). `DEPT_KEYS` reused from the existing module.
