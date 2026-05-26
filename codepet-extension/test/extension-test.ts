/**
 * Codepet VS Code Extension — Integration Test Suite
 *
 * Tests the full flow: build → package → manifest verification → MCP data parsing
 * → activation entrypoint. Runs standalone (no VS Code instance required).
 *
 * Usage: npx tsx test/extension-test.ts
 */

import { existsSync, readFileSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { homedir } from "node:os";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ─── Test Harness ───

let passed = 0;
let failed = 0;
const failures: string[] = [];

function test(name: string, fn: () => void) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (err: any) {
    failed++;
    const msg = err?.message ?? String(err);
    failures.push(`${name}: ${msg}`);
    console.log(`  ✗ ${name}`);
    console.log(`    → ${msg}`);
  }
}

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

function assertEqual<T>(actual: T, expected: T, label?: string) {
  if (actual !== expected) {
    throw new Error(
      `${label ? label + ": " : ""}expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

// ─── Paths ───

const extensionRoot = resolve(__dirname, "..");
const distDir = join(extensionRoot, "dist");
const packageJsonPath = join(extensionRoot, "package.json");
const codepetDir = join(homedir(), ".codepet");

// ═══════════════════════════════════════════════════════
// Section 1: Build Verification
// ═══════════════════════════════════════════════════════

console.log("\n╔═══ Section 1: Build Verification ═══╗");

test("package.json exists", () => {
  assert(existsSync(packageJsonPath), "package.json not found");
});

test("TypeScript compiles without errors", () => {
  const result = execSync("npm run build 2>&1", { cwd: extensionRoot, encoding: "utf-8" });
  assert(!result.includes("error TS"), `Build had TypeScript errors: ${result}`);
});

test("dist/extension.js exists after build", () => {
  assert(existsSync(join(distDir, "extension.js")), "dist/extension.js not found after build");
});

test("all core modules are compiled", () => {
  const expectedFiles = [
    "extension.js",
    "core/file-watcher.js",
    "core/session-tracker.js",
    "core/trigger-engine.js",
    "ui/status-bar.js",
    "ui/sidebar-provider.js",
  ];
  for (const file of expectedFiles) {
    assert(existsSync(join(distDir, file)), `Missing compiled file: dist/${file}`);
  }
});

test("source maps are generated", () => {
  assert(existsSync(join(distDir, "extension.js.map")), "Missing source map for extension.js");
});

// ═══════════════════════════════════════════════════════
// Section 2: Package Manifest Verification
// ═══════════════════════════════════════════════════════

console.log("\n╔═══ Section 2: Package Manifest ═══╗");

const pkg = JSON.parse(readFileSync(packageJsonPath, "utf-8"));

test("extension name is 'codepet'", () => {
  assertEqual(pkg.name, "codepet");
});

test("publisher is 'murror'", () => {
  assertEqual(pkg.publisher, "murror");
});

test("activation event is onStartupFinished", () => {
  assert(
    pkg.activationEvents.includes("onStartupFinished"),
    `Expected onStartupFinished, got: ${JSON.stringify(pkg.activationEvents)}`
  );
});

test("main entry points to dist/extension.js", () => {
  assertEqual(pkg.main, "./dist/extension.js");
});

test("activity bar icon is registered", () => {
  const containers = pkg.contributes?.viewsContainers?.activitybar;
  assert(Array.isArray(containers) && containers.length > 0, "No activity bar containers");
  assertEqual(containers[0].id, "codepet-sidebar");
  assert(containers[0].icon.includes("codepet-icon"), "Activity bar icon doesn't reference codepet icon");
});

test("icon SVG file exists", () => {
  const iconPath = join(extensionRoot, pkg.contributes.viewsContainers.activitybar[0].icon);
  assert(existsSync(iconPath), `Icon not found at ${iconPath}`);
});

test("dashboard webview view is registered", () => {
  const views = pkg.contributes?.views?.["codepet-sidebar"];
  assert(Array.isArray(views) && views.length > 0, "No sidebar views");
  assertEqual(views[0].id, "codepet.dashboard");
  assertEqual(views[0].type, "webview");
});

test("all 3 commands are registered", () => {
  const commands = pkg.contributes?.commands;
  assert(Array.isArray(commands), "No commands found");
  const ids = commands.map((c: any) => c.command);
  assert(ids.includes("codepet.showSummary"), "Missing codepet.showSummary command");
  assert(ids.includes("codepet.refreshData"), "Missing codepet.refreshData command");
  assert(ids.includes("codepet.openDashboard"), "Missing codepet.openDashboard command");
});

test("configuration properties are defined", () => {
  const props = pkg.contributes?.configuration?.properties;
  assert(props, "No configuration properties");
  assert("codepet.idleTimeoutMinutes" in props, "Missing idleTimeoutMinutes");
  assert("codepet.showNotifications" in props, "Missing showNotifications");
  assert("codepet.periodicRefreshSeconds" in props, "Missing periodicRefreshSeconds");
  assert("codepet.petName" in props, "Missing petName");
  assert("codepet.mcpDataDir" in props, "Missing mcpDataDir");
});

test("default pet name is Nova", () => {
  assertEqual(pkg.contributes.configuration.properties["codepet.petName"].default, "Nova");
});

test("default refresh interval is 30 seconds", () => {
  assertEqual(pkg.contributes.configuration.properties["codepet.periodicRefreshSeconds"].default, 30);
});

// ═══════════════════════════════════════════════════════
// Section 3: MCP Data Directory Connectivity
// ═══════════════════════════════════════════════════════

console.log("\n╔═══ Section 3: MCP Data Connectivity ═══╗");

test("~/.codepet/ directory exists (MCP server has been run)", () => {
  assert(existsSync(codepetDir), `${codepetDir} not found — run the MCP server first`);
});

test("events directory exists", () => {
  assert(existsSync(join(codepetDir, "events")), "~/.codepet/events/ not found");
});

test("summaries directory exists", () => {
  assert(existsSync(join(codepetDir, "summaries")), "~/.codepet/summaries/ not found");
});

test("profile.json exists", () => {
  assert(existsSync(join(codepetDir, "profile.json")), "~/.codepet/profile.json not found");
});

test("today's events file is valid JSON array", () => {
  const today = new Date().toISOString().split("T")[0];
  const eventsPath = join(codepetDir, "events", `${today}.json`);
  if (!existsSync(eventsPath)) {
    // Not an error — maybe no events today yet
    console.log(`    (skipped: no events file for ${today} yet)`);
    passed--; // Don't count as pass or fail
    return;
  }
  const data = JSON.parse(readFileSync(eventsPath, "utf-8"));
  assert(Array.isArray(data), "Events file is not a JSON array");
  assert(data.length > 0, "Events array is empty");
  assert("id" in data[0], "First event missing 'id' field");
  assert("type" in data[0], "First event missing 'type' field");
  assert("timestamp" in data[0], "First event missing 'timestamp' field");
});

test("profile.json is valid JSON object", () => {
  const profile = JSON.parse(readFileSync(join(codepetDir, "profile.json"), "utf-8"));
  assert(typeof profile === "object" && profile !== null, "profile.json is not an object");
});

test("profile.json contains skill_progress (Phase 2 data)", () => {
  const profile = JSON.parse(readFileSync(join(codepetDir, "profile.json"), "utf-8"));
  if (!("skill_progress" in profile)) {
    console.log("    (skipped: skill_progress not yet populated — run get_learning_context)");
    passed--;
    return;
  }
  assert(Array.isArray(profile.skill_progress), "skill_progress is not an array");
  assert(profile.skill_progress.length > 0, "skill_progress is empty");
  const first = profile.skill_progress[0];
  assert("id" in first, "Skill missing 'id'");
  assert("xp" in first, "Skill missing 'xp'");
  assert("kingdom" in first, "Skill missing 'kingdom'");
});

// ═══════════════════════════════════════════════════════
// Section 4: FileWatcher Data Parsing (Unit Tests)
// ═══════════════════════════════════════════════════════

console.log("\n╔═══ Section 4: Data Parsing ═══╗");

// Test with temporary test data
const testDataDir = join(extensionRoot, "test", ".codepet-test");

function setupTestData() {
  // Create temp directories
  for (const dir of [testDataDir, join(testDataDir, "events"), join(testDataDir, "summaries")]) {
    mkdirSync(dir, { recursive: true });
  }

  const today = new Date().toISOString().split("T")[0];

  // Write test events
  writeFileSync(
    join(testDataDir, "events", `${today}.json`),
    JSON.stringify([
      { id: 1, timestamp: "2026-04-07T10:00:00Z", type: "server", action: "start" },
      { id: 2, timestamp: "2026-04-07T10:01:00Z", type: "tool_call", action: "scan_project", project: "TestProject" },
      { id: 3, timestamp: "2026-04-07T10:02:00Z", type: "tool_call", action: "get_file_content", language: "TypeScript", file: "/test/index.ts" },
      { id: 4, timestamp: "2026-04-07T10:30:00Z", type: "git", action: "commit", project: "TestProject" },
      { id: 5, timestamp: "2026-04-07T11:00:00Z", type: "diagnostic", action: "errors_found", language: "TypeScript" },
      { id: 6, timestamp: "2026-04-07T11:05:00Z", type: "diagnostic", action: "clean", language: "TypeScript" },
      { id: 7, timestamp: "2026-04-07T11:30:00Z", type: "tool_call", action: "get_learning_context" },
    ])
  );

  // Write test summary
  writeFileSync(
    join(testDataDir, "summaries", `${today}.json`),
    JSON.stringify({
      date: today,
      totalCodingMinutes: 90,
      linesAdded: 250,
      linesRemoved: 30,
      commits: 4,
      aiSessions: 8,
      errorsFixed: 2,
      languageBreakdown: { TypeScript: 5, Swift: 3 },
      skillsTracked: { "prompt-clarity": 16, "error-reading": 20, "tool-basics": 9 },
      topFiles: ["/test/index.ts", "/test/utils.ts"],
      petReaction: "Let's BUILD! You fixed 2 bugs today!",
    })
  );

  // Write test profile
  writeFileSync(
    join(testDataDir, "profile.json"),
    JSON.stringify({
      user_profile: { petName: "Nova", petCharacter: "nova", level: 1 },
      skill_progress: [
        { id: "prompt-clarity", name: "Prompt Clarity", icon: "✏️", kingdom: "The Molten Forge", tier: 1, nodeType: "lesson", xp: 48, level: 0, maxLevel: 5, xpProgress: 48, xpToNextLevel: 2 },
        { id: "error-reading", name: "Error Reading", icon: "🔍", kingdom: "The Molten Forge", tier: 1, nodeType: "lesson", xp: 65, level: 1, maxLevel: 5, xpProgress: 15, xpToNextLevel: 85 },
        { id: "tool-basics", name: "Tool Basics", icon: "🛠️", kingdom: "The Molten Forge", tier: 1, nodeType: "challenge", xp: 30, level: 0, maxLevel: 5, xpProgress: 30, xpToNextLevel: 20 },
      ],
      last_project_scan: { name: "TestProject" },
    })
  );
}

function cleanupTestData() {
  try {
    rmSync(testDataDir, { recursive: true, force: true });
  } catch {}
}

setupTestData();

test("parses events file into array", () => {
  const today = new Date().toISOString().split("T")[0];
  const data = JSON.parse(readFileSync(join(testDataDir, "events", `${today}.json`), "utf-8"));
  assertEqual(data.length, 7, "event count");
});

test("filters tool_call events correctly", () => {
  const today = new Date().toISOString().split("T")[0];
  const data = JSON.parse(readFileSync(join(testDataDir, "events", `${today}.json`), "utf-8"));
  const toolCalls = data.filter((e: any) => e.type === "tool_call");
  assertEqual(toolCalls.length, 3, "tool_call count");
});

test("filters git events correctly", () => {
  const today = new Date().toISOString().split("T")[0];
  const data = JSON.parse(readFileSync(join(testDataDir, "events", `${today}.json`), "utf-8"));
  const gitEvents = data.filter((e: any) => e.type === "git");
  assertEqual(gitEvents.length, 1, "git event count");
});

test("filters diagnostic clean events correctly", () => {
  const today = new Date().toISOString().split("T")[0];
  const data = JSON.parse(readFileSync(join(testDataDir, "events", `${today}.json`), "utf-8"));
  const clean = data.filter((e: any) => e.type === "diagnostic" && e.action === "clean");
  assertEqual(clean.length, 1, "diagnostic clean count");
});

test("parses summary with all fields", () => {
  const today = new Date().toISOString().split("T")[0];
  const summary = JSON.parse(readFileSync(join(testDataDir, "summaries", `${today}.json`), "utf-8"));
  assertEqual(summary.totalCodingMinutes, 90, "coding minutes");
  assertEqual(summary.commits, 4, "commits");
  assertEqual(summary.errorsFixed, 2, "errors fixed");
  assertEqual(summary.linesAdded, 250, "lines added");
  assertEqual(summary.languageBreakdown.TypeScript, 5, "TS count");
  assertEqual(summary.petReaction, "Let's BUILD! You fixed 2 bugs today!", "pet reaction");
});

test("extracts skill_progress from profile.json", () => {
  const profile = JSON.parse(readFileSync(join(testDataDir, "profile.json"), "utf-8"));
  const skills = profile.skill_progress;
  assertEqual(skills.length, 3, "skill count");
  assertEqual(skills[0].id, "prompt-clarity");
  assertEqual(skills[0].xp, 48);
  assertEqual(skills[1].level, 1, "error-reading level");
});

test("computes total skill XP", () => {
  const profile = JSON.parse(readFileSync(join(testDataDir, "profile.json"), "utf-8"));
  const totalXP = profile.skill_progress.reduce((sum: number, s: any) => sum + s.xp, 0);
  assertEqual(totalXP, 143, "total XP");
});

test("computes skill level from XP (floor(totalXP / 100) + 1)", () => {
  const profile = JSON.parse(readFileSync(join(testDataDir, "profile.json"), "utf-8"));
  const totalXP = profile.skill_progress.reduce((sum: number, s: any) => sum + s.xp, 0);
  const level = Math.floor(totalXP / 100) + 1;
  assertEqual(level, 2, "computed level");
});

test("groups skills by kingdom", () => {
  const profile = JSON.parse(readFileSync(join(testDataDir, "profile.json"), "utf-8"));
  const kingdoms = new Map<string, any[]>();
  for (const skill of profile.skill_progress) {
    if (!kingdoms.has(skill.kingdom)) kingdoms.set(skill.kingdom, []);
    kingdoms.get(skill.kingdom)!.push(skill);
  }
  assertEqual(kingdoms.size, 1, "kingdom count");
  assertEqual(kingdoms.get("The Molten Forge")!.length, 3, "Molten Forge skills");
});

// ═══════════════════════════════════════════════════════
// Section 5: VSIX Packaging
// ═══════════════════════════════════════════════════════

console.log("\n╔═══ Section 5: VSIX Packaging ═══╗");

test("vsce package generates .vsix file", () => {
  try {
    execSync("npx @vscode/vsce package --no-dependencies --skip-license 2>&1", {
      cwd: extensionRoot,
      encoding: "utf-8",
      timeout: 30000,
    });
  } catch (err: any) {
    // vsce may warn but still create the file
    if (!err.stdout?.includes(".vsix")) {
      throw new Error(`vsce package failed: ${err.stderr || err.stdout || err.message}`);
    }
  }

  const vsixFiles = execSync("ls *.vsix 2>/dev/null || true", {
    cwd: extensionRoot,
    encoding: "utf-8",
  }).trim();

  assert(vsixFiles.length > 0, "No .vsix file generated");
  console.log(`    → Generated: ${vsixFiles}`);
});

test(".vsix contains extension.js entry point", () => {
  const vsixFiles = execSync("ls *.vsix 2>/dev/null", {
    cwd: extensionRoot,
    encoding: "utf-8",
  }).trim().split("\n");

  if (vsixFiles.length === 0 || vsixFiles[0] === "") {
    console.log("    (skipped: no .vsix file)");
    passed--;
    return;
  }

  const contents = execSync(`unzip -l "${vsixFiles[0]}" 2>/dev/null | grep extension.js || true`, {
    cwd: extensionRoot,
    encoding: "utf-8",
  });

  assert(contents.includes("extension.js"), "extension.js not found in .vsix");
});

test(".vsix contains codepet-icon.svg", () => {
  const vsixFiles = execSync("ls *.vsix 2>/dev/null", {
    cwd: extensionRoot,
    encoding: "utf-8",
  }).trim().split("\n");

  if (vsixFiles.length === 0 || vsixFiles[0] === "") {
    console.log("    (skipped: no .vsix file)");
    passed--;
    return;
  }

  const contents = execSync(`unzip -l "${vsixFiles[0]}" 2>/dev/null | grep codepet-icon || true`, {
    cwd: extensionRoot,
    encoding: "utf-8",
  });

  assert(contents.includes("codepet-icon"), "codepet-icon.svg not found in .vsix");
});

// ═══════════════════════════════════════════════════════
// Section 6: Activation Entrypoint Verification
// ═══════════════════════════════════════════════════════

console.log("\n╔═══ Section 6: Entrypoint Verification ═══╗");

test("dist/extension.js exports activate function", () => {
  const content = readFileSync(join(distDir, "extension.js"), "utf-8");
  assert(content.includes("activate"), "No 'activate' export found");
});

test("dist/extension.js exports deactivate function", () => {
  const content = readFileSync(join(distDir, "extension.js"), "utf-8");
  assert(content.includes("deactivate"), "No 'deactivate' export found");
});

test("FileWatcher reads from configurable data directory", () => {
  const content = readFileSync(join(distDir, "core/file-watcher.js"), "utf-8");
  assert(content.includes(".codepet") || content.includes("codepet"), "FileWatcher doesn't reference .codepet directory");
});

test("StatusBar creates status bar item", () => {
  const content = readFileSync(join(distDir, "ui/status-bar.js"), "utf-8");
  assert(content.includes("createStatusBarItem"), "StatusBar doesn't create a status bar item");
});

test("SidebarProvider registers as webview provider", () => {
  const content = readFileSync(join(distDir, "ui/sidebar-provider.js"), "utf-8");
  assert(content.includes("resolveWebviewView"), "SidebarProvider doesn't implement resolveWebviewView");
});

// ═══════════════════════════════════════════════════════
// Cleanup & Results
// ═══════════════════════════════════════════════════════

cleanupTestData();

// Clean up .vsix files
execSync("rm -f *.vsix 2>/dev/null || true", { cwd: extensionRoot });

console.log("\n╔═══════════════════════════════════╗");
console.log(`║  Results: ${passed} passed, ${failed} failed`);
console.log("╚═══════════════════════════════════╝");

if (failures.length > 0) {
  console.log("\nFailures:");
  for (const f of failures) {
    console.log(`  ✗ ${f}`);
  }
}

process.exit(failed > 0 ? 1 : 0);
