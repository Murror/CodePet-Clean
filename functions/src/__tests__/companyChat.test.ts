import { companionFor, buildSystemPrompt, buildMessages } from "../companyChatCore";

describe("companionFor", () => {
  it("returns the named companion for a known id", () => {
    expect(companionFor("luna").name).toBe("Luna");
    expect(companionFor("luna").voice).toMatch(/gentle|warm/i);
  });
  it("falls back to byte for an unknown id", () => {
    expect(companionFor("does-not-exist").name).toBe("Byte");
  });
  it("has all seven starters", () => {
    for (const id of ["byte", "nova", "crash", "luna", "sage", "glitch", "null"]) {
      expect(companionFor(id).name.length).toBeGreaterThan(0);
    }
  });
});

describe("buildSystemPrompt", () => {
  const base = { companionId: "luna", context: "Project: Acme. Next step: pricing page.", language: "en" };
  it("names the chosen companion and injects the context", () => {
    const s = buildSystemPrompt(base);
    expect(s).toContain("Luna");
    expect(s).toContain("Acme");
    expect(s).toContain("pricing page");
  });
  it("adds a Vietnamese instruction only for vi", () => {
    expect(buildSystemPrompt({ ...base, language: "vi" })).toMatch(/Vietnamese/i);
    expect(buildSystemPrompt(base)).not.toMatch(/Vietnamese/i);
  });
  it("falls back to byte for an unknown companion", () => {
    expect(buildSystemPrompt({ ...base, companionId: "zzz" })).toContain("Byte");
  });
});

describe("buildMessages", () => {
  it("maps roles and appends the new user message last", () => {
    const m = buildMessages(
      [{ role: "me", text: "hi" }, { role: "companion", text: "hey" }],
      "what next?",
    );
    expect(m).toEqual([
      { role: "user", content: "hi" },
      { role: "assistant", content: "hey" },
      { role: "user", content: "what next?" },
    ]);
  });
  it("drops a leading assistant/companion turn", () => {
    const m = buildMessages([{ role: "companion", text: "welcome" }], "hello");
    expect(m).toEqual([{ role: "user", content: "hello" }]);
  });
  it("coalesces consecutive same-role turns", () => {
    const m = buildMessages(
      [{ role: "me", text: "a" }, { role: "me", text: "b" }],
      "c",
    );
    // a+b (user) coalesced, then final user c coalesced too → one user block
    expect(m).toEqual([{ role: "user", content: "a\n\nb\n\nc" }]);
  });
  it("caps to the last 20 messages", () => {
    const hist = Array.from({ length: 40 }, (_, i) => ({
      role: i % 2 === 0 ? "me" : "companion",
      text: `t${i}`,
    }));
    const m = buildMessages(hist, "final");
    expect(m.length).toBeLessThanOrEqual(20);
    expect(m[m.length - 1]).toEqual({ role: "user", content: "final" });
  });
  it("handles empty history", () => {
    expect(buildMessages([], "only")).toEqual([{ role: "user", content: "only" }]);
  });
});
