import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

export const summarizeTurn = onRequest({ cors: false }, async (_req, res) => {
  res.status(501).json({ error: "not_implemented" });
});
