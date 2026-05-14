import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { UserRole } from '../shared/types';
import { db, logger, serverTs } from '../shared/utils';

interface DeleteGroupEnrollmentRequest {
  enrollmentId: string;
  studentId?: string; // For parent calls
}

export const deleteGroupEnrollment = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerId = request.auth.uid;
    const callerRole = request.auth.token['role'] as UserRole | undefined;
    if (callerRole !== 'student' && callerRole !== 'parent') {
      throw new HttpsError('permission-denied', 'Seuls les étudiants ou parents peuvent annuler');
    }

    const data = request.data as DeleteGroupEnrollmentRequest;
    if (!data.enrollmentId) {
      throw new HttpsError('invalid-argument', 'enrollmentId requis');
    }

    const enrollmentRef = db().collection('group_enrollments').doc(data.enrollmentId);
    const enrollmentSnap = await enrollmentRef.get();

    if (!enrollmentSnap.exists) {
      throw new HttpsError('not-found', 'Inscription introuvable');
    }

    const enrollment = enrollmentSnap.data() as {
      studentId?: string;
      parentId?: string;
      slotId?: string;
      status?: string;
    };

    // Permission checks
    let effectiveStudentId = enrollment.studentId ?? '';
    if (callerRole === 'parent') {
      if (!data.studentId) {
        throw new HttpsError('invalid-argument', 'studentId requis pour un parent');
      }
      const parentSnap = await db().collection('users').doc(callerId).get();
      const linkedIds = (parentSnap.data()?.['linkedStudentIds'] as string[] | undefined) ?? [];
      if (!linkedIds.includes(data.studentId)) {
        throw new HttpsError('permission-denied', 'Cet étudiant n\'est pas lié à ce parent');
      }
      effectiveStudentId = data.studentId;
    } else if (callerId !== effectiveStudentId) {
      throw new HttpsError('permission-denied', 'Un étudiant ne peut annuler que sa propre inscription');
    }

    // Only allow cancellation for certain statuses
    const currentStatus = enrollment.status ?? 'pending_payment';
    if (!['pending_payment', 'paid'].includes(currentStatus)) {
      throw new HttpsError(
        'failed-precondition',
        `Impossible d'annuler une inscription avec le statut: ${currentStatus}`
      );
    }

    const slotId = enrollment.slotId ?? '';
    if (!slotId) {
      throw new HttpsError('invalid-argument', 'slotId manquant dans l\'inscription');
    }

    const slotRef = db().collection('group_session_slots').doc(slotId);

    const result = await db().runTransaction(async (tx) => {
      const slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) {
        throw new HttpsError('not-found', 'Créneau de groupe introuvable');
      }

      const slot = slotSnap.data() as {
        currentParticipants?: number;
        enrolledStudentIds?: string[];
        status?: string;
      };

      const currentParticipants = slot.currentParticipants ?? 0;
      const enrolledStudentIds = slot.enrolledStudentIds ?? [];

      if (!enrolledStudentIds.includes(effectiveStudentId)) {
        throw new HttpsError('failed-precondition', 'Cet étudiant n\'était pas inscrit à ce créneau');
      }

      // Delete enrollment
      tx.delete(enrollmentRef);

      // Update slot
      const slotUpdates: Record<string, unknown> = {
        currentParticipants: admin.firestore.FieldValue.increment(-1),
        enrolledStudentIds: admin.firestore.FieldValue.arrayRemove(effectiveStudentId),
        updatedAt: serverTs(),
      };

      // If slot was 'full', revert to 'open'
      if (slot.status === 'full' && currentParticipants > 0) {
        slotUpdates['status'] = 'open';
      }

      tx.update(slotRef, slotUpdates);

      return {
        deletedEnrollmentId: data.enrollmentId,
        success: true,
      };
    });

    logger.info('deleteGroupEnrollment: enrollment cancelled', {
      enrollmentId: data.enrollmentId,
      slotId,
      studentId: effectiveStudentId,
      previousStatus: currentStatus,
      callerRole,
    });

    return result;
  },
);
