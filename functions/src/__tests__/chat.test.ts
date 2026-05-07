import { validateChatPayload } from "../chat";

describe("validateChatPayload", () => {
  const valid = {
    session_id: "s1",
    language: "vi",
    pet_persona: { id: "byte", name: "Byte", personality: "glitchy", domain: "Data" },
    session_context: {
      user_brief: "building a journal",
      summary: { summary: "We worked on X.", lesson: "Stay focused." },
      turns: [
        {
          prompt: "fix the layout",
          what_you_wanted: "you wanted",
          what_happened: "you did",
          lesson: "be patient",
          duration_minutes: 10,
          events: [{ time: "09:00", tool: "Edit", path: "foo.swift" }]
        }
      ]
    },
    history: [
      { role: "user", text: "hi" },
      { role: "pet", text: "hi back" }
    ],
    user_message: "what was the messy part?"
  };

  test("returns null for a valid payload", () => {
    expect(validateChatPayload(valid)).toBeNull();
  });

  test("rejects missing session_id", () => {
    const bad = { ...valid, session_id: "" };
    expect(validateChatPayload(bad)).toMatch(/session_id/);
  });

  test("rejects missing user_message", () => {
    const bad = { ...valid, user_message: "" };
    expect(validateChatPayload(bad)).toMatch(/user_message/);
  });

  test("rejects bad language", () => {
    const bad = { ...valid, language: "fr" };
    expect(validateChatPayload(bad)).toMatch(/language/);
  });

  test("rejects non-array turns", () => {
    const bad = { ...valid, session_context: { ...valid.session_context, turns: "x" as any } };
    expect(validateChatPayload(bad)).toMatch(/turns/);
  });

  test("rejects history > 20 messages", () => {
    const bad = {
      ...valid,
      history: Array.from({ length: 21 }, (_, i) => ({ role: "user" as const, text: `m${i}` }))
    };
    expect(validateChatPayload(bad)).toMatch(/history/);
  });

  test("rejects history with bad role", () => {
    const bad = { ...valid, history: [{ role: "assistant" as any, text: "x" }] };
    expect(validateChatPayload(bad)).toMatch(/role/);
  });

  test("rejects pet_persona missing fields", () => {
    const bad = { ...valid, pet_persona: { id: "byte" } as any };
    expect(validateChatPayload(bad)).toMatch(/pet_persona/);
  });

  test("accepts payload without optional fields", () => {
    const minimal = {
      session_id: "s1",
      language: "en",
      session_context: { turns: [{ prompt: "hi", events: [] }] },
      history: [],
      user_message: "what?"
    };
    expect(validateChatPayload(minimal)).toBeNull();
  });
});
