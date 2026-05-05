import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, serverTs, logger } from '../shared/utils';
import { ParentLinkRequest } from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// requestParentLink — Callable (parent role only)
//
// A parent enters their child's email address to request account linking.
// The request is then reviewed and approved by admin (verifyParentLink).
//
// Self-service: the parent initiates without needing to contact support.
// Admin verification: prevents fraudulent links (e.g., a stranger linking
// to a minor's account without consent).
// ─────────────────────────────────────────────────────────────────────────────
export const requestParentLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }

  const callerRole = request.auth.token['role'] as string | undefined;
  if (callerRole !== 'parent') {
    throw new HttpsError('permission-denied', 'Réservé aux parents');
  }

  const parentId    = request.auth.uid;
  const { studentEmail, relationship } = request.data as {
    studentEmail: string;
    relationship: 'parent' | 'guardian' | 'grandparent' | 'other';
  };

  if (!studentEmail) {
    throw new HttpsError('invalid-argument', 'Email de l\'étudiant requis');
  }

  // Look up student by email
  let studentId: string | null = null;
  try {
    const fbUser = await (await import('../shared/utils')).auth().getUserByEmail(studentEmail);
    studentId = fbUser.uid;
  } catch {
    throw new HttpsError('not-found', 'Aucun compte étudiant trouvé avec cet email');
  }

  // Verify the target is actually a student
  const studentSnap = await db().collection('users').doc(studentId).get();
  if (!studentSnap.exists || studentSnap.data()?.['role'] !== 'student') {
    throw new HttpsError('failed-precondition', 'Ce compte n\'est pas un compte étudiant');
  }

  // Check for duplicate pending request
  const existing = await db()
    .collection('link_requests')
    .where('parentId',  '==', parentId)
    .where('studentId', '==', studentId)
    .where('status',    '==', 'pending_admin_verification')
    .limit(1)
    .get();

  if (!existing.empty) {
    throw new HttpsError('already-exists', 'Une demande de liaison est déjà en cours');
  }

  // Check if already linked
  const parentSnap  = await db().collection('users').doc(parentId).get();
  const linkedIds: string[] = parentSnap.data()?.['linkedStudentIds'] ?? [];
  if (linkedIds.includes(studentId)) {
    throw new HttpsError('already-exists', 'Ce compte est déjà lié');
  }

  const reqRef = db().collection('link_requests').doc();
  const linkRequest: ParentLinkRequest = {
    id:           reqRef.id,
    parentId,
    studentId,
    studentEmail,
    relationship,
    status:       'pending_admin_verification',
    createdAt:    serverTs(),
    updatedAt:    serverTs(),
  };

  await reqRef.set(linkRequest);

  logger.info('requestParentLink: request created', {
    requestId: reqRef.id,
    parentId,
    studentId,
  });

  return { requestId: reqRef.id };
});
