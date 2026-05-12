import * as admin from 'firebase-admin';

// Initialize once — all other modules import via shared/utils.ts helpers
admin.initializeApp();

export { initUserProfile }    from './auth/onUserCreate';
export { updateMyRole }       from './auth/updateMyRole';
export { createBooking }      from './booking/createBooking';
export { updateBookingStatus } from './booking/updateBookingStatus';
export { initiatePayment }    from './payments/initiatePayment';
export { simulatePayment }    from './payments/simulatePayment';
export { flutterwaveWebhook } from './payments/flutterwaveWebhook';
export { orangeMoneyWebhook } from './payments/orangeMoneyWebhook';
export { waveWebhook }        from './payments/waveWebhook';
export { getConfig }          from './config/platformConfig';
export { submitApplication }  from './tutor/submitApplication';
export { reviewApplication }  from './tutor/reviewApplication';
export { requestParentLink }  from './linking/requestParentLink';
export { verifyParentLink }   from './linking/verifyParentLink';
export { createDailyRoom }    from './sessions/createDailyRoom';
export { createGroupSlot }    from './sessions/createGroupSlot';
export { enrollInGroupSession } from './sessions/enrollInGroupSession';
export { submitReview }       from './sessions/submitReview';
export { sessionReminders }   from './sessions/sessionReminders';
export { onTutorMessage }     from './sessions/onTutorMessage';
export { triggerSessionSummary, generateSessionSummary } from './sessions/triggerSessionSummary';
