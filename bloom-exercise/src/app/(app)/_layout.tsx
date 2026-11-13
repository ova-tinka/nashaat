import { Redirect, Stack } from 'expo-router';
import { ActivityIndicator } from 'react-native';
import { Button, ErrorText, Panel, Screen } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { BloomProvider } from '../../lib/bloom-context';
import { MacCreditRecovery } from '../../components/mac-credit-recovery';
import { colors } from '../../theme';
import { supabase } from '../../lib/supabase';

export default function AppLayout() {
  const { session, loading, profileId, profileLoading, profileError, refreshProfile } = useAuth();
  if (loading || (session && profileLoading)) return <Screen><ActivityIndicator color={colors.accent} /></Screen>;
  if (!session) return <Redirect href="/sign-in" />;
  if (profileError || !profileId) return <Screen><Panel><ErrorText>{profileError ?? 'Profile unavailable.'}</ErrorText><Button label="Try again" onPress={() => void refreshProfile()} /><Button label="Sign out" secondary onPress={() => { void supabase?.auth.signOut({ scope: 'local' }); }} /></Panel></Screen>;
  return <BloomProvider key={`${session.user.id}:${profileId}`} userId={profileId}><MacCreditRecovery key={`${session.user.id}:${profileId}`} /><Stack screenOptions={{ headerShown: false }} /></BloomProvider>;
}
