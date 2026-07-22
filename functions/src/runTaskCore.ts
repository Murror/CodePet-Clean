// Pure logic for the runTask CF — no firebase/express/anthropic imports, so it can be
// unit-tested (and verified) without loading the heavy Cloud-Functions module tree.
// The IO handler lives in runTask.ts and imports from here.

import { companionFor } from "./companyChatCore";

// Mirrors native `DeliverableKind`. Keep in sync with codepet/Models — this is the
// contract the Swift client decodes `kind` against.
export const DELIVERABLE_KINDS = new Set([
  "doc",
  "post",
  "email",
  "legal",
  "screens",
  "sheet",
  "site",
  "dms",
  "calendar",
  "checklist",
  "plan",
  "text",
  "other",
]);

const clip = (v: unknown, n: number) => (typeof v === "string" ? v.trim().slice(0, n) : "");

export interface RunTaskArgs {
  companionId: string;
  language: string;
  context: string;
  taskTitle: string;
  taskDetail: string;
}

/** Build the companion-voiced generation prompt for a single roadmap task. */
export function buildRunTaskPrompt(args: RunTaskArgs): string {
  const c = companionFor(args.companionId);
  const context = clip(args.context, 4000);
  const taskTitle = clip(args.taskTitle, 200);
  const taskDetail = clip(args.taskDetail, 1000);
  const kindsList = Array.from(DELIVERABLE_KINDS).join(", ");
  const vi = args.language === "vi" ? "\n\nWrite the title and body in natural, fluent Vietnamese." : "";

  return (
    `You are ${c.name}, the AI building companion inside Codepet — a senior operator who does real work for a solo founder, department by department.\n\n` +
    `Voice: ${c.voice}\n\n` +
    `The founder's company:\n${context || "The founder hasn't filled in much of a brief yet — keep the deliverable general but still genuinely useful."}\n\n` +
    `Task to complete: ${taskTitle || "(untitled task)"}\n` +
    (taskDetail ? `Task detail: ${taskDetail}\n` : "") +
    `\nProduce the REAL deliverable for this task — not a plan to do it, not a description of what you would do, the actual finished artifact (the document, the copy, the checklist, the email, whatever the task calls for), written as markdown in the body. Pick whichever "kind" best fits what you produced from this exact list: ${kindsList}. Give it a short, clear title. Ground everything in the founder's actual company context above — do not invent facts about them.` +
    vi
  );
}

export interface Deliverable {
  kind: string;
  title: string;
  body: string;
}

/** Validate + coerce the model's raw tool input into a safe deliverable, or null if unusable. */
export function coerceDeliverable(raw: unknown, taskTitle: string): Deliverable | null {
  const r = (raw ?? {}) as Record<string, unknown>;
  const body = typeof r.body === "string" ? r.body.trim() : "";
  if (!body) return null;

  const rawKind = typeof r.kind === "string" ? r.kind.trim() : "";
  const kind = DELIVERABLE_KINDS.has(rawKind) ? rawKind : "doc";

  const rawTitle = typeof r.title === "string" ? r.title.trim() : "";
  const title = rawTitle || clip(taskTitle, 200) || "Untitled deliverable";

  return { kind, title, body };
}
