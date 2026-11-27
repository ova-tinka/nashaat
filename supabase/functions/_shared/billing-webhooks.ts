import { admin } from './supabase.ts';
import { requiredEnv } from './billing.ts';

export type BillingWebhook = {
  id: string;
  provider: 'revenuecat' | 'tap';
  provider_event_id: string;
  event_type: string;
  webhook_reference: string;
};

export function billingSandbox() {
  const mode = requiredEnv('BLOOM_BILLING_ENVIRONMENT');
  if (mode !== 'sandbox' && mode !== 'production') throw new Error('Invalid billing environment');
  return mode === 'sandbox';
}

export async function queueBillingWebhook(
  provider: BillingWebhook['provider'], eventId: string, eventType: string, reference: string,
) {
  const { error } = await admin.rpc('bloom_queue_billing_webhook', {
    p_provider: provider, p_event_id: eventId, p_event_type: eventType, p_reference: reference,
  });
  if (error) throw error;
}

export async function claimBillingWebhooks(): Promise<BillingWebhook[]> {
  const { data, error } = await admin.rpc('bloom_claim_billing_webhooks');
  if (error) throw error;
  return (data ?? []) as BillingWebhook[];
}

export async function finishBillingWebhook(id: string) {
  const { error } = await admin.rpc('bloom_finish_billing_webhook', { p_id: id });
  if (error) throw error;
}
