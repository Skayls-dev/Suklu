import { onRequest } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';
import { PaymentDocument } from '../shared/types';
import {
  db, serverTs, logger,
  isEventProcessed, markEventProcessed,
} from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// waveWebhook
//
// Handles POST callbacks from Wave Mobile Money (Sénégal / Côte d'Ivoire).
// Wave uses HMAC-SHA256 with the secret in the Wave-Signature header.
//
// NOTE: Wave's Business API is invite-only. Verify current webhook spec at
// https://docs.wave.com/business/ before going live.
// ─────────────────────────────────────────────────────────────────────────────
export const waveWebhook = onRequest(
  { secrets: ['WAVE_WEBHOOK_SECRET'] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // ── Signature verification ────────────────────────────────────────────────
    const secret    = process.env.WAVE_WEBHOOK_SECRET!;
    const signature = req.headers['wave-signature'] as string | undefined;
    const rawBody   = JSON.stringify(req.body);
    const expected  = 'sha256=' + crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');

    if (!signature || !crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expected),
    )) {
      logger.warn('waveWebhook: invalid signature');
      res.status(401).send('Unauthorized');
      return;
    }

    const payload = req.body as Record<string, unknown>;
    const event   = payload['type'] as string | undefined;

    // Wave sends various event types; we only care about payment.completed
    if (event !== 'payment.completed' && event !== 'checkout-session.payment.succeeded') {
      res.status(200).send('OK');
      return;
    }

    const waveData  = (payload['data'] as Record<string, unknown>) ?? payload;
    const txId      = waveData['id']            as string | undefined;
    const txStatus  = (waveData['payment_status'] as string | undefined)?.toLowerCase();
    const bookingId = (waveData['client_reference'] as string | undefined);
    const userId    = (waveData['metadata'] as Record<string, string> | undefined)?.['userId'];
    const amount    = waveData['amount']        as number;
    const currency  = (waveData['currency'] as string | undefined) ?? 'XOF';

    if (!txId || !bookingId || !userId) {
      logger.error('waveWebhook: missing required fields', { txId, bookingId, userId });
      res.status(400).send('Bad Request');
      return;
    }

    if (await isEventProcessed(txId)) {
      logger.info('waveWebhook: duplicate event, skipping', { txId });
      res.status(200).send('OK');
      return;
    }

    const paymentStatus = (txStatus === 'succeeded' || txStatus === 'complete') ? 'success' : 'failed';

    try {
      await db().runTransaction(async (tx) => {
        const paymentRef = db().collection('payments').doc();
        const payment: PaymentDocument = {
          id:                    paymentRef.id,
          bookingId,
          userId,
          amount,
          currency,
          provider:              'wave',
          providerTransactionId: txId,
          status:                paymentStatus,
          processedAt:           serverTs(),
          createdAt:             serverTs(),
          webhookPayload:        payload,
        };
        tx.set(paymentRef, payment);

        if (paymentStatus === 'success') {
          tx.update(db().collection('bookings').doc(bookingId), {
            status:    'confirmed',
            updatedAt: serverTs(),
          });
        }

        markEventProcessed(tx, txId, { provider: 'wave', bookingId, paymentStatus });
      });

      logger.info('waveWebhook: processed', { txId, paymentStatus, bookingId });
      res.status(200).send('OK');
    } catch (err) {
      logger.error('waveWebhook: transaction failed', { txId, err });
      res.status(500).send('Internal Server Error');
    }
  },
);
