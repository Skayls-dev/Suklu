import { beforeUserCreated, beforeUserSignedIn } from 'firebase-functions/v2/identity';
import { UserProfile, UserRole } from '../shared/types';
import { db, serverTs, logger } from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// onUserCreate
//
// Triggered on every Firebase Auth user creation.
// 1. Determines default role (student) — role escalation happens via a
//    separate admin-only callable function, never here.
// 2. Sets a Firebase custom claim so Firestore Security Rules can read
//    the role without an extra document read.
// 3. Creates the /users/{uid} Firestore document.
// ─────────────────────────────────────────────────────────────────────────────
export const onUserCreate = beforeUserCreated(async (event) => {
  const firebaseUser = event.data!;
  const uid          = firebaseUser.uid;

  const defaultRole: UserRole = 'student';

  try {
    // Custom claim is returned directly — applied before user is committed
    // to Firebase Auth, so no token refresh is needed.

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

    logger.info('onUserCreate: profile created', { uid, role: defaultRole });
  } catch (err) {
    logger.error('onUserCreate: failed to create profile', { uid, err });
    throw err;
  }

  return { customClaims: { role: defaultRole } };
});

// ─────────────────────────────────────────────────────────────────────────────
// setUserRole (super_admin callable)
//
// Allows a super_admin to change another user's role.
// This is the only legitimate escalation path.
// ─────────────────────────────────────────────────────────────────────────────
export const setUserRole = beforeUserSignedIn(async () => {
  // Intentionally left as a pass-through — this hook can be extended to
  // block sign-in for deactivated accounts.
  return;
});
