import { admin } from './supabase.ts';
import { providerFetch, requiredEnv } from './billing.ts';
import { billingSandbox } from './billing-webhooks.ts';
import { revenueCatSubscriptions } from './revenuecat-billing.ts';

export async function syncRevenueCat(profile: string, eventId?: string, eventType?: string) {
  const started = Date.now();
  const response = await providerFetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(profile)}`,
    requiredEnv('BLOOM_REVENUECAT_SECRET_KEY'),
  );
  if (!response.ok) throw new Error('RevenueCat customer lookup failed');
  const rows = revenueCatSubscriptions(await response.json(), profile, billingSandbox(), started);
  const { error } = await admin.rpc('bloom_apply_revenuecat', {
    p_profile: profile, p_fetched_at: new Date(started).toISOString(), p_rows: rows,
    p_event_id: eventId ?? null, p_event_type: eventType ?? null,
  });
  if (error) throw error;
}
