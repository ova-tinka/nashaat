import { createContext, useCallback, useContext, useEffect, useRef, useState, type PropsWithChildren } from 'react';
import { AppState, Platform } from 'react-native';
import { loadBloomData, updateCreditRules, updateCredits, type ActiveWorkout, type CreditSettings, type Subscription, type WorkoutAnalytics, type WorkoutPlan } from './bloom';
import { isMacDesktop } from './macos-blocking';
import { cancelBlockingRulesSync, syncBlockingRules, type BlockingRulesPlatform } from './blocking-rules-sync';
import type { ChildRule } from './family';

type BloomState = {
  plans: WorkoutPlan[];
  completedSessions: number;
  activeWorkout: ActiveWorkout | null;
  creditsEnabled: boolean;
  creditSettings: CreditSettings | null;
  creditBalance: number;
  workoutAnalytics: WorkoutAnalytics | null;
  subscription: Subscription | null;
  blockingRules: ChildRule[];
  blockingRulesSyncError: string | null;
  blockingRulesSyncedAt: number | null;
  blockingRulesSyncStatus: string | null;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  setCreditsEnabled: (enabled: boolean) => Promise<void>;
  saveCreditRules: (settings: Omit<CreditSettings, 'credits_enabled'>) => Promise<void>;
};
const BloomContext = createContext<BloomState | null>(null);

export function BloomProvider({ userId, children }: PropsWithChildren<{ userId: string }>) {
  const [plans, setPlans] = useState<WorkoutPlan[]>([]);
  const [completedSessions, setCompletedSessions] = useState(0);
  const [activeWorkout, setActiveWorkout] = useState<ActiveWorkout | null>(null);
  const [creditsEnabled, setCreditsEnabled] = useState(true);
  const [creditSettings, setCreditSettings] = useState<CreditSettings | null>(null);
  const [creditBalance, setCreditBalance] = useState(0);
  const [workoutAnalytics, setWorkoutAnalytics] = useState<WorkoutAnalytics | null>(null);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [blockingRules, setBlockingRules] = useState<{ userId: string; rules: ChildRule[] } | null>(null);
  const [blockingRulesSync, setBlockingRulesSync] = useState<{ userId: string; error: string | null; syncedAt: number | null; status: string | null }>({ userId, error: null, syncedAt: null, status: null });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const refreshVersion = useRef(0);

  const refresh = useCallback(async () => {
    const version = ++refreshVersion.current;
    setError(null);
    try {
      const data = await loadBloomData(userId);
      if (version !== refreshVersion.current) return;
      setPlans(data.plans);
      setCompletedSessions(data.completedSessions);
      setActiveWorkout(data.activeWorkout);
      setCreditsEnabled(data.creditsEnabled);
      setCreditSettings(data.creditSettings);
      setCreditBalance(data.creditBalance);
      setWorkoutAnalytics(data.workoutAnalytics);
      setSubscription(data.subscription);
    } catch {
      if (version === refreshVersion.current) setError('Could not load your Bloom data. Check your connection and try again.');
    } finally {
      if (version === refreshVersion.current) setLoading(false);
    }
  }, [userId]);

  // Load the authenticated user's data when this provider mounts.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void refresh(); }, [refresh]);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') void refresh();
    });
    return () => subscription.remove();
  }, [refresh]);

  useEffect(() => {
    const platform: BlockingRulesPlatform | null = isMacDesktop()
      ? 'macos'
      : Platform.OS === 'android' || Platform.OS === 'ios' ? Platform.OS : null;
    if (!platform) return;
    let mounted = true;
    let inFlight = false;
    let requestedAgain = false;
    let version = 0;

    const sync = async () => {
      if (platform !== 'macos' && AppState.currentState !== 'active') return;
      if (inFlight) { requestedAgain = true; return; }
      inFlight = true;
      const currentVersion = ++version;
      try {
        const result = await syncBlockingRules(userId, platform);
        if (!mounted || currentVersion !== version || !result) return;
        setBlockingRules({ userId, rules: result.rules });
        setBlockingRulesSync({ userId, error: null, syncedAt: Date.now(), status: result.nativeStatus });
      } catch {
        if (mounted && currentVersion === version) {
          setBlockingRulesSync((current) => ({ userId, error: 'Could not confirm parent-set blocking rules. Check protection and try again.', syncedAt: current.userId === userId ? current.syncedAt : null, status: current.userId === userId ? current.status : null }));
        }
      } finally {
        inFlight = false;
        if (mounted && requestedAgain) { requestedAgain = false; void sync(); }
      }
    };

    void sync();
    const interval = setInterval(() => { void sync(); }, 60_000);
    const lifecycle = AppState.addEventListener('change', (state) => { if (state === 'active') void sync(); });
    return () => {
      mounted = false;
      version += 1;
      cancelBlockingRulesSync(userId, platform);
      clearInterval(interval);
      lifecycle.remove();
    };
  }, [userId]);

  async function changeCredits(enabled: boolean) {
    await updateCredits(userId, enabled);
    refreshVersion.current += 1;
    setCreditsEnabled(enabled);
    setCreditSettings((current) => current ? { ...current, credits_enabled: enabled } : current);
  }

  async function saveCreditRules(settings: Omit<CreditSettings, 'credits_enabled'>) {
    await updateCreditRules(userId, settings);
    refreshVersion.current += 1;
    setCreditSettings((current) => current ? { ...current, ...settings } : current);
  }

  return <BloomContext.Provider value={{ plans, completedSessions, activeWorkout, creditsEnabled, creditSettings, creditBalance, workoutAnalytics, subscription,
    blockingRules: blockingRules?.userId === userId ? blockingRules.rules : [],
    blockingRulesSyncError: blockingRulesSync.userId === userId ? blockingRulesSync.error : null,
    blockingRulesSyncedAt: blockingRulesSync.userId === userId ? blockingRulesSync.syncedAt : null,
    blockingRulesSyncStatus: blockingRulesSync.userId === userId ? blockingRulesSync.status : null,
    loading, error, refresh, setCreditsEnabled: changeCredits, saveCreditRules }}>{children}</BloomContext.Provider>;
}

export function useBloom() {
  const context = useContext(BloomContext);
  if (!context) throw new Error('BloomProvider is missing');
  return context;
}
