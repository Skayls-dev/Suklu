/**
 * seed-test-data-emulator.js
 * 
 * Seeds test data to Firebase Emulator
 * 
 * Usage:
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   node seed-test-data-emulator.js
 */

const admin = require('firebase-admin');

// Initialize with emulator settings
const app = admin.initializeApp({
  projectId: 'suklu-dev',
  apiKey: 'AIzaSyA3PWu3omWkAliC4AlQXBSHo2LBsNDpOwM',
}, 'emulator');

const db = admin.firestore(app);
const auth = admin.auth(app);
const NOW = admin.firestore.Timestamp.now();

function daysFromNow(n) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return admin.firestore.Timestamp.fromDate(d);
}

const SUBJECTS = [
  { id: 'mathematics', name: 'Mathématiques', icon: '➗', category: 'sciences' },
  { id: 'french',      name: 'Français',      icon: '📖', category: 'languages' },
  { id: 'english',     name: 'Anglais',       icon: '🇬🇧', category: 'languages' },
  { id: 'physics',     name: 'Physique',      icon: '⚡', category: 'sciences' },
  { id: 'chemistry',   name: 'Chimie',        icon: '🧪', category: 'sciences' },
  { id: 'biology',     name: 'SVT',           icon: '🌿', category: 'sciences' },
  { id: 'history',     name: 'Histoire-Géo',  icon: '🌍', category: 'humanities' },
  { id: 'philosophy',  name: 'Philosophie',   icon: '💭', category: 'humanities' },
];

const TEST_ACCOUNTS = {
  'student@suklu.test': 'Test1234!',
  'tutor@suklu.test': 'Test1234!',
  'parent@suklu.test': 'Test1234!',
  'admin@suklu.test': 'Test1234!',
};

async function createTestAccounts() {
  console.log('\n📝 Creating test accounts...');
  const uids = {};
  
  for (const [email, password] of Object.entries(TEST_ACCOUNTS)) {
    try {
      // Try to get existing user
      const user = await auth.getUserByEmail(email);
      uids[email] = user.uid;
      console.log(`  ✓  ${email} (existing)`);
    } catch (error) {
      // Create new user
      const user = await auth.createUser({
        email,
        password,
        emailVerified: true,
      });
      uids[email] = user.uid;
      console.log(`  ✓  ${email} (created)`);
    }
  }
  
  return uids;
}

async function seedSubjects() {
  console.log('\n📚 Seeding subjects...');
  const batch = db.batch();
  
  for (const subject of SUBJECTS) {
    batch.set(db.collection('subjects').doc(subject.id), {
      ...subject,
      isActive: true,
      createdAt: NOW,
    });
  }
  
  await batch.commit();
  console.log(`  ✓  ${SUBJECTS.length} subjects created`);
}

async function seedPlatformConfig() {
  console.log('\n⚙️  Seeding platform config...');
  
  const config = {
    pricing: {
      mode: 'flat_rate',
      flatRates: {
        XOF: { 30: 5000,  60: 9000,  90: 13000 },
      },
    },
    roomMode: 'ephemeral',
    supportedCountries: [
      { code: 'SN', name: 'Sénégal', currency: 'XOF', paymentProviders: ['wave', 'orange_money'] },
    ],
    contentModerationRoles: ['super_admin'],
  };
  
  await db.collection('platform_config').doc('global').set(config, { merge: true });
  console.log('  ✓  Platform config created');
}

async function seedUserProfiles(uids) {
  console.log('\n👤 Seeding user profiles...');
  
  // Student profile
  await db.collection('users').doc(uids['student@suklu.test']).set({
    uid: uids['student@suklu.test'],
    email: 'student@suklu.test',
    role: 'student',
    fullName: 'Jean Étudiant',
    country: 'SN',
    createdAt: NOW,
  }, { merge: true });
  console.log('  ✓  Student profile');
  
  // Tutor profile
  await db.collection('users').doc(uids['tutor@suklu.test']).set({
    uid: uids['tutor@suklu.test'],
    email: 'tutor@suklu.test',
    role: 'tutor',
    fullName: 'Marie Tutrice',
    country: 'SN',
    hasTutorProfile: true,
    createdAt: NOW,
  }, { merge: true });
  
  // Tutor details
  await db.collection('tutor_profiles').doc(uids['tutor@suklu.test']).set({
    uid: uids['tutor@suklu.test'],
    fullName: 'Marie Tutrice',
    bio: 'Professeure de mathématiques avec 7 ans d\'expérience.',
    subjects: ['mathematics', 'physics'],
    gradeLevels: ['3ème', 'Terminale'],
    country: 'SN',
    currency: 'XOF',
    phoneNumber: '+221770000001',
    yearsExperience: 7,
    rating: 4.8,
    reviewCount: 24,
    isVerified: true,
    isActive: true,
    hourlyRate: 9000,
    createdAt: NOW,
  });
  console.log('  ✓  Tutor profile');
  
  // Parent profile
  await db.collection('users').doc(uids['parent@suklu.test']).set({
    uid: uids['parent@suklu.test'],
    email: 'parent@suklu.test',
    role: 'parent',
    fullName: 'Sophie Parente',
    country: 'SN',
    createdAt: NOW,
  }, { merge: true });
  console.log('  ✓  Parent profile');
  
  // Admin profile
  await db.collection('users').doc(uids['admin@suklu.test']).set({
    uid: uids['admin@suklu.test'],
    email: 'admin@suklu.test',
    role: 'super_admin',
    fullName: 'Admin Suklu',
    country: 'SN',
    createdAt: NOW,
  }, { merge: true });
  console.log('  ✓  Admin profile');
}

async function seedBookings(uids) {
  console.log('\n📅 Seeding bookings...');
  
  const studentUid = uids['student@suklu.test'];
  const tutorUid = uids['tutor@suklu.test'];
  
  // Pending booking
  await db.collection('bookings').add({
    studentId: studentUid,
    tutorId: tutorUid,
    subject: 'mathematics',
    grade: 'Terminale',
    duration: 60,
    requestedAt: NOW,
    scheduledDate: daysFromNow(2),
    status: 'pending',
    rate: 9000,
  });
  
  // Confirmed booking
  await db.collection('bookings').add({
    studentId: studentUid,
    tutorId: tutorUid,
    subject: 'physics',
    grade: 'Terminale',
    duration: 90,
    requestedAt: daysFromNow(-5),
    scheduledDate: daysFromNow(-2),
    status: 'confirmed',
    rate: 13000,
  });
  
  console.log('  ✓  2 bookings created');
}

async function seedParentLinking(uids) {
  console.log('\n🔗 Seeding parent-student linking...');
  
  const parentUid = uids['parent@suklu.test'];
  const studentUid = uids['student@suklu.test'];
  
  // Link record
  const linkId = `link_${Date.now()}`;
  await db.collection('parent_links').doc(linkId).set({
    parentId: parentUid,
    studentId: studentUid,
    status: 'active',
    createdAt: NOW,
  });
  
  console.log('  ✓  Parent-student link created');
}

async function main() {
  try {
    console.log('\n╔════════════════════════════════════════╗');
    console.log('║  🌱 Seeding Firebase Emulator Data     ║');
    console.log('╚════════════════════════════════════════╝');
    
    // 1. Create test accounts
    const uids = await createTestAccounts();
    
    // 2. Seed data
    await seedSubjects();
    await seedPlatformConfig();
    await seedUserProfiles(uids);
    await seedBookings(uids);
    await seedParentLinking(uids);
    
    console.log('\n✅ Seeding complete!\n');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Seeding failed:', error.message);
    process.exit(1);
  }
}

main();
