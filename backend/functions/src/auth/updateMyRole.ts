import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { UserRole } from '../shared/types';
import { auth, db, serverTs } from '../shared/utils';

const allowedSelfRoles: UserRole[] = ['student', 'parent', 'tutor'];

export const updateMyRole = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const role = request.data?.['role'] as string | undefined;
    if (!role || !allowedSelfRoles.includes(role as UserRole)) {
      throw new HttpsError('invalid-argument', 'Rôle invalide');
    }

    const callerRole = request.auth.token['role'] as string | undefined;
    if (callerRole === 'academic_staff' || callerRole === 'super_admin') {
      throw new HttpsError('permission-denied', 'Ce rôle ne peut pas être modifié ici');
    }

    const uid = request.auth.uid;

    await db().collection('users').doc(uid).set(
      {
        role,
        updatedAt: serverTs(),
      },
      { merge: true },
    );

    await auth().setCustomUserClaims(uid, { role });

    return { role };
  },
);
