import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, useCallback, useContext, useEffect, useRef, useState, type PropsWithChildren } from 'react';
import { AppState } from 'react-native';
import { useAuth } from './auth';
import { billingSummary, type BillingSummary } from './billing';

export const BILLING_CACHE_MAX_AGE_MS = 24 * 60 * 60 * 1000;

export type CachedBillingRecord = {
  cachedAt: number;
  summary: BillingSummary;
};

export function billingCacheKey(profileId: string): string {
  return `bloom:billing-cache:v1:${profileId}`;
}

export function isCachedBillingUsable(record: CachedBillingRecord | null, nowMillis = Date.now()): boolean {
  if (!record || typeof record.cachedAt !== 'number' || !Number.isFinite(record.cachedAt)) return false;
  if (nowMillis < record.cachedAt || nowMillis - record.cachedAt > BILLING_CACHE_MAX_AGE_MS) return false;
  const plan = record.summary?.plan;
  if (plan?.period_end) {
    const endMillis = Date.parse(plan.period_end);
    if (Number.isFinite(endMillis) && nowMillis >= endMillis) return false;
  }
  if (!plan && record.summary?.enforcement_at) {
    const enforcementMillis = Date.parse(record.summary.enforcement_at);
    if (Number.isFinite(enforcementMillis) && nowMillis >= enforcementMillis) return false;
  }
  return true;
}

const BillingContext = createContext<{
  summary: BillingSummary | null;
  error: boolean;
  stale: boolean;
  loading: boolean;
  refresh: () => Promise<void>;
}>({
  summary: null,
  error: false,
  stale: false,
  loading: true,
  refresh: async () => undefined,
});

export function BillingProvider({ children }: PropsWithChildren) {
  const { profileId } = useAuth();
  const [summary, setSummary] = useState<BillingSummary | null>(null);
  const request = useRef(0);
  const [error, setError] = useState(false);
  const [stale, setStale] = useState(false);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    const version = ++request.current;
    try {
      const value = await billingSummary();
      if (version !== request.current) return;
      setSummary(value);
      setError(false);
      setStale(false);
      setLoading(false);
      if (profileId) {
        const record: CachedBillingRecord = { cachedAt: Date.now(), summary: value };
        await AsyncStorage.setItem(billingCacheKey(profileId), JSON.stringify(record)).catch(() => undefined);
      }
    } catch {
      if (version !== request.current) return;
      let usedCache = false;
      if (profileId) {
        try {
          const raw = await AsyncStorage.getItem(billingCacheKey(profileId));
          if (raw) {
            const parsed = JSON.parse(raw) as CachedBillingRecord;
            if (isCachedBillingUsable(parsed)) {
              setSummary(parsed.summary);
              setStale(true);
              usedCache = true;
            }
          }
        } catch {
          // Ignore malformed cache
        }
      }
      if (!usedCache) {
        setStale(false);
      }
      setError(true);
      setLoading(false);
    }
  }, [profileId]);

  useEffect(() => {
    void Promise.resolve().then(refresh);
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') void refresh();
    });
    return () => sub.remove();
  }, [refresh]);

  return (
    <BillingContext.Provider value={{ summary, error, stale, loading, refresh }}>
      {children}
    </BillingContext.Provider>
  );
}

export function useBilling() {
  return useContext(BillingContext);
}
