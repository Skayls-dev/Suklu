import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db, logger } from '../shared/utils';
import { sendPushNotification } from '../shared/notifications';

export const onTutorMessage = onDocumentCreated(
  {
    document: 'session_messages/{messageId}',
    region: 'europe-west1',
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) {
      return;
    }

    const senderRole = (message['senderRole'] as string | undefined) ?? '';
    if (senderRole !== 'tutor') {
      return;
    }

    const sessionId = (message['sessionId'] as string | undefined) ?? '';
    const recipientId = (message['recipientId'] as string | undefined) ?? '';
    const content = (message['content'] as string | undefined) ?? '';

    if (!sessionId || !recipientId) {
      logger.warn('onTutorMessage.missing_fields', {
        messageId: event.params.messageId,
      });
      return;
    }

    const sessionSnap = await db().collection('sessions').doc(sessionId).get();
    const subjectId = (sessionSnap.data()?.['subjectId'] as string | undefined) ?? '';

    await sendPushNotification({
      uid: recipientId,
      title: 'Message de votre tuteur',
      body: content.substring(0, 100),
      data: {
        sessionId,
        type: 'tutor_message',
        subjectId,
      },
    });

    logger.info('notification.sent', {
      type: 'tutor_message',
      sessionId,
      recipientId,
    });
  },
);
