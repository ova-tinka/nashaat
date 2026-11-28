import { supabase } from './supabase';

export type BillingProviderName = 'app_store' | 'play_store' | 'tap';
export type MobileBillingProvider = Exclude<BillingProviderName, 'tap'>;
export type BillingPeriod = 'week' | 'month' | 'year';
export type BillingFeature = 'coach_chat' | 'coach_weekly' | 'study_tutor' | 'document_help' | 'mock_exam_assess' | 'read_reflection' | 'task_breakdown';
export type BillingProduct = {
  id: string;
  tier: 'basic' | 'premium';
  scope: 'individual' | 'household';
  period: BillingPeriod;
  provider: BillingProviderName;
  store_product: string;
  weekly_credits: number;
  seat_limit: number | null;
  currency: string | null;
  price_minor: number | null;
};
export type BillingSummary = {
  plan: (Pick<BillingProduct, 'tier' | 'scope' | 'period' | 'provider'> & {
    subscription_id: string; has_household: boolean; period_end: string; cancel_at_end: boolean; is_payer: boolean; status: string; overlapping: boolean;
  }) | null;
  store_providers?: MobileBillingProvider[];
  allowance: number;
  remaining: number;
  metered: boolean;
  can_access: boolean;
  next_refill_at: string | null;
  notice_at: string | null;
  enforcement_at: string | null;
  feature_costs: Record<BillingFeature, number>;
  recent_usage: { feature: BillingFeature; credits: number; created_at: string }[];
};
export type BillingCatalog = { enabled: boolean; products: BillingProduct[]; households: { id: string; name: string }[] };
export type BillingQuote = { amount_minor: number; recurring_minor: number; currency: string; period: BillingPeriod; kind: string };
export type BillingSeatList = { seat_limit: number; household_id: string; members: { profile_id: string; role: string; name: string | null; enabled: boolean }[] };
export type BillingHistory = {
  charges: { id: string; state: string; amount_minor: number; currency: string; created_at: string; receipt_url: string | null }[];
  refunds: { id: string; charge_id: string; state: string; amount_minor: number | null; review_note: string | null; created_at: string }[];
  scheduled: { product_id: string; period_end: string } | null;
  is_staff: boolean;
};
export type RefundReview = { id: string; reason: string; refundable_minor: number; currency: string; created_at: string };
export type Checkout = { id: string; checkout_url: string | null; state: string };

function client() {
  if (!supabase) throw new Error('Billing is unavailable.');
  return supabase;
}

export async function billingSummary(): Promise<BillingSummary> {
  const { data, error } = await client().rpc('bloom_billing_summary');
  if (error) throw error;
  return data;
}

export async function billingAccount<T>(action: string, input: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await client().rpc('bloom_billing_account', { p_action: action, p_input: input });
  if (error) throw new Error(error.message);
  return data as T;
}

export async function tapBilling<T>(action: string, input: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await client().functions.invoke<T>('bloom-tap', { body: { action, input } });
  if (error) {
    const details: unknown = await error.context?.json?.().catch(() => null);
    throw new Error(details && typeof details === 'object' && 'error' in details && typeof details.error === 'string'
      ? details.error : 'Billing is temporarily unavailable.');
  }
  return data as T;
}

export async function syncStoreBilling() {
  const { error } = await client().functions.invoke('bloom-revenuecat/sync', { body: {} });
  if (error) throw new Error('Purchase verification is still pending. Try refreshing shortly.');
}

export function money(minor: number, currency: string, locale: string): string {
  const format = new Intl.NumberFormat(locale, { style: 'currency', currency });
  return format.format(minor / 10 ** (format.resolvedOptions().maximumFractionDigits ?? 2));
}
