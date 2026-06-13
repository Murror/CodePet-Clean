import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { handleSummarizeTurn } from "./summarizeTurn";
import { handleSummarizeSession } from "./summarizeSession";
import { handleChatSession } from "./chat";
import { handleGenerateGuidance } from "./generateGuidance";
import { handleGeneratePlan } from "./generatePlan";
import { handleRevenueCatWebhook } from "./revenueCatWebhook";
import { handleExtractKnowledge } from "./extractKnowledge";

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
