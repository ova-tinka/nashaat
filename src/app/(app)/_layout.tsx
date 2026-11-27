import { Redirect, router, Stack, useGlobalSearchParams, usePathname } from 'expo-router';
import { ActivityIndicator, Platform, StyleSheet, View, useWindowDimensions } from 'react-native';
import { Body, Button, ErrorText, Panel, Screen } from '../../components/bloom-ui';
import { BloomAppHeader, BloomDesktopNavigation, BloomDesktopSectionNavigation } from '../../components/app-shell';
import { useAuth } from '../../lib/auth';
import { BillingProvider, useBilling } from '../../lib/billing-context';
import { BloomProvider } from '../../lib/bloom-context';
import { MacCreditRecovery } from '../../components/mac-credit-recovery';
import { supabase } from '../../lib/supabase';
import { isChildRestrictedRoute } from '../../lib/route-access';
import { useLocale } from '../../lib/locale-context';
import { useBloomTheme } from '../../lib/theme-context';
import { ModuleVisibilityProvider } from '../../lib/module-visibility';
import { isMacDesktop } from '../../lib/macos-blocking';

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
    ? { pathname: '/sign-in', params: { checkout: attempt, tap_id: tapId } } : '/sign-in'} />;
  if (profileError || !profileId) return <Screen><Panel><ErrorText>{profileError ?? 'Profile unavailable.'}</ErrorText><Button label="Try again" onPress={() => void refreshProfile()} /><Button label="Sign out" secondary onPress={() => { void supabase?.auth.signOut({ scope: 'local' }); }} /></Panel></Screen>;
  if (isChildRestrictedRoute(pathname, childProfile, assignedModules)) return <Redirect href="/" />;
  return <BloomProvider key={`${session.user.id}:${profileId}`} userId={profileId}>
    <BillingProvider>
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
