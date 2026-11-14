import { randomUUID } from 'expo-crypto';
import { router, useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { CreditRulesEditor } from '../../components/credit-rules-editor';
import { deletePlan, formatScheduledDays, updateCredits, updateCreditRules } from '../../lib/bloom';
import { addChildRule, addWebsiteRule, adjustChildCredit, deleteChildRule, deleteWebsiteRule, loadChild, type ChildRule, type WebsiteRuleScope } from '../../lib/family';
import { colors } from '../../theme';

export default function FamilyChildScreen() {
  const { childId, name } = useLocalSearchParams<{ childId: string; name?: string }>();
  const [child, setChild] = useState<Awaited<ReturnType<typeof loadChild>> | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const pending = useRef<{ key: string; id: string } | null>(null);
  const [platform, setPlatform] = useState<ChildRule['platform']>('android');
  const [kind, setKind] = useState<ChildRule['target_type']>('website');
  const [identifier, setIdentifier] = useState('');
  const [website, setWebsite] = useState('');
  const [websiteScope, setWebsiteScope] = useState<WebsiteRuleScope>('focus');

  const load = useCallback(async () => {
    try { setChild(await loadChild(childId)); setError(null); }
    catch { setError('Could not load this child’s settings. Check the family connection and try again.'); }
    finally { setLoading(false); }
  }, [childId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));

  async function run(action: () => Promise<void>) {
    setBusy(true); setError(null);
    try { await action(); await load(); }
    catch (cause) {
      if (cause instanceof Error && cause.message === 'iOS allows up to 50 always-blocked domains.') setError(cause.message);
      else setError('Could not save this change. Check the values and family connection, then try again.');
    }
    finally { setBusy(false); }
  }
  async function adjust() {
    const value = Number(amount);
    if (!/^-?\d+(\.\d{1,4})?$/.test(amount.trim()) || !Number.isFinite(value) || value === 0 || Math.abs(value) > 10080) {
      setError('Enter a nonzero number of minutes, up to 10,080.'); return;
    }
    const key = JSON.stringify([childId, value, reason.trim()]);
    if (pending.current?.key !== key) pending.current = { key, id: randomUUID() };
    const requestId = pending.current.id;
    await run(async () => { await adjustChildCredit(childId, requestId, value, reason); pending.current = null; setAmount(''); setReason(''); });
  }

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Family</Eyebrow><Heading>{name || 'Child settings'}</Heading><Body>Manage the linked account’s workouts and credit rules.</Body></View>
    <Button label="Back to family" secondary onPress={() => router.back()} />
    {loading && <ActivityIndicator color={colors.accent} />}
    {error && <ErrorText>{error}</ErrorText>}
    {child && <>
      <Panel><Label>Screen-time credits</Label><Body>Available: {Math.round(child.balance * 100) / 100} minutes</Body>
        <Button label={child.settings.credits_enabled ? 'Turn credits off' : 'Turn credits on'} secondary busy={busy} onPress={() => void run(() => updateCredits(childId, !child.settings.credits_enabled))} />
        <Field label="Adjustment in minutes (use minus to remove)" value={amount} onChangeText={setAmount} keyboardType="numbers-and-punctuation" />
        <Field label="Reason (optional)" value={reason} onChangeText={setReason} maxLength={200} />
        <Button label="Apply adjustment" busy={busy} onPress={() => void adjust()} />
      </Panel>
      <CreditRulesEditor key={JSON.stringify(child.settings)} settings={child.settings} onSave={async (rules) => { await updateCreditRules(childId, rules); await load(); }} />
      <Panel><Label>Coaching</Label><Body>Manage permission and review workout proposals. Private conversations stay with the child.</Body><Button label="Manage coaching" secondary onPress={() => router.push({ pathname: '/child-coaching', params: { childId, name } } as unknown as Href)} /></Panel>
      <Panel><Label>Competitions and search</Label><Body>Control whether this child appears in search and approve event requests.</Body><Button label="Manage competitions" secondary onPress={() => router.push({ pathname: '/child-competitions', params: { childId, name } } as unknown as Href)} /></Panel>
      <Panel><Eyebrow>This week</Eyebrow>
        <Label>{child.workoutAnalytics.weekly_workout_target === null ? `${child.workoutAnalytics.workouts_completed} workouts completed` : `${child.workoutAnalytics.workouts_completed} of ${child.workoutAnalytics.weekly_workout_target} workouts`}</Label>
        {child.workoutAnalytics.planned_workouts > 0 && <Body>{child.workoutAnalytics.completed_planned_workouts} of {child.workoutAnalytics.planned_workouts} scheduled workouts complete · {child.workoutAnalytics.rest_days} rest days</Body>}
        {child.workoutAnalytics.missed_planned_workouts > 0 && <Body>A scheduled day passed without a workout. It’s okay to adjust the plan or leave room for rest.</Body>}
        {child.workoutAnalytics.weekly_credit_target_minutes !== null && <Body>{child.workoutAnalytics.credits_earned_minutes.toLocaleString(undefined, { maximumFractionDigits: 2 })} of {child.workoutAnalytics.weekly_credit_target_minutes} goal minutes earned</Body>}
        <Body>{child.workoutAnalytics.active_days} active days · {child.workoutAnalytics.exercise_minutes} timed exercise minutes · {child.workoutAnalytics.sets_completed} sets · {child.workoutAnalytics.reps_completed} repetitions</Body>
        {child.workoutAnalytics.history.slice(0, 5).map((item) => <View key={item.id} style={sharedStyles.row}><View style={sharedStyles.grow}><Body>{item.plan_title}</Body><Body>{new Date(item.completed_at).toLocaleDateString()} · {item.exercises_completed} exercises · {item.sets_completed} sets</Body></View>{item.credits_earned_minutes > 0 && <Body>+{item.credits_earned_minutes.toLocaleString(undefined, { maximumFractionDigits: 2 })} min</Body>}</View>)}
      </Panel>
      <Panel><Label>Workout plans</Label>
        {child.plans.length === 0 && <Body>No plans yet.</Body>}
        {child.plans.map((plan) => <View key={plan.id} style={sharedStyles.column}><Body>{plan.title} · {plan.bloom_plan_exercises.length} exercises</Body><Body>{formatScheduledDays(plan.scheduled_days)}</Body><Button label={`Edit ${plan.title}`} secondary onPress={() => router.push({ pathname: '/new-plan', params: { childId, planId: plan.id } } as Href)} /><Button label={`Delete ${plan.title}`} secondary busy={busy} onPress={() => void run(() => deletePlan(plan.id))} /></View>)}
        <Button label="Create workout for this child" onPress={() => router.push({ pathname: '/new-plan', params: { childId } } as Href)} />
      </Panel>
      <Panel><Eyebrow>iPhone website rules</Eyebrow><Body>Always rules use iOS web-content filtering on the child’s iPhone, need Screen Time access there, and support up to 50 domains. Focus-only rules use Bloom’s Safari extension while Focus is on. Safari Private Browsing may be disabled while the iOS filter is active; other browser coverage should be checked on the device. The child can add their own rules but can’t remove parent-managed ones.</Body>
        {child.websiteRules.map((rule) => <View key={rule.id} style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Body>{rule.domain} · {rule.scope === 'always' ? 'Always' : 'During Focus'}</Body><Body>{rule.created_by === childId ? 'Added by child' : 'Parent-managed'}</Body></View>
          <Button label="Remove" secondary busy={busy} onPress={() => void run(() => deleteWebsiteRule(childId, rule.id))} />
        </View>)}
        <Body>Rule applies to</Body>{(['always', 'focus'] as const).map((choice) => <Button key={choice} secondary label={`${websiteScope === choice ? '✓ ' : ''}${choice === 'always' ? 'Always' : 'During Focus'}`} onPress={() => setWebsiteScope(choice)} />)}
        <Field label="Website or URL" value={website} onChangeText={setWebsite} autoCapitalize="none" autoCorrect={false} keyboardType="url" placeholder="example.com" />
        <Button label={websiteScope === 'always' ? 'Add always-blocked domain' : 'Add Safari Focus domain'} busy={busy} disabled={!website.trim()} onPress={() => void run(async () => { await addWebsiteRule(childId, websiteScope, website); setWebsite(''); })} />
      </Panel>
      <Panel><Label>App blocking rules</Label><Body>Android and macOS sync parent-set app rules when Focus opens. On iPhone, apps remain selected on the child’s device in Apple’s Screen Time picker. Website rules for Safari are managed above.</Body>
        {child.rules.map((rule) => <View key={rule.id} style={sharedStyles.column}><Body>{rule.platform} · {rule.target_type} · {rule.target_identifier}</Body><Button label="Remove rule" secondary busy={busy} onPress={() => void run(() => deleteChildRule(childId, rule.id))} /></View>)}
        <Body>Platform</Body>{(['android', 'ios', 'macos'] as const).map((choice) => <Button key={choice} secondary label={`${platform === choice ? '✓ ' : ''}${choice}`} onPress={() => setPlatform(choice)} />)}
        <Body>Type</Body>{(['app', 'website'] as const).map((choice) => <Button key={choice} secondary label={`${kind === choice ? '✓ ' : ''}${choice}`} onPress={() => setKind(choice)} />)}
        <Field label={kind === 'website' ? 'Website domain' : 'App identifier'} value={identifier} onChangeText={setIdentifier} autoCapitalize="none" autoCorrect={false} maxLength={500} />
        {platform === 'ios' && kind === 'app' && <Body>Apple hides app selections behind local tokens, so Bloom cannot enforce an account app rule by package name on iOS. Choose the app in Apple’s Screen Time picker on that device.</Body>}
        {platform === 'ios' && kind === 'website' && <Body>Safari website rules are managed in the section above. This older Focus rule stays available for existing synced settings.</Body>}
        <Button label="Save rule" busy={busy} disabled={!identifier.trim() || (platform === 'ios' && kind === 'app')} onPress={() => void run(async () => { await addChildRule(childId, platform, kind, identifier); setIdentifier(''); })} />
      </Panel>
    </>}
  </Screen>;
}
