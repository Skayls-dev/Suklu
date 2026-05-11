import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, serverTs, logger } from '../shared/utils';
import { sendPushNotification } from '../shared/notifications';

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

    const {
      bookingId,
      newStatus,
      status,
    } = request.data as { bookingId: string; newStatus?: string; status?: string };
    const nextStatus = newStatus ?? status;

    if (!bookingId || !nextStatus) {
      throw new HttpsError('invalid-argument', 'bookingId et newStatus requis');
    }

    const allowedStatuses = ['confirmed', 'cancelled', 'completed'];
    if (!allowedStatuses.includes(nextStatus)) {
      throw new HttpsError(
        'invalid-argument',
        `Statut invalide. Valeurs acceptées: ${allowedStatuses.join(', ')}`,
      );
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

    const currentStatus = booking['status'] as string;
    const allowedTransitions: Record<string, string[]> = {
      pending: ['confirmed', 'cancelled'],
      confirmed: ['completed', 'cancelled'],
      completed: [],
      cancelled: [],
    };

    if (!allowedTransitions[currentStatus]?.includes(nextStatus)) {
      throw new HttpsError(
        'failed-precondition',
        `Transition invalide de '${currentStatus}' vers '${nextStatus}'`,
      );
    }

    await bookingRef.update({ status: nextStatus, updatedAt: serverTs() });

    try {
      const studentId = booking['studentId'] as string;
      const parentId = booking['parentId'] as string | undefined;
      const subjectId = (booking['subjectId'] as string | undefined) ?? 'votre matière';
      const formattedDate = formatScheduledAt(booking['scheduledAt']);

      if (nextStatus === 'confirmed') {
        await sendPushNotification({
          uid: studentId,
          title: 'Réservation confirmée ✅',
          body: `Votre session de ${subjectId} est confirmée pour le ${formattedDate}`,
          data: { bookingId, type: 'booking_confirmed' },
        });
        logger.info('notification.sent', { bookingId, uid: studentId, type: 'booking_confirmed' });

        if (parentId) {
          await sendPushNotification({
            uid: parentId,
            title: 'Réservation confirmée ✅',
            body: `La session de ${subjectId} est confirmée pour le ${formattedDate}`,
            data: { bookingId, type: 'booking_confirmed' },
          });
          logger.info('notification.sent', { bookingId, uid: parentId, type: 'booking_confirmed' });
        }
      }

      if (nextStatus === 'cancelled') {
        await sendPushNotification({
          uid: studentId,
          title: 'Réservation annulée',
          body: `Votre session de ${subjectId} a été annulée.`,
          data: { bookingId, type: 'booking_cancelled' },
        });
        logger.info('notification.sent', { bookingId, uid: studentId, type: 'booking_cancelled' });
      }

      if (nextStatus === 'completed') {
        await sendPushNotification({
          uid: studentId,
          title: 'Session terminée 🎓',
          body: 'Évaluez votre tuteur et consultez votre progression.',
          data: { bookingId, type: 'session_completed' },
        });
        logger.info('notification.sent', { bookingId, uid: studentId, type: 'session_completed' });
      }
    } catch (error) {
      logger.error('notification.send.booking_status_failed', {
        bookingId,
        nextStatus,
        error,
      });
    }

    logger.info(`Booking ${bookingId} → ${nextStatus} by tutor ${callerId}`);
    return { success: true };
  },
);

function formatScheduledAt(raw: unknown): string {
  if (raw instanceof admin.firestore.Timestamp) {
    return new Intl.DateTimeFormat('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(raw.toDate());
  }

  return 'date prévue';
}
