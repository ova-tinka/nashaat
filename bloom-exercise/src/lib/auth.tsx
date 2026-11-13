import type { Session } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useRef, useState, type PropsWithChildren } from 'react';
import { AppState, Platform } from 'react-native';
import { supabase } from './supabase';

type ProfileState = { accountId: string; profileId: string | null; managedChild: boolean; childProfile: boolean; error: string | null };
type AuthState = { session: Session | null; loading: boolean; configured: boolean; profileId: string | null;
  managedChild: boolean; childProfile: boolean; profileLoading: boolean; profileError: string | null; refreshProfile: () => Promise<void> };
const AuthContext = createContext<AuthState>({ session: null, loading: true, configured: false, profileId: null,
  managedChild: false, childProfile: false, profileLoading: false, profileError: null, refreshProfile: async () => {} });

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(Boolean(supabase));
  const [profile, setProfile] = useState<ProfileState | null>(null);
  const [profileBusy, setProfileBusy] = useState(false);
  const profileVersion = useRef(0);
  const accountId = session?.user.id;

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let mounted = true;
    let receivedEvent = false;
    const { data: { subscription } } = client.auth.onAuthStateChange((_event, nextSession) => {
      receivedEvent = true;
      if (mounted) {
        setSession(nextSession);
        setLoading(false);
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
    if (!accountId || !supabase) { setProfile(null); setProfileBusy(false); return; }
    setProfileBusy(true);
    try {
      const { data, error } = await supabase.rpc('bloom_current_profile');
      if (error || typeof data?.profile_id !== 'string' || typeof data?.managed_child !== 'boolean' || typeof data?.child_profile !== 'boolean') throw new Error('Profile unavailable');
      if (profileVersion.current === version) setProfile({ accountId, profileId: data.profile_id, managedChild: data.managed_child, childProfile: data.child_profile, error: null });
    } catch {
      if (profileVersion.current === version) setProfile({ accountId, profileId: null, managedChild: false, childProfile: false, error: 'Could not load your Bloom profile. Check your connection and try again.' });
    } finally { if (profileVersion.current === version) setProfileBusy(false); }
  }, [accountId]);

  // Profile identity may differ from the Auth account after email linking.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void refreshProfile(); return () => { profileVersion.current += 1; }; }, [refreshProfile]);
  const current = profile?.accountId === accountId ? profile : null;

  return <AuthContext.Provider value={{ session, loading, configured: Boolean(supabase), profileId: current?.profileId ?? null,
    managedChild: current?.managedChild ?? false, childProfile: current?.childProfile ?? false, profileLoading: Boolean(accountId && (!current || profileBusy)),
    profileError: current?.error ?? null, refreshProfile }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
