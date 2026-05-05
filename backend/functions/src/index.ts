import * as admin from 'firebase-admin';

// Initialize once — all other modules import via shared/utils.ts helpers
admin.initializeApp();

export { onUserCreate }       from './auth/onUserCreate';
export { createBooking }      from './booking/createBooking';
export { flutterwaveWebhook } from './payments/flutterwaveWebhook';
export { orangeMoneyWebhook } from './payments/orangeMoneyWebhook';
export { waveWebhook }        from './payments/waveWebhook';
export { getConfig }          from './config/platformConfig';
export { submitApplication }  from './tutor/submitApplication';
export { reviewApplication }  from './tutor/reviewApplication';
export { requestParentLink }  from './linking/requestParentLink';
export { verifyParentLink }   from './linking/verifyParentLink';
export { createDailyRoom }    from './sessions/createDailyRoom';
