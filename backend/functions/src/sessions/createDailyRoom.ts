import { onCall, HttpsError } from 'firebase-functions/v2/https';
import axios from 'axios';
import { db, serverTs, logger } from '../shared/utils';
import { getPlatformConfig } from '../config/platformConfig';
import { UserRole } from '../shared/types';

async function ensureTutorStudentLink(params: {
  tutorId: string;
  studentId: string;
  bookingId: string;
  sessionId: string;
}): Promise<void> {
  const { tutorId, studentId, bookingId, sessionId } = params;
  const linkId = `${tutorId}_${studentId}`;

  await db().collection('tutor_student_links').doc(linkId).set({
    id: linkId,
    tutorId,
    studentId,
    bookingIds:     [bookingId],
    sessionIds:     [sessionId],
    createdAt:      serverTs(),
    updatedAt:      serverTs(),
    lastBookingId:  bookingId,
    lastSessionId:  sessionId,
  }, { merge: true });
}

function extractRoomName(roomUrl: string): string {
  const cleanUrl = roomUrl.split('?')[0];
  const parsed = new URL(cleanUrl);
  const segments = parsed.pathname.split('/').filter(Boolean);
  if (segments.length === 0) {
    throw new Error('Invalid Daily room URL');
  }
  return segments[segments.length - 1];
}

async function buildJoinUrl(roomUrl: string, dailyKey: string): Promise<string> {
  const roomName = extractRoomName(roomUrl);
  const tokenExp = Math.floor(Date.now() / 1000) + 4 * 60 * 60;

  const tokenRes = await axios.post(
    'https://api.daily.co/v1/meeting-tokens',
    {
      properties: {
        room_name: roomName,
        exp: tokenExp,
      },
    },
    { headers: { Authorization: `Bearer ${dailyKey}`, 'Content-Type': 'application/json' } },
  );

  const token = tokenRes.data.token as string;
  return `${roomUrl.split('?')[0]}?t=${encodeURIComponent(token)}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// createDailyRoom — Callable
//
// - Tutor/admin can create the room if it does not exist yet.
// - Tutor and student can request a fresh join URL (tokenized) when a room exists.
//
// Room modes (configured in /platform_config/global.roomMode):
//   ephemeral  — unique room per booking, expires 1 hour after scheduled end.
//                Best for privacy (room is gone after use).
//   persistent — one room per tutor, name = tutorId. Created once, reused.
//                Best for tutors with regular weekly students (same link).
// ─────────────────────────────────────────────────────────────────────────────
export const createDailyRoom = onCall(
  { secrets: ['DAILY_API_KEY'], cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerRole = request.auth.token['role'] as UserRole | undefined;
    const isTutorSide =
      callerRole === 'tutor' || callerRole === 'academic_staff' || callerRole === 'super_admin';
    const isStudentSide = callerRole === 'student';

    const { bookingId } = request.data as { bookingId: string };
    if (!bookingId) {
      throw new HttpsError('invalid-argument', 'bookingId requis');
    }

    logger.info('createDailyRoom: called', {
      callerUid: request.auth.uid,
      callerRole,
      bookingId,
      isTutorSide,
      isStudentSide,
    });

    // ── Validate booking ────────────────────────────────────────────────────
    const bookingSnap = await db().collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) {
      logger.warn('createDailyRoom: booking not found', { bookingId });
      throw new HttpsError('not-found', 'Réservation introuvable');
    }
    const booking = bookingSnap.data()!;
    const isBookingTutor = booking['tutorId'] === request.auth.uid;
    const isBookingStudent = booking['studentId'] === request.auth.uid;

    logger.info('createDailyRoom: booking found', {
      bookingId,
      status: booking['status'],
      tutorId: booking['tutorId'],
      studentId: booking['studentId'],
      isBookingTutor,
      isBookingStudent,
    });

    if (!isTutorSide && !isStudentSide) {
      logger.warn('createDailyRoom: role denied', { callerRole });
      throw new HttpsError('permission-denied', 'Rôle non autorisé pour cette session');
    }

    if (callerRole === 'super_admin') {
      // allowed
    } else if (isTutorSide && !isBookingTutor) {
      logger.warn('createDailyRoom: not booking tutor', { callerUid: request.auth.uid, tutorId: booking['tutorId'] });
      throw new HttpsError('permission-denied', 'Vous n\'êtes pas le tuteur de cette session');
    } else if (isStudentSide && !isBookingStudent) {
      logger.warn('createDailyRoom: not booking student', { callerUid: request.auth.uid, studentId: booking['studentId'] });
      throw new HttpsError('permission-denied', 'Vous n\'êtes pas l\'étudiant de cette session');
    }

    if (booking['status'] !== 'confirmed') {
      logger.warn('createDailyRoom: booking not confirmed', { bookingId, status: booking['status'] });
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
      const existingRoomUrl = sessionSnap.docs[0].data()['roomUrl'] as string;
      await ensureTutorStudentLink({
        tutorId,
        studentId: booking['studentId'] as string,
        bookingId,
        sessionId: sessionSnap.docs[0].id,
      });
      const joinUrl = await buildJoinUrl(existingRoomUrl, dailyKey);

      return {
        roomUrl: joinUrl,
        sessionId: sessionSnap.docs[0].id,
      };
    }

    if (!isTutorSide) {
      throw new HttpsError(
        'failed-precondition',
        'La salle n\'est pas encore créée. Le tuteur doit d\'abord créer la salle.',
      );
    }

    // ── Provision Daily.co room ─────────────────────────────────────────────
    let roomUrl: string;
    const scheduledAt = booking['scheduledAt'];
    const durationMin = booking['durationMinutes'] as number;

    // Expiry must be in the future for Daily.co.
    // For old or delayed sessions, fallback to now-based expiry.
    const nowMs       = Date.now();
    const scheduledMs = scheduledAt?.toDate?.().getTime?.() ?? nowMs;
    const baseStartMs = Math.max(nowMs, scheduledMs);
    const expTs       = Math.floor(
      (baseStartMs + (durationMin + 30) * 60 * 1000) / 1000,
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

    const joinUrl = await buildJoinUrl(roomUrl, dailyKey);

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

    await ensureTutorStudentLink({
      tutorId,
      studentId: booking['studentId'] as string,
      bookingId,
      sessionId: sessionRef.id,
    });

    logger.info('createDailyRoom: session document updated', {
      sessionId: sessionRef.id, roomUrl, roomMode,
    });

    return { roomUrl: joinUrl, sessionId: sessionRef.id };
  },
);
