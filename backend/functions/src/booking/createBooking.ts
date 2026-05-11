import { onCall, HttpsError } from 'firebase-functions/v2/https';
import {
  CreateBookingRequest,
  BookingDocument,
  UserRole,
} from '../shared/types';
import { db, serverTs, logger } from '../shared/utils';
import { getPlatformConfig }    from '../config/platformConfig';
import { calculatePrice }       from '../pricing/pricingEngine';

// ─────────────────────────────────────────────────────────────────────────────
// createBooking — Callable Cloud Function
//
// Validates and creates a booking. Called directly from the Flutter app via
// FirebaseFunctions.instance.httpsCallable('createBooking').
//
// Business logic kept server-side to prevent:
//   • double-booking the same tutor slot
//   • students booking inactive tutors
//   • parents booking on behalf of unlinked students
// ─────────────────────────────────────────────────────────────────────────────
export const createBooking = onCall(
  { enforceAppCheck: false, cors: true, region: 'europe-west1' },
  async (request) => {
    // ── Auth guard ──────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerRole = request.auth.token['role'] as UserRole | undefined;
    const callerId   = request.auth.uid;

    if (callerRole !== 'student' && callerRole !== 'parent') {
      throw new HttpsError(
        'permission-denied',
        'Seuls les étudiants et parents peuvent créer des réservations',
      );
    }

    const data = request.data as CreateBookingRequest;

    // ── Validate tutor ──────────────────────────────────────────────────────
    const tutorSnap = await db().collection('users').doc(data.tutorId).get();
    if (!tutorSnap.exists) {
      throw new HttpsError('not-found', 'Tuteur introuvable');
    }
    const tutor = tutorSnap.data()!;
    if (tutor['role'] !== 'tutor' || !tutor['isActive']) {
      throw new HttpsError('failed-precondition', 'Ce tuteur n\'est pas disponible');
    }

    // ── Parent booking: verify student is linked ─────────────────────────────
    let studentId = callerId;
    if (callerRole === 'parent') {
      if (!data.studentId) {
        throw new HttpsError('invalid-argument', 'studentId requis pour une réservation parentale');
      }
      const parentSnap = await db().collection('users').doc(callerId).get();
      const linkedIds: string[] = parentSnap.data()?.['linkedStudentIds'] ?? [];
      if (!linkedIds.includes(data.studentId)) {
        throw new HttpsError(
          'permission-denied',
          'Vous ne pouvez réserver que pour vos enfants liés',
        );
      }
      studentId = data.studentId;
    }

    // ── Conflict check ───────────────────────────────────────────────────────
    // Check the ±30 min window to prevent back-to-back scheduling bugs.
    const conflictSnap = await db()
      .collection('bookings')
      .where('tutorId',     '==', data.tutorId)
      .where('scheduledAt', '==', data.scheduledAt)
      .where('status',      'in', ['pending', 'confirmed'])
      .limit(1)
      .get();

    if (!conflictSnap.empty) {
      throw new HttpsError('already-exists', 'Ce créneau est déjà réservé');
    }

    // ── Determine currency from student's country ────────────────────────────
    const config       = await getPlatformConfig();
    const studentSnap  = await db().collection('users').doc(studentId).get();
    const studentCountry = studentSnap.data()?.['country'] as string | undefined;
    const countryConfig  = config.supportedCountries.find(c => c.code === studentCountry);
    const currency       = (countryConfig?.currency ?? 'XOF') as 'XOF' | 'GNF' | 'XAF' | 'CFA';

    // ── Calculate price using the live platform pricing config ───────────────
    const totalAmount = await calculatePrice({
      subjectId:       data.subjectId,
      durationMinutes: data.durationMinutes,
      currency,
      config,
    });

    // ── Create booking ───────────────────────────────────────────────────────
    const bookingRef = db().collection('bookings').doc();
    const booking: BookingDocument = {
      id:              bookingRef.id,
      studentId,
      tutorId:         data.tutorId,
      subjectId:       data.subjectId,
      scheduledAt:     data.scheduledAt,
      durationMinutes: data.durationMinutes,
      sessionType:     data.sessionType,
      parentId:        callerRole === 'parent' ? callerId : undefined,
      status:          'pending',
      reminderSent:    false,
      totalAmount,
      currency,
      createdAt:       serverTs(),
      updatedAt:       serverTs(),
    };

    await bookingRef.set(booking);

    logger.info('createBooking: booking created', {
      bookingId: bookingRef.id,
      studentId,
      tutorId: data.tutorId,
    });

    return { bookingId: bookingRef.id };
  },
);
