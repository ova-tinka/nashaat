import { createContext, useCallback, useContext, useEffect, useRef, useState, type PropsWithChildren } from 'react';
import { AppState } from 'react-native';
import { billingSummary, type BillingSummary } from './billing';

const BillingContext = createContext<{ summary: BillingSummary | null; error: boolean; refresh: () => Promise<void> }>({
  summary: null, error: false, refresh: async () => undefined,
});

export function BillingProvider({ children }: PropsWithChildren) {
  const [summary, setSummary] = useState<BillingSummary | null>(null);
  const request = useRef(0);
  const [error, setError] = useState(false);
  const refresh = useCallback(() => {
    const version = ++request.current;
    return billingSummary().then(value => {
      if (version !== request.current) return;
      setSummary(value);
      setError(false);
    }, () => {
      if (version === request.current) setError(true);
    });
  }, []);
  useEffect(() => {
    void Promise.resolve().then(refresh);
    const sub = AppState.addEventListener('change', state => { if (state === 'active') void refresh(); });
    return () => sub.remove();
  }, [refresh]);
  return <BillingContext.Provider value={{ summary, error, refresh }}>{children}</BillingContext.Provider>;
}

export function useBilling() { return useContext(BillingContext); }
