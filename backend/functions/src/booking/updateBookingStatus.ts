import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, serverTs, logger } from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// updateBookingStatus — callable by tutors to confirm or cancel a booking
// ─────────────────────────────────────────────────────────────────────────────
export const updateBookingStatus = onCall(
  { enforceAppCheck: false, cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerRole = request.auth.token['role'] as string | undefined;
    const callerId   = request.auth.uid;

    if (callerRole !== 'tutor') {
      throw new HttpsError('permission-denied', 'Seuls les tuteurs peuvent modifier le statut');
    }

    const { bookingId, status } = request.data as { bookingId: string; status: string };

    if (!bookingId || !status) {
      throw new HttpsError('invalid-argument', 'bookingId et status requis');
    }

    const allowed = ['confirmed', 'cancelled'];
    if (!allowed.includes(status)) {
      throw new HttpsError('invalid-argument', `Statut invalide. Valeurs acceptées: ${allowed.join(', ')}`);
    }

    const bookingRef  = db().collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Réservation introuvable');
    }

    const booking = bookingSnap.data()!;

    // Only the assigned tutor can modify the booking
    if (booking['tutorId'] !== callerId) {
      throw new HttpsError('permission-denied', 'Vous n\'êtes pas le tuteur de cette réservation');
    }

    // Can only confirm/cancel a pending booking
    if (booking['status'] !== 'pending') {
      throw new HttpsError(
        'failed-precondition',
        `Impossible de modifier une réservation avec le statut '${booking['status']}'`,
      );
    }

    await bookingRef.update({ status, updatedAt: serverTs() });

    logger.info(`Booking ${bookingId} → ${status} by tutor ${callerId}`);
    return { success: true };
  },
);
