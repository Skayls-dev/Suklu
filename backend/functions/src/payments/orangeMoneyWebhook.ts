import { onRequest } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';
import { PaymentDocument } from '../shared/types';
import {
  db, serverTs, logger,
  isEventProcessed, markEventProcessed,
} from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// orangeMoneyWebhook
//
// Handles POST callbacks from Orange Money API (Côte d'Ivoire / Sénégal etc.).
// Orange Money sends an HMAC-SHA256 signature in the X-Orange-Signature header.
//
// NOTE: Orange Money's webhook contract differs slightly per country.
// Verify the exact payload format against Orange Money's sandbox documentation
// for your target market before going live.
// ─────────────────────────────────────────────────────────────────────────────
export const orangeMoneyWebhook = onRequest(
  { secrets: ['ORANGE_MONEY_WEBHOOK_SECRET'] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // ── Signature verification ────────────────────────────────────────────────
    const secret    = process.env.ORANGE_MONEY_WEBHOOK_SECRET!;
    const signature = req.headers['x-orange-signature'] as string | undefined;
    const rawBody   = JSON.stringify(req.body);
    const expected  = crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');

    if (!signature || !crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expected),
    )) {
      logger.warn('orangeMoneyWebhook: invalid signature');
      res.status(401).send('Unauthorized');
      return;
    }

    const payload   = req.body as Record<string, unknown>;
    const txId      = payload['transactionId']  as string | undefined;
    const txStatus  = (payload['status'] as string | undefined)?.toLowerCase();
    const bookingId = (payload['externalId'] as string | undefined);
    const userId    = (payload['metadata'] as Record<string, string> | undefined)?.['userId'];
    const amount    = payload['amount']   as number;
    const currency  = (payload['currency'] as string | undefined) ?? 'XOF';

    if (!txId || !bookingId || !userId) {
      logger.error('orangeMoneyWebhook: missing required fields', { txId, bookingId });
      res.status(400).send('Bad Request');
      return;
    }

    if (await isEventProcessed(txId)) {
      logger.info('orangeMoneyWebhook: duplicate event, skipping', { txId });
      res.status(200).send('OK');
      return;
    }

    const paymentStatus = txStatus === 'success' ? 'success' : 'failed';

    try {
      await db().runTransaction(async (tx) => {
        const paymentRef = db().collection('payments').doc();
        const payment: PaymentDocument = {
          id:                    paymentRef.id,
          bookingId,
          userId,
          amount,
          currency,
          provider:              'orange_money',
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

        markEventProcessed(tx, txId, { provider: 'orange_money', bookingId, paymentStatus });
      });

      logger.info('orangeMoneyWebhook: processed', { txId, paymentStatus, bookingId });
      res.status(200).send('OK');
    } catch (err) {
      logger.error('orangeMoneyWebhook: transaction failed', { txId, err });
      res.status(500).send('Internal Server Error');
    }
  },
);
