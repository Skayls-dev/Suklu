import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions/v2';

// Lazy singletons — safe to call before admin.initializeApp() is called in
// index.ts because these only execute at function invocation time.
export const db   = () => admin.firestore();
export const auth = () => admin.auth();

export { logger };

// ─── Idempotency helpers ──────────────────────────────────────────────────────
// Prevents duplicate processing of webhook events.
// eventId is typically the provider's unique transaction / event ID.

export async function isEventProcessed(eventId: string): Promise<boolean> {
  const snap = await db()
    .collection('processed_events')
    .doc(eventId)
    .get();
  return snap.exists;
}

export async function markEventProcessed(
  tx: admin.firestore.Transaction,
  eventId: string,
  meta: Record<string, unknown>,
): Promise<void> {
  const ref = db().collection('processed_events').doc(eventId);
  tx.set(ref, {
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...meta,
  });
}

// ─── Typed server timestamp ────────────────────────────────────────────────────
export const serverTs = () => admin.firestore.FieldValue.serverTimestamp();
