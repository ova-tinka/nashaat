import { authenticateActiveUser, userClient } from '../_shared/supabase.ts';
import { json, record, requiredEnv, secureMatch, str, uuid } from '../_shared/billing.ts';
import { billingSandbox, queueBillingWebhook } from '../_shared/billing-webhooks.ts';
import { revenueCatProfiles } from '../_shared/revenuecat-billing.ts';
import { reportEdgeException } from '../_shared/sentry.ts';
import { syncRevenueCat } from '../_shared/revenuecat-sync.ts';

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
      if (event.environment && event.environment !== (billingSandbox() ? 'SANDBOX' : 'PRODUCTION')) {
        return json({ received: true });
      }
      const id = str(event.id);
      const type = str(event.type);
      if (!id || !type) return json({ error: 'Invalid event' }, 400);
      for (const profile of revenueCatProfiles(event)) {
        await queueBillingWebhook('revenuecat', `${id}:${profile}`, type, profile);
      }
      return json({ received: true });
    }
    if (action !== 'sync' || !bearer.startsWith('Bearer ')) return json({ error: 'Unauthorized' }, 401);
    const token = bearer.slice(7);
    const active = await authenticateActiveUser(token);
    if (!active) return json({ error: 'Unauthorized' }, 401);
    const client = userClient(token);
    const { data, error } = await client.rpc('bloom_current_profile');
    const profile = str(data?.profile_id);
    if (error || !uuid.test(profile) || data.child_profile) return json({ error: 'Purchases are managed by the payer' }, 403);
    await syncRevenueCat(profile);
    return json({ synced: true });
  } catch (error) {
    await reportEdgeException('bloom-revenuecat', error, { action });
    return json({ error: 'Subscription verification is temporarily unavailable' }, 503);
  }
});
