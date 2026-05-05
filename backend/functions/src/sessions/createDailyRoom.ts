import { onCall, HttpsError } from 'firebase-functions/v2/https';
import axios from 'axios';
import { db, serverTs, logger } from '../shared/utils';
import { getPlatformConfig } from '../config/platformConfig';
import { UserRole } from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// createDailyRoom — Callable (tutor | academic_staff | super_admin)
//
// Provisions a Daily.co video room for a booking and writes the room URL to
// the session document.
//
// Room modes (configured in /platform_config/global.roomMode):
//   ephemeral  — unique room per booking, expires 1 hour after scheduled end.
//                Best for privacy (room is gone after use).
//   persistent — one room per tutor, name = tutorId. Created once, reused.
//                Best for tutors with regular weekly students (same link).
// ─────────────────────────────────────────────────────────────────────────────
export const createDailyRoom = onCall(
  { secrets: ['DAILY_API_KEY'] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerRole = request.auth.token['role'] as UserRole | undefined;
    if (callerRole !== 'tutor' && callerRole !== 'academic_staff' && callerRole !== 'super_admin') {
      throw new HttpsError('permission-denied', 'Réservé aux tuteurs');
    }

    const { bookingId } = request.data as { bookingId: string };
    if (!bookingId) {
      throw new HttpsError('invalid-argument', 'bookingId requis');
    }

    // ── Validate booking ────────────────────────────────────────────────────
    const bookingSnap = await db().collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Réservation introuvable');
    }
    const booking = bookingSnap.data()!;
    if (booking['tutorId'] !== request.auth.uid && callerRole !== 'super_admin') {
      throw new HttpsError('permission-denied', 'Vous n\'êtes pas le tuteur de cette session');
    }
    if (booking['status'] !== 'confirmed') {
      throw new HttpsError('failed-precondition', 'La réservation doit être confirmée avant de créer une salle');
    }

    // ── Load platform config ────────────────────────────────────────────────
    const config    = await getPlatformConfig();
    const roomMode  = config.roomMode;
    const dailyKey  = process.env.DAILY_API_KEY!;
    const tutorId   = booking['tutorId'] as string;

    // ── Check if session already has a room ─────────────────────────────────
    const sessionSnap = await db()
      .collection('sessions')
      .where('bookingId', '==', bookingId)
      .limit(1)
      .get();

    if (!sessionSnap.empty && sessionSnap.docs[0].data()['roomUrl']) {
      return { roomUrl: sessionSnap.docs[0].data()['roomUrl'] };
    }

    // ── Provision Daily.co room ─────────────────────────────────────────────
    let roomUrl: string;
    const scheduledAt = booking['scheduledAt'];
    const durationMin = booking['durationMinutes'] as number;

    // Expiry = scheduled time + duration + 30 min grace period
    const expTs = Math.floor(
      (scheduledAt.toDate().getTime() + (durationMin + 30) * 60 * 1000) / 1000,
    );

    if (roomMode === 'persistent') {
      // Try to get existing room; create if not found
      const roomName = `tutor-${tutorId}`;
      try {
        const getRes = await axios.get(
          `https://api.daily.co/v1/rooms/${roomName}`,
          { headers: { Authorization: `Bearer ${dailyKey}` } },
        );
        roomUrl = getRes.data.url as string;
        logger.info('createDailyRoom: reusing persistent room', { roomName });
      } catch {
        const createRes = await axios.post(
          'https://api.daily.co/v1/rooms',
          {
            name:       roomName,
            privacy:    'private',
            properties: { enable_chat: true, enable_screenshare: true },
          },
          { headers: { Authorization: `Bearer ${dailyKey}`, 'Content-Type': 'application/json' } },
        );
        roomUrl = createRes.data.url as string;
        logger.info('createDailyRoom: created persistent room', { roomName });
      }
    } else {
      // ephemeral: new room per booking
      const createRes = await axios.post(
        'https://api.daily.co/v1/rooms',
        {
          privacy:    'private',
          properties: {
            exp:                expTs,
            enable_chat:        true,
            enable_screenshare: true,
            enable_recording:   'cloud',
          },
        },
        { headers: { Authorization: `Bearer ${dailyKey}`, 'Content-Type': 'application/json' } },
      );
      roomUrl = createRes.data.url as string;
      logger.info('createDailyRoom: created ephemeral room', { bookingId });
    }

    // ── Create or update session document ───────────────────────────────────
    const sessionRef = sessionSnap.empty
      ? db().collection('sessions').doc()
      : sessionSnap.docs[0].ref;

    await sessionRef.set({
      id:         sessionRef.id,
      bookingId,
      studentId:  booking['studentId'],
      tutorId,
      roomUrl,
      roomMode,
      scheduledAt: booking['scheduledAt'],
      durationMinutes: durationMin,
      status:     'scheduled',
      createdAt:  serverTs(),
      updatedAt:  serverTs(),
    }, { merge: true });

    logger.info('createDailyRoom: session document updated', {
      sessionId: sessionRef.id, roomUrl, roomMode,
    });

    return { roomUrl, sessionId: sessionRef.id };
  },
);
