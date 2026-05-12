import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { getPlatformConfig } from '../config/platformConfig';
import { GroupSessionSlot, UserRole } from '../shared/types';
import { db, logger, serverTs } from '../shared/utils';

interface CreateGroupSlotRequest {
  subjectId: string;
  gradeLevel: string;
  scheduledAt: string;
  durationMinutes: 30 | 60 | 90;
  maxParticipants: number;
  description?: string;
}

function roundUpToHundred(value: number): number {
  return Math.ceil(value / 100) * 100;
}

export const createGroupSlot = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const callerId = request.auth.uid;
    const callerRole = request.auth.token['role'] as UserRole | undefined;
    if (callerRole !== 'tutor') {
      throw new HttpsError('permission-denied', 'Seuls les tuteurs peuvent créer un créneau de groupe');
    }

    const data = request.data as CreateGroupSlotRequest;
    if (!data.subjectId || !data.gradeLevel || !data.scheduledAt) {
      throw new HttpsError('invalid-argument', 'subjectId, gradeLevel et scheduledAt sont requis');
    }
    if (![30, 60, 90].includes(data.durationMinutes)) {
      throw new HttpsError('invalid-argument', 'durationMinutes doit être 30, 60 ou 90');
    }
    if (!Number.isInteger(data.maxParticipants) || data.maxParticipants < 2 || data.maxParticipants > 20) {
      throw new HttpsError('invalid-argument', 'maxParticipants doit être compris entre 2 et 20');
    }

    const scheduledAtDate = new Date(data.scheduledAt);
    if (Number.isNaN(scheduledAtDate.getTime())) {
      throw new HttpsError('invalid-argument', 'scheduledAt invalide (format ISO 8601 attendu)');
    }

    const tutorProfileSnap = await db().collection('tutor_profiles').doc(callerId).get();
    if (!tutorProfileSnap.exists || tutorProfileSnap.data()?.['isActive'] !== true) {
      throw new HttpsError('failed-precondition', 'Le profil tuteur est inactif ou introuvable');
    }

    const config = await getPlatformConfig();
    const currency = 'XOF';
    const ratesByDuration = config.pricing.flatRates[currency];
    if (!ratesByDuration) {
      throw new HttpsError('failed-precondition', `Tarification ${currency} indisponible`);
    }

    const basePrice = ratesByDuration[data.durationMinutes];
    if (typeof basePrice !== 'number' || basePrice <= 0) {
      throw new HttpsError('failed-precondition', 'Tarif introuvable pour cette durée');
    }

    const discounted = basePrice * 0.75;
    const pricePerStudent = roundUpToHundred(discounted);

    const slotRef = db().collection('group_session_slots').doc();
    const slot: GroupSessionSlot = {
      id: slotRef.id,
      tutorId: callerId,
      subjectId: data.subjectId,
      gradeLevel: data.gradeLevel,
      scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAtDate),
      durationMinutes: data.durationMinutes,
      maxParticipants: data.maxParticipants,
      currentParticipants: 0,
      enrolledStudentIds: [],
      pricePerStudent,
      currency,
      status: 'open',
      description: data.description?.trim() || undefined,
      createdAt: serverTs(),
      updatedAt: serverTs(),
    };

    await slotRef.set(slot);

    logger.info('createGroupSlot: slot created', {
      slotId: slotRef.id,
      tutorId: callerId,
      subjectId: data.subjectId,
      gradeLevel: data.gradeLevel,
      maxParticipants: data.maxParticipants,
      pricePerStudent,
    });

    return {
      slotId: slotRef.id,
      pricePerStudent,
      currency,
    };
  },
);
