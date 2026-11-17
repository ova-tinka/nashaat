import { useState } from 'react';
import { router, type Href } from 'expo-router';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { CreditRulesEditor } from '../../../components/credit-rules-editor';
import { DatabaseDiagnostics } from '../../../components/database-diagnostics';
import { useBloom } from '../../../lib/bloom-context';
import { supabase } from '../../../lib/supabase';
import { useAuth } from '../../../lib/auth';
import { colors } from '../../../theme';
import { closeDeviceAccess } from '../../../lib/close-device-access';

export default function SettingsScreen() {
  const { profileId, managedChild } = useAuth();
  const { creditsEnabled, creditSettings, subscription, loading, error, refresh, setCreditsEnabled, saveCreditRules } = useBloom();
  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  async function changeCredits(value: boolean) {
    setSaving(true); setActionError(null);
    try { await setCreditsEnabled(value); }
    catch { setActionError('Could not save your setting. Please try again.'); }
    finally { setSaving(false); }
  }
  async function signOut() {
    try { if (profileId) await closeDeviceAccess(profileId); }
    catch { setActionError('Could not close screen-time access. Please try again.'); return; }
    const { error: signOutError } = await supabase!.auth.signOut();
    if (signOutError) setActionError('Could not sign out. Please try again.');
  }
  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Your account</Eyebrow><Heading>Profile & settings</Heading></View>
    {loading && <ActivityIndicator color={colors.accent} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" secondary onPress={() => void refresh()} /></Panel>}
    {actionError && <ErrorText>{actionError}</ErrorText>}
    {profileId && <DatabaseDiagnostics key={profileId} userId={profileId} />}
    {!loading && !error && <>
      <Panel><Eyebrow>Screen time</Eyebrow><View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Earn screen-time credits</Label><Body>{managedChild ? 'Your parent manages this setting.' : 'Enabled by default. You can change this whenever you like.'}</Body></View><Switch accessibilityLabel="Earn screen-time credits" value={creditsEnabled} onValueChange={(value) => void changeCredits(value)} disabled={saving || managedChild} trackColor={{ false: colors.border, true: colors.accent }} /></View></Panel>
      {creditSettings && !managedChild && <CreditRulesEditor key={JSON.stringify(creditSettings)} settings={creditSettings} onSave={saveCreditRules} />}
      <Panel><Eyebrow>Subscription</Eyebrow><Label>{subscription ? `Status: ${subscription.status.replaceAll('_', ' ')}` : 'No subscription found'}</Label><Body>Purchase and plan management are not connected yet.</Body></Panel>
      <Panel><Eyebrow>Family</Eyebrow><Label>Parent and child accounts</Label><Body>Connect accounts with an invitation.</Body><Button label="Manage family" secondary onPress={() => router.push('/family' as Href)} /></Panel>
      <Panel><Eyebrow>Profile switching</Eyebrow><Label>Parent PIN</Label><Body>Set up a device PIN or return to a child profile.</Body><Button label="Switch profiles" secondary onPress={() => router.push('/profile-switch' as Href)} /></Panel>
      <Panel><Eyebrow>AI coach</Eyebrow><Label>Movement advice</Label><Body>Choose your privacy preferences and review suggested workout changes.</Body><Button label="Open coach" secondary onPress={() => router.push('/coach' as Href)} /></Panel>
      <Panel><Eyebrow>Competitions</Eyebrow><Label>Move together</Label><Body>Join friends and earn recognition for completed workouts.</Body><Button label="Open competitions" secondary onPress={() => router.push('/competitions' as Href)} /></Panel>
    </>}
    <Button label="Sign out" secondary onPress={() => void signOut()} />
  </Screen>;
}
