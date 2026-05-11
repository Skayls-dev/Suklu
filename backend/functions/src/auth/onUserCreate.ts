import * as functionsV1 from 'firebase-functions/v1';
import { UserRecord } from 'firebase-admin/auth';
import { UserProfile, UserRole } from '../shared/types';
import { auth, db, serverTs, logger } from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// initUserProfile — auth trigger (gen1)
//
// Triggered on every Firebase Auth user creation.
// Sets custom claims (role) and creates the Firestore profile.
// ─────────────────────────────────────────────────────────────────────────────
export const initUserProfile = functionsV1.auth.user().onCreate(async (firebaseUser: UserRecord) => {
  const uid           = firebaseUser.uid;
  const defaultRole: UserRole = 'student';

  try {
    const profile: UserProfile = {
      uid,
      email:       firebaseUser.email       ?? '',
      displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Utilisateur',
      phoneNumber: firebaseUser.phoneNumber ?? undefined,
      role:        defaultRole,
      isActive:    true,
      parentIds:   [],
      createdAt:   serverTs(),
      updatedAt:   serverTs(),
    };

    await db().collection('users').doc(uid).set(profile);
    await auth().setCustomUserClaims(uid, { role: defaultRole });

    logger.info('initUserProfile: profile created', { uid, role: defaultRole });
  } catch (err) {
    logger.error('initUserProfile: failed to create profile', { uid, err });
    throw err;
  }
});
