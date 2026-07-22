import { buildRunTaskPrompt, coerceDeliverable, DELIVERABLE_KINDS } from "../runTaskCore";

describe("buildRunTaskPrompt", () => {
  const base = {
    companionId: "luna",
    language: "en",
    context: "Project: Acme. Stage: build.",
    taskTitle: "Write the pricing page copy",
    taskDetail: "Three tiers, monthly billing.",
  };

  it("names the chosen companion", () => {
    expect(buildRunTaskPrompt(base)).toContain("Luna");
  });

  it("includes the founder's context, task title, and task detail", () => {
    const p = buildRunTaskPrompt(base);
    expect(p).toContain("Acme");
    expect(p).toContain("Write the pricing page copy");
    expect(p).toContain("Three tiers, monthly billing.");
  });

  it("falls back to byte for an unknown companion", () => {
    expect(buildRunTaskPrompt({ ...base, companionId: "zzz" })).toContain("Byte");
  });

  it("adds a Vietnamese instruction only for vi", () => {
    expect(buildRunTaskPrompt({ ...base, language: "vi" })).toMatch(/Vietnamese/i);
    expect(buildRunTaskPrompt(base)).not.toMatch(/Vietnamese/i);
  });

  it("falls back to a general note when context is empty", () => {
    expect(buildRunTaskPrompt({ ...base, context: "" })).toMatch(/hasn't filled in much/i);
  });
});

describe("coerceDeliverable", () => {
  it("accepts a valid kind/title/body", () => {
    const d = coerceDeliverable({ kind: "post", title: "Launch post", body: "Hello world" }, "fallback title");
    expect(d).toEqual({ kind: "post", title: "Launch post", body: "Hello world" });
  });

  it("defaults an unknown kind to doc", () => {
    const d = coerceDeliverable({ kind: "not-a-kind", title: "t", body: "b" }, "fallback title");
    expect(d?.kind).toBe("doc");
  });

  it("requires a non-empty body — returns null when empty", () => {
    expect(coerceDeliverable({ kind: "doc", title: "t", body: "" }, "fallback title")).toBeNull();
    expect(coerceDeliverable({ kind: "doc", title: "t", body: "   " }, "fallback title")).toBeNull();
    expect(coerceDeliverable(null, "fallback title")).toBeNull();
  });

  it("falls back title -> taskTitle when title is missing", () => {
    const d = coerceDeliverable({ kind: "doc", body: "content" }, "fallback title");
    expect(d?.title).toBe("fallback title");
  });

  it("covers every allowed kind in DELIVERABLE_KINDS", () => {
    for (const kind of DELIVERABLE_KINDS) {
      const d = coerceDeliverable({ kind, title: "t", body: "b" }, "fallback");
      expect(d?.kind).toBe(kind);
    }
  });
});
