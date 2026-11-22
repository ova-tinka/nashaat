import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { AccessibilityInfo, ActivityIndicator, LayoutAnimation, Platform, Pressable, StyleSheet, Switch, Text, UIManager, View } from 'react-native';
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
import BloomBlocking from '../../../../modules/bloom-blocking/src/BloomBlockingModule';
import type { BlockingStatus } from '../../../../modules/bloom-blocking/src/BloomBlocking.types';
import { isMacDesktop } from '../../../lib/macos-blocking';
import type { GrowthModuleId } from '../../../lib/growth-modules';

const rewardPillars = [
  { id: 'exercise', title: 'Exercise', icon: 'fitness-center', color: '#19D96B' },
  { id: 'study', title: 'Study', icon: 'school', color: '#247BFF' },
  { id: 'read', title: 'Read', icon: 'menu-book', color: '#9155F7' },
  { id: 'tasks', title: 'Tasks', icon: 'check-box', color: '#E743C8' },
] as const;
const growthPillars: GrowthModuleId[] = ['study', 'read', 'tasks'];
const rewardModules: Record<GrowthModuleId, GrowthModuleId[]> = { study: ['study'], read: ['read'], tasks: ['tasks'] };
type RewardPillar = (typeof rewardPillars)[number]['id'];

export default function SettingsScreen() {
  const { profileId, managedChild, childProfile, assignedModules } = useAuth();
  const { creditsEnabled, creditSettings, creditBalance, subscription, loading, error, refresh, setCreditsEnabled, saveCreditRules } = useBloom();
  const { theme } = useBloomTheme();
  const { visibleModules, loaded: visibilityLoaded, setModuleVisibility } = useModuleVisibility();
  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [rewardSection, setRewardSection] = useState<RewardPillar | null>(null);
  const [visitedRewards, setVisitedRewards] = useState<RewardPillar[]>([]);
  const [showDiagnostics, setShowDiagnostics] = useState(false);
  const [memoryEnabled, setMemoryEnabled] = useState<boolean | null>(null);
  const [blockingStatus, setBlockingStatus] = useState<BlockingStatus | null>(null);
  const [blockingBusy, setBlockingBusy] = useState(false);
  const [routineCount, setRoutineCount] = useState<number | null>(null);
  const [manualActive, setManualActive] = useState<boolean | null>(null);
  const [manualTargets, setManualTargets] = useState<number | null>(null);
  const [manualRemaining, setManualRemaining] = useState<number | null>(null);
  const [manualBusy, setManualBusy] = useState(false);

  useFocusEffect(useCallback(() => {
    if (isMacDesktop() || (Platform.OS !== 'ios' && Platform.OS !== 'android')) return;
    const check = () => {
      try {
        setBlockingStatus(BloomBlocking.getStatus());
        if (Platform.OS === 'android' && profileId && BloomBlocking.getFocusAccount() === profileId) {
          const routines: unknown = JSON.parse(BloomBlocking.getFocusRoutines(profileId));
          setRoutineCount(Array.isArray(routines) ? routines.filter((item) => item?.enabled === true).length : null);
          const manual: unknown = JSON.parse(BloomBlocking.getManualFocus(profileId));
          const appCount = manual && typeof manual === 'object' && 'apps' in manual && Array.isArray(manual.apps) ? manual.apps.length : null;
          const siteCount = manual && typeof manual === 'object' && 'websites' in manual && Array.isArray(manual.websites) ? manual.websites.length : null;
          setManualTargets(appCount !== null && siteCount !== null ? appCount + siteCount : null);
          setManualActive(manual && typeof manual === 'object' && 'active' in manual && typeof manual.active === 'boolean' ? manual.active : null);
          setManualRemaining(manual && typeof manual === 'object' && 'remainingMillis' in manual && typeof manual.remainingMillis === 'number' ? manual.remainingMillis : null);
        } else if (Platform.OS === 'ios' && profileId) {
          const manual = BloomBlocking.getIosManualFocus(profileId);
          setManualTargets(manual.appCount + manual.websiteCount + manual.categoryCount);
          setManualActive(manual.active); setManualRemaining(null);
          const routines: unknown = JSON.parse(BloomBlocking.getIosFocusRoutines(profileId));
          setRoutineCount(Array.isArray(routines) ? routines.filter((item) => item?.enabled === true).length : null);
        } else { setRoutineCount(null); setManualTargets(null); setManualRemaining(null); setManualActive(null); }
      } catch {
        try { setBlockingStatus(BloomBlocking.getStatus()); } catch { setBlockingStatus(null); }
        setRoutineCount(null); setManualTargets(null); setManualRemaining(null); setManualActive(null);
      }
    };
    check();
    const timer = setInterval(check, 5000);
    return () => clearInterval(timer);
  }, [profileId]));

  async function changeCredits(value: boolean) {
    setSaving(true); setActionError(null);
    try { await setCreditsEnabled(value); }
    catch { setActionError('Could not save your setting. Please try again.'); }
    finally { setSaving(false); }
  }

  async function toggleManualFocus() {
    if (!profileId || !blockingStatus) return;
    setManualBusy(true); setActionError(null);
    try {
      if (Platform.OS === 'ios') {
        if (manualActive) await BloomBlocking.stopIosManualFocus(profileId);
        else await BloomBlocking.startIosManualFocus(profileId);
      } else if (manualActive) await BloomBlocking.stopManualFocus(profileId);
      else await BloomBlocking.startManualFocus(profileId, 0);
      setManualActive(!manualActive); setBlockingStatus(BloomBlocking.getStatus()); setManualRemaining(null);
    } catch (cause) { setActionError(cause instanceof Error ? cause.message : 'Could not update Manual Focus.'); }
    finally { setManualBusy(false); }
  }

  async function toggleEarnedAccess() {
    setBlockingBusy(true); setActionError(null);
    try {
      if (blockingStatus?.active) await BloomBlocking.stopBlocking();
      else await BloomBlocking.startBlocking();
      setBlockingStatus(BloomBlocking.getStatus());
    } catch (cause) {
      setActionError(cause instanceof Error ? cause.message : 'Could not update Earned Access.');
    } finally { setBlockingBusy(false); }
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
        <View style={styles.focusHeading}>
          <View style={[styles.focusIcon, { backgroundColor: theme.colors.surfaceTinted }]}><MaterialIcons name="shield" size={22} color={theme.colors.action} /></View>
          <View style={sharedStyles.grow}><Eyebrow>Focus & Blocking</Eyebrow><Label>{blockingStatusLabel(blockingStatus)}</Label></View>
        </View>
        <Body>Choose what Bloom should block on this device and check whether protection is active.</Body>
        <Button label="Manage blocking" onPress={() => router.push('/focus')} />

        <View style={[styles.modeCard, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}>
          <View style={styles.modeHeading}>
            <View style={[styles.modeIcon, { backgroundColor: theme.colors.surfaceTinted }]}><MaterialIcons name="schedule" size={19} color={theme.colors.action} /></View>
            <View style={sharedStyles.grow}><Label>Earned Access</Label><Body>{blockingStatus?.active ? 'Enabled on this device' : 'Disabled on this device'}</Body></View>
          </View>
          <Body>Unlock selected apps using screen-time credits. {blockingStatus ? `${blockingStatus.appCount + blockingStatus.websiteCount + blockingStatus.categoryCount} apps, sites, or categories selected.` : 'Device selection status is unavailable.'}</Body>
          <Body>{Math.round(creditBalance * 100) / 100} minutes in your shared balance. Credit earning rules are directly below.</Body>
          <Body>Credit sessions currently consume their timed amount, including idle time or time when another Focus rule blocks the app.</Body>
          <Button label={blockingStatus?.active ? 'Pause Earned Access' : 'Enable Earned Access'} onPress={() => void toggleEarnedAccess()} busy={blockingBusy} disabled={blockingBusy || !blockingStatus || (!blockingStatus.active && blockingStatus.appCount + blockingStatus.websiteCount + blockingStatus.categoryCount === 0)} />
        </View>

        <View style={[styles.modeCard, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}>
          <View style={styles.modeHeading}>
            <View style={[styles.modeIcon, { backgroundColor: theme.colors.surfaceTinted }]}><MaterialIcons name="center-focus-strong" size={19} color={theme.colors.action} /></View>
            <View style={sharedStyles.grow}><Label>Manual Focus</Label><Body>{manualActive === null ? 'Status unavailable' : manualActive ? 'Active' : 'Inactive'}</Body></View>
          </View>
          {(Platform.OS === 'android' || Platform.OS === 'ios') && !isMacDesktop() ? <>
            <Body>Block selected apps whenever you choose. Available credits never override an active session.</Body>
            <Body>{manualTargets === null ? 'Sync this device to review your selection.' : `${manualTargets} apps and websites selected.`}</Body>
            {manualActive && <Body>{manualRemaining === null ? 'Runs until stopped.' : `${Math.ceil(manualRemaining / 60000)} minutes remaining.`}</Body>}
            <Button label={manualActive ? 'End Focus' : 'Start Focus'} onPress={() => void toggleManualFocus()} busy={manualBusy} disabled={manualBusy || manualActive === null || !blockingStatus || (!manualActive && (!blockingStatus.authorized || (Platform.OS === 'android' && blockingStatus.serviceConnected !== true) || !manualTargets))} />
            <Button label="Configure Manual Focus" variant="secondary" onPress={() => router.push('/manual-focus' as Href)} />
          </> : <Body>Independent Manual Focus is not available on this device.</Body>}
        </View>

        <View style={[styles.modeCard, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}>
          <View style={styles.modeHeading}>
            <View style={[styles.modeIcon, { backgroundColor: theme.colors.surfaceTinted }]}><MaterialIcons name="calendar-month" size={19} color={theme.colors.action} /></View>
            <View style={sharedStyles.grow}><Label>Scheduled Focus</Label><Body>{routineCount === null ? 'Status unavailable' : `${routineCount} enabled routines · ${blockingStatus?.scheduledActiveCount ?? 0} active now`}</Body></View>
          </View>
          {(Platform.OS === 'android' || Platform.OS === 'ios') && !isMacDesktop() ? <>
            <Body>Automatically block selected apps during your routines. Overlapping routines combine their restrictions.</Body>
            <Button label="Manage routines" variant="secondary" onPress={() => router.push('/focus-routines' as Href)} />
          </> : <Body>Recurring blocking routines are not available on this device.</Body>}
        </View>
      </Panel>

      <Panel>
        <Eyebrow>Earned Screen-Time Credits</Eyebrow>
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>Earn screen-time credits</Label><Body>{managedChild ? 'Your parent manages this setting.' : 'Change whether completed Exercise, Study, Read, and Tasks activity can earn credits.'}</Body></View>
          <Switch accessibilityLabel="Earn screen-time credits" value={creditsEnabled} onValueChange={(value) => void changeCredits(value)} disabled={saving || managedChild} trackColor={{ false: theme.colors.border, true: theme.colors.action }} />
        </View>
        <Body>All four pillars contribute to your shared screen-time balance.</Body>
        {rewardPillars.map((pillar) => <Pressable key={pillar.id} accessibilityRole="button" accessibilityLabel={`${pillar.title} reward settings`} accessibilityState={{ expanded: rewardSection === pillar.id }} onPress={() => {
          setVisitedRewards((current) => current.includes(pillar.id) ? current : [...current, pillar.id]);
          setRewardSection((current) => current === pillar.id ? null : pillar.id);
        }} style={[styles.rewardLink, { borderTopColor: theme.colors.border }]}>
          <MaterialIcons name={pillar.icon} size={22} color={pillar.color} />
          <View style={sharedStyles.grow}><Label>{pillar.title}</Label></View>
          <MaterialIcons name={rewardSection === pillar.id ? 'expand-less' : 'expand-more'} size={22} color={theme.colors.inkMuted} />
        </Pressable>)}
      </Panel>
      {managedChild && rewardSection === 'exercise' && <Panel><Body>Your parent manages Exercise reward rules.</Body></Panel>}
      {creditSettings && !managedChild && visitedRewards.includes('exercise') && <View style={rewardSection === 'exercise' ? undefined : { display: 'none' }}><CreditRulesEditor key={JSON.stringify(creditSettings)} settings={creditSettings} onSave={saveCreditRules} /></View>}
      {profileId && growthPillars.filter((pillar) => visitedRewards.includes(pillar)).map((pillar) => <View key={`growth-rewards:${profileId}:${pillar}`} style={rewardSection === pillar ? undefined : { display: 'none' }}><GrowthRewardControls profileId={profileId} editable={!managedChild} approvalByDefault={childProfile} allowedModules={rewardModules[pillar]} heading={`${rewardPillars.find((entry) => entry.id === pillar)?.title} rewards`} /></View>)}
      <Panel>
        <Eyebrow>Bloom plan</Eyebrow>
        <Label>{subscription ? `Status: ${subscription.status.replaceAll('_', ' ')}` : 'No subscription found'}</Label>
        <Body>Purchase and plan management are not connected yet.</Body>
      </Panel>

      {profileId && <SettingsAccordion title="Personal Memory" icon="psychology" status={memoryEnabled === null ? 'Status unavailable' : memoryEnabled ? 'Enabled' : 'Disabled'}><GrowthMemoryControls key={`growth-memory:${profileId}`} profileId={profileId} onStatusChange={setMemoryEnabled} /></SettingsAccordion>}
      <SettingsAccordion title="Devices & sync" icon="devices">
        <Body>Review each device’s last report, Focus capability and sync status.</Body>
        <Button label="Manage devices" variant="secondary" onPress={() => router.push('/devices' as Href)} />
      </SettingsAccordion>

      <Button label="Sign out" variant="secondary" onPress={() => void signOut()} />
      <SettingsAccordion title="Show Pillars" icon="dashboard">
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
      </SettingsAccordion>

    </>}

    {__DEV__ && <Eyebrow>Developer Tools</Eyebrow>}
    {__DEV__ && profileId && <View style={sharedStyles.column}>
      <Button label={showDiagnostics ? 'Hide developer diagnostics' : 'Show developer diagnostics'} variant="tertiary" onPress={() => setShowDiagnostics((visible) => !visible)} />
      {showDiagnostics && <DatabaseDiagnostics key={profileId} userId={profileId} />}
    </View>}
    {__DEV__ && <Button label="Design system gallery" variant="tertiary" onPress={() => router.push('/design-system' as Href)} />}
  </Screen>;
}

function blockingStatusLabel(status: BlockingStatus | null): string {
  if (isMacDesktop()) return 'Review this device’s Focus status';
  if (Platform.OS !== 'ios' && Platform.OS !== 'android') return 'Blocking unavailable on this platform';
  if (!status || !status.supported) return 'Enforcement unavailable';
  if (!status.authorized) return 'Blocking permission needed';
  if (status.scheduleError) return 'Scheduled Focus enforcement needs attention';
  if (status.manualFocusError) return 'Manual Focus status unavailable';
  const scheduled = (status.scheduledActiveCount ?? 0) > 0;
  const manual = status.manualFocusActive === true;
  if (Platform.OS === 'android' && (status.active || scheduled || manual) && status.serviceConnected !== true) return 'Blocking service needs attention';
  if ([scheduled, manual, status.active].filter(Boolean).length > 1) return Platform.OS === 'ios' ? 'Multiple Focus restrictions configured' : 'Multiple Focus restrictions active';
  if (manual) return Platform.OS === 'ios' ? 'Manual Focus configured' : 'Manual Focus active';
  if (scheduled) return 'Scheduled Focus active';
  return status.active ? Platform.OS === 'ios' ? 'Focus restrictions configured' : 'Focus blocking is on' : 'Focus blocking is off';
}

function SettingsAccordion({ title, icon, status, children }: { title: string; icon: 'psychology' | 'devices' | 'dashboard'; status?: string; children: ReactNode }) {
  const [expanded, setExpanded] = useState(false);
  const [reduceMotion, setReduceMotion] = useState(true);
  const { theme } = useBloomTheme();
  useEffect(() => {
    let mounted = true;
    void AccessibilityInfo.isReduceMotionEnabled().then((value) => { if (mounted) setReduceMotion(value); }).catch(() => undefined);
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    if (Platform.OS === 'android') UIManager.setLayoutAnimationEnabledExperimental?.(true);
    return () => { mounted = false; subscription.remove(); };
  }, []);
  function toggle() {
    if (!reduceMotion && Platform.OS !== 'web') LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setExpanded((current) => !current);
  }
  return <Panel>
    <Pressable accessibilityRole="button" accessibilityLabel={title} accessibilityState={{ expanded }} onPress={toggle} style={styles.accordionHeader}>
      <MaterialIcons name={icon} size={22} color={theme.colors.action} />
      <View style={sharedStyles.grow}><Label>{title}</Label>{status && <Body>{status}</Body>}</View>
      <MaterialIcons name={expanded ? 'expand-less' : 'expand-more'} size={24} color={theme.colors.inkMuted} />
    </Pressable>
    <View style={expanded ? undefined : { display: 'none' }}>{children}</View>
  </Panel>;
}

const styles = StyleSheet.create({
  focusHeading: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  focusIcon: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  modeCard: { gap: 8, padding: 12, borderWidth: StyleSheet.hairlineWidth, borderRadius: 18 },
  modeHeading: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  modeIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  rewardLink: { minHeight: 52, flexDirection: 'row', alignItems: 'center', gap: 12, borderTopWidth: StyleSheet.hairlineWidth },
  accordionHeader: { minHeight: 48, flexDirection: 'row', alignItems: 'center', gap: 12 },
  pillarChoice: { minHeight: 68, flexDirection: 'row', alignItems: 'center', gap: 12, borderTopWidth: StyleSheet.hairlineWidth, paddingVertical: 12 },
  pillarDescription: { fontSize: 13, lineHeight: 19, marginTop: 3 },
  pressed: { opacity: 0.76 },
});
