import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, logger, serverTs } from '../shared/utils';
import { UserRole } from '../shared/types';

const DEFAULT_GATEWAY_URL = 'http://localhost:8000';

async function requestSessionSummary(sessionId: string): Promise<{ summary: unknown }> {
  const sessionSnap = await db().collection('sessions').doc(sessionId).get();
  if (!sessionSnap.exists) {
    throw new Error(`Session ${sessionId} not found`);
  }
  const session = sessionSnap.data()!;

  const bookingId = (session['bookingId'] as string | undefined) ?? '';
  if (!bookingId) {
    throw new Error(`Session ${sessionId} missing bookingId`);
  }

  const bookingSnap = await db().collection('bookings').doc(bookingId).get();
  if (!bookingSnap.exists) {
    throw new Error(`Booking ${bookingId} not found for session ${sessionId}`);
  }
  const booking = bookingSnap.data()!;

  const gatewayBase = (process.env.AI_GATEWAY_URL ?? DEFAULT_GATEWAY_URL).replace(/\/$/, '');
  const url = `${gatewayBase}/session-summary`;

  const body = {
    session_id: sessionId,
    subject: (booking['subjectId'] as string | undefined) ?? 'unknown',
    grade_level: (booking['gradeLevel'] as string | undefined) ?? (booking['grade_level'] as string | undefined) ?? 'unknown',
    duration_minutes: (session['durationMinutes'] as number | undefined) ?? 60,
    tutor_notes: (session['tutorNotes'] as string | undefined) ?? '',
    session_chat_history: '',
    country: 'Sénégal',
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`AI Gateway ${response.status}: ${text}`);
  }

  const json = await response.json() as { summary?: unknown };
  if (!json.summary) {
    throw new Error('AI Gateway response missing summary');
  }
  return { summary: json.summary };
}

async function generateAndPersistSummary(sessionId: string): Promise<{ generated: boolean; summary?: unknown }> {
  const sessionRef = db().collection('sessions').doc(sessionId);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    throw new HttpsError('not-found', 'Session introuvable');
  }

  const session = sessionSnap.data()!;
  if (session['status'] !== 'completed') {
    return { generated: false };
  }
  if (session['aiSummary'] != null) {
    return { generated: false, summary: session['aiSummary'] };
  }

  const { summary } = await requestSessionSummary(sessionId);
  await sessionRef.update({
    aiSummary: summary,
    aiSummaryGeneratedAt: serverTs(),
    updatedAt: serverTs(),
  });

  return { generated: true, summary };
}

export const triggerSessionSummary = onDocumentUpdated(
  {
    document: 'sessions/{sessionId}',
    region: 'europe-west1',
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!after) {
      return;
    }

    const wasCompleted = before?.['status'] === 'completed';
    const isCompleted = after['status'] === 'completed';
    const hasSummary = after['aiSummary'] != null;

    if (!isCompleted || wasCompleted || hasSummary) {
      return;
    }

    try {
      const result = await generateAndPersistSummary(event.params.sessionId);
      logger.info('triggerSessionSummary.generated', {
        sessionId: event.params.sessionId,
        generated: result.generated,
      });
    } catch (error) {
      logger.error('triggerSessionSummary.failed', {
        sessionId: event.params.sessionId,
        error: String(error),
      });
    }
  },
);

export const generateSessionSummary = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const role = request.auth.token['role'] as UserRole | undefined;
    if (!role) {
      throw new HttpsError('permission-denied', 'Rôle manquant');
    }

    const sessionId = (request.data?.sessionId as string | undefined) ?? '';
    if (!sessionId) {
      throw new HttpsError('invalid-argument', 'sessionId requis');
    }

    const sessionSnap = await db().collection('sessions').doc(sessionId).get();
    if (!sessionSnap.exists) {
      throw new HttpsError('not-found', 'Session introuvable');
    }

    const session = sessionSnap.data()!;
    const callerId = request.auth.uid;
    const isParticipant = session['studentId'] === callerId || session['tutorId'] === callerId;
    const isStaff = role === 'academic_staff' || role === 'super_admin';
    if (!isParticipant && !isStaff) {
      throw new HttpsError('permission-denied', 'Accès interdit à cette session');
    }

    const result = await generateAndPersistSummary(sessionId);
    return {
      generated: result.generated,
      summary: result.summary ?? null,
    };
  },
);
