/**
 * seed-test-data.js
 *
 * Seeds realistic test data in Firestore for Suklu:
 *   - Tutor profiles (linked to tutor@suklu.test)
 *   - Subjects catalogue
 *   - Bookings (pending, confirmed, completed)
 *   - Sessions
 *   - Progress records
 *   - Parent–student link (parent@suklu.test ↔ student@suklu.test)
 *   - Platform config
 *
 * Run: node scripts/seed-test-data.js
 * Prerequisite: GOOGLE_APPLICATION_CREDENTIALS must be set
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'suklu-prod' });

const db  = admin.firestore();
const NOW = admin.firestore.Timestamp.now();

function daysFromNow(n) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return admin.firestore.Timestamp.fromDate(d);
}

// ── UIDs from the seed-test-accounts script ───────────────────────────────────
// We resolve them dynamically so the script is idempotent.
async function getUid(email) {
  const user = await admin.auth().getUserByEmail(email);
  return user.uid;
}

// ── Subjects catalogue ────────────────────────────────────────────────────────
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

// ── Platform config ────────────────────────────────────────────────────────────
const PLATFORM_CONFIG = {
  pricing: {
    mode: 'flat_rate',
    flatRates: {
      XOF: { 30: 5000,  60: 9000,  90: 13000 },
      GNF: { 30: 50000, 60: 90000, 90: 130000 },
      XAF: { 30: 5000,  60: 9000,  90: 13000 },
    },
    tieredRates:    {},
    perMinuteRates: {},
  },
  roomMode: 'ephemeral',
  supportedCountries: [
    { code: 'SN', name: 'Sénégal',          currency: 'XOF', paymentProviders: ['wave', 'orange_money'] },
    { code: 'CI', name: "Côte d'Ivoire",    currency: 'XOF', paymentProviders: ['wave', 'orange_money', 'flutterwave'] },
    { code: 'CM', name: 'Cameroun',         currency: 'XAF', paymentProviders: ['orange_money', 'flutterwave'] },
    { code: 'GN', name: 'Guinée Conakry',   currency: 'GNF', paymentProviders: ['orange_money'] },
  ],
  contentModerationRoles: ['super_admin'],
};

// ── Grade levels ──────────────────────────────────────────────────────────────
const GRADE_LEVELS = ['6ème', '5ème', '4ème', '3ème', 'Seconde', 'Première', 'Terminale', 'Licence 1', 'Licence 2'];

async function main() {
  console.log('\n🌱  Seeding test data on suklu-prod...\n');

  // ── Resolve UIDs ────────────────────────────────────────────────────────────
  const [studentUid, tutorUid, parentUid, adminUid] = await Promise.all([
    getUid('student@suklu.test'),
    getUid('tutor@suklu.test'),
    getUid('parent@suklu.test'),
    getUid('admin@suklu.test'),
  ]);
  console.log('  ✓  UIDs resolved');

  const batch1 = db.batch();

  // ── Platform config ─────────────────────────────────────────────────────────
  batch1.set(db.doc('platform_config/global'), PLATFORM_CONFIG, { merge: true });
  console.log('  ✓  Platform config');

  // ── Subjects catalogue ───────────────────────────────────────────────────────
  for (const subject of SUBJECTS) {
    batch1.set(db.doc(`subjects/${subject.id}`), {
      ...subject,
      isActive:  true,
      createdAt: NOW,
    }, { merge: true });
  }
  console.log('  ✓  Subjects catalogue (8 matières)');

  await batch1.commit();

  // ── Tutor profile ────────────────────────────────────────────────────────────
  const tutorProfileData = {
    uid:              tutorUid,
    userId:           tutorUid,
    fullName:         'Marie Tutrice',
    bio:              'Professeure de mathématiques et physique avec 7 ans d\'expérience. Spécialisée dans la préparation au Baccalauréat et aux concours d\'entrée aux grandes écoles.',
    subjects:         ['mathematics', 'physics', 'chemistry'],
    gradeLevels:      ['3ème', 'Seconde', 'Première', 'Terminale'],
    country:          'SN',
    currency:         'XOF',
    phoneNumber:      '+221770000001',
    diplomas:         ['Master en Mathématiques – UCAD Dakar', 'CAPES Mathématiques'],
    yearsExperience:  7,
    rating:           4.8,
    reviewCount:      24,
    isVerified:       true,
    isActive:         true,
    hourlyRate:       9000,
    availableSlots: [
      { dayOfWeek: 1, startHour: 9,  endHour: 12 },
      { dayOfWeek: 1, startHour: 14, endHour: 18 },
      { dayOfWeek: 3, startHour: 9,  endHour: 18 },
      { dayOfWeek: 5, startHour: 14, endHour: 18 },
      { dayOfWeek: 6, startHour: 9,  endHour: 12 },
    ],
    createdAt: NOW,
    updatedAt: NOW,
  };
  await db.doc(`tutor_profiles/${tutorUid}`).set(tutorProfileData, { merge: true });
  console.log('  ✓  Tutor profile');

  // Update tutor user doc with tutor profile flag
  await db.doc(`users/${tutorUid}`).set({ hasTutorProfile: true, country: 'SN' }, { merge: true });

  // ── Tutor application (approved) ─────────────────────────────────────────────
  const tutorAppId = `app_${tutorUid}`;
  await db.doc(`tutor_applications/${tutorAppId}`).set({
    id:                    tutorAppId,
    userId:                tutorUid,
    fullName:              'Marie Tutrice',
    phoneNumber:           '+221770000001',
    subjects:              ['mathematics', 'physics', 'chemistry'],
    gradeLevels:           ['3ème', 'Seconde', 'Première', 'Terminale'],
    bio:                   'Professeure expérimentée spécialisée en sciences exactes.',
    country:               'SN',
    diplomas:              ['Master en Mathématiques – UCAD Dakar'],
    yearsExperience:       7,
    status:                'approved',
    backgroundCheckStatus: 'clear',
    documents:             [],
    reviewedBy:            adminUid,
    reviewedAt:            NOW,
    createdAt:             NOW,
    updatedAt:             NOW,
  }, { merge: true });
  console.log('  ✓  Tutor application (approved)');

  // ── Student profile extras ────────────────────────────────────────────────────
  await db.doc(`users/${studentUid}`).set({
    country:    'SN',
    gradeLevel: 'Terminale',
    subjects:   ['mathematics', 'physics', 'french'],
    parentIds:  [parentUid],
  }, { merge: true });

  // ── Parent–student link ───────────────────────────────────────────────────────
  const linkId = `link_${parentUid}_${studentUid}`;
  await db.doc(`parent_link_requests/${linkId}`).set({
    id:           linkId,
    parentId:     parentUid,
    studentId:    studentUid,
    studentEmail: 'student@suklu.test',
    relationship: 'parent',
    status:       'approved',
    reviewedBy:   adminUid,
    reviewedAt:   NOW,
    createdAt:    NOW,
    updatedAt:    NOW,
  }, { merge: true });
  await db.doc(`users/${parentUid}`).set({ linkedStudentIds: [studentUid] }, { merge: true });
  console.log('  ✓  Parent–student link (approved)');

  // ── Bookings ──────────────────────────────────────────────────────────────────
  const bookings = [
    {
      id:              'booking_001',
      studentId:       studentUid,
      tutorId:         tutorUid,
      subjectId:       'mathematics',
      scheduledAt:     daysFromNow(2),
      durationMinutes: 60,
      sessionType:     'one_on_one',
      status:          'confirmed',
      totalAmount:     9000,
      currency:        'XOF',
      createdAt:       NOW,
      updatedAt:       NOW,
    },
    {
      id:              'booking_002',
      studentId:       studentUid,
      tutorId:         tutorUid,
      subjectId:       'physics',
      scheduledAt:     daysFromNow(5),
      durationMinutes: 90,
      sessionType:     'one_on_one',
      status:          'pending',
      totalAmount:     13000,
      currency:        'XOF',
      createdAt:       NOW,
      updatedAt:       NOW,
    },
    {
      id:              'booking_003',
      studentId:       studentUid,
      tutorId:         tutorUid,
      subjectId:       'mathematics',
      scheduledAt:     daysFromNow(-7),
      durationMinutes: 60,
      sessionType:     'one_on_one',
      status:          'completed',
      sessionId:       'session_001',
      totalAmount:     9000,
      currency:        'XOF',
      createdAt:       daysFromNow(-8),
      updatedAt:       daysFromNow(-7),
    },
    {
      id:              'booking_004',
      studentId:       studentUid,
      tutorId:         tutorUid,
      subjectId:       'physics',
      scheduledAt:     daysFromNow(-14),
      durationMinutes: 30,
      sessionType:     'one_on_one',
      status:          'completed',
      sessionId:       'session_002',
      totalAmount:     5000,
      currency:        'XOF',
      parentId:        parentUid,
      createdAt:       daysFromNow(-15),
      updatedAt:       daysFromNow(-14),
    },
    {
      id:              'booking_005',
      studentId:       studentUid,
      tutorId:         tutorUid,
      subjectId:       'french',
      scheduledAt:     daysFromNow(-3),
      durationMinutes: 60,
      sessionType:     'one_on_one',
      status:          'cancelled',
      totalAmount:     9000,
      currency:        'XOF',
      createdAt:       daysFromNow(-4),
      updatedAt:       daysFromNow(-3),
    },
  ];

  const batchBookings = db.batch();
  for (const b of bookings) {
    batchBookings.set(db.doc(`bookings/${b.id}`), b, { merge: true });
  }
  await batchBookings.commit();
  console.log('  ✓  Bookings (2 à venir, 2 terminées, 1 annulée)');

  // ── Sessions (completed) ──────────────────────────────────────────────────────
  const sessions = [
    {
      id:              'session_001',
      bookingId:       'booking_003',
      tutorId:         tutorUid,
      studentId:       studentUid,
      subjectId:       'mathematics',
      startedAt:       daysFromNow(-7),
      endedAt:         daysFromNow(-7),
      durationMinutes: 60,
      dailyRoomUrl:    'https://suklu.daily.co/session_001_test',
      status:          'completed',
      tutorNotes:      'Bonne progression sur les fonctions dérivées. À revoir: intégrales.',
      createdAt:       daysFromNow(-7),
      updatedAt:       daysFromNow(-7),
    },
    {
      id:              'session_002',
      bookingId:       'booking_004',
      tutorId:         tutorUid,
      studentId:       studentUid,
      subjectId:       'physics',
      startedAt:       daysFromNow(-14),
      endedAt:         daysFromNow(-14),
      durationMinutes: 30,
      dailyRoomUrl:    'https://suklu.daily.co/session_002_test',
      status:          'completed',
      tutorNotes:      'Introduction aux lois de Newton. Exercices sur la 2ème loi à compléter.',
      createdAt:       daysFromNow(-14),
      updatedAt:       daysFromNow(-14),
    },
  ];

  const batchSessions = db.batch();
  for (const s of sessions) {
    batchSessions.set(db.doc(`sessions/${s.id}`), s, { merge: true });
  }
  await batchSessions.commit();
  console.log('  ✓  Sessions (2 terminées)');

  // ── Progress records ──────────────────────────────────────────────────────────
  const progressRecords = [
    {
      id:         `progress_${studentUid}_mathematics`,
      studentId:  studentUid,
      tutorId:    tutorUid,
      subjectId:  'mathematics',
      sessionCount:     3,
      totalMinutes:     180,
      averageRating:    4.5,
      lastSessionAt:    daysFromNow(-7),
      topicsCompleted:  ['Fonctions', 'Dérivées', 'Limites'],
      topicsInProgress: ['Intégrales', 'Suites'],
      createdAt:        NOW,
      updatedAt:        daysFromNow(-7),
    },
    {
      id:         `progress_${studentUid}_physics`,
      studentId:  studentUid,
      tutorId:    tutorUid,
      subjectId:  'physics',
      sessionCount:     1,
      totalMinutes:     30,
      averageRating:    4.0,
      lastSessionAt:    daysFromNow(-14),
      topicsCompleted:  ['Lois de Newton (intro)'],
      topicsInProgress: ['Dynamique', 'Énergie'],
      createdAt:        NOW,
      updatedAt:        daysFromNow(-14),
    },
  ];

  const batchProgress = db.batch();
  for (const p of progressRecords) {
    batchProgress.set(db.doc(`progress/${p.id}`), p, { merge: true });
  }
  await batchProgress.commit();
  console.log('  ✓  Progress records (maths + physique)');

  // ── Payments ──────────────────────────────────────────────────────────────────
  const payments = [
    {
      id:                    'payment_001',
      bookingId:             'booking_003',
      userId:                studentUid,
      amount:                9000,
      currency:              'XOF',
      provider:              'wave',
      providerTransactionId: 'WAVE_TEST_001',
      status:                'success',
      processedAt:           daysFromNow(-7),
      createdAt:             daysFromNow(-7),
      webhookPayload:        { test: true },
    },
    {
      id:                    'payment_002',
      bookingId:             'booking_004',
      userId:                parentUid,
      amount:                5000,
      currency:              'XOF',
      provider:              'orange_money',
      providerTransactionId: 'OM_TEST_001',
      status:                'success',
      processedAt:           daysFromNow(-14),
      createdAt:             daysFromNow(-14),
      webhookPayload:        { test: true },
    },
  ];

  const batchPayments = db.batch();
  for (const p of payments) {
    batchPayments.set(db.doc(`payments/${p.id}`), p, { merge: true });
  }
  await batchPayments.commit();
  console.log('  ✓  Paiements (Wave + Orange Money)');

  // ── Tutor reviews ─────────────────────────────────────────────────────────────
  const reviews = [
    {
      id:        'review_001',
      tutorId:   tutorUid,
      studentId: studentUid,
      sessionId: 'session_001',
      rating:    5,
      comment:   'Excellente session! Marie explique très clairement et s\'adapte bien au niveau.',
      createdAt: daysFromNow(-7),
    },
    {
      id:        'review_002',
      tutorId:   tutorUid,
      studentId: studentUid,
      sessionId: 'session_002',
      rating:    4,
      comment:   'Bonne introduction à la physique. Un peu rapide sur certains concepts.',
      createdAt: daysFromNow(-14),
    },
  ];

  const batchReviews = db.batch();
  for (const r of reviews) {
    batchReviews.set(db.doc(`reviews/${r.id}`), r, { merge: true });
  }
  await batchReviews.commit();
  console.log('  ✓  Avis tuteur (2 avis)');

  // Summary
  console.log('\n✅  Seed terminé!\n');
  console.log('Données créées:');
  console.log('─────────────────────────────────────────────────────────────');
  console.log('  📚  8 matières dans le catalogue');
  console.log('  👩‍🏫  1 profil tuteur (Marie Tutrice, Maths/Physique/Chimie)');
  console.log('  👨‍🎓  1 profil étudiant (Terminale, lié à parent)');
  console.log('  👪  1 lien parent–étudiant approuvé');
  console.log('  📅  5 réservations (2 à venir, 2 terminées, 1 annulée)');
  console.log('  🎥  2 sessions terminées');
  console.log('  📈  2 fiches de progression (maths + physique)');
  console.log('  💳  2 paiements (Wave + Orange Money)');
  console.log('  ⭐  2 avis');
  console.log('  ⚙️   Config plateforme (tarifs XOF/GNF/XAF)');
  console.log('─────────────────────────────────────────────────────────────\n');

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌  Seed failed:', err.message);
  process.exit(1);
});
