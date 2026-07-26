import { companionFor, buildSystemPrompt, buildContextBlock, buildMessages } from "../companyChatCore";

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
  const base = { companionId: "luna", language: "en" };
  it("names the chosen companion", () => {
    expect(buildSystemPrompt(base)).toContain("Luna");
  });
  it("adds a Vietnamese instruction only for vi", () => {
    expect(buildSystemPrompt({ ...base, language: "vi" })).toMatch(/Vietnamese/i);
    expect(buildSystemPrompt(base)).not.toMatch(/Vietnamese/i);
  });
  it("falls back to byte for an unknown companion", () => {
    expect(buildSystemPrompt({ ...base, companionId: "zzz" })).toContain("Byte");
  });
  it("keeps the per-request context OUT of the cacheable block", () => {
    // The founder's company grounding must live in a separate (uncached) block.
    expect(buildSystemPrompt(base)).not.toMatch(/The founder's company:/);
  });
});

describe("buildContextBlock", () => {
  it("includes the provided context", () => {
    const b = buildContextBlock("Project: Acme. Next step: pricing page.");
    expect(b).toContain("Acme");
    expect(b).toContain("pricing page");
  });
  it("falls back to a general note when context is empty", () => {
    expect(buildContextBlock("")).toMatch(/brief yet/i);
  });
  it("starts with a blank-line separator (system blocks concatenate with no gap)", () => {
    expect(buildContextBlock("x").startsWith("\n\n")).toBe(true);
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

// ─── handleCompanyChat handler ──────────────────────────────────────────────
// Mirrors chat.test.ts's harness: mocked auth/rateLimit modules, a fake Express
// `res`, and (for the streaming path) an injected fake stream factory standing
// in for the Anthropic call. The JSON path calls the real `client().messages.create`
// wiring, so the Anthropic SDK itself is mocked at module level for those cases.

jest.mock("../auth", () => ({
  verifyAuth: jest.fn(async (header: string | undefined) => {
    if (header === "Bearer good") return { uid: "user1" };
    return null;
  }),
  extractBearerToken: (h: string | undefined) => (h?.startsWith("Bearer ") ? h.slice(7) : null)
}));

jest.mock("../rateLimit", () => ({
  checkAndIncrement: jest.fn(async (uid: string) => ({
    allowed: uid !== "capped",
    resetAt: new Date("2026-05-08T00:00:00Z"),
    limit: 50
  }))
}));

const mockMessagesCreate = jest.fn(async () => ({
  content: [{ type: "text", text: "Hello founder." }],
  usage: { input_tokens: 10, output_tokens: 5 }
}));

jest.mock("@anthropic-ai/sdk", () => {
  return jest.fn().mockImplementation(() => ({
    messages: {
      create: mockMessagesCreate,
      // Only reached if a test forgets to inject a stream factory — fail loudly
      // rather than making a real network call.
      stream: jest.fn(() => {
        throw new Error("real Anthropic stream() called in test — inject a stream factory");
      })
    }
  }));
});

function makeReq(overrides: any = {}): any {
  return {
    method: "POST",
    headers: { authorization: "Bearer good" },
    body: {
      language: "en",
      companion_id: "byte",
      context: "Project: Acme.",
      history: [],
      user_message: "what next?"
    },
    ...overrides
  };
}

function makeRes() {
  const headers: Record<string, string> = {};
  const writes: string[] = [];
  let ended = false;
  return {
    headers,
    writes,
    ended: () => ended,
    setHeader(k: string, v: string) { headers[k] = v; },
    status(code: number) { (this as any).statusCode = code; return this; },
    json(obj: any) { writes.push(JSON.stringify(obj)); ended = true; (this as any).statusCode = (this as any).statusCode || 200; },
    write(chunk: string) { writes.push(chunk); return true; },
    end() { ended = true; },
    flushHeaders() { /* noop */ }
  };
}

describe("handleCompanyChat", () => {
  let handleCompanyChat: typeof import("../companyChat").handleCompanyChat;
  let __setStreamFactoryForTests: typeof import("../companyChat").__setStreamFactoryForTests;
  let __resetStreamFactoryForTests: typeof import("../companyChat").__resetStreamFactoryForTests;

  beforeAll(() => {
    process.env.ANTHROPIC_API_KEY = "test-key";
    // Require after the module-level mocks above are registered.
    ({ handleCompanyChat, __setStreamFactoryForTests, __resetStreamFactoryForTests } = require("../companyChat"));
  });

  beforeEach(() => {
    __resetStreamFactoryForTests();
    mockMessagesCreate.mockClear();
  });

  test("rejects non-POST methods", async () => {
    const req = makeReq({ method: "GET" });
    const res = makeRes();
    await handleCompanyChat(req as any, res as any);
    expect((res as any).statusCode).toBe(405);
  });

  test("returns 401 for missing auth", async () => {
    const req = makeReq({ headers: { authorization: undefined } });
    const res = makeRes();
    await handleCompanyChat(req as any, res as any);
    expect((res as any).statusCode).toBe(401);
  });

  test("returns 400 for missing user_message", async () => {
    const req = makeReq({ body: { ...makeReq().body, user_message: "" } });
    const res = makeRes();
    await handleCompanyChat(req as any, res as any);
    expect((res as any).statusCode).toBe(400);
  });

  // ── Non-streaming JSON path (no Accept header) — unchanged ────────────────

  describe("JSON path (no Accept: text/event-stream)", () => {
    test("returns {reply, run_task_id} on success", async () => {
      const req = makeReq();
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);

      expect((res as any).statusCode).toBe(200);
      expect(mockMessagesCreate).toHaveBeenCalledTimes(1);
      const body = JSON.parse((res as any).writes[0]);
      expect(body).toEqual({ reply: "Hello founder.", run_task_id: null });
    });

    test("returns 429 when rate-limited (before any Anthropic call)", async () => {
      const rl = require("../rateLimit");
      rl.checkAndIncrement.mockImplementationOnce(async () => ({
        allowed: false,
        resetAt: new Date("2026-05-08T00:00:00Z"),
        limit: 50
      }));
      const req = makeReq();
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);
      expect((res as any).statusCode).toBe(429);
      expect(mockMessagesCreate).not.toHaveBeenCalled();
    });

    test("returns 502 when the Anthropic call fails", async () => {
      mockMessagesCreate.mockImplementationOnce(async () => {
        throw new Error("upstream down");
      });
      const req = makeReq();
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);
      expect((res as any).statusCode).toBe(502);
    });
  });

  // ── Streaming path (Accept: text/event-stream) — new, opt-in ──────────────

  describe("SSE path (Accept: text/event-stream)", () => {
    function makeStreamingReq(overrides: any = {}): any {
      return makeReq({
        headers: { authorization: "Bearer good", accept: "text/event-stream" },
        ...overrides
      });
    }

    test("streams delta frames and a final done frame, matching chat.ts's format", async () => {
      __setStreamFactoryForTests(async function* () {
        yield { type: "text", text: "Here's " };
        yield { type: "text", text: "the plan." };
        yield {
          type: "done",
          usage: { cache_read_input_tokens: 10, input_tokens: 5, output_tokens: 5 }
        };
      });

      const req = makeStreamingReq();
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);

      expect((res as any).headers["Content-Type"]).toBe("text/event-stream");
      expect(mockMessagesCreate).not.toHaveBeenCalled(); // streaming path never touches the JSON call

      const body = (res as any).writes.join("");
      expect(body).toContain('event: delta\ndata: {"text":"Here\'s "}');
      expect(body).toContain('event: delta\ndata: {"text":"the plan."}');
      expect(body).toContain('event: done');
      expect(body).toContain('"cache_hit":true');
      expect(body).toContain('"model":"claude-sonnet-5"');
      expect((res as any).ended()).toBe(true);
    });

    test("mid-stream failure emits an error frame (headers already sent)", async () => {
      __setStreamFactoryForTests(async function* () {
        yield { type: "text", text: "Here's " };
        throw new Error("upstream blew up");
      });

      const req = makeStreamingReq();
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);

      const body = (res as any).writes.join("");
      expect(body).toContain('event: delta\ndata: {"text":"Here\'s "}');
      expect(body).toContain('event: error');
      expect((res as any).statusCode).toBe(200); // headers already sent — SSE convention from chat.ts
    });

    test("pre-stream auth failure returns a plain 401 JSON error, not an SSE frame", async () => {
      const req = makeStreamingReq({ headers: { authorization: undefined, accept: "text/event-stream" } });
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);

      expect((res as any).statusCode).toBe(401);
      expect((res as any).headers["Content-Type"]).toBeUndefined();
      const body = JSON.parse((res as any).writes[0]);
      expect(body).toEqual({ error: "invalid_token" });
    });

    test("pre-stream rate-limit failure returns a plain 429 JSON error, not an SSE frame", async () => {
      const rl = require("../rateLimit");
      rl.checkAndIncrement.mockImplementationOnce(async () => ({
        allowed: false,
        resetAt: new Date("2026-05-08T00:00:00Z"),
        limit: 50
      }));
      const req = makeStreamingReq();
      const res = makeRes();
      await handleCompanyChat(req as any, res as any);

      expect((res as any).statusCode).toBe(429);
      expect((res as any).headers["Content-Type"]).toBeUndefined();
      const body = JSON.parse((res as any).writes[0]);
      expect(body.error).toBe("daily_limit_reached");
    });
  });
});
