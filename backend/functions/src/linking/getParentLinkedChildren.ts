import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { db, logger } from '../shared/utils';
import { UserRole } from '../shared/types';

interface ParentLinkedChild {
  uid: string;
  fullName: string;
  gradeLevel: string;
  avatarUrl: string | null;
  isLimitedProfile: boolean;
}

export const getParentLinkedChildren = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerRole = request.auth.token['role'] as UserRole | undefined;
    if (callerRole !== 'parent') {
      throw new HttpsError('permission-denied', 'Réservé aux parents');
    }

    const parentId = request.auth.uid;
    const parentSnap = await db().collection('users').doc(parentId).get();
    if (!parentSnap.exists) {
      throw new HttpsError('not-found', 'Compte parent introuvable');
    }

    const linkedIds = ((parentSnap.data()?.['linkedStudentIds'] as unknown[]) ?? [])
      .map((value) => String(value));

    if (linkedIds.length === 0) {
      return { children: [] as ParentLinkedChild[] };
    }

    const children: ParentLinkedChild[] = [];

    for (const studentId of linkedIds) {
      const studentSnap = await db().collection('users').doc(studentId).get();
      if (!studentSnap.exists) {
        children.push({
          uid: studentId,
          fullName: `Compte élève lié (${studentId.substring(0, 8)}...)`,
          gradeLevel: 'Profil indisponible',
          avatarUrl: null,
          isLimitedProfile: true,
        });
        continue;
      }

      const studentData = studentSnap.data() ?? {};
      const role = studentData['role'];
      if (role !== 'student') {
        children.push({
          uid: studentId,
          fullName: `Compte lié (${studentId.substring(0, 8)}...)`,
          gradeLevel: 'Profil indisponible',
          avatarUrl: null,
          isLimitedProfile: true,
        });
        continue;
      }

      children.push({
        uid: studentId,
        fullName: String(studentData['fullName'] ?? studentData['displayName'] ?? 'Élève'),
        gradeLevel: String(studentData['gradeLevel'] ?? '—'),
        avatarUrl: studentData['avatarUrl'] != null ? String(studentData['avatarUrl']) : null,
        isLimitedProfile: false,
      });
    }

    logger.info('getParentLinkedChildren: success', {
      parentId,
      count: children.length,
    });

    return { children };
  },
);
