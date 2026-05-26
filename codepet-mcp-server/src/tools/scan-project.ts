/**
 * scan_project — Project Fingerprinting Tool
 *
 * Walks the project tree (respecting .gitignore), detects languages,
 * frameworks, structure, and returns a project fingerprint.
 *
 * Data captured → session logger:
 *   - Project name and root path
 *   - Detected languages and percentages
 *   - Frameworks and dependencies
 *   - File count and structure depth
 */

import { z } from "zod";
import { readdir, stat, readFile } from "node:fs/promises";
import { join, extname, basename, resolve } from "node:path";
import { existsSync } from "node:fs";
import type { SessionLogger } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

// Language detection by file extension
const EXTENSION_MAP: Record<string, string> = {
  ".swift": "Swift",
  ".ts": "TypeScript",
  ".tsx": "TypeScript (React)",
  ".js": "JavaScript",
  ".jsx": "JavaScript (React)",
  ".py": "Python",
  ".rs": "Rust",
  ".go": "Go",
  ".java": "Java",
  ".kt": "Kotlin",
  ".rb": "Ruby",
  ".php": "PHP",
  ".c": "C",
  ".cpp": "C++",
  ".h": "C/C++ Header",
  ".cs": "C#",
  ".html": "HTML",
  ".css": "CSS",
  ".scss": "SCSS",
  ".json": "JSON",
  ".yaml": "YAML",
  ".yml": "YAML",
  ".toml": "TOML",
  ".md": "Markdown",
  ".sql": "SQL",
  ".sh": "Shell",
  ".zsh": "Shell",
  ".bash": "Shell",
  ".dockerfile": "Docker",
  ".proto": "Protocol Buffers",
  ".graphql": "GraphQL",
  ".vue": "Vue",
  ".svelte": "Svelte",
};

// Framework detection patterns
const FRAMEWORK_SIGNATURES: Array<{ name: string; files: string[]; deps?: string[] }> = [
  { name: "SwiftUI", files: ["*.swift"], deps: [] },
  { name: "Firebase", files: ["GoogleService-Info.plist"], deps: ["firebase", "FirebaseAuth"] },
  { name: "React", files: [], deps: ["react", "react-dom"] },
  { name: "Next.js", files: ["next.config.js", "next.config.ts", "next.config.mjs"], deps: ["next"] },
  { name: "Vue", files: [], deps: ["vue"] },
  { name: "Svelte", files: ["svelte.config.js"], deps: ["svelte"] },
  { name: "Express", files: [], deps: ["express"] },
  { name: "FastAPI", files: [], deps: ["fastapi"] },
  { name: "Django", files: ["manage.py"], deps: ["django"] },
  { name: "Tailwind CSS", files: ["tailwind.config.js", "tailwind.config.ts"], deps: ["tailwindcss"] },
  { name: "Docker", files: ["Dockerfile", "docker-compose.yml", "docker-compose.yaml"], deps: [] },
];

// Directories to always skip
const SKIP_DIRS = new Set([
  "node_modules", ".git", ".svn", ".hg", "dist", "build", ".build",
  "__pycache__", ".pytest_cache", ".next", ".nuxt", ".output",
  "target", "Pods", "DerivedData", ".swiftpm", "vendor",
  ".venv", "venv", "env", ".tox", "coverage", ".nyc_output",
]);

interface ProjectFingerprint {
  name: string;
  rootPath: string;
  languages: Array<{ language: string; files: number; percentage: number }>;
  frameworks: string[];
  structure: {
    totalFiles: number;
    totalDirs: number;
    maxDepth: number;
    topLevelEntries: string[];
  };
  dependencies: {
    packageManager?: string;
    count: number;
  };
  buildSystem?: string;
}

async function walkDir(
  dir: string,
  depth: number,
  maxDepth: number,
  langCounts: Map<string, number>,
  stats: { files: number; dirs: number; maxDepth: number }
): Promise<void> {
  if (depth > maxDepth) return;

  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return; // Permission denied or other access error
  }

  for (const entry of entries) {
    if (entry.name.startsWith(".") && entry.name !== ".env.example") continue;

    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      stats.dirs++;
      stats.maxDepth = Math.max(stats.maxDepth, depth + 1);
      await walkDir(join(dir, entry.name), depth + 1, maxDepth, langCounts, stats);
    } else if (entry.isFile()) {
      stats.files++;
      const ext = extname(entry.name).toLowerCase();
      const lang = EXTENSION_MAP[ext];
      if (lang) {
        langCounts.set(lang, (langCounts.get(lang) ?? 0) + 1);
      }
    }
  }
}

async function detectFrameworks(rootPath: string): Promise<string[]> {
  const detected: string[] = [];

  // Check for dependency files to scan
  const depFiles: Record<string, string[]> = {};

  // package.json (Node.js)
  const pkgPath = join(rootPath, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(await readFile(pkgPath, "utf-8"));
      const allDeps = [
        ...Object.keys(pkg.dependencies ?? {}),
        ...Object.keys(pkg.devDependencies ?? {}),
      ];
      depFiles["npm"] = allDeps;
    } catch {
      // Malformed package.json
    }
  }

  // Check each framework signature
  for (const fw of FRAMEWORK_SIGNATURES) {
    // Check by file existence
    for (const file of fw.files) {
      if (!file.includes("*") && existsSync(join(rootPath, file))) {
        if (!detected.includes(fw.name)) detected.push(fw.name);
        break;
      }
    }

    // Check by dependency name
    if (fw.deps && fw.deps.length > 0) {
      for (const [, deps] of Object.entries(depFiles)) {
        if (fw.deps.some((d) => deps.includes(d))) {
          if (!detected.includes(fw.name)) detected.push(fw.name);
          break;
        }
      }
    }
  }

  // SwiftUI special detection: look for "import SwiftUI" in Swift files
  if (!detected.includes("SwiftUI")) {
    const swiftFiles = join(rootPath, "**/*.swift");
    // Simple heuristic: check if Package.swift or .xcodeproj exists
    const hasXcode =
      existsSync(join(rootPath, "Package.swift")) ||
      (await readdir(rootPath).then((entries) =>
        entries.some((e) => e.endsWith(".xcodeproj") || e.endsWith(".xcworkspace"))
      ));
    if (hasXcode) {
      detected.push("Xcode");
    }
  }

  return detected;
}

async function detectBuildSystem(rootPath: string): Promise<string | undefined> {
  const checks: Array<[string, string]> = [
    ["Makefile", "Make"],
    ["CMakeLists.txt", "CMake"],
    ["build.gradle", "Gradle"],
    ["build.gradle.kts", "Gradle (Kotlin)"],
    ["pom.xml", "Maven"],
    ["Cargo.toml", "Cargo"],
    ["go.mod", "Go Modules"],
    ["Package.swift", "Swift Package Manager"],
    ["Gemfile", "Bundler"],
    ["pyproject.toml", "Python (pyproject)"],
    ["setup.py", "Python (setuptools)"],
  ];

  for (const [file, name] of checks) {
    if (existsSync(join(rootPath, file))) return name;
  }

  // Check for Xcode project
  try {
    const entries = await readdir(rootPath);
    if (entries.some((e) => e.endsWith(".xcodeproj"))) return "Xcode";
  } catch {
    // Ignore
  }

  if (existsSync(join(rootPath, "package.json"))) return "npm";
  return undefined;
}

export function registerScanProject(server: McpServer, logger: SessionLogger): void {
  server.tool(
    "scan_project",
    "Scan a project directory to detect languages, frameworks, structure, and dependencies. Returns a project fingerprint used for context-aware coding assistance and skill tracking.",
    {
      path: z
        .string()
        .describe("Absolute path to the project root directory"),
      maxDepth: z
        .number()
        .optional()
        .default(6)
        .describe("Maximum directory depth to scan (default: 6)"),
    },
    async ({ path: projectPath, maxDepth }) => {
      const rootPath = resolve(projectPath);

      if (!existsSync(rootPath)) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ error: `Path does not exist: ${rootPath}` }),
            },
          ],
        };
      }

      // Walk the directory tree
      const langCounts = new Map<string, number>();
      const stats = { files: 0, dirs: 0, maxDepth: 0 };
      await walkDir(rootPath, 0, maxDepth ?? 6, langCounts, stats);

      // Build language breakdown
      const totalLangFiles = Array.from(langCounts.values()).reduce((a, b) => a + b, 0);
      const languages = Array.from(langCounts.entries())
        .map(([language, files]) => ({
          language,
          files,
          percentage: totalLangFiles > 0 ? Math.round((files / totalLangFiles) * 100) : 0,
        }))
        .sort((a, b) => b.files - a.files);

      // Detect frameworks
      const frameworks = await detectFrameworks(rootPath);

      // Detect build system
      const buildSystem = await detectBuildSystem(rootPath);

      // Get top-level entries
      let topLevelEntries: string[] = [];
      try {
        topLevelEntries = (await readdir(rootPath))
          .filter((e) => !e.startsWith(".") || e === ".gitignore")
          .slice(0, 20);
      } catch {
        // Ignore
      }

      // Detect package manager and dependency count
      let packageManager: string | undefined;
      let depCount = 0;

      if (existsSync(join(rootPath, "package-lock.json"))) packageManager = "npm";
      else if (existsSync(join(rootPath, "yarn.lock"))) packageManager = "yarn";
      else if (existsSync(join(rootPath, "pnpm-lock.yaml"))) packageManager = "pnpm";
      else if (existsSync(join(rootPath, "bun.lockb"))) packageManager = "bun";

      if (existsSync(join(rootPath, "package.json"))) {
        try {
          const pkg = JSON.parse(await readFile(join(rootPath, "package.json"), "utf-8"));
          depCount =
            Object.keys(pkg.dependencies ?? {}).length +
            Object.keys(pkg.devDependencies ?? {}).length;
        } catch {
          // Ignore
        }
      }

      const fingerprint: ProjectFingerprint = {
        name: basename(rootPath),
        rootPath,
        languages,
        frameworks,
        structure: {
          totalFiles: stats.files,
          totalDirs: stats.dirs,
          maxDepth: stats.maxDepth,
          topLevelEntries,
        },
        dependencies: {
          packageManager,
          count: depCount,
        },
        buildSystem,
      };

      // Log to session logger
      logger.logEvent({
        type: "tool_call",
        action: "scan_project",
        project: fingerprint.name,
        language: languages[0]?.language,
        metadata: {
          totalFiles: stats.files,
          languages: languages.map((l) => l.language),
          frameworks,
        },
      });

      // Cache project summary for resource endpoint
      logger.setProfileValue("last_project_scan", fingerprint);

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(fingerprint, null, 2),
          },
        ],
      };
    }
  );
}
