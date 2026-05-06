import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, serverTs, logger } from '../shared/utils';
import { UserRole } from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// verifyParentLink — Callable (academic_staff | super_admin only)
//
// Admin approves or rejects a parent-child link request.
// On approval:
//   • parent.linkedStudentIds += studentId
//   • student.parentIds       += parentId
// Both updates run in a transaction for consistency.
// ─────────────────────────────────────────────────────────────────────────────
export const verifyParentLink = onCall({ cors: true, region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }

  const reviewerRole = request.auth.token['role'] as UserRole | undefined;
  if (reviewerRole !== 'academic_staff' && reviewerRole !== 'super_admin') {
    throw new HttpsError('permission-denied', 'Réservé au personnel académique');
  }

  const { requestId, decision, rejectionReason } = request.data as {
    requestId:        string;
    decision:         'approve' | 'reject';
    rejectionReason?: string;
  };

  if (!requestId || !decision) {
    throw new HttpsError('invalid-argument', 'requestId et decision requis');
  }

  const reqRef  = db().collection('link_requests').doc(requestId);
  const reqSnap = await reqRef.get();

  if (!reqSnap.exists) {
    throw new HttpsError('not-found', 'Demande introuvable');
  }

  const linkReq = reqSnap.data()!;

  if (linkReq['status'] !== 'pending_admin_verification') {
    throw new HttpsError('failed-precondition', 'Cette demande a déjà été traitée');
  }

  const { parentId, studentId } = linkReq as { parentId: string; studentId: string };

  if (decision === 'reject') {
    await reqRef.update({
      status:          'rejected',
      reviewedBy:      request.auth!.uid,
      reviewedAt:      serverTs(),
      updatedAt:       serverTs(),
      rejectionReason: rejectionReason ?? 'Non précisé',
    });
    logger.info('verifyParentLink: rejected', { requestId });
    return { requestId, status: 'rejected' };
  }

  // ── Approve: bidirectional update in a transaction ────────────────────────
  await db().runTransaction(async (tx) => {
    const parentRef  = db().collection('users').doc(parentId);
    const studentRef = db().collection('users').doc(studentId);

    const [parentSnap, studentSnap] = await Promise.all([
      tx.get(parentRef),
      tx.get(studentRef),
    ]);

    if (!parentSnap.exists || !studentSnap.exists) {
      throw new HttpsError('not-found', 'Compte parent ou étudiant introuvable');
    }

    const linkedStudentIds: string[] = parentSnap.data()?.['linkedStudentIds'] ?? [];
    const parentIds:        string[] = studentSnap.data()?.['parentIds']        ?? [];

    if (!linkedStudentIds.includes(studentId)) {
      tx.update(parentRef,  {
        linkedStudentIds: admin.firestore.FieldValue.arrayUnion(studentId),
        updatedAt:        serverTs(),
      });
    }
    if (!parentIds.includes(parentId)) {
      tx.update(studentRef, {
        parentIds: admin.firestore.FieldValue.arrayUnion(parentId),
        updatedAt: serverTs(),
      });
    }

    tx.update(reqRef, {
      status:     'approved',
      reviewedBy: request.auth!.uid,
      updatedAt:  serverTs(),
    });
  });

  logger.info('verifyParentLink: approved', { requestId, parentId, studentId });
  return { requestId, status: 'approved' };
});
