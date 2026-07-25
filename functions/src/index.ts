import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { handleSummarizeTurn } from "./summarizeTurn";
import { handleSummarizeSession } from "./summarizeSession";
import { handleChatSession } from "./chat";
import { handleGenerateGuidance } from "./generateGuidance";
import { handleGeneratePlan } from "./generatePlan";
import { handleSynthesizeBrief } from "./synthesizeBrief";
import { handleRevenueCatWebhook } from "./revenueCatWebhook";
import { handleExtractKnowledge } from "./extractKnowledge";
import { handleEnrichBrief } from "./enrichBrief";
import { handleScaffoldRoadmap } from "./scaffoldRoadmap";
import { handleCompanyChat } from "./companyChat";
import { handleGenerateRoadmap } from "./generateRoadmap";
import { handleRunTask } from "./runTask";
import { handleExtractDecisions } from "./extractDecisions";

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

// minInstances: 1 keeps a single warm container alive so the first
// summarize call after idle doesn't pay a 5–30s cold-start penalty.
// Cost: ~$5–8 / month per warm instance. Applied only to summarizeTurn —
// chatSession streams so cold start is masked, and summarizeSession fires
// less frequently.
export const summarizeTurn = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"],
    minInstances: 1
  },
  handleSummarizeTurn
);

export const summarizeSession = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleSummarizeSession
);

export const chatSession = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleChatSession
);

export const scaffoldRoadmap = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleScaffoldRoadmap
);

export const enrichBrief = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleEnrichBrief
);

export const companyChat = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleCompanyChat
);

export const runTask = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleRunTask
);

export const generateRoadmap = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleGenerateRoadmap
);

export const extractDecisions = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleExtractDecisions
);

export const generateGuidance = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleGenerateGuidance
);

export const generatePlan = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleGeneratePlan
);

export const synthesizeBrief = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleSynthesizeBrief
);

// RevenueCat -> Firestore entitlements bridge. No declared secret so it can
// deploy inert before RevenueCat is connected; reads REVENUECAT_WEBHOOK_TOKEN
// from env at runtime (rejects all requests until that is set).
export const revenueCatWebhook = onRequest(
  {
    cors: false
  },
  handleRevenueCatWebhook
);

export const extractKnowledge = onRequest(
  {
    cors: false,
    secrets: ["ANTHROPIC_API_KEY"]
  },
  handleExtractKnowledge
);
