import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, logger, serverTs } from '../shared/utils';
import { PaymentDocument } from '../shared/types';

// simulatePayment — DEV helper to unblock booking/payment flow.
// Marks a pending booking as paid and confirmed without PSP integration.
export const simulatePayment = onCall(
  { enforceAppCheck: false, cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerRole = request.auth.token['role'] as string | undefined;
    const callerId = request.auth.uid;

    if (callerRole !== 'student' && callerRole !== 'parent' && callerRole !== 'super_admin') {
      throw new HttpsError('permission-denied', 'Rôle non autorisé pour simuler le paiement');
    }

    const { bookingId } = request.data as { bookingId?: string };
    if (!bookingId) {
      throw new HttpsError('invalid-argument', 'bookingId requis');
    }

    const bookingRef = db().collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', 'Réservation introuvable');
    }

    const booking = bookingSnap.data()!;
    const isOwner = booking['studentId'] === callerId || booking['parentId'] === callerId;
    if (callerRole !== 'super_admin' && !isOwner) {
      throw new HttpsError('permission-denied', 'Accès non autorisé à cette réservation');
    }

    if (booking['status'] !== 'pending') {
      throw new HttpsError('failed-precondition', 'La réservation doit être en attente de paiement');
    }

    const txRef = `sim_${bookingId}_${Date.now()}`;

    await db().runTransaction(async (tx) => {
      const paymentRef = db().collection('payments').doc();
      const payment: PaymentDocument = {
        id: paymentRef.id,
        bookingId,
        userId: callerId,
        amount: booking['totalAmount'] as number,
        currency: booking['currency'] as string,
        provider: 'flutterwave',
        providerTransactionId: txRef,
        status: 'success',
        processedAt: serverTs(),
        createdAt: serverTs(),
        webhookPayload: {
          source: 'simulatePayment',
          simulated: true,
          simulatedBy: callerId,
          simulatedAt: new Date().toISOString(),
        },
      };

      tx.set(paymentRef, payment);
      tx.update(bookingRef, {
        status: 'confirmed',
        txRef,
        paymentMethod: 'simulation',
        paymentInitiatedAt: serverTs(),
        updatedAt: serverTs(),
      });
    });

    logger.info('simulatePayment: booking confirmed', { bookingId, callerId });
    return { success: true, bookingId, status: 'confirmed' };
  },
);
