import { admin, userClient } from '../_shared/supabase.ts';
import { json, providerFetch, record, requiredEnv, secureMatch, str, uuid } from '../_shared/billing.ts';
import { currencyDigits, tapResult, verifyTapWebhook } from '../_shared/tap-billing.ts';

const customerActions = new Set([
  'quote','checkout','history','checkout_status','cancel','resume','schedule','card_update',
  'refund_request','refund_queue','refund_decision','play_offer',
]);

async function db(action: string, input = {}, profile: string | null = null) {
  const { data, error } = await admin.rpc('bloom_billing_tap', { p_profile: profile, p_action: action, p_input: input });
  if (error) throw error;
  return data;
}

async function tap(path: string, body?: Record<string, unknown>) {
  const response = await providerFetch(`https://api.tap.company/v2/${path}`, requiredEnv('BLOOM_TAP_SECRET_KEY'),
    body ? 'POST' : 'GET', body);
  if (!response.ok) throw new Error('Tap transaction unavailable');
  return record(await response.json());
}

function callback() {
  return { url: `${requiredEnv('BLOOM_BILLING_FUNCTION_BASE').replace(/\/$/, '')}/bloom-tap/webhook` };
}

async function verifyAndSave(payload: unknown, expected?: string) {
  const mode = requiredEnv('BLOOM_BILLING_ENVIRONMENT');
  if (mode !== 'sandbox' && mode !== 'production') throw new Error('Invalid billing environment');
  const { action, values } = tapResult(payload, mode === 'production');
  if (expected && values.id.toLowerCase() !== expected.toLowerCase()) throw new Error('Unexpected payment reference');
  return db(action, {
    ...values,
    variable_agreement: Deno.env.get('BLOOM_TAP_VARIABLE_RENEWALS') === 'true',
  });
}

function pathFor(providerRef: string): string {
  if (/^chg_[a-z0-9]+$/i.test(providerRef)) return 'charges/';
  if (/^re_[a-z0-9]+$/i.test(providerRef)) return 'refunds/';
  if (/^auth_[a-z0-9]+$/i.test(providerRef)) return 'authorize/';
  throw new Error('Invalid Tap reference');
}

async function retrieve(providerRef: string, expected?: string) {
  const payload = await tap(pathFor(providerRef) + encodeURIComponent(providerRef));
  if (payload.id !== providerRef) throw new Error('Unexpected Tap reference');
  return verifyAndSave(payload, expected);
}

async function processCharge(id: string, email?: string) {
  const attempt = record(await db('claim_charge', { id }));
  if (!attempt.id) return;
  if (attempt.provider_ref) return retrieve(str(attempt.provider_ref), id);
  const agreement = record(attempt.agreement);
  const renewal = attempt.kind === 'renewal';
  // An abandoned interactive checkout can be reconciled by reference or webhook,
  // but a background worker must never create another hosted payment session.
  if (!renewal && !email) return;
  let source = 'src_card';
  if (renewal) {
    const token = await tap('tokens', { saved_card: { card_id: agreement.card_ref, customer_id: agreement.customer_ref } });
    source = str(token.id);
    if (!source) throw new Error('Renewal token unavailable');
  }
  const currency = str(attempt.currency);
  const billingSite = requiredEnv('BLOOM_BILLING_WEB_ORIGIN');
  const redirect = new URL('/subscription', billingSite);
  redirect.searchParams.set('attempt', id);
  const payload = await tap(attempt.kind === 'card_update' ? 'authorize' : 'charges', {
    amount: Number(attempt.amount_minor) / 10 ** currencyDigits(currency), currency,
    customer_initiated: !renewal, threeDSecure: !renewal, save_card: !renewal,
    description: attempt.kind === 'card_update' ? 'Bloom card verification' : 'Bloom subscription',
    source: { id: source },
    customer: agreement.customer_ref ? { id: agreement.customer_ref } : { first_name: 'Bloom member', email },
    ...(renewal ? { payment_agreement: { id: agreement.agreement_ref } } : { redirect: { url: redirect.href } }),
    ...(attempt.kind === 'card_update' ? { auto: { type: 'VOID', time: 1 } } : {}),
    reference: { order: id, transaction: id, idempotent: id },
    post: callback(),
  });
  return verifyAndSave(payload, id);
}

async function processRefund(id: string) {
  const refund = record(await db('claim_refund', { id }));
  if (!refund.id) return;
  if (refund.provider_ref) return retrieve(str(refund.provider_ref), id);
  const currency = str(refund.currency);
  const payload = await tap('refunds', {
    charge_id: refund.charge_ref,
    currency, amount: Number(refund.amount_minor) / 10 ** currencyDigits(currency),
    reason: 'requested_by_customer', reference: { order: id, transaction: id, idempotent: id }, post: callback(),
  });
  return verifyAndSave(payload, id);
}

async function runWorker() {
  const work = record(await db('due'));
  const ids = (value: unknown): string[] => Array.isArray(value) ? value.filter(id => typeof id === 'string' && uuid.test(id)) : [];
  const renewals = await Promise.allSettled(ids(work.subscriptions).map(id => db('claim_renewal', { id })));
  const results = await Promise.allSettled([
    ...[...new Set([...ids(work.attempts), ...renewals.flatMap(result =>
      result.status === 'fulfilled' && typeof result.value === 'string' ? [result.value] : [],
    )])].map(id => processCharge(id)),
    ...ids(work.refunds).map(processRefund),
  ]);
  return {
    handled: results.length,
    failed: [...renewals, ...results].filter(result => result.status === 'rejected').length,
  };
}

Deno.serve(async request => {
  const actionPath = new URL(request.url).pathname.split('/').pop();
  const bearer = request.headers.get('authorization') ?? '';
  const origin = request.headers.get('origin');
  const allowedOrigin = Deno.env.get('BLOOM_BILLING_WEB_ORIGIN');
  const cors = origin && origin === allowedOrigin ? {
    'access-control-allow-origin': origin, 'access-control-allow-methods': 'POST, OPTIONS', vary: 'Origin',
    'access-control-allow-headers': 'authorization, apikey, x-client-info, content-type',
  } : undefined;
  const reply = (data: unknown, status = 200) => json(data, status, cors);
  if (request.method === 'OPTIONS') return new Response(null, { status: cors ? 204 : 403, headers: cors });
  if (request.method !== 'POST') return reply({ error: 'Method unavailable' }, 405);
  try {
    if (actionPath === 'worker') {
      if (!secureMatch(bearer, `Bearer ${requiredEnv('BLOOM_BILLING_WORKER_TOKEN')}`)) return reply({ error: 'Unauthorized' }, 401);
      const result = await runWorker();
      return reply(result, result.failed ? 503 : 200);
    }
    if (actionPath === 'webhook') {
      const signature = request.headers.get('hashstring') ?? '';
      if (!/^[0-9a-f]{64}$/i.test(signature)) return reply({ error: 'Unauthorized' }, 401);
      const payload = record(await request.json());
      const trusted = await verifyTapWebhook(payload, signature, requiredEnv('BLOOM_TAP_SECRET_KEY')).catch(() => false);
      if (!trusted) return reply({ error: 'Unauthorized' }, 401);
      await retrieve(str(payload.id));
      return reply({ received: true });
    }
    if (!bearer.startsWith('Bearer ')) return reply({ error: 'Unauthorized' }, 401);
    const token = bearer.slice(7);
    const client = userClient(token);
    const identity = await client.auth.getUser(token);
    if (identity.error || !identity.data.user) return reply({ error: 'Unauthorized' }, 401);
    const { data, error } = await client.rpc('bloom_current_profile');
    const profile = str(data?.profile_id);
    if (error || !uuid.test(profile) || data.child_profile) return reply({ error: 'Billing is managed by the payer' }, 403);
    const body = record(await request.json());
    const action = str(body.action);
    if (!customerActions.has(action)) return reply({ error: 'Billing action unavailable' }, 400);
    const input = record(body.input);
    if (action === 'card_update') input.verification_minor = Number(requiredEnv('BLOOM_TAP_CARD_CHECK_MINOR'));
    const result = await db(action, input, profile);
    if (action === 'checkout' || action === 'card_update') {
      const attempt = record(result);
      const id = str(attempt.id);
      const checkout = record(await processCharge(id, identity.data.user.email));
      return reply({ id, state: checkout.state ?? attempt.state, checkout_url: checkout.checkout_url ?? attempt.checkout_url });
    }
    if (action === 'checkout_status') {
      const attempt = record(result);
      const tapId = str(input.tap_id) || str(attempt.provider_ref);
      let verified: unknown;
      if (tapId && attempt.state !== 'captured') verified = await retrieve(tapId, str(attempt.id));
      return reply({ state: record(verified).state ?? attempt.state });
    }
    return reply(result);
  } catch (error) {
    const value = record(error);
    const code = str(value.code);
    return code === 'P0001' || code === '42501'
      ? reply({ error: str(value.message) }, 409)
      : reply({ error: 'Billing is temporarily unavailable' }, 503);
  }
});
