const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function loadCredential() {
  const fromEnv = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const localPath = path.join(__dirname, 'service-account.json');
  const credentialPath = fromEnv || (fs.existsSync(localPath) ? localPath : null);

  if (!credentialPath) {
    throw new Error(
      'Aucune cle de service trouvee. Definissez GOOGLE_APPLICATION_CREDENTIALS ou ajoutez scripts/service-account.json.',
    );
  }

  const serviceAccount = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
  return admin.credential.cert(serviceAccount);
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value.toDate === 'function') return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  return 0;
}

async function main() {
  const isDryRun = process.argv.includes('--dry-run');

  admin.initializeApp({
    credential: loadCredential(),
    projectId: 'suklu-prod',
  });

  const db = admin.firestore();
  const sessionsSnap = await db.collection('sessions').get();
  const links = new Map();

  for (const doc of sessionsSnap.docs) {
    const data = doc.data();
    const tutorId = (data.tutorId || '').toString().trim();
    const studentId = (data.studentId || '').toString().trim();
    if (!tutorId || !studentId) continue;

    const linkId = `${tutorId}_${studentId}`;
    const previous = links.get(linkId) || {
      id: linkId,
      tutorId,
      studentId,
      bookingIds: new Set(),
      sessionIds: new Set(),
      latestAt: 0,
      lastBookingId: '',
      lastSessionId: '',
    };

    if (data.bookingId) previous.bookingIds.add(String(data.bookingId));
    previous.sessionIds.add(doc.id);

    const latestAt = Math.max(
      toMillis(data.updatedAt),
      toMillis(data.scheduledAt),
      toMillis(data.startedAt),
      toMillis(data.createdAt),
    );

    if (latestAt >= previous.latestAt) {
      previous.latestAt = latestAt;
      previous.lastBookingId = data.bookingId ? String(data.bookingId) : previous.lastBookingId;
      previous.lastSessionId = doc.id;
    }

    links.set(linkId, previous);
  }

  if (links.size == 0) {
    console.log('Aucun lien tuteur-etudiant a backfiller.');
    return;
  }

  console.log(`Liens detectes: ${links.size}`);

  if (isDryRun) {
    for (const entry of links.values()) {
      console.log(
        `- ${entry.id}: ${entry.sessionIds.size} sessions, ${entry.bookingIds.size} reservations`,
      );
    }
    return;
  }

  let batch = db.batch();
  let ops = 0;

  for (const entry of links.values()) {
    const ref = db.collection('tutor_student_links').doc(entry.id);
    batch.set(
      ref,
      {
        id: entry.id,
        tutorId: entry.tutorId,
        studentId: entry.studentId,
        bookingIds: Array.from(entry.bookingIds),
        sessionIds: Array.from(entry.sessionIds),
        lastBookingId: entry.lastBookingId || null,
        lastSessionId: entry.lastSessionId || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    ops += 1;
    if (ops === 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
  }

  console.log(`Backfill termine: ${links.size} documents ecrits dans tutor_student_links.`);
}

main().catch((error) => {
  console.error('Echec du backfill tutor_student_links:', error);
  process.exitCode = 1;
});