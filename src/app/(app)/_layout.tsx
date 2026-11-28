import { useEffect } from 'react';
import { Redirect, Stack, router, useGlobalSearchParams, usePathname, type Href } from 'expo-router';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { ActivityIndicator, Platform, StyleSheet, View, useWindowDimensions } from 'react-native';
import { Body, Button, ErrorText, Panel, Screen } from '../../components/bloom-ui';
import { BloomAppHeader, BloomDesktopNavigation, BloomDesktopSectionNavigation } from '../../components/app-shell';
import { useAuth } from '../../lib/auth';
import { buildSignInHref } from '../../lib/auth-return-path';
import { BillingProvider, useBilling } from '../../lib/billing-context';
import { useBloom, BloomProvider } from '../../lib/bloom-context';
import { MacCreditRecovery } from '../../components/mac-credit-recovery';
import { supabase } from '../../lib/supabase';
import { isChildRestrictedRoute } from '../../lib/route-access';
import { useLocale } from '../../lib/locale-context';
import { useBloomTheme } from '../../lib/theme-context';
import { ModuleVisibilityProvider } from '../../lib/module-visibility';
import { isMacDesktop, macosFilter } from '../../lib/macos-blocking';

export default function AppLayout() {
  const { theme } = useBloomTheme();
  const { session, loading, profileId, profileLoading, profileError, childProfile, assignedModules, refreshProfile } = useAuth();
  const pathname = usePathname();
  const { attempt, tap_id: tapId } = useGlobalSearchParams<{ attempt?: string; tap_id?: string }>();
  const { width } = useWindowDimensions();
  const desktop = isMacDesktop() || (Platform.OS === 'web' && width >= 1024);
  const immersive = pathname === '/session' || ['/apps/read/session', '/apps/read/session-complete', '/apps/study/active-session', '/apps/study/session-complete', '/apps/study/learning-check'].includes(pathname) || pathname.startsWith('/apps/read/reader/');
  if (loading || (session && profileLoading)) return <Screen><ActivityIndicator color={theme.colors.action} /></Screen>;
  if (!session) return <Redirect href={pathname === '/subscription' && attempt
    ? { pathname: '/sign-in', params: { checkout: attempt, tap_id: tapId } }
    : buildSignInHref(pathname) as Href} />;
  if (profileError || !profileId) return <Screen><Panel><ErrorText>{profileError ?? 'Profile unavailable.'}</ErrorText><Button label="Try again" onPress={() => void refreshProfile()} /><Button label="Sign out" secondary onPress={() => { void supabase?.auth.signOut({ scope: 'local' }); }} /></Panel></Screen>;
  if (isChildRestrictedRoute(pathname, childProfile, assignedModules)) return <Redirect href="/" />;
  return <BloomProvider key={`${session.user.id}:${profileId}`} userId={profileId}>
    <BillingProvider>
      <MacDeepLinkListener />
      <MacBalanceSync />
      <MacCreditRecovery key={`${session.user.id}:${profileId}`} />
      <ModuleVisibilityProvider key={`pillars:${profileId}`} profileId={profileId}>
        <View style={[styles.app, { backgroundColor: theme.colors.canvas }]}>
          {!immersive && <BloomAppHeader />}
          <View style={styles.workspace}>
            {desktop && !immersive && <BloomDesktopNavigation />}
            <View style={styles.routes}>
              {desktop && !immersive && <BloomDesktopSectionNavigation />}
              {!immersive && pathname === '/' && <BillingNotice />}
              <View style={styles.routeStack}><Stack screenOptions={{ headerShown: false }} /></View>
            </View>
          </View>
        </View>
      </ModuleVisibilityProvider>
    </BillingProvider>
  </BloomProvider>;
}

function BillingNotice() {
  const { summary } = useBilling();
  const { locale, language } = useLocale();
  if (!summary?.metered || summary.plan) return null;
  const arabic = language === 'ar';
  return <Panel>
    {summary.can_access && summary.enforcement_at
      ? <Body>{arabic ? 'ينتهي الوصول الانتقالي في' : 'Your transition access ends'} {
        new Date(summary.enforcement_at).toLocaleDateString(locale, { dateStyle: 'long' })
      }</Body>
      : <Body>{arabic ? 'تحتاج إلى اشتراك لبدء نشاط جديد.' : 'Choose a subscription to start new activities.'}</Body>}
    <Button label={arabic ? 'عرض الاشتراك' : 'View subscription'} secondary onPress={() => router.push('/subscription')} />
  </Panel>;
}

const styles = StyleSheet.create({
  app: { flex: 1 },
  workspace: { flex: 1, flexDirection: 'row' },
  routes: { flex: 1, minWidth: 0 },
  routeStack: { flex: 1, minWidth: 0 },
});

function MacDeepLinkListener() {
  useEffect(() => {
    if (!isMacDesktop()) return;
    let active = true;
    const navigate = (route: string | null) => {
      if (!active || !route || !route.startsWith('/focus')) return;
      router.push(route as Href);
    };
    void invoke<string | null>('take_pending_deep_link').then(navigate).catch(() => undefined);
    let unlisten: (() => void) | undefined;
    void listen<string>('bloom-deep-link', (event) => navigate(event.payload))
      .then((fn) => {
        if (active) unlisten = fn;
        else fn();
      })
      .catch(() => undefined);
    return () => {
      active = false;
      unlisten?.();
    };
  }, []);
  return null;
}

function MacBalanceSync() {
  const { creditsEnabled, creditBalance, loading } = useBloom();
  const roundedBalance = Math.max(0, Math.floor(creditBalance * 100) / 100);
  useEffect(() => {
    if (!isMacDesktop() || loading) return;
    void macosFilter(
      'syncDisplayBalance',
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      { creditsEnabled, balanceMinutes: roundedBalance },
    ).catch(() => undefined);
  }, [creditsEnabled, loading, roundedBalance]);
  return null;
}
