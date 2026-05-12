import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, logger, serverTs } from '../shared/utils';
import { ReviewDocument, UserRole } from '../shared/types';

interface SubmitReviewRequest {
  sessionId: string;
  rating: number;
  comment: string;
}

export const submitReview = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerId = request.auth.uid;
    const callerRole = request.auth.token['role'] as UserRole | undefined;
    if (callerRole !== 'student' && callerRole !== 'tutor') {
      throw new HttpsError('permission-denied', 'Seuls les étudiants et tuteurs peuvent soumettre une review');
    }

    const data = request.data as SubmitReviewRequest;
    if (!data.sessionId) {
      throw new HttpsError('invalid-argument', 'sessionId requis');
    }

    const rating = Number(data.rating);
    if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
      throw new HttpsError('invalid-argument', 'rating doit être entre 1 et 5');
    }

    const comment = (data.comment ?? '').trim();
    if (comment.length < 10 || comment.length > 500) {
      throw new HttpsError('invalid-argument', 'comment doit contenir entre 10 et 500 caractères');
    }

    const sessionSnap = await db().collection('sessions').doc(data.sessionId).get();
    if (!sessionSnap.exists) {
      throw new HttpsError('not-found', 'Session introuvable');
    }
    const session = sessionSnap.data()!;

    if (session['status'] !== 'completed') {
      throw new HttpsError('failed-precondition', 'La session doit être terminée avant notation');
    }

    const tutorId = session['tutorId'] as string;
    const studentId = session['studentId'] as string;
    const bookingId = session['bookingId'] as string | undefined;

    if (callerId !== tutorId && callerId !== studentId) {
      throw new HttpsError('permission-denied', 'Vous n\'êtes pas participant à cette session');
    }

    const duplicateSnap = await db()
        .collection('reviews')
        .where('sessionId', '==', data.sessionId)
        .where('authorId', '==', callerId)
        .limit(1)
        .get();
    if (!duplicateSnap.empty) {
      throw new HttpsError('already-exists', 'Review déjà soumise pour cette session');
    }

    const isStudentAuthor = callerId === studentId;
    const authorRole: 'student' | 'tutor' = isStudentAuthor ? 'student' : 'tutor';
    const targetRole: 'tutor' | 'student' = isStudentAuthor ? 'tutor' : 'student';
    const targetId = isStudentAuthor ? tutorId : studentId;

    const reviewRef = db().collection('reviews').doc();
    const reviewDoc: ReviewDocument = {
      id: reviewRef.id,
      sessionId: data.sessionId,
      bookingId: bookingId ?? '',
      authorId: callerId,
      authorRole,
      targetId,
      targetRole,
      rating,
      comment,
      isVisible: true,
      createdAt: serverTs(),
    };

    await reviewRef.set(reviewDoc);

    if (authorRole === 'student') {
      const tutorReviewsSnap = await db()
          .collection('reviews')
          .where('targetId', '==', tutorId)
          .where('targetRole', '==', 'tutor')
          .get();

      const ratings = tutorReviewsSnap.docs
          .map((doc) => Number(doc.data()['rating'] ?? 0))
          .filter((value: number) => value > 0);

      const reviewCount = ratings.length;
      const averageRating = reviewCount == 0
          ? 0
          : ratings.reduce((a: number, b: number) => a + b) / reviewCount;

      await db().runTransaction(async (tx) => {
        const tutorRef = db().collection('tutor_profiles').doc(tutorId);
        tx.set(tutorRef, {
          'rating': averageRating,
          'reviewCount': reviewCount,
          'updatedAt': serverTs(),
        }, { merge: true });
      });
    }

    logger.info('submitReview: review created', {
      reviewId: reviewRef.id,
      sessionId: data.sessionId,
      authorId: callerId,
      authorRole,
      targetId,
      targetRole,
    });

    return {'reviewId': reviewRef.id};
  },
);
