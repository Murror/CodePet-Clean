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
    "\n\nALWAYS write the markdown `body`. If (and only if) the kind you chose is checklist, doc, plan, or dms, ALSO fill `payload` with that kind's structured fields (leave `payload` empty for any other kind):\n" +
    "- checklist: Build a concrete setup/launch checklist — exactly 5-7 actionable steps in order (`items[].t`), each with `done` true only for obvious already-satisfied prerequisites.\n" +
    "- doc: `call` = the decision/recommendation in 1-2 sentences up front; `sections[]` = 2-5 labeled {h,p} reasoning blocks (why it's right, tradeoffs, what's out); `next[]` = 1-3 next actions.\n" +
    "- plan: an HONEST code-change plan — `goal` (one line), `steps[]` (3-5 ordered), `changes[]` = {area, edit} in plain terms (no fabricated file paths), `verify[]` (future-tense checks), `risks` (one line). Never claim it shipped.\n" +
    "- dms: exactly 4 personalized 1:1 outreach `messages[]` = {name (persona placeholder), note (why a strong target), msg (warm specific DM)}." +
    vi
  );
}

export interface Deliverable {
  kind: string;
  title: string;
  body: string;
  payload?: DeliverablePayload;
}

export interface ChecklistItem { t: string; done: boolean; }
export interface ChecklistPayload { items: ChecklistItem[]; }
export interface DocSection { h: string; p: string; }
export interface DocPayload { call: string; sections: DocSection[]; next: string[]; }
export interface PlanChange { area: string; edit: string; }
export interface PlanPayload { goal: string; steps: string[]; changes: PlanChange[]; verify: string[]; risks: string; }
export interface DmMessage { name: string; note: string; msg: string; }
export interface DmsPayload { messages: DmMessage[]; }
export type DeliverablePayload = ChecklistPayload | DocPayload | PlanPayload | DmsPayload;

const STRUCTURED_KINDS = new Set(["checklist", "doc", "plan", "dms"]);
const s = (v: unknown, n = 600) => (typeof v === "string" ? v.trim().slice(0, n) : "");
const strArr = (v: unknown, n = 12, len = 400): string[] =>
  Array.isArray(v) ? v.map((x) => s(x, len)).filter(Boolean).slice(0, n) : [];

/** Sanitize the raw payload for a kind; null if it lacks the kind's required content. */
export function coercePayload(kind: string, raw: unknown): DeliverablePayload | null {
  const r = (raw ?? {}) as Record<string, unknown>;
  if (kind === "checklist") {
    const items = (Array.isArray(r.items) ? r.items : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { t: s(o.t, 300), done: o.done === true }; })
      .filter((it) => it.t).slice(0, 7);
    return items.length ? { items } : null;
  }
  if (kind === "doc") {
    const call = s(r.call, 600);
    const sections = (Array.isArray(r.sections) ? r.sections : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { h: s(o.h, 120), p: s(o.p, 1200) }; })
      .filter((x) => x.h && x.p).slice(0, 6);
    const next = strArr(r.next, 3, 200);
    return call && sections.length ? { call, sections, next } : null;
  }
  if (kind === "plan") {
    const goal = s(r.goal, 300);
    const steps = strArr(r.steps, 6, 300);
    const changes = (Array.isArray(r.changes) ? r.changes : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { area: s(o.area, 120), edit: s(o.edit, 400) }; })
      .filter((x) => x.area && x.edit).slice(0, 8);
    const verify = strArr(r.verify, 6, 300);
    const risks = s(r.risks, 300);
    return goal && steps.length && changes.length ? { goal, steps, changes, verify, risks } : null;
  }
  if (kind === "dms") {
    const messages = (Array.isArray(r.messages) ? r.messages : [])
      .map((it) => { const o = (it ?? {}) as Record<string, unknown>; return { name: s(o.name, 80), note: s(o.note, 200), msg: s(o.msg, 1200) }; })
      .filter((x) => x.name && x.msg).slice(0, 4);
    return messages.length ? { messages } : null;
  }
  return null;
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

  if (STRUCTURED_KINDS.has(kind)) {
    const payload = coercePayload(kind, (raw as Record<string, unknown>)?.payload);
    if (payload) return { kind, title, body, payload };
  }
  return { kind, title, body };
}
