import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, serverTs, logger } from '../shared/utils';
import { TutorApplication } from '../shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// submitApplication — Callable
//
// Any authenticated user can apply to become a tutor.
// Flow:
//   1. User uploads CV and ID documents to Firebase Storage (client-side).
//   2. Client calls this function with the Storage paths.
//   3. Function creates /tutor_applications/{id} with status 'pending_document_review'.
//   4. Admin reviews via reviewApplication function.
// ─────────────────────────────────────────────────────────────────────────────
export const submitApplication = onCall({ cors: true, region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }

  const userId = request.auth.uid;
  const data   = request.data as {
    fullName:         string;
    phoneNumber:      string;
    subjects:         string[];
    gradeLevels:      string[];
    bio:              string;
    cvStoragePath:    string; // gs://... path of uploaded CV
    idStoragePath:    string; // gs://... path of uploaded ID document
    country:          string;
    diplomas?:        string[];
    yearsExperience?: number;
  };

  // Validate required fields
  if (!data.cvStoragePath || !data.idStoragePath) {
    throw new HttpsError('invalid-argument', 'CV et pièce d\'identité requis');
  }
  if (!data.subjects || data.subjects.length === 0) {
    throw new HttpsError('invalid-argument', 'Au moins une matière requise');
  }

  // Check for duplicate application
  const existing = await db()
    .collection('tutor_applications')
    .where('userId', '==', userId)
    .where('status', 'not-in', ['rejected'])
    .limit(1)
    .get();

  if (!existing.empty) {
    throw new HttpsError('already-exists', 'Une demande est déjà en cours pour ce compte');
  }

  const appRef: admin.firestore.DocumentReference = db().collection('tutor_applications').doc();
  const application: TutorApplication = {
    id:                   appRef.id,
    userId,
    fullName:             data.fullName,
    phoneNumber:          data.phoneNumber,
    subjects:             data.subjects,
    gradeLevels:          data.gradeLevels,
    bio:                  data.bio,
    country:              data.country,
    diplomas:             data.diplomas ?? [],
    yearsExperience:      data.yearsExperience ?? 0,
    status:               'pending_document_review',
    backgroundCheckStatus: 'pending',
    documents: [
      { type: 'cv',         storagePath: data.cvStoragePath,    uploadedAt: serverTs() },
      { type: 'national_id', storagePath: data.idStoragePath, uploadedAt: serverTs() },
    ],
    createdAt: serverTs(),
    updatedAt: serverTs(),
  };

  await appRef.set(application);

  logger.info('submitApplication: created', { applicationId: appRef.id, userId });
  return { applicationId: appRef.id };
});
