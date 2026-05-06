import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, serverTs, logger, auth } from '../shared/utils';
import { TutorApplicationStatus, UserRole } from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// reviewApplication — Callable (academic_staff | super_admin only)
//
// Two-stage approval flow mirrors a real background-check process:
//
//  Stage 1 — Document review:
//    decision: 'approve_documents' → status: 'background_check_pending'
//    decision: 'reject'            → status: 'rejected'
//
//  Stage 2 — Background check clearance:
//    decision: 'approve_background' → status: 'approved'
//                                   → user.role = 'tutor', custom claim updated
//    decision: 'reject'             → status: 'rejected'
//
// Both stages can be performed by staff, or by different staff members.
// ─────────────────────────────────────────────────────────────────────────────
export const reviewApplication = onCall({ cors: true, region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }

  const reviewerRole = request.auth.token['role'] as UserRole | undefined;
  if (reviewerRole !== 'academic_staff' && reviewerRole !== 'super_admin') {
    throw new HttpsError('permission-denied', 'Réservé au personnel académique');
  }

  const { applicationId, decision, rejectionReason } = request.data as {
    applicationId:   string;
    decision:        'approve_documents' | 'approve_background' | 'reject';
    rejectionReason?: string;
  };

  if (!applicationId || !decision) {
    throw new HttpsError('invalid-argument', 'applicationId et decision requis');
  }

  const appRef  = db().collection('tutor_applications').doc(applicationId);
  const appSnap = await appRef.get();

  if (!appSnap.exists) {
    throw new HttpsError('not-found', 'Demande introuvable');
  }

  const app = appSnap.data()!;
  const reviewerId = request.auth.uid;

  let newStatus: TutorApplicationStatus;
  const update: Record<string, unknown> = {
    reviewedBy: reviewerId,
    reviewedAt: serverTs(),
    updatedAt:  serverTs(),
  };

  if (decision === 'reject') {
    newStatus = 'rejected';
    update['rejectionReason'] = rejectionReason ?? 'Non précisé';

  } else if (decision === 'approve_documents') {
    if (app['status'] !== 'pending_document_review') {
      throw new HttpsError('failed-precondition', 'La demande n\'est pas en attente de révision documentaire');
    }
    newStatus = 'background_check_pending';

  } else if (decision === 'approve_background') {
    if (app['status'] !== 'background_check_pending') {
      throw new HttpsError('failed-precondition', 'La vérification de fond n\'est pas encore en cours');
    }
    newStatus = 'approved';

    // ── Promote user to tutor ───────────────────────────────────────────────
    const userId = app['userId'] as string;

    await auth().setCustomUserClaims(userId, { role: 'tutor' as UserRole });
    await db().collection('users').doc(userId).update({
      role:      'tutor' as UserRole,
      updatedAt: serverTs(),
    });

    logger.info('reviewApplication: user promoted to tutor', { userId, applicationId });

  } else {
    throw new HttpsError('invalid-argument', 'Décision invalide');
  }

  update['status'] = newStatus;
  update['backgroundCheckStatus'] = decision === 'approve_background' ? 'clear' : app['backgroundCheckStatus'];

  await appRef.update(update);

  logger.info('reviewApplication: reviewed', { applicationId, decision, newStatus, reviewerId });
  return { applicationId, newStatus };
});
