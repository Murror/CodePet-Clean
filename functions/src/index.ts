import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { handleSummarizeTurn } from "./summarizeTurn";
import { handleSummarizeSession } from "./summarizeSession";
import { handleChatSession } from "./chat";

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
