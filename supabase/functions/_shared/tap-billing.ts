import { record, secureMatch, str, uuid } from './billing.ts';

export function currencyDigits(currency: string): number {
  return new Intl.NumberFormat('en', { style: 'currency', currency }).resolvedOptions().maximumFractionDigits ?? 2;
}

export function tapMinor(amount: unknown, currency: string): number {
  if (!/^[A-Z]{3}$/.test(currency) || (typeof amount !== 'number' && typeof amount !== 'string')) {
    throw new Error('Invalid payment amount');
  }
  const value = Number(amount) * 10 ** currencyDigits(currency);
  const minor = Math.round(value);
  if (!Number.isSafeInteger(minor) || minor <= 0 || Math.abs(value - minor) > 0.000001) {
    throw new Error('Invalid payment amount');
  }
  return minor;
}

export async function verifyTapWebhook(payload: unknown, signature: string, secret: string): Promise<boolean> {
  const object = record(payload);
  const currency = str(object.currency);
  const reference = record(object.reference);
  const created = record(object.transaction).created ?? object.created;
  if (!['charge', 'authorize', 'refund'].includes(str(object.object)) || !str(object.id)
    || !str(object.status) || !created || !/^[A-Z]{3}$/.test(currency)) return false;
  const amount = (tapMinor(object.amount, currency) / 10 ** currencyDigits(currency)).toFixed(currencyDigits(currency));
  const canonical = 'x_id' + object.id + 'x_amount' + amount + 'x_currency' + currency +
    'x_gateway_reference' + str(reference.gateway) + 'x_payment_reference' + str(reference.payment) +
    'x_status' + object.status + 'x_created' + created;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(canonical)));
  const expected = Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
  return secureMatch(expected, signature.toLowerCase());
}

export function tapResult(payload: unknown, live: boolean) {
  const object = record(payload);
  const references = record(object.reference);
  const kind = str(object.object);
  const id = str(references.order) || str(references.transaction);
  const providerRef = str(object.id);
  const status = str(object.status);
  const currency = str(object.currency);
  if (object.live_mode !== live || !uuid.test(id) || !providerRef || !status) throw new Error('Unexpected Tap transaction');
  const result = { id, provider_ref: providerRef, currency, amount_minor: tapMinor(object.amount, currency) };
  if (kind === 'refund') {
    return { action: 'refund_result', values: {
      ...result, charge_ref: str(object.charge_id),
      state: status === 'REFUNDED' ? 'refunded'
        : ['DECLINED', 'FAILED', 'RESTRICTED', 'REJECTED', 'CANCELLED', 'CANCELED'].includes(status) ? 'failed' : 'pending',
    } };
  }
  if (kind !== 'charge' && kind !== 'authorize') throw new Error('Unexpected Tap resource');
  const captured = status === 'CAPTURED' || (kind === 'authorize' && status === 'AUTHORIZED');
  return { action: 'charge_result', values: {
    ...result, state: captured ? 'captured'
      : ['DECLINED', 'FAILED', 'RESTRICTED', 'ABANDONED', 'CANCELLED', 'CANCELED', 'VOID', 'TIMEDOUT'].includes(status) ? 'declined' : 'pending',
    customer_ref: str(record(object.customer).id), card_ref: str(record(object.card).id),
    agreement_ref: str(record(object.payment_agreement).id),
    checkout_url: httpsUrl(record(object.transaction).url),
    receipt_url: httpsUrl(record(object.receipt).url),
  } };
}

export function httpsUrl(value: unknown): string | null {
  try {
    const url = new URL(str(value));
    return url.protocol === 'https:' && !url.username && !url.password ? url.href : null;
  } catch {
    return null;
  }
}
