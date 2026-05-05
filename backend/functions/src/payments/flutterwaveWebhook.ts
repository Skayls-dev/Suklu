import { onRequest } from 'firebase-functions/v2/https';
import { PaymentDocument } from '../shared/types';
import {
  db, serverTs, logger,
  isEventProcessed, markEventProcessed,
} from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// flutterwaveWebhook
//
// Handles POST callbacks from Flutterwave (Rave) for West/Central Africa.
// Security:  HMAC-SHA512 signature check using the Flutterwave secret hash.
// Idempotency: event deduplicated on flw_ref (unique per transaction).
// ─────────────────────────────────────────────────────────────────────────────
export const flutterwaveWebhook = onRequest(
  { secrets: ['FLUTTERWAVE_SECRET_HASH'] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // ── Signature verification ────────────────────────────────────────────────
    const secretHash  = process.env.FLUTTERWAVE_SECRET_HASH!;
    const signature   = req.headers['verif-hash'] as string | undefined;

    if (!signature || signature !== secretHash) {
      logger.warn('flutterwaveWebhook: invalid signature');
      res.status(401).send('Unauthorized');
      return;
    }

    const payload = req.body as Record<string, unknown>;
    const event   = payload['event'] as string | undefined;
    const data    = payload['data']  as Record<string, unknown> | undefined;

    if (!data || event !== 'charge.completed') {
      // Acknowledge non-payment events without processing
      res.status(200).send('OK');
      return;
    }

    const flwRef    = data['flw_ref']        as string;
    const txStatus  = (data['status'] as string | undefined)?.toLowerCase();
    const bookingId = (data['meta'] as Record<string, string> | undefined)?.['bookingId'];
    const userId    = (data['meta'] as Record<string, string> | undefined)?.['userId'];
    const amount    = data['amount']         as number;
    const currency  = data['currency']       as string;

    if (!flwRef || !bookingId || !userId) {
      logger.error('flutterwaveWebhook: missing required fields', { flwRef, bookingId, userId });
      res.status(400).send('Bad Request');
      return;
    }

    // ── Idempotency check ─────────────────────────────────────────────────────
    if (await isEventProcessed(flwRef)) {
      logger.info('flutterwaveWebhook: duplicate event, skipping', { flwRef });
      res.status(200).send('OK');
      return;
    }

    const paymentStatus = txStatus === 'successful' ? 'success' : 'failed';

    try {
      await db().runTransaction(async (tx) => {
        const paymentRef = db().collection('payments').doc();
        const payment: PaymentDocument = {
          id:                    paymentRef.id,
          bookingId,
          userId,
          amount,
          currency,
          provider:              'flutterwave',
          providerTransactionId: flwRef,
          status:                paymentStatus,
          processedAt:           serverTs(),
          createdAt:             serverTs(),
          webhookPayload:        payload,
        };
        tx.set(paymentRef, payment);

        // Update booking status only on successful payment
        if (paymentStatus === 'success') {
          const bookingRef = db().collection('bookings').doc(bookingId);
          tx.update(bookingRef, {
            status:    'confirmed',
            updatedAt: serverTs(),
          });
        }

        markEventProcessed(tx, flwRef, {
          provider:  'flutterwave',
          bookingId,
          paymentStatus,
        });
      });

      logger.info('flutterwaveWebhook: processed', { flwRef, paymentStatus, bookingId });
      res.status(200).send('OK');
    } catch (err) {
      logger.error('flutterwaveWebhook: transaction failed', { flwRef, err });
      res.status(500).send('Internal Server Error');
    }
  },
);
