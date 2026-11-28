import { router, type Href } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Platform, View } from 'react-native';
import BloomBlocking from '../../../modules/bloom-blocking/src/BloomBlockingModule';
import { BloomWordmark, Body, Button, DesktopContent, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { trackEvent } from '../../lib/analytics';
import { useAuth } from '../../lib/auth';
import { useBilling } from '../../lib/billing-context';
import { isMacDesktop, macosFilter } from '../../lib/macos-blocking';
import {
  ONBOARDING_GOAL_OPTIONS,
  ONBOARDING_STEPS,
  defaultOnboardingState,
  loadOnboardingState,
  recommendedFirstAction,
  saveOnboardingState,
  type OnboardingGoal,
  type OnboardingState,
  type OnboardingUsageMode,
} from '../../lib/onboarding';
import { useBloomTheme } from '../../lib/theme-context';

export default function OnboardingScreen() {
  const { theme } = useBloomTheme();
  const { profileId, childProfile } = useAuth();
  const { summary, refresh: refreshBilling } = useBilling();
  const [state, setState] = useState<OnboardingState>(defaultOnboardingState());
  const [loadedFor, setLoadedFor] = useState<string | null>(null);
  const [permissionStatus, setPermissionStatus] = useState<'checking' | 'ready' | 'needs_setup' | 'unsupported'>('checking');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!profileId) return;
    let active = true;
    void loadOnboardingState(profileId).then((loaded) => {
      if (!active) return;
      setState(loaded);
      setLoadedFor(profileId);
      void trackEvent('onboarding_started', { onboarding_step: ONBOARDING_STEPS[loaded.currentStep] }, { onceKey: `onboarding:${profileId}` });
    });
    return () => { active = false; };
  }, [profileId]);

  const checkPermissions = useCallback(async () => {
    setPermissionStatus('checking');
    try {
      if (isMacDesktop()) {
        const result = await macosFilter('selfCheck');
        const check = result.selfCheck;
        if (check?.monitorLive && check.policyBrokerReady && check.accessibilityTrusted) {
          setPermissionStatus('ready');
        } else {
          setPermissionStatus('needs_setup');
        }
        return;
      }
      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        const status = await BloomBlocking.getStatus();
        if (!status.supported) setPermissionStatus('unsupported');
        else if (status.authorized) setPermissionStatus('ready');
        else setPermissionStatus('needs_setup');
        return;
      }
      setPermissionStatus('unsupported');
    } catch {
      setPermissionStatus('needs_setup');
    }
  }, []);

  useEffect(() => {
    if (ONBOARDING_STEPS[state.currentStep] === 'permissions') {
      void Promise.resolve().then(checkPermissions);
    }
  }, [checkPermissions, state.currentStep]);

  if (childProfile) {
    return <Screen><DesktopContent><Panel><Body>Child profiles are managed by a parent.</Body><Button label="Continue" onPress={() => router.replace('/')} /></Panel></DesktopContent></Screen>;
  }

  if (!profileId || loadedFor !== profileId) {
    return <Screen><ActivityIndicator color={theme.colors.action} /></Screen>;
  }

  const stepKey = ONBOARDING_STEPS[state.currentStep] ?? 'welcome';
  const hasPaidAccess = Boolean(summary?.can_access && (summary.plan || !summary.metered));
  const actionTarget = recommendedFirstAction(state.goals);

  async function persist(next: OnboardingState) {
    setState(next);
    if (profileId) await saveOnboardingState(profileId, next);
  }

  async function goToStep(nextIndex: number, extra?: Partial<OnboardingState>) {
    const clamped = Math.max(0, Math.min(ONBOARDING_STEPS.length - 1, nextIndex));
    void trackEvent('onboarding_step_completed', { onboarding_step: stepKey });
    await persist({ ...state, ...extra, currentStep: clamped });
  }

  function toggleGoal(goal: OnboardingGoal) {
    const exists = state.goals.includes(goal);
    const goals = exists ? state.goals.filter((item) => item !== goal) : [...state.goals, goal];
    void persist({ ...state, goals });
  }

  function setUsageMode(usageMode: OnboardingUsageMode) {
    void persist({ ...state, usageMode });
  }

  async function openPermissionsFlow() {
    setBusy(true);
    setError(null);
    void trackEvent('permission_setup_started');
    try {
      if (isMacDesktop()) {
        router.push('/focus' as Href);
        return;
      }
      if (Platform.OS === 'ios') {
        const granted = await BloomBlocking.requestAuthorization();
        void trackEvent(granted ? 'permission_setup_completed' : 'permission_setup_failed');
        await checkPermissions();
        return;
      }
      if (Platform.OS === 'android') {
        await BloomBlocking.requestAccessibilityPermission();
        await checkPermissions();
        return;
      }
    } catch {
      void trackEvent('permission_setup_failed', { error_category: 'os_permission' });
      setError('Could not open device permissions. You can configure them later in Focus.');
    } finally {
      setBusy(false);
    }
  }

  async function finishOnboarding(targetRoute: Href) {
    const completedState: OnboardingState = {
      ...state,
      completed: true,
      completedAt: new Date().toISOString(),
    };
    await persist(completedState);
    void trackEvent('onboarding_completed', { source: actionTarget.pillar ?? 'focus' });
    router.replace(targetRoute);
  }

  return <Screen>
    <DesktopContent maxWidth={680}>
      <View style={sharedStyles.column}>
        <BloomWordmark size={28} />
        <Eyebrow>Setup · Step {state.currentStep + 1} of {ONBOARDING_STEPS.length}</Eyebrow>
        <Heading>
          {stepKey === 'welcome' ? 'Welcome to Bloom'
            : stepKey === 'goals' ? 'What matters most to you?'
            : stepKey === 'usage_mode' ? 'How will you use Bloom?'
            : stepKey === 'earned_screen_time' ? 'How earned screen time works'
            : stepKey === 'permissions' ? 'Device permissions'
            : stepKey === 'subscription' ? 'Bloom subscription'
            : 'Start your first activity'}
        </Heading>
      </View>

      {error && <ErrorText>{error}</ErrorText>}

      {stepKey === 'welcome' && <Panel>
        <Body>
          Bloom helps you reduce unproductive screen time and redirect your attention toward meaningful activities across four pillars: Exercise, Study, Reading, and Tasks.
        </Body>
        <Body>
          You choose which distracting apps and websites to block, and earn screen-time access by completing real work.
        </Body>
        <Button label="Get started" onPress={() => void goToStep(1)} />
      </Panel>}

      {stepKey === 'goals' && <Panel>
        <Body>Select the goals you want to focus on first (optional).</Body>
        {ONBOARDING_GOAL_OPTIONS.map((option) => {
          const selected = state.goals.includes(option.id);
          return <Button
            key={option.id}
            label={`${selected ? '✓ ' : ''}${option.label}`}
            variant={selected ? 'primary' : 'secondary'}
            onPress={() => toggleGoal(option.id)}
          />;
        })}
        <View style={sharedStyles.row}>
          <Button label="Back" variant="tertiary" onPress={() => void goToStep(0)} />
          <Button label="Continue" onPress={() => void goToStep(2)} />
        </View>
      </Panel>}

      {stepKey === 'usage_mode' && <Panel>
        <Body>Bloom works completely as an individual account. Optional Family Space features are always available later in Settings.</Body>
        <Button
          label={`${state.usageMode === 'individual' ? '✓ ' : ''}Individual (Recommended)`}
          variant={state.usageMode === 'individual' ? 'primary' : 'secondary'}
          onPress={() => setUsageMode('individual')}
        />
        <Button
          label={`${state.usageMode === 'family' ? '✓ ' : ''}Family & Guardian`}
          variant={state.usageMode === 'family' ? 'primary' : 'secondary'}
          onPress={() => setUsageMode('family')}
        />
        {state.usageMode === 'family' && <Body>You can invite or link family members anytime from Settings → Family Space.</Body>}
        <View style={sharedStyles.row}>
          <Button label="Back" variant="tertiary" onPress={() => void goToStep(1)} />
          <Button label="Continue" onPress={() => void goToStep(3)} />
        </View>
      </Panel>}

      {stepKey === 'earned_screen_time' && <Panel>
        <Label>1. Complete real activities</Label>
        <Body>Finish workouts, study sessions, reading sessions, or tasks.</Body>
        <Label>2. Earn screen-time credits</Label>
        <Body>Bloom adds earned minutes to your account-wide balance.</Body>
        <Label>3. Unlock blocked distractions intentionally</Label>
        <Body>Apps and websites you choose stay blocked until you spend earned minutes—no willpower battle required.</Body>
        <View style={sharedStyles.row}>
          <Button label="Back" variant="tertiary" onPress={() => void goToStep(2)} />
          <Button label="Continue" onPress={() => void goToStep(4)} />
        </View>
      </Panel>}

      {stepKey === 'permissions' && <Panel>
        <Body>
          {Platform.OS === 'ios'
            ? 'Bloom uses Apple Screen Time (Family Controls) to shield distracting apps and websites on your iPhone or iPad.'
            : Platform.OS === 'android'
            ? 'Bloom uses Android Accessibility access to detect and block selected distraction apps.'
            : isMacDesktop()
            ? 'On macOS, Bloom uses a Network Filter, Background Monitor, and Accessibility to block distracting websites and overlay the Bloom Shield.'
            : 'App blocking runs on iPhone, iPad, Android, and macOS. You can configure permissions on those devices anytime.'}
        </Body>
        <Label>
          Current status: {permissionStatus === 'ready' ? 'Authorized'
            : permissionStatus === 'checking' ? 'Checking…'
            : permissionStatus === 'unsupported' ? 'Not required in browser'
            : 'Setup needed'}
        </Label>
        {permissionStatus === 'needs_setup' && (
          <Button label="Configure permissions" onPress={() => void openPermissionsFlow()} busy={busy} />
        )}
        <Button label="Recheck permission status" variant="secondary" onPress={() => void checkPermissions()} disabled={busy} />
        <View style={sharedStyles.row}>
          <Button label="Back" variant="tertiary" onPress={() => void goToStep(3)} />
          <Button
            label={permissionStatus === 'ready' || permissionStatus === 'unsupported' ? 'Continue' : 'Skip for now'}
            variant={permissionStatus === 'ready' ? 'primary' : 'secondary'}
            onPress={() => void goToStep(5, { skippedPermissions: permissionStatus !== 'ready' })}
          />
        </View>
      </Panel>}

      {stepKey === 'subscription' && <Panel>
        <Body>
          Bloom is a paid subscription covering all four pillars and cross-device Focus. Paid plans include weekly usage credits for AI-assisted study and coaching tools.
        </Body>
        {hasPaidAccess ? <>
          <Label>Subscription active</Label>
          <Body>Your account has active Bloom access.</Body>
        </> : <>
          <Label>Subscription required for full access</Label>
          <Body>Choose a weekly, monthly, or yearly plan to unlock all Bloom activities.</Body>
          <Button label="View subscription plans" onPress={() => router.push('/subscription' as Href)} />
          <Button label="Refresh subscription status" variant="secondary" onPress={() => void refreshBilling()} />
        </>}
        <Button label="Privacy Policy & Terms" variant="tertiary" onPress={() => router.push('/legal' as Href)} />
        <View style={sharedStyles.row}>
          <Button label="Back" variant="tertiary" onPress={() => void goToStep(4)} />
          <Button label="Continue" variant={hasPaidAccess ? 'primary' : 'secondary'} onPress={() => void goToStep(6)} />
        </View>
      </Panel>}

      {stepKey === 'first_action' && <Panel>
        <Label>Recommended next step: {actionTarget.label}</Label>
        <Body>{actionTarget.description}</Body>
        <Button label={actionTarget.label} onPress={() => void finishOnboarding(actionTarget.route)} />
        <Button label="Go to Home dashboard" variant="secondary" onPress={() => void finishOnboarding('/' as Href)} />
        <Button label="Back" variant="tertiary" onPress={() => void goToStep(5)} />
      </Panel>}
    </DesktopContent>
  </Screen>;
}
