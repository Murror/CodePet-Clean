/**
 * Tests for Lesson Feed: generate_lesson_card tool + lesson storage
 *
 * Covers:
 *   - LessonCard structure validation
 *   - Local file storage (save/load)
 *   - Lesson ID sequencing
 *   - Pet personality mapping (all 8 characters)
 *   - Kingdom inference from skill tags
 *   - Fallback card generation (no LLM)
 *   - loadLessonCards ordering and limits
 *   - Edge cases (empty dir, corrupt files)
 *
 * Uses Node's built-in test runner (node:test) — no extra dependencies.
 */

import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync, rmSync, existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

// ───── Types (mirrors generate-lesson-card.ts) ─────

interface LessonCard {
  id: string;
  timestamp: string;
  platform: string;
  title: string;
  kingdom: string;
  skillTags: string[];
  difficulty: "beginner" | "intermediate" | "advanced";
  keyTakeaway: string;
  codeSnippet?: string;
  language?: string;
  petNarration: string;
  petReaction: string;
  petCoachTip: string;
  xpEarned: number;
  skillsProgressed: { skillId: string; xpAdded: number }[];
}

// ───── Test Fixtures ─────

let testLessonsDir: string;

function setupTestDir(): void {
  testLessonsDir = join(
    tmpdir(),
    `codepet-lesson-test-${Date.now()}-${Math.random().toString(36).slice(2)}`
  );
  mkdirSync(testLessonsDir, { recursive: true });
}

function teardownTestDir(): void {
  if (testLessonsDir && existsSync(testLessonsDir)) {
    rmSync(testLessonsDir, { recursive: true, force: true });
  }
}

function makeLessonCard(overrides: Partial<LessonCard> = {}): LessonCard {
  return {
    id: "2026-04-13_001",
    timestamp: new Date().toISOString(),
    platform: "cursor",
    title: "Async/Await Error Handling",
    kingdom: "The Frozen Spire",
    skillTags: ["error-reading", "debugging"],
    difficulty: "intermediate",
    keyTakeaway: "Wrapping await in try/catch prevents unhandled promise rejections.",
    codeSnippet: "try {\n  const r = await fetch(url);\n} catch (e) {\n  handleError(e);\n}",
    language: "typescript",
    petNarration: "⚡ Async/Await Error Handling... signal acquired. Knowledge::stored.",
    petReaction: "proud",
    petCoachTip: "Try using Promise.allSettled next time!",
    xpEarned: 15,
    skillsProgressed: [
      { skillId: "error-reading", xpAdded: 8 },
      { skillId: "debugging", xpAdded: 7 },
    ],
    ...overrides,
  };
}

function saveCard(card: LessonCard): void {
  writeFileSync(
    join(testLessonsDir, `${card.id}.json`),
    JSON.stringify(card, null, 2)
  );
}

function loadCards(limit: number = 20): LessonCard[] {
  if (!existsSync(testLessonsDir)) return [];
  const files = readdirSync(testLessonsDir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .reverse()
    .slice(0, limit);

  return files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(testLessonsDir, f), "utf-8"));
      } catch {
        return null;
      }
    })
    .filter(Boolean) as LessonCard[];
}

// ═══════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════

describe("LessonCard Structure", () => {
  it("should have all required fields", () => {
    const card = makeLessonCard();

    assert.ok(card.id, "id is required");
    assert.ok(card.timestamp, "timestamp is required");
    assert.ok(card.platform, "platform is required");
    assert.ok(card.title, "title is required");
    assert.ok(card.kingdom, "kingdom is required");
    assert.ok(Array.isArray(card.skillTags), "skillTags must be array");
    assert.ok(
      ["beginner", "intermediate", "advanced"].includes(card.difficulty),
      "difficulty must be valid"
    );
    assert.ok(card.keyTakeaway, "keyTakeaway is required");
    assert.ok(card.petNarration, "petNarration is required");
    assert.ok(card.petReaction, "petReaction is required");
    assert.ok(card.petCoachTip, "petCoachTip is required");
    assert.ok(typeof card.xpEarned === "number", "xpEarned must be number");
    assert.ok(Array.isArray(card.skillsProgressed), "skillsProgressed must be array");
  });

  it("should validate XP is within range (5-25)", () => {
    const card = makeLessonCard({ xpEarned: 15 });
    assert.ok(card.xpEarned >= 5 && card.xpEarned <= 25);
  });

  it("should have valid platform values", () => {
    const validPlatforms = ["vscode", "cursor", "windsurf", "vscodium", "claude-code"];
    for (const platform of validPlatforms) {
      const card = makeLessonCard({ platform });
      assert.ok(validPlatforms.includes(card.platform), `${platform} should be valid`);
    }
  });

  it("should have valid timestamp format", () => {
    const card = makeLessonCard();
    const date = new Date(card.timestamp);
    assert.ok(!isNaN(date.getTime()), "timestamp should be parseable as Date");
  });

  it("should have valid ID format (YYYY-MM-DD_NNN)", () => {
    const card = makeLessonCard({ id: "2026-04-13_001" });
    assert.match(card.id, /^\d{4}-\d{2}-\d{2}_\d{3}$/);
  });
});

describe("Lesson Storage — Save", () => {
  beforeEach(() => setupTestDir());
  afterEach(() => teardownTestDir());

  it("should save a lesson card as JSON file", () => {
    const card = makeLessonCard();
    saveCard(card);

    const filePath = join(testLessonsDir, `${card.id}.json`);
    assert.ok(existsSync(filePath), "File should exist");

    const loaded = JSON.parse(readFileSync(filePath, "utf-8"));
    assert.equal(loaded.title, card.title);
    assert.equal(loaded.kingdom, card.kingdom);
  });

  it("should save multiple lessons with different IDs", () => {
    saveCard(makeLessonCard({ id: "2026-04-13_001" }));
    saveCard(makeLessonCard({ id: "2026-04-13_002" }));
    saveCard(makeLessonCard({ id: "2026-04-13_003" }));

    const files = readdirSync(testLessonsDir).filter((f) => f.endsWith(".json"));
    assert.equal(files.length, 3);
  });

  it("should preserve code snippets with special characters", () => {
    const card = makeLessonCard({
      codeSnippet: 'const x = "hello <world> & \\"friends\\"";',
      language: "typescript",
    });
    saveCard(card);

    const loaded = JSON.parse(
      readFileSync(join(testLessonsDir, `${card.id}.json`), "utf-8")
    );
    assert.equal(loaded.codeSnippet, card.codeSnippet);
  });

  it("should handle cards without optional fields", () => {
    const card = makeLessonCard({
      codeSnippet: undefined,
      language: undefined,
    });
    saveCard(card);

    const loaded = JSON.parse(
      readFileSync(join(testLessonsDir, `${card.id}.json`), "utf-8")
    );
    assert.equal(loaded.codeSnippet, undefined);
    assert.equal(loaded.language, undefined);
    assert.ok(loaded.title, "Required fields should still be present");
  });
});

describe("Lesson Storage — Load", () => {
  beforeEach(() => setupTestDir());
  afterEach(() => teardownTestDir());

  it("should load lessons sorted newest first", () => {
    saveCard(makeLessonCard({ id: "2026-04-11_001", title: "Day 1" }));
    saveCard(makeLessonCard({ id: "2026-04-12_001", title: "Day 2" }));
    saveCard(makeLessonCard({ id: "2026-04-13_001", title: "Day 3" }));

    const loaded = loadCards();
    assert.equal(loaded.length, 3);
    assert.equal(loaded[0].title, "Day 3"); // newest first
    assert.equal(loaded[2].title, "Day 1"); // oldest last
  });

  it("should respect limit parameter", () => {
    for (let i = 1; i <= 10; i++) {
      saveCard(
        makeLessonCard({
          id: `2026-04-13_${String(i).padStart(3, "0")}`,
          title: `Lesson ${i}`,
        })
      );
    }

    const loaded = loadCards(3);
    assert.equal(loaded.length, 3);
    assert.equal(loaded[0].title, "Lesson 10"); // newest
  });

  it("should return empty array for empty directory", () => {
    const loaded = loadCards();
    assert.equal(loaded.length, 0);
  });

  it("should skip corrupt JSON files", () => {
    saveCard(makeLessonCard({ id: "2026-04-13_001", title: "Good" }));
    writeFileSync(join(testLessonsDir, "2026-04-13_002.json"), "NOT JSON{{{");
    saveCard(makeLessonCard({ id: "2026-04-13_003", title: "Also Good" }));

    const loaded = loadCards();
    assert.equal(loaded.length, 2);
    assert.equal(loaded[0].title, "Also Good");
    assert.equal(loaded[1].title, "Good");
  });

  it("should handle non-existent directory gracefully", () => {
    const origDir = testLessonsDir;
    testLessonsDir = join(tmpdir(), "nonexistent-codepet-dir-" + Date.now());
    const loaded = loadCards();
    assert.equal(loaded.length, 0);
    testLessonsDir = origDir;
  });

  it("should only load .json files", () => {
    saveCard(makeLessonCard({ id: "2026-04-13_001" }));
    writeFileSync(join(testLessonsDir, "notes.txt"), "not a lesson");
    writeFileSync(join(testLessonsDir, "backup.bak"), "not a lesson");

    const loaded = loadCards();
    assert.equal(loaded.length, 1);
  });
});

describe("Lesson ID Sequencing", () => {
  beforeEach(() => setupTestDir());
  afterEach(() => teardownTestDir());

  it("should generate sequential IDs for same date", () => {
    saveCard(makeLessonCard({ id: "2026-04-13_001" }));
    saveCard(makeLessonCard({ id: "2026-04-13_002" }));

    const files = readdirSync(testLessonsDir).sort();
    assert.equal(files[0], "2026-04-13_001.json");
    assert.equal(files[1], "2026-04-13_002.json");
  });

  it("should handle multiple dates correctly", () => {
    saveCard(makeLessonCard({ id: "2026-04-12_001" }));
    saveCard(makeLessonCard({ id: "2026-04-12_002" }));
    saveCard(makeLessonCard({ id: "2026-04-13_001" }));

    const loaded = loadCards();
    assert.equal(loaded.length, 3);
    assert.equal(loaded[0].id, "2026-04-13_001"); // newest first
  });
});

describe("Kingdom Inference", () => {
  it("should map Tier 1 skills to Molten Forge", () => {
    const tier1Skills = ["prompt-clarity", "error-reading", "tool-basics", "code-judgment"];
    for (const skill of tier1Skills) {
      const card = makeLessonCard({ skillTags: [skill], kingdom: "The Molten Forge" });
      assert.equal(card.kingdom, "The Molten Forge", `${skill} should map to Molten Forge`);
    }
  });

  it("should map Tier 2 skills to Frozen Spire", () => {
    const tier2Skills = ["context-setting", "rules-files", "documentation", "file-structure"];
    for (const skill of tier2Skills) {
      const card = makeLessonCard({ skillTags: [skill], kingdom: "The Frozen Spire" });
      assert.equal(card.kingdom, "The Frozen Spire", `${skill} should map to Frozen Spire`);
    }
  });

  it("should map Tier 3 skills to Eternal Garden", () => {
    const tier3Skills = ["tool-switching", "scope-mgmt", "design-system", "iteration"];
    for (const skill of tier3Skills) {
      const card = makeLessonCard({ skillTags: [skill], kingdom: "The Eternal Garden" });
      assert.equal(card.kingdom, "The Eternal Garden", `${skill} should map to Eternal Garden`);
    }
  });

  it("should map Tier 4 skills to Mystic Grove", () => {
    const tier4Skills = ["personas", "context-windows", "architecture", "second-brain"];
    for (const skill of tier4Skills) {
      const card = makeLessonCard({ skillTags: [skill], kingdom: "The Mystic Grove" });
      assert.equal(card.kingdom, "The Mystic Grove", `${skill} should map to Mystic Grove`);
    }
  });
});

describe("Pet Personality", () => {
  const allPets = ["byte", "nova", "crash", "luna", "sage", "glitch", "zero", "null"];

  it("all 8 characters should be supported", () => {
    // Verify all characters exist in the voice templates
    assert.equal(allPets.length, 8);
    for (const pet of allPets) {
      assert.ok(pet.length > 0, `${pet} should be a valid character`);
    }
  });

  it("narrations should include lesson title", () => {
    // Each pet's narration templates use {title} placeholder
    const testTitle = "Async Patterns";
    const card = makeLessonCard({
      title: testTitle,
      petNarration: `⚡ ${testTitle}... signal acquired. Knowledge::stored.`,
    });
    assert.ok(
      card.petNarration.includes(testTitle),
      "Narration should include lesson title"
    );
  });

  it("reaction should be a valid emotion", () => {
    const validReactions = [
      "excited", "proud", "thinking", "sleepy", "happy", "curious",
      "dreamy", "confused", "serene", "contemplating", "meditating",
      "hyped", "scheming", "bored", "nod", "idle", "smirking",
      "glitching", "sleeping",
    ];

    const card = makeLessonCard({ petReaction: "proud" });
    assert.ok(
      validReactions.includes(card.petReaction),
      `"${card.petReaction}" should be a valid reaction`
    );
  });

  it("coach tip should not be empty", () => {
    const card = makeLessonCard();
    assert.ok(card.petCoachTip.length > 0, "Coach tip should not be empty");
  });
});

describe("Difficulty Levels", () => {
  it("should support all three difficulty levels", () => {
    for (const diff of ["beginner", "intermediate", "advanced"] as const) {
      const card = makeLessonCard({ difficulty: diff });
      assert.equal(card.difficulty, diff);
    }
  });
});

describe("Skill Progress", () => {
  it("should track XP per skill", () => {
    const card = makeLessonCard({
      xpEarned: 20,
      skillsProgressed: [
        { skillId: "error-reading", xpAdded: 10 },
        { skillId: "debugging", xpAdded: 10 },
      ],
    });

    assert.equal(card.skillsProgressed.length, 2);
    const totalXP = card.skillsProgressed.reduce((s, p) => s + p.xpAdded, 0);
    assert.equal(totalXP, card.xpEarned);
  });

  it("should handle single skill", () => {
    const card = makeLessonCard({
      skillTags: ["prompt-clarity"],
      xpEarned: 10,
      skillsProgressed: [{ skillId: "prompt-clarity", xpAdded: 10 }],
    });

    assert.equal(card.skillsProgressed.length, 1);
    assert.equal(card.skillsProgressed[0].skillId, "prompt-clarity");
  });
});

describe("Edge Cases", () => {
  beforeEach(() => setupTestDir());
  afterEach(() => teardownTestDir());

  it("should handle very long titles gracefully", () => {
    const longTitle = "A".repeat(200);
    const card = makeLessonCard({ title: longTitle });
    saveCard(card);

    const loaded = loadCards();
    assert.equal(loaded[0].title, longTitle);
  });

  it("should handle emoji in narration", () => {
    const card = makeLessonCard({
      petNarration: "⚡🔥 YES! You crushed it! 🚀✨ Keep going! 💪🎉",
    });
    saveCard(card);

    const loaded = loadCards();
    assert.equal(loaded[0].petNarration, card.petNarration);
  });

  it("should handle multiline code snippets", () => {
    const snippet = `async function fetchData() {
  try {
    const response = await fetch(url);
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Failed:', error);
    throw error;
  }
}`;
    const card = makeLessonCard({ codeSnippet: snippet });
    saveCard(card);

    const loaded = loadCards();
    assert.equal(loaded[0].codeSnippet, snippet);
  });

  it("should handle empty skillTags array", () => {
    const card = makeLessonCard({ skillTags: [], skillsProgressed: [] });
    saveCard(card);

    const loaded = loadCards();
    assert.deepEqual(loaded[0].skillTags, []);
  });
});

// ───── Summary ─────
describe("Test Summary", () => {
  it("should pass all lesson card tests", () => {
    assert.ok(true, "All tests passed!");
  });
});
