import { onCall }      from 'firebase-functions/v2/https';
import { db, logger }  from '../shared/utils';

// ─────────────────────────────────────────────────────────────────────────────
// Platform Configuration
//
// A single Firestore document `/platform_config/global` is the source of truth
// for all configurable platform behaviour:
//   • pricing mode & rates
//   • supported countries / currencies
//   • Daily.co room mode (ephemeral | persistent)
//   • content moderation reviewer role list
//
// Mutations go through super_admin only (enforced by Firestore Rules).
// This callable exposes the config to authenticated clients (Flutter app).
// ─────────────────────────────────────────────────────────────────────────────

export const CONFIG_DOC = '/platform_config/global';

// ── TypeScript shape ──────────────────────────────────────────────────────────

export interface DurationRates {
  30: number;
  60: number;
  90: number;
}

export interface PricingConfig {
  mode: 'flat_rate' | 'tiered' | 'per_minute';
  // flat_rate: { [currency]: { [durationMin]: priceInCurrency } }
  flatRates:     Record<string, DurationRates>;
  // tiered: { [currency]: { [subjectCategory]: DurationRates, default: DurationRates } }
  tieredRates:   Record<string, Record<string, DurationRates>>;
  // per_minute: { [currency]: ratePerMinute }
  perMinuteRates: Record<string, number>;
}

export interface SupportedCountry {
  code:             string;  // ISO 3166-1 alpha-2
  name:             string;
  currency:         string;
  paymentProviders: string[];
}

export interface PlatformConfig {
  pricing:                  PricingConfig;
  roomMode:                 'ephemeral' | 'persistent';
  supportedCountries:       SupportedCountry[];
  contentModerationRoles:   string[];   // roles that can review flagged content
}

// ── Default config seeded on first deploy ────────────────────────────────────
export const DEFAULT_CONFIG: PlatformConfig = {
  pricing: {
    mode: 'flat_rate',
    flatRates: {
      XOF: { 30: 5000,  60: 9000,  90: 13000 },
      GNF: { 30: 50000, 60: 90000, 90: 130000 },
      XAF: { 30: 5000,  60: 9000,  90: 13000 },
    },
    tieredRates: {
      XOF: {
        mathematics: { 30: 7000, 60: 12000, 90: 17000 },
        sciences:    { 30: 7000, 60: 12000, 90: 17000 },
        languages:   { 30: 5000, 60: 9000,  90: 13000 },
        default:     { 30: 5000, 60: 9000,  90: 13000 },
      },
    },
    perMinuteRates: { XOF: 167, GNF: 1667, XAF: 167 },
  },
  roomMode: 'ephemeral',
  supportedCountries: [
    { code: 'SN', name: 'Sénégal',       currency: 'XOF', paymentProviders: ['wave', 'orange_money', 'flutterwave'] },
    { code: 'CI', name: "Côte d'Ivoire", currency: 'XOF', paymentProviders: ['orange_money', 'flutterwave'] },
    { code: 'ML', name: 'Mali',          currency: 'XOF', paymentProviders: ['orange_money', 'flutterwave'] },
    { code: 'BF', name: 'Burkina Faso',  currency: 'XOF', paymentProviders: ['orange_money', 'flutterwave'] },
    { code: 'GN', name: 'Guinée',        currency: 'GNF', paymentProviders: ['orange_money', 'flutterwave'] },
    { code: 'CM', name: 'Cameroun',      currency: 'XAF', paymentProviders: ['orange_money', 'flutterwave'] },
  ],
  contentModerationRoles: ['super_admin', 'academic_staff'],
};

// ── Helpers ───────────────────────────────────────────────────────────────────

export async function getPlatformConfig(): Promise<PlatformConfig> {
  const snap = await db().doc(CONFIG_DOC).get();
  if (!snap.exists) {
    // Seed default on first read
    await db().doc(CONFIG_DOC).set(DEFAULT_CONFIG);
    logger.info('platformConfig: seeded default config');
    return DEFAULT_CONFIG;
  }
  return snap.data() as PlatformConfig;
}

// ── Callable: getConfig ───────────────────────────────────────────────────────
// Authenticated clients call this to get the platform config (e.g., to display
// supported countries in the registration form).
export const getConfig = onCall(async (request) => {
  if (!request.auth) return { error: 'unauthenticated' };
  const config = await getPlatformConfig();
  // Strip server-only fields before sending to client
  const { contentModerationRoles: _, ...clientConfig } = config;
  return clientConfig;
});
