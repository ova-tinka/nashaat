import { admin, userClient } from '../_shared/supabase.ts';
import { json, providerFetch, record, requiredEnv, secureMatch, str, uuid } from '../_shared/billing.ts';
import { revenueCatProfiles, revenueCatSubscriptions } from '../_shared/revenuecat-billing.ts';

function sandboxMode() {
  const mode = requiredEnv('BLOOM_BILLING_ENVIRONMENT');
  if (mode !== 'sandbox' && mode !== 'production') throw new Error('Invalid billing environment');
  return mode === 'sandbox';
}

async function sync(profile: string, eventId?: string, eventType?: string) {
  const started = Date.now();
  const response = await providerFetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(profile)}`,
    requiredEnv('BLOOM_REVENUECAT_SECRET_KEY'),
  );
  if (!response.ok) throw new Error('RevenueCat customer lookup failed');
  const rows = revenueCatSubscriptions(await response.json(), profile, sandboxMode(), started);
  const { error } = await admin.rpc('bloom_apply_revenuecat', {
    p_profile: profile, p_fetched_at: new Date(started).toISOString(), p_rows: rows,
    p_event_id: eventId ?? null, p_event_type: eventType ?? null,
  });
  if (error) throw error;
}

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ error: 'Method unavailable' }, 405);
  const action = new URL(request.url).pathname.split('/').pop();
  const bearer = request.headers.get('authorization') ?? '';
  try {
    if (action === 'webhook') {
      if (!secureMatch(bearer, `Bearer ${requiredEnv('BLOOM_REVENUECAT_WEBHOOK_TOKEN')}`)) {
        return json({ error: 'Unauthorized' }, 401);
      }
      const event = record(record(await request.json()).event);
      if (event.type === 'TEST') return json({ received: true });
      if (event.environment && event.environment !== (sandboxMode() ? 'SANDBOX' : 'PRODUCTION')) {
        return json({ received: true });
      }
      const id = str(event.id);
      const type = str(event.type);
      if (!id || !type) return json({ error: 'Invalid event' }, 400);
      for (const profile of revenueCatProfiles(event)) {
        await sync(profile, `${id}:${profile}`, type);
      }
      return json({ received: true });
    }
    if (action !== 'sync' || !bearer.startsWith('Bearer ')) return json({ error: 'Unauthorized' }, 401);
    const token = bearer.slice(7);
    const client = userClient(token);
    const identity = await client.auth.getUser(token);
    if (identity.error || !identity.data.user) return json({ error: 'Unauthorized' }, 401);
    const { data, error } = await client.rpc('bloom_current_profile');
    const profile = str(data?.profile_id);
    if (error || !uuid.test(profile) || data.child_profile) return json({ error: 'Purchases are managed by the payer' }, 403);
    await sync(profile);
    return json({ synced: true });
  } catch {
    return json({ error: 'Subscription verification is temporarily unavailable' }, 503);
  }
});
