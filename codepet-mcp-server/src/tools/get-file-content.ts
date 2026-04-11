/**
 * get_file_content — File Content Reader
 *
 * Reads file contents with language detection, line count, size info,
 * and optional line range selection. Useful for AI clients that need
 * to inspect specific files in context.
 *
 * Data captured → session logger:
 *   - File path and language
 *   - Lines read, total lines
 *   - File size
 */

import { z } from "zod";
import { readFile, stat } from "node:fs/promises";
import { extname, basename, resolve, relative } from "node:path";
import { existsSync } from "node:fs";
import type { SessionLogger } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

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
  ".c": "C",
  ".cpp": "C++",
  ".h": "C/C++ Header",
  ".cs": "C#",
  ".rb": "Ruby",
  ".php": "PHP",
  ".css": "CSS",
  ".scss": "SCSS",
  ".html": "HTML",
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
  ".graphql": "GraphQL",
  ".vue": "Vue",
  ".svelte": "Svelte",
  ".xml": "XML",
  ".proto": "Protocol Buffers",
};

// Max file size we'll read (1MB)
const MAX_FILE_SIZE = 1_048_576;

interface FileContent {
  path: string;
  relativePath?: string;
  filename: string;
  language: string;
  content: string;
  totalLines: number;
  linesReturned: { start: number; end: number };
  sizeBytes: number;
  lastModified: string;
}

export function registerGetFileContent(
  server: McpServer,
  logger: SessionLogger
): void {
  server.tool(
    "get_file_content",
    "Read a file's contents with language detection, line numbers, and metadata. Supports reading specific line ranges.",
    {
      path: z.string().describe("Absolute path to the file to read"),
      startLine: z
        .number()
        .int()
        .positive()
        .optional()
        .describe("First line to return (1-based, default: 1)"),
      endLine: z
        .number()
        .int()
        .positive()
        .optional()
        .describe("Last line to return (inclusive, default: end of file)"),
      projectRoot: z
        .string()
        .optional()
        .describe("Project root for computing relative path"),
    },
    async ({ path: filePath, startLine, endLine, projectRoot }) => {
      const absPath = resolve(filePath);

      if (!existsSync(absPath)) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ error: `File not found: ${absPath}` }),
            },
          ],
        };
      }

      // Check file size
      const fileStat = await stat(absPath);

      if (!fileStat.isFile()) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                error: `Not a file: ${absPath} (is a directory?)`,
              }),
            },
          ],
        };
      }

      if (fileStat.size > MAX_FILE_SIZE) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({
                error: `File too large: ${fileStat.size} bytes (max ${MAX_FILE_SIZE})`,
                path: absPath,
                sizeBytes: fileStat.size,
              }),
            },
          ],
        };
      }

      // Detect language
      const ext = extname(absPath).toLowerCase();
      const filename = basename(absPath);
      let language = EXTENSION_MAP[ext] ?? "Unknown";

      // Special filename-based detection
      if (filename === "Dockerfile") language = "Docker";
      else if (filename === "Makefile") language = "Make";
      else if (filename === "Podfile") language = "Ruby";
      else if (filename === "Gemfile") language = "Ruby";
      else if (filename === "Cargo.toml") language = "TOML (Rust)";
      else if (filename === "Package.swift") language = "Swift (SPM)";

      // Read content
      const raw = await readFile(absPath, "utf-8");
      const allLines = raw.split("\n");
      const totalLines = allLines.length;

      // Apply line range
      const start = Math.max(1, startLine ?? 1);
      const end = Math.min(totalLines, endLine ?? totalLines);
      const selectedLines = allLines.slice(start - 1, end);
      const content = selectedLines.join("\n");

      const result: FileContent = {
        path: absPath,
        relativePath: projectRoot
          ? relative(resolve(projectRoot), absPath)
          : undefined,
        filename,
        language,
        content,
        totalLines,
        linesReturned: { start, end },
        sizeBytes: fileStat.size,
        lastModified: fileStat.mtime.toISOString(),
      };

      // Log the event
      logger.logEvent({
        type: "tool_call",
        action: "get_file_content",
        file: absPath,
        language,
        metadata: {
          totalLines,
          linesRead: end - start + 1,
          sizeBytes: fileStat.size,
        },
      });

      return {
        content: [
          { type: "text" as const, text: JSON.stringify(result, null, 2) },
        ],
      };
    }
  );
}
