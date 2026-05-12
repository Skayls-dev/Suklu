import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { GroupEnrollment, UserRole } from '../shared/types';
import { db, logger, serverTs } from '../shared/utils';

interface EnrollInGroupSessionRequest {
  slotId: string;
  studentId?: string;
}

export const enrollInGroupSession = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerId = request.auth.uid;
    const callerRole = request.auth.token['role'] as UserRole | undefined;
    if (callerRole !== 'student' && callerRole !== 'parent') {
      throw new HttpsError('permission-denied', 'Seuls les étudiants ou parents peuvent s\'inscrire');
    }

    const data = request.data as EnrollInGroupSessionRequest;
    if (!data.slotId) {
      throw new HttpsError('invalid-argument', 'slotId requis');
    }

    let effectiveStudentId = callerId;
    let effectiveParentId: string | undefined;

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
      effectiveParentId = callerId;
    } else if (data.studentId && data.studentId !== callerId) {
      throw new HttpsError('permission-denied', 'Un étudiant ne peut s\'inscrire que pour lui-même');
    }

    const slotRef = db().collection('group_session_slots').doc(data.slotId);
    const enrollmentRef = db().collection('group_enrollments').doc();

    const result = await db().runTransaction(async (tx) => {
      const slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) {
        throw new HttpsError('not-found', 'Créneau de groupe introuvable');
      }

      const slot = slotSnap.data() as {
        status?: string;
        currentParticipants?: number;
        maxParticipants?: number;
        enrolledStudentIds?: string[];
        pricePerStudent?: number;
        currency?: string;
      };

      const status = slot.status ?? 'open';
      const currentParticipants = slot.currentParticipants ?? 0;
      const maxParticipants = slot.maxParticipants ?? 0;
      const enrolledStudentIds = slot.enrolledStudentIds ?? [];

      if (status !== 'open') {
        throw new HttpsError('failed-precondition', 'Ce créneau n\'est plus ouvert aux inscriptions');
      }
      if (currentParticipants >= maxParticipants) {
        throw new HttpsError('failed-precondition', 'Ce créneau est déjà complet');
      }
      if (enrolledStudentIds.includes(effectiveStudentId)) {
        throw new HttpsError('already-exists', 'Cet étudiant est déjà inscrit à ce créneau');
      }

      const enrollment: GroupEnrollment = {
        id: enrollmentRef.id,
        slotId: data.slotId,
        studentId: effectiveStudentId,
        parentId: effectiveParentId,
        status: 'pending_payment',
        enrolledAt: serverTs(),
      };

      tx.set(enrollmentRef, enrollment);

      const nextParticipants = currentParticipants + 1;
      const slotUpdates: Record<string, unknown> = {
        currentParticipants: admin.firestore.FieldValue.increment(1),
        enrolledStudentIds: admin.firestore.FieldValue.arrayUnion(effectiveStudentId),
        updatedAt: serverTs(),
      };
      if (nextParticipants >= maxParticipants) {
        slotUpdates['status'] = 'full';
      }

      tx.update(slotRef, slotUpdates);

      return {
        enrollmentId: enrollmentRef.id,
        pricePerStudent: slot.pricePerStudent ?? 0,
        currency: (slot.currency as string | undefined) ?? 'XOF',
      };
    });

    logger.info('enrollInGroupSession: enrollment created', {
      slotId: data.slotId,
      enrollmentId: result.enrollmentId,
      studentId: effectiveStudentId,
      callerRole,
    });

    return result;
  },
);
