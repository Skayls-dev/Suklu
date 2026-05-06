import { onCall, HttpsError } from 'firebase-functions/v2/https';
import axios from 'axios';
import { db, serverTs, logger } from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// initiatePayment — callable by student/parent
//
// Returns a Flutterwave payment link for a pending booking.
// Wave and Orange Money are handled via Flutterwave's multi-provider API.
// The booking stays 'pending' until the webhook confirms payment.
// ─────────────────────────────────────────────────────────────────────────────
export const initiatePayment = onCall(
  {
    secrets: ['FLUTTERWAVE_SECRET_KEY'],
    cors:    true,
    region:  'europe-west1',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const { bookingId, paymentMethod } = request.data as {
      bookingId:     string;
      paymentMethod: 'flutterwave' | 'wave' | 'orange_money';
    };

    if (!bookingId) {
      throw new HttpsError('invalid-argument', 'bookingId requis');
    }

    // ── Validate booking ────────────────────────────────────────────────────
    const bookingSnap = await db().collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) throw new HttpsError('not-found', 'Réservation introuvable');

    const booking   = bookingSnap.data()!;
    const callerId  = request.auth.uid;

    if (booking['studentId'] !== callerId && booking['parentId'] !== callerId) {
      throw new HttpsError('permission-denied', 'Accès non autorisé');
    }

    if (booking['status'] !== 'pending') {
      throw new HttpsError('failed-precondition', 'Cette réservation n\'est pas en attente de paiement');
    }

    // ── Get user email / name ───────────────────────────────────────────────
    const userSnap = await db().collection('users').doc(callerId).get();
    const user     = userSnap.data()!;

    const amount   = booking['totalAmount'] as number;
    const currency = booking['currency']    as string;

    // ── Build Flutterwave payment link ──────────────────────────────────────
    const secretKey = process.env.FLUTTERWAVE_SECRET_KEY!;
    const txRef     = `suklu_${bookingId}_${Date.now()}`;

    // Determine Flutterwave payment type based on method
    const paymentOptions = paymentMethod === 'wave'
      ? 'mobilemoneysn'                      // Wave Sénégal
      : paymentMethod === 'orange_money'
        ? 'mobilemoneyfranco'                // Orange Money (Franco-Africa)
        : 'card,mobilemoneysn,mobilemoneyfranco'; // all methods

    try {
      const response = await axios.post(
        'https://api.flutterwave.com/v3/payments',
        {
          tx_ref:           txRef,
          amount:           amount,
          currency:         currency,
          redirect_url:     'https://suklu.app/payment-success',
          payment_options:  paymentOptions,
          customer: {
            email:        user['email'],
            name:         user['displayName'],
            phonenumber:  user['phoneNumber'] ?? '',
          },
          meta: {
            bookingId,
            userId: callerId,
          },
          customizations: {
            title:       'Suklu – Tutorat',
            description: `Réservation ${bookingId.substring(0, 8)}`,
            logo:        'https://suklu.app/logo.png',
          },
        },
        {
          headers: {
            Authorization: `Bearer ${secretKey}`,
            'Content-Type': 'application/json',
          },
        },
      );

      const paymentLink = response.data?.data?.link as string | undefined;
      if (!paymentLink) {
        throw new Error('Flutterwave did not return a payment link');
      }

      // Store the txRef on the booking for webhook reconciliation
      await db().collection('bookings').doc(bookingId).update({
        txRef,
        paymentMethod,
        paymentInitiatedAt: serverTs(),
      });

      logger.info('initiatePayment', { bookingId, txRef, amount, currency });
      return { paymentLink, txRef };

    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error('initiatePayment.error', { bookingId, error: msg });
      throw new HttpsError('internal', `Erreur paiement: ${msg}`);
    }
  },
);
