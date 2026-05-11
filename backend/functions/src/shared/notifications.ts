import * as admin from 'firebase-admin';

import { db, logger } from './utils';

export interface NotificationPayload {
  uid: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendPushNotification(payload: NotificationPayload): Promise<void> {
  try {
    const userRef = db().collection('users').doc(payload.uid);
    const userSnap = await userRef.get();

    if (!userSnap.exists) {
      logger.info('notification.skipped.user_not_found', { uid: payload.uid });
      return;
    }

    const tokensMap = userSnap.data()?.['fcmTokens'] as Record<string, string> | undefined;
    const tokens = Object.keys(tokensMap ?? {});

    if (tokens.length === 0) {
      logger.info('notification.skipped.no_tokens', { uid: payload.uid });
      return;
    }

    const result = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data,
    });

    const staleTokens: string[] = [];
    result.responses.forEach((response, index) => {
      if (
        !response.success &&
        response.error?.code === 'messaging/registration-token-not-registered'
      ) {
        staleTokens.push(tokens[index]);
      }
    });

    if (staleTokens.length > 0) {
      const currentMap = {
        ...((userSnap.data()?.['fcmTokens'] as Record<string, string> | undefined) ?? {}),
      };
      for (const staleToken of staleTokens) {
        delete currentMap[staleToken];
      }
      await userRef.set({ fcmTokens: currentMap }, { merge: true });
      logger.info('notification.tokens.cleaned', {
        uid: payload.uid,
        removedCount: staleTokens.length,
      });
    }
  } catch (error) {
    logger.error('notification.send.failed', {
      uid: payload.uid,
      error,
    });
  }
}
