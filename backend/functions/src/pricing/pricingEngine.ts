import { getPlatformConfig, PlatformConfig } from '../config/platformConfig';

// ─────────────────────────────────────────────────────────────────────────────
// Pricing Engine
//
// calculatePrice() is called by createBooking.ts to set BookingDocument.totalAmount.
// It reads the live platform config so pricing can be updated without a deploy.
//
// Subject categories (for tiered mode) are broad groupings — the actual
// subjectId is mapped to a category here. Extend the map as new subjects
// are added to the catalogue.
// ─────────────────────────────────────────────────────────────────────────────

const SUBJECT_CATEGORY_MAP: Record<string, string> = {
  mathematics:    'mathematics',
  maths:          'mathematics',
  algebra:        'mathematics',
  geometry:       'mathematics',
  physics:        'sciences',
  chemistry:      'sciences',
  biology:        'sciences',
  'physique-chimie': 'sciences',
  svt:            'sciences',
  french:         'languages',
  français:       'languages',
  english:        'languages',
  anglais:        'languages',
  arabic:         'languages',
  arabe:          'languages',
};

function subjectToCategory(subjectId: string): string {
  return SUBJECT_CATEGORY_MAP[subjectId.toLowerCase()] ?? 'default';
}

export async function calculatePrice(params: {
  subjectId:       string;
  durationMinutes: 30 | 60 | 90;
  currency:        string;
  config?:         PlatformConfig; // pass pre-fetched config to avoid extra Firestore read
}): Promise<number> {
  const config = params.config ?? await getPlatformConfig();
  const { subjectId, durationMinutes, currency } = params;
  const pricing = config.pricing;
  const cur     = currency in pricing.flatRates ? currency : 'XOF'; // fallback

  switch (pricing.mode) {
    case 'flat_rate': {
      const rates = pricing.flatRates[cur] ?? pricing.flatRates['XOF'];
      return rates[durationMinutes] ?? 0;
    }
    case 'tiered': {
      const category    = subjectToCategory(subjectId);
      const currRates   = pricing.tieredRates[cur] ?? pricing.tieredRates['XOF'];
      const subjectRates = currRates?.[category] ?? currRates?.['default'];
      return subjectRates?.[durationMinutes] ?? 0;
    }
    case 'per_minute': {
      const rate = pricing.perMinuteRates[cur] ?? pricing.perMinuteRates['XOF'] ?? 0;
      return Math.round(rate * durationMinutes);
    }
    default:
      return 0;
  }
}
