/**
 * seed-test-accounts.js
 *
 * Creates test accounts in Firebase Auth + Firestore for local testing.
 * Run: node scripts/seed-test-accounts.js
 *
 * Prerequisites:
 *   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account JSON
 *     OR running with Application Default Credentials (firebase login --reuse-token)
 *   - npm install firebase-admin  (in this scripts folder or globally)
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'suklu-prod' });

const auth      = admin.auth();
const firestore = admin.firestore();

const NOW = admin.firestore.FieldValue.serverTimestamp();

const TEST_ACCOUNTS = [
  {
    email:       'student@suklu.test',
    password:    'Test1234!',
    displayName: 'Alex Étudiant',
    role:        'student',
  },
  {
    email:       'tutor@suklu.test',
    password:    'Test1234!',
    displayName: 'Marie Tutrice',
    role:        'tutor',
  },
  {
    email:       'parent@suklu.test',
    password:    'Test1234!',
    displayName: 'Jean Parent',
    role:        'parent',
  },
  {
    email:       'admin@suklu.test',
    password:    'Test1234!',
    displayName: 'Super Admin',
    role:        'super_admin',
  },
];

async function upsertAccount({ email, password, displayName, role }) {
  let uid;

  // Create or retrieve the Firebase Auth user
  try {
    const existing = await auth.getUserByEmail(email);
    uid = existing.uid;
    console.log(`  ↺  ${email} already exists (uid: ${uid})`);
  } catch {
    const created = await auth.createUser({ email, password, displayName });
    uid = created.uid;
    console.log(`  ✓  ${email} created (uid: ${uid})`);
  }

  // Set custom claim so Firestore Security Rules can read the role
  await auth.setCustomUserClaims(uid, { role });

  // Upsert the /users/{uid} Firestore document
  await firestore.collection('users').doc(uid).set(
    {
      uid,
      email,
      displayName,
      role,
      isActive:   true,
      parentIds:  [],
      createdAt:  NOW,
      updatedAt:  NOW,
    },
    { merge: true },
  );

  console.log(`  ✓  Firestore profile set for ${email} (role: ${role})`);
}

async function main() {
  console.log('\n🌱  Seeding test accounts on suklu-prod...\n');
  for (const account of TEST_ACCOUNTS) {
    await upsertAccount(account);
  }

  console.log('\n✅  Done!\n');
  console.log('Test accounts:');
  console.log('─────────────────────────────────────────────');
  for (const a of TEST_ACCOUNTS) {
    console.log(`  ${a.role.padEnd(14)} ${a.email}  /  ${a.password}`);
  }
  console.log('─────────────────────────────────────────────\n');

  process.exit(0);
}

main().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
