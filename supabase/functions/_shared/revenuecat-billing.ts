import { record, str, uuid } from './billing.ts';

function iso(value: unknown): string | null {
  const timestamp = Date.parse(str(value));
  return Number.isFinite(timestamp) ? new Date(timestamp).toISOString() : null;
}

export function revenueCatProfiles(event: Record<string, unknown>): string[] {
  const ids = event.type === 'TRANSFER'
    ? [...[event.transferred_from, event.transferred_to].flat()]
    : [event.app_user_id, event.original_app_user_id, ...(Array.isArray(event.aliases) ? event.aliases : [])];
  return [...new Set(ids.filter((id): id is string => typeof id === 'string' && uuid.test(id)).map(id => id.toLowerCase()))];
}

export function revenueCatSubscriptions(snapshot: unknown, profile: string, sandbox: boolean, at: number) {
  const subscriber = record(record(snapshot).subscriber);
  if (!subscriber.subscriptions || typeof subscriber.subscriptions !== 'object') throw new Error('Invalid subscription snapshot');
  const original = str(subscriber.original_app_user_id);
  if (uuid.test(original) && original.toLowerCase() !== profile.toLowerCase()) {
    throw new Error('Subscription account ownership requires review');
  }
  return Object.entries(record(subscriber.subscriptions)).flatMap(([product, raw]) => {
    const entry = record(raw);
    if (!['app_store', 'play_store'].includes(str(entry.store)) || entry.is_sandbox !== sandbox) return [];
    if (entry.ownership_type === 'FAMILY_SHARED') return [];
    const start = iso(entry.original_purchase_date) ?? iso(entry.purchase_date);
    const end = iso(entry.expires_date);
    if (!start || !end) throw new Error('Invalid subscription period');
    const grace = iso(entry.grace_period_expires_date);
    const plan = str(entry.product_plan_identifier);
    const sku = plan && !product.includes(':') ? `${product}:${plan}` : product;
    const status = iso(entry.refunded_at) ? 'revoked'
      : Date.parse(end) > at ? 'active' : grace && Date.parse(grace) > at ? 'grace_period' : 'expired';
    return [{
      provider: entry.store, sku, subscription_ref: `${profile}:${sku}:${start}`, status,
      start_at: start, period_start: iso(entry.purchase_date) ?? start, end_at: end, grace_until: grace,
      cancel_at_end: Boolean(entry.unsubscribe_detected_at),
    }];
  });
}
