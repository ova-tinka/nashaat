import type { Session } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useRef, useState, type PropsWithChildren } from 'react';
import { AppState, Platform } from 'react-native';
import { supabase } from './supabase';
import { loadMyModuleAssignments } from './module-assignments';
import { resetAnalytics, setAnalyticsIdentity } from './analytics';
import { setSentryUser } from './sentry';
import type { ModuleKey } from '../theme';

type ProfileState = { accountId: string; profileId: string | null; managedChild: boolean; childProfile: boolean; assignedModules: ModuleKey[]; error: string | null };
type AuthState = {
  session: Session | null;
  loading: boolean;
  configured: boolean;
  passwordRecovery: boolean;
  clearPasswordRecovery: () => void;
  profileId: string | null;
  managedChild: boolean;
  childProfile: boolean;
  assignedModules: ModuleKey[];
  profileLoading: boolean;
  profileError: string | null;
  refreshProfile: () => Promise<void>;
};
const AuthContext = createContext<AuthState>({
  session: null,
  loading: true,
  configured: false,
  passwordRecovery: false,
  clearPasswordRecovery: () => {},
  profileId: null,
  managedChild: false,
  childProfile: false,
  assignedModules: [],
  profileLoading: false,
  profileError: null,
  refreshProfile: async () => {},
});

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(Boolean(supabase));
  const [passwordRecovery, setPasswordRecovery] = useState(false);
  const [profile, setProfile] = useState<ProfileState | null>(null);
  const profileVersion = useRef(0);
  const accountId = session?.user.id;

  const clearPasswordRecovery = useCallback(() => {
    setPasswordRecovery(false);
  }, []);

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let mounted = true;
    let receivedEvent = false;
    const { data: { subscription } } = client.auth.onAuthStateChange((event, nextSession) => {
      receivedEvent = true;
      if (mounted) {
        setSession(nextSession);
        setLoading(false);
        if (event === 'PASSWORD_RECOVERY') {
          setPasswordRecovery(true);
        } else if (event === 'SIGNED_OUT') {
          setPasswordRecovery(false);
          setSentryUser(null);
          resetAnalytics();
        }
      }
    });
    void client.auth.getSession().then(({ data }) => {
      if (mounted && !receivedEvent) {
        setSession(data.session);
        setLoading(false);
      }
    }).catch(() => {
      if (mounted && !receivedEvent) setLoading(false);
    });

    const appState = Platform.OS === 'web' ? null : AppState.addEventListener('change', (state) => {
      if (state === 'active') client.auth.startAutoRefresh();
      else client.auth.stopAutoRefresh();
    });
    if (Platform.OS !== 'web' && AppState.currentState === 'active') client.auth.startAutoRefresh();
    return () => {
      mounted = false;
      subscription.unsubscribe();
      appState?.remove();
      if (Platform.OS !== 'web') client.auth.stopAutoRefresh();
    };
  }, []);

  const refreshProfile = useCallback(async () => {
    const version = ++profileVersion.current;
    if (!accountId || !supabase) {
      setProfile(null);
      setSentryUser(null);
      setAnalyticsIdentity(null);
      return;
    }
    try {
      const { data, error } = await supabase.rpc('bloom_current_profile');
      if (error || typeof data?.profile_id !== 'string' || typeof data?.managed_child !== 'boolean' || typeof data?.child_profile !== 'boolean') throw new Error('Profile unavailable');
      const assignedModules = data.child_profile ? await loadMyModuleAssignments() : [];
      if (profileVersion.current === version) {
        setProfile({ accountId, profileId: data.profile_id, managedChild: data.managed_child, childProfile: data.child_profile, assignedModules, error: null });
        setSentryUser(data.profile_id, { childProfile: data.child_profile });
        setAnalyticsIdentity(data.profile_id, { childProfile: data.child_profile });
      }
    } catch {
      if (profileVersion.current === version) {
        setProfile({ accountId, profileId: null, managedChild: false, childProfile: false, assignedModules: [], error: 'Could not load your Bloom profile. Check your connection and try again.' });
      }
    }
  }, [accountId]);

  // Profile identity may differ from the Auth account after email linking.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void refreshProfile(); return () => { profileVersion.current += 1; }; }, [refreshProfile]);
  useEffect(() => {
    if (!accountId || Platform.OS === 'web') return;
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') void refreshProfile();
    });
    return () => subscription.remove();
  }, [accountId, refreshProfile]);
  const current = profile?.accountId === accountId ? profile : null;

  return <AuthContext.Provider value={{
    session,
    loading,
    configured: Boolean(supabase),
    passwordRecovery,
    clearPasswordRecovery,
    profileId: current?.profileId ?? null,
    managedChild: current?.managedChild ?? false,
    childProfile: current?.childProfile ?? false,
    assignedModules: current?.assignedModules ?? [],
    profileLoading: Boolean(accountId && !current),
    profileError: current?.error ?? null,
    refreshProfile,
  }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
