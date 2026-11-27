import { revenueCatProfiles, revenueCatSubscriptions } from './revenuecat-billing.ts';
import { tapMinor, tapResult, verifyTapWebhook } from './tap-billing.ts';

const profile = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
const now = Date.parse('2026-06-01T12:00:00Z');

function assert(condition: unknown, detail: string): asserts condition {
  if (!condition) throw new Error(detail);
}

Deno.test('RevenueCat canonical customer ownership, environments, Play base-plan mapping and revocation', () => {
  const entry = {
    original_purchase_date: '2026-05-25T12:00:00Z', expires_date: '2026-06-22T12:00:00Z',
    is_sandbox: true, store: 'play_store', product_plan_identifier: 'month',
  };
  const payload = { subscriber: { original_app_user_id: profile, subscriptions: {
    'bloom-basic': entry,
    'bloom-premium': { ...entry, store: 'app_store', is_sandbox: false },
    'shared': { ...entry, store: 'app_store', ownership_type: 'FAMILY_SHARED' },
  } } };
  const result = revenueCatSubscriptions(payload, profile, true, now);
  assert(result.length === 1 && result[0].sku === 'bloom-basic:month', 'wrong store or plan');
  assert(result[0].status === 'active', 'active subscription lost');
  const only = (subscription: unknown) => ({ subscriber: { original_app_user_id: profile, subscriptions: { basic: subscription } } });
  const grace = revenueCatSubscriptions(only({
    ...entry, expires_date: '2026-06-01T11:00:00Z', grace_period_expires_date: '2026-06-04T12:00:00Z',
  }), profile, true, now);
  assert(grace[0].status === 'grace_period', 'provider grace not recognized');
  assert(revenueCatSubscriptions(only({ ...entry, refunded_at: '2026-06-01T10:00:00Z' }), profile, true, now)[0].status === 'revoked',
    'refund with revocation was not applied');
  try { revenueCatSubscriptions(payload, other, true, now); }
  catch { return; }
  throw new Error('RevenueCat alias acquired another profile’s subscription');
});

Deno.test('RevenueCat reconciles both sides of a transfer and ignores anonymous aliases', () => {
  const profiles = revenueCatProfiles({ type: 'TRANSFER', transferred_from: [profile, '$RCAnonymousID:fixture'],
    transferred_to: [other, other] });
  assert(profiles.join(',') === [profile, other].join(','), 'transfer lookup incomplete');
});

Deno.test('Tap preserves minor units across currencies and refuses ambiguous amounts', () => {
  assert(tapMinor(14.399, 'KWD') === 14399, 'incorrect three-digit rounding');
  assert(tapMinor(14, 'JPY') === 14, 'incorrect zero-digit rounding');
  try { tapMinor('14.399', 'USD'); } catch { return; }
  throw new Error('fractional minor unit was accepted');
});

Deno.test('Tap webhook verifies a deterministic hash and rejects status changes', async () => {
  const charge = {
    id: 'chg_fixture', object: 'charge', amount: 17.61, currency: 'USD', status: 'CAPTURED',
    live_mode: false, transaction: { created: 1770000000000 },
    reference: { gateway: 'fixture-gateway', payment: 'fixture-payment', order: profile },
  };
  const encoder = new TextEncoder();
  const secret = 'test-key-only';
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(
    'x_idchg_fixturex_amount17.61x_currencyUSDx_gateway_referencefixture-gatewayx_payment_referencefixture-paymentx_statusCAPTUREDx_created1770000000000',
  )));
  const signature = Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
  assert(await verifyTapWebhook(charge, signature, secret), 'valid Tap webhook was rejected');
  assert(!await verifyTapWebhook({ ...charge, status: 'DECLINED' }, signature, secret), 'tampered webhook was accepted');
  assert(tapResult(charge, false).values.state === 'captured', 'charge state mismatch');
  assert(tapResult({ ...charge, object: 'refund', status: 'ACCEPTED', charge_id: charge.id }, false).values.state === 'pending',
    'gateway acceptance marked refund as settled');
  try { tapResult(charge, true); } catch { return; }
  throw new Error('sandbox charge was accepted in production');
});
