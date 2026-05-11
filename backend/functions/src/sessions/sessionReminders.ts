import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { db, logger } from '../shared/utils';
import { sendPushNotification } from '../shared/notifications';

export const sessionReminders = onSchedule(
  {
    schedule: 'every 5 minutes',
    region: 'europe-west1',
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const upperBound = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 35 * 60 * 1000),
    );

    const snapshot = await db()
      .collection('bookings')
      .where('status', '==', 'confirmed')
      .where('scheduledAt', '>=', now)
      .where('scheduledAt', '<=', upperBound)
      .where('reminderSent', '!=', true)
      .get();

    if (snapshot.empty) {
      logger.info('session_reminders.none_pending');
      return;
    }

    for (const doc of snapshot.docs) {
      const booking = doc.data();
      const bookingId = doc.id;
      const subjectId = (booking['subjectId'] as string | undefined) ?? 'votre matière';
      const studentId = booking['studentId'] as string | undefined;
      const tutorId = booking['tutorId'] as string | undefined;
      const roomUrl = (booking['roomUrl'] as string | undefined) ?? '';

      if (!studentId || !tutorId) {
        logger.warn('session_reminders.skipped_missing_participants', { bookingId });
        continue;
      }

      await sendPushNotification({
        uid: studentId,
        title: '📅 Session dans 30 minutes !',
        body: `Votre session de ${subjectId} commence bientôt. Préparez-vous !`,
        data: {
          bookingId,
          type: 'session_reminder',
          roomUrl,
        },
      });

      await sendPushNotification({
        uid: tutorId,
        title: '📅 Session dans 30 minutes',
        body: 'Votre session avec un élève commence bientôt.',
        data: {
          bookingId,
          type: 'session_reminder',
        },
      });

      await doc.ref.update({ reminderSent: true });
      logger.info('session_reminders.sent', { bookingId, studentId, tutorId });
    }
  },
);
