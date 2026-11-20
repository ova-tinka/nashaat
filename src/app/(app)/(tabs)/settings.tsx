import { useState } from 'react';
import { router, type Href } from 'expo-router';
import { ActivityIndicator, Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { CreditRulesEditor } from '../../../components/credit-rules-editor';
import { GrowthRewardControls } from '../../../components/growth-reward-controls';
import { GrowthMemoryControls } from '../../../components/growth-memory-controls';
import { DatabaseDiagnostics } from '../../../components/database-diagnostics';
import { useBloom } from '../../../lib/bloom-context';
import { supabase } from '../../../lib/supabase';
import { useAuth } from '../../../lib/auth';
import { closeDeviceAccess } from '../../../lib/close-device-access';
import { useBloomTheme } from '../../../lib/theme-context';
import { useModuleVisibility } from '../../../lib/module-visibility';
import { moduleManifest } from '../../../lib/module-manifest';
import type { ThemeMode } from '../../../theme';

const appearanceOptions: { mode: ThemeMode; title: string; shortLabel: string }[] = [
  { mode: 'light', title: 'Light', shortLabel: 'Light' },
  { mode: 'highContrast', title: 'High contrast', shortLabel: 'High contrast' },
];

export default function SettingsScreen() {
  const { profileId, managedChild, childProfile, assignedModules } = useAuth();
  const { creditsEnabled, creditSettings, subscription, loading, error, refresh, setCreditsEnabled, saveCreditRules } = useBloom();
  const { mode, setMode, theme } = useBloomTheme();
  const { visibleModules, loaded: visibilityLoaded, setModuleVisibility } = useModuleVisibility();
  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [showEarningRules, setShowEarningRules] = useState(false);
  const [showDiagnostics, setShowDiagnostics] = useState(false);

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

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Your account</Eyebrow>
      <Heading>Settings</Heading>
      <Body>Manage your Bloom experience, connected devices and screen-time preferences.</Body>
    </View>

    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" variant="secondary" onPress={() => void refresh()} /></Panel>}
    {actionError && <ErrorText>{actionError}</ErrorText>}

    {!loading && !error && <>
      <Panel>
        <Eyebrow>Appearance & accessibility</Eyebrow>
        <Label>Color and contrast</Label>
        <Body>Choose the display that feels clearest. Text size follows your device settings and reduced motion follows your system preference.</Body>
        <View style={styles.appearanceChoices} accessibilityRole="radiogroup" accessibilityLabel="Appearance mode">
          {appearanceOptions.map((option) => {
            const selected = mode === option.mode;
            return <Pressable
              key={option.mode}
              accessibilityRole="radio"
              accessibilityLabel={option.title}
              accessibilityState={{ selected }}
              onPress={() => setMode(option.mode)}
              style={({ pressed }) => [styles.appearanceChoice, { backgroundColor: selected ? theme.colors.surfaceTinted : theme.colors.surface, borderColor: selected ? theme.colors.focusRing : theme.colors.border }, pressed && styles.pressed]}>
              <Text style={[styles.appearanceText, { color: theme.colors.ink }]}>{option.shortLabel}</Text>
            </Pressable>;
          })}
        </View>
      </Panel>

      <Panel>
        <Eyebrow>Your home</Eyebrow>
        <Label>Show pillars</Label>
        <Body>Choose which Bloom spaces appear in your Home and main navigation. Your saved activity and goals stay in your profile.</Body>
        {!visibilityLoaded && <Body>Loading your saved choices.</Body>}
        {moduleManifest.filter((module) => module.available && (!childProfile || assignedModules.includes(module.id))).map((module) => {
          const selected = visibleModules.includes(module.id);
          return <View key={module.id} style={[styles.pillarChoice, { borderTopColor: theme.colors.border }]}>
            <View style={sharedStyles.grow}>
              <Label>{module.name}</Label>
              <Text style={[styles.pillarDescription, { color: theme.colors.inkMuted }]}>{module.description}</Text>
            </View>
            <Switch
              accessibilityLabel={`Show ${module.name} in Home and navigation`}
              accessibilityHint="Hiding a pillar leaves its saved activity in your Bloom profile."
              value={selected}
              disabled={!visibilityLoaded}
              onValueChange={(visible) => setModuleVisibility(module.id, visible)}
              trackColor={{ false: theme.colors.border, true: theme.modules[module.id].deep }}
              thumbColor={theme.colors.surface}
            />
          </View>;
        })}
        {moduleManifest.every((module) => !module.available || (childProfile && !assignedModules.includes(module.id))) &&
          <Body>Your guardian can assign a Bloom pillar to your profile.</Body>}
      </Panel>

      <Panel>
        <Eyebrow>Devices & sync</Eyebrow>
        <Label>Connected devices</Label>
        <Body>Review each device’s last report, Focus capability and sync status.</Body>
        <Button label="Manage devices" variant="secondary" onPress={() => router.push('/devices' as Href)} />
      </Panel>

      <Panel>
        <Eyebrow>Focus & blocking</Eyebrow>
        <Label>Protection for this device</Label>
        <Body>Permission and enforcement status are specific to the device you are using.</Body>
        <Button label="Open Focus settings" variant="secondary" onPress={() => router.push('/focus' as Href)} />
      </Panel>

      <Panel>
        <Eyebrow>Screen time</Eyebrow>
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>Earn screen-time credits</Label><Body>{managedChild ? 'Your parent manages this setting.' : 'Change whether completed Exercise, Study, Read, and Tasks activity can earn credits.'}</Body></View>
          <Switch accessibilityLabel="Earn screen-time credits" value={creditsEnabled} onValueChange={(value) => void changeCredits(value)} disabled={saving || managedChild} trackColor={{ false: theme.colors.border, true: theme.colors.action }} />
        </View>
        {!managedChild && <Button label={showEarningRules ? 'Hide Exercise earning rules' : 'Configure Exercise earning rules'} variant="tertiary" onPress={() => setShowEarningRules((visible) => !visible)} />}
      </Panel>
      {creditSettings && !managedChild && showEarningRules && <CreditRulesEditor key={JSON.stringify(creditSettings)} settings={creditSettings} onSave={saveCreditRules} />}
      {profileId && <GrowthRewardControls key={`growth-rewards:${profileId}`} profileId={profileId} editable={!managedChild} approvalByDefault={childProfile} />}
      {profileId && <GrowthMemoryControls key={`growth-memory:${profileId}`} profileId={profileId} />}

      {!childProfile && <Panel>
        <Eyebrow>Family & profiles</Eyebrow>
        <Label>Personal and family spaces</Label>
        <Body>Family is optional. Your personal space stays available alongside guardian tools.</Body>
        <Button label="Manage Family Space" variant="secondary" onPress={() => router.push('/family' as Href)} />
        <Button label="Profile switching and PIN" variant="tertiary" onPress={() => router.push('/profile-switch' as Href)} />
      </Panel>}

      <Panel>
        <Eyebrow>Privacy & coaching</Eyebrow>
        <Label>Movement advice</Label>
        <Body>Review coaching consent and preferences before using Bloom’s movement coach.</Body>
        <Button label="Coach preferences" variant="secondary" onPress={() => router.push('/coach' as Href)} />
      </Panel>

      <Panel>
        <Eyebrow>Bloom plan</Eyebrow>
        <Label>{subscription ? `Status: ${subscription.status.replaceAll('_', ' ')}` : 'No subscription found'}</Label>
        <Body>Purchase and plan management are not connected yet.</Body>
      </Panel>

      <Panel>
        <Eyebrow>Community</Eyebrow>
        <Label>Competitions</Label>
        <Body>Join friends and review your movement challenges.</Body>
        <Button label="Open competitions" variant="secondary" onPress={() => router.push('/competitions' as Href)} />
      </Panel>
    </>}

    {__DEV__ && profileId && <View style={sharedStyles.column}>
      <Button label={showDiagnostics ? 'Hide developer diagnostics' : 'Show developer diagnostics'} variant="tertiary" onPress={() => setShowDiagnostics((visible) => !visible)} />
      {showDiagnostics && <DatabaseDiagnostics key={profileId} userId={profileId} />}
    </View>}
    {__DEV__ && <Button label="Design system gallery" variant="tertiary" onPress={() => router.push('/design-system' as Href)} />}
    <Button label="Sign out" variant="secondary" onPress={() => void signOut()} />
  </Screen>;
}

const styles = StyleSheet.create({
  appearanceChoices: { flexDirection: 'row', gap: 8 },
  appearanceChoice: { flex: 1, minHeight: 48, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 12, paddingHorizontal: 6 },
  appearanceText: { fontSize: 13, fontWeight: '700', textAlign: 'center' },
  pillarChoice: { minHeight: 68, flexDirection: 'row', alignItems: 'center', gap: 12, borderTopWidth: StyleSheet.hairlineWidth, paddingVertical: 12 },
  pillarDescription: { fontSize: 13, lineHeight: 19, marginTop: 3 },
  pressed: { opacity: 0.76 },
});
