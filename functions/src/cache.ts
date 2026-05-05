import * as admin from "firebase-admin";

export interface CachedNarrative {
  title: string;
  what_you_wanted: string;
  what_happened: string;
  lesson: string;
  model: string;
}

const TTL_DAYS = 7;
const TTL_MS = TTL_DAYS * 24 * 60 * 60 * 1000;

export function cacheKey(uid: string, turnId: string): string {
  return `${uid}__${turnId}`;
}

export function isCacheEntryFresh(generatedAt: Date, now: Date = new Date()): boolean {
  return now.getTime() - generatedAt.getTime() < TTL_MS;
}

export async function getCached(
  uid: string,
  turnId: string,
  now: Date = new Date()
): Promise<CachedNarrative | null> {
  const db = admin.firestore();
  const ref = db.collection("narratives_cache").doc(cacheKey(uid, turnId));
  const snap = await ref.get();
  if (!snap.exists) return null;
  const data = snap.data() as { narrative: CachedNarrative; generated_at: admin.firestore.Timestamp };
  if (!isCacheEntryFresh(data.generated_at.toDate(), now)) return null;
  return data.narrative;
}

export async function putCached(
  uid: string,
  turnId: string,
  narrative: CachedNarrative
): Promise<void> {
  const db = admin.firestore();
  const ref = db.collection("narratives_cache").doc(cacheKey(uid, turnId));
  await ref.set({
    narrative,
    generated_at: admin.firestore.Timestamp.now(),
    expires_at: admin.firestore.Timestamp.fromMillis(Date.now() + TTL_MS)
  });
}
