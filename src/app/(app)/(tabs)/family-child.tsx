import { getAppLocale } from '../../../lib/locale-context';
import { randomUUID } from 'expo-crypto';
import { router, useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import { useCallback, useMemo, useRef, useState } from 'react';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { ActivityIndicator, Pressable, StyleSheet, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, LocalizedText as Text, Panel, Screen, sharedStyles, useIsDesktopColumns } from '../../../components/bloom-ui';
import { CreditRulesEditor } from '../../../components/credit-rules-editor';
import { GrowthRewardControls } from '../../../components/growth-reward-controls';
import { ChildGrowthAiConsentControls, ChildStudyDocumentControls } from '../../../components/child-study-tutor-controls';
import { deletePlan, formatScheduledDays, updateCredits, updateCreditRules, type WorkoutAnalytics } from '../../../lib/bloom';
import { addChildRule, addWebsiteRule, adjustChildCredit, deleteChildRule, deleteWebsiteRule, loadChild, type ChildRule, type WebsiteRuleScope } from '../../../lib/family';
import { loadChildModuleAssignments, saveChildModuleAssignments, type ChildModuleAssignment } from '../../../lib/module-assignments';
import { useAuth } from '../../../lib/auth';
import { moduleManifest } from '../../../lib/module-manifest';
import { useBloomTheme } from '../../../lib/theme-context';
import type { ModuleKey } from '../../../theme';
import type { GrowthModuleId } from '../../../lib/growth-modules';

export default function FamilyChildScreen() {
  const { childId, name } = useLocalSearchParams<{ childId: string; name?: string }>();
  const { profileId } = useAuth();
  const { theme } = useBloomTheme();
  const desktopColumns = useIsDesktopColumns();
  const [child, setChild] = useState<Awaited<ReturnType<typeof loadChild>> | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [confirmAdjustment, setConfirmAdjustment] = useState(false);
  const pending = useRef<{ key: string; id: string } | null>(null);
  const [platform, setPlatform] = useState<ChildRule['platform']>('android');
  const [kind, setKind] = useState<ChildRule['target_type']>('website');
  const [identifier, setIdentifier] = useState('');
  const [website, setWebsite] = useState('');
  const [websiteScope, setWebsiteScope] = useState<WebsiteRuleScope>('focus');
  const [confirmWebsiteRemoval, setConfirmWebsiteRemoval] = useState<string | null>(null);
  const [confirmRuleRemoval, setConfirmRuleRemoval] = useState<string | null>(null);
  const [confirmCreditsEnabled, setConfirmCreditsEnabled] = useState<boolean | null>(null);
  const [confirmPlanRemoval, setConfirmPlanRemoval] = useState<string | null>(null);
  const [pendingWebsite, setPendingWebsite] = useState<{ domain: string; scope: WebsiteRuleScope } | null>(null);
  const [pendingRule, setPendingRule] = useState<{ platform: ChildRule['platform']; kind: ChildRule['target_type']; identifier: string } | null>(null);
  const [moduleAssignments, setModuleAssignments] = useState<ChildModuleAssignment[]>([]);
  const assignedGrowthModules = useMemo(() => moduleAssignments
    .filter((assignment) => assignment.assigned && assignment.module_id !== 'exercise')
    .map((assignment) => assignment.module_id as GrowthModuleId), [moduleAssignments]);
  const [moduleDraft, setModuleDraft] = useState<ModuleKey[]>([]);
  const [confirmModules, setConfirmModules] = useState(false);
  const [section, setSection] = useState<'overview' | 'modules' | 'limits' | 'activity'>('overview');
  const loadRequest = useRef(0);
  const loadedTarget = useRef<string | null>(null);

  const load = useCallback(async () => {
    const request = ++loadRequest.current;
    const target = `${profileId ?? 'unavailable'}:${childId}`;
    if (loadedTarget.current !== target) {
      loadedTarget.current = target;
      setChild(null);
      setModuleAssignments([]);
      setModuleDraft([]);
      setError(null);
    }
    setLoading(true);
    try {
      const [childData, assignments] = await Promise.all([loadChild(childId), loadChildModuleAssignments(childId)]);
      if (request !== loadRequest.current) return;
      setChild(childData);
      setModuleAssignments(assignments);
      setModuleDraft(assignments.filter((assignment) => assignment.assigned).map((assignment) => assignment.module_id));
      setError(null);
    }
    catch { if (request === loadRequest.current) setError('Could not load this child’s settings. Check the family connection and try again.'); }
    finally { if (request === loadRequest.current) setLoading(false); }
  }, [childId, profileId]);
  useFocusEffect(useCallback(() => {
    void load();
    return () => { loadRequest.current += 1; };
  }, [load]));

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
    setConfirmAdjustment(true);
  }
  async function applyAdjustment() {
    const value = Number(amount);
    const key = JSON.stringify([childId, value, reason.trim()]);
    if (pending.current?.key !== key) pending.current = { key, id: randomUUID() };
    const requestId = pending.current.id;
    await run(async () => {
      await adjustChildCredit(childId, requestId, value, reason);
      pending.current = null;
      setAmount(''); setReason(''); setConfirmAdjustment(false);
    });
  }

  const currentModules = moduleAssignments.filter((assignment) => assignment.assigned).map((assignment) => assignment.module_id);
  const modulesChanged = currentModules.length !== moduleDraft.length || currentModules.some((id) => !moduleDraft.includes(id));
  const assignedNames = moduleManifest.filter((module) => moduleDraft.includes(module.id)).map((module) => module.name);

  return <Screen safeAreaTop={false}>
    <View style={styles.headerRow}>
      <Pressable accessibilityRole="button" accessibilityLabel="Back to Family Space" accessibilityHint="Returns to the family overview." onPress={() => router.back()}
        style={({ pressed }) => [styles.backButton, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, pressed && { opacity: 0.8 }]}>
        <MaterialIcons name="arrow-back" size={21} color={theme.colors.ink} />
      </Pressable>
      <View style={sharedStyles.grow}><Eyebrow>Family Space · Child profile</Eyebrow><Heading>{name || 'Child settings'}</Heading></View>
    </View>
    <Body>Manage access and approved activity for this child profile.</Body>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <ErrorText>{error}</ErrorText>}
    {child && <>
      {!desktopColumns && <View accessibilityRole="tablist" style={styles.sectionTabs}>
        {([
          ['overview', 'Overview'], ['modules', 'Modules'], ['limits', 'Limits'], ['activity', 'Activity'],
        ] as const).map(([key, label]) => {
          const selected = section === key;
          return <Pressable key={key} accessibilityRole="tab" accessibilityState={{ selected }}
            accessibilityLabel={`${label} section${selected ? ', selected' : ''}`} onPress={() => setSection(key)}
            style={[styles.sectionTab, { borderColor: selected ? theme.colors.action : theme.colors.border, backgroundColor: selected ? theme.colors.surfaceTinted : theme.colors.surface }]}>
            <Text style={[styles.sectionTabText, { color: selected ? theme.colors.action : theme.colors.inkMuted }]}>{label}</Text>
          </Pressable>;
        })}
      </View>}
      <View style={[styles.workspace, desktopColumns && styles.desktopWorkspace]}>
      <View style={[styles.column, desktopColumns && styles.desktopColumn]}>
      {!desktopColumns && section === 'overview' && <WeeklyActivitySummary analytics={child.workoutAnalytics} />}
      {(desktopColumns || section === 'modules') && <Panel><Eyebrow>Module access</Eyebrow><Label>Choose the modules {name || 'this child'} can use</Label><Body>New child profiles start with no modules assigned. A child can open only modules you assign here.</Body>
        {moduleManifest.map((module) => {
          const assigned = moduleDraft.includes(module.id);
          return <View key={module.id} style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Label>{module.name}</Label><Body>{module.available ? assigned ? 'Assigned to this child' : 'Not assigned' : 'Coming later · cannot be assigned yet'}</Body></View>
            <Switch accessibilityLabel={`${assigned ? 'Remove' : 'Assign'} ${module.name} ${assigned ? 'from' : 'to'} ${name || 'this child'}`} value={assigned} disabled={!module.available || busy} onValueChange={(enabled) => {
              setConfirmModules(false);
              setModuleDraft((current) => enabled ? [...current, module.id] : current.filter((id) => id !== module.id));
            }} trackColor={{ true: theme.colors.action }} />
          </View>;
        })}
        {!modulesChanged ? <Button label="Assignments are up to date" secondary disabled onPress={() => undefined} /> : !confirmModules
          ? <Button label="Review module assignments" secondary onPress={() => setConfirmModules(true)} disabled={busy} />
          : <View style={sharedStyles.column}>
            <Body>{assignedNames.length ? `Confirm assigning ${assignedNames.join(', ')} to ${name || 'this child'}.` : `Confirm removing all module access for ${name || 'this child'}.`}</Body>
            <Body>The child will lose access to any unassigned areas. Bloom will note who made this change and when.</Body>
            <Button label="Confirm assignments" busy={busy} onPress={() => void run(async () => {
              const saved = await saveChildModuleAssignments(childId, moduleDraft);
              setModuleAssignments(saved);
              setModuleDraft(saved.filter((assignment) => assignment.assigned).map((assignment) => assignment.module_id));
              setConfirmModules(false);
            })} />
            <Button label="Keep current assignments" secondary onPress={() => setConfirmModules(false)} disabled={busy} />
          </View>}
        {moduleAssignments.some((assignment) => assignment.updated_at) && <Body>Last assignment update: {new Date(moduleAssignments.filter((assignment) => assignment.updated_at).reduce((latest, assignment) => assignment.updated_at! > latest ? assignment.updated_at! : latest, '')).toLocaleString(getAppLocale())}</Body>}
      </Panel>}
      {(desktopColumns || section === 'limits') && <><Panel><Label>Screen-time credits</Label><Body>Available: {Math.round(child.balance * 100) / 100} minutes</Body>
        {confirmCreditsEnabled === null ? <Button label={child.settings.credits_enabled ? 'Review turning credits off' : 'Review turning credits on'} secondary busy={busy} onPress={() => setConfirmCreditsEnabled(!child.settings.credits_enabled)} /> : <View style={sharedStyles.column}>
          <Body>{confirmCreditsEnabled ? 'Enable screen-time rewards for' : 'Turn off screen-time rewards for'} {name || 'this child'}? Bloom will save this change to their account.</Body>
          <Button label={`Confirm credits ${confirmCreditsEnabled ? 'on' : 'off'}`} busy={busy} onPress={() => void run(async () => { await updateCredits(childId, confirmCreditsEnabled); setConfirmCreditsEnabled(null); })} />
          <Button label="Cancel" variant="secondary" onPress={() => setConfirmCreditsEnabled(null)} disabled={busy} />
        </View>}
        <Field label="Adjustment in minutes (use minus to remove)" value={amount} onChangeText={(value) => { setAmount(value); setConfirmAdjustment(false); }} keyboardType="numbers-and-punctuation" />
        <Field label="Reason (optional)" value={reason} onChangeText={(value) => { setReason(value); setConfirmAdjustment(false); }} maxLength={200} />
        {!confirmAdjustment ? <Button label="Review adjustment" secondary onPress={() => void adjust()} /> : <View style={sharedStyles.column}>
          <Body>{Number(amount) > 0 ? 'Add' : 'Remove'} {Math.abs(Number(amount)).toLocaleString(getAppLocale())} minutes {Number(amount) > 0 ? 'to' : 'from'} the shared balance for {name || 'this child'}? Bloom will keep a record of this change.</Body>
          {reason.trim() && <Body>Reason: {reason.trim()}</Body>}
          <Button label="Confirm adjustment" busy={busy} onPress={() => void applyAdjustment()} />
          <Button label="Cancel" secondary onPress={() => setConfirmAdjustment(false)} disabled={busy} />
        </View>}
      </Panel>
      <CreditRulesEditor key={JSON.stringify(child.settings)} settings={child.settings} subjectLabel={name || 'this child'} onSave={async (rules) => { await updateCreditRules(childId, rules); await load(); }} />
      <GrowthRewardControls key={`growth-rewards:${childId}`} profileId={childId} editable={Boolean(profileId)} approvalByDefault
        allowedModules={assignedGrowthModules} heading="Manage Study, Read & Tasks rewards" />
      {assignedGrowthModules.includes('study') && <ChildGrowthAiConsentControls key={`study-tutor:${childId}`} childId={childId} childName={name || 'this child'} moduleId="study" />}
      {assignedGrowthModules.includes('read') && <ChildGrowthAiConsentControls key={`read-reflection:${childId}`} childId={childId} childName={name || 'this child'} moduleId="read" />}
      {assignedGrowthModules.includes('study') && <ChildStudyDocumentControls key={`study-documents:${childId}`} childId={childId} childName={name || 'this child'} />}
      </>}
      {(desktopColumns || section === 'overview') && <><Panel><Label>Coaching</Label><Body>Manage permission and review workout proposals. Private conversations stay with the child.</Body><Button label="Manage coaching" secondary onPress={() => router.push({ pathname: '/child-coaching', params: { childId, name } } as unknown as Href)} /></Panel>
      <Panel><Label>Competitions and search</Label><Body>Control whether this child appears in search and approve event requests.</Body><Button label="Manage competitions" secondary onPress={() => router.push({ pathname: '/child-competitions', params: { childId, name } } as unknown as Href)} /></Panel></>}
      </View>
      <View style={[styles.column, desktopColumns && styles.desktopColumn]}>
      {desktopColumns && <WeeklyActivitySummary analytics={child.workoutAnalytics} />}
      {(desktopColumns || section === 'activity') && <><Panel><Eyebrow>Recent activity · {name || 'child account'}</Eyebrow>
        {child.workoutAnalytics.history.length === 0 && <Body>No completed workouts are available yet.</Body>}
        {child.workoutAnalytics.history.map((item) => <View key={item.id} style={sharedStyles.row}><View style={sharedStyles.grow}><Label>{item.plan_title}</Label><Body>Completed by {name || 'this child'} · {new Date(item.completed_at).toLocaleString(getAppLocale())}</Body><Body>{item.exercises_completed} exercises · {item.sets_completed} sets</Body></View>{item.credits_earned_minutes > 0 && <Body>+{item.credits_earned_minutes.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} min</Body>}</View>)}
        {child.workoutAnalytics.history.length === 20 && <Body>Showing the 20 most recent completed workouts available here.</Body>}
      </Panel>
      <Panel><Eyebrow>Study and reading · {child.growthActivity.length}</Eyebrow>
        <Body>Only completed Study sessions and saved reading progress are shown. Private tutor conversations, notes, and document contents stay in the child profile.</Body>
        {child.growthActivity.length === 0 && <Body>No Study sessions or reading progress are available for the modules assigned to this profile.</Body>}
        {child.growthActivity.map((activity) => <View key={`${activity.type}:${activity.id}`} style={sharedStyles.row}>
          <View style={sharedStyles.grow}>
            <Label>{activity.title}</Label>
            <Body>{activity.moduleId === 'study' ? `Study session · ${Math.floor((activity.durationSeconds ?? 0) / 60)} min` : `Reading · ${Math.round(activity.progressPercent ?? 0)}%${activity.pageCount !== null ? ` · page ${activity.currentPage ?? 0} of ${activity.pageCount}` : ''}`}</Body>
            <Body>{new Date(activity.occurredAt).toLocaleString(getAppLocale())}</Body>
          </View>
        </View>)}
      </Panel>
      <Panel><Label>Workout plans</Label>
        {child.plans.length === 0 && <Body>No plans yet.</Body>}
        {child.plans.map((plan) => <View key={plan.id} style={sharedStyles.column}><Body>{plan.title} · {plan.bloom_plan_exercises.length} exercises</Body><Body>{formatScheduledDays(plan.scheduled_days, getAppLocale())}</Body><Button label={`Edit ${plan.title}`} secondary onPress={() => router.push({ pathname: '/new-plan', params: { childId, planId: plan.id } } as Href)} />
          {confirmPlanRemoval === plan.id ? <><Body>Delete “{plan.title}” and its schedule for {name || 'this child'}?</Body><Button label="Confirm plan deletion" variant="destructive" busy={busy} onPress={() => void run(async () => { await deletePlan(plan.id); setConfirmPlanRemoval(null); })} /><Button label="Keep plan" variant="secondary" onPress={() => setConfirmPlanRemoval(null)} disabled={busy} /></>
            : <Button label={`Review deleting ${plan.title}`} variant="secondary" busy={busy} onPress={() => setConfirmPlanRemoval(plan.id)} />}</View>)}
        <Button label="Create workout for this child" onPress={() => router.push({ pathname: '/new-plan', params: { childId } } as Href)} />
      </Panel></>}
      {(desktopColumns || section === 'limits') && <><Panel><Eyebrow>iPhone website rules</Eyebrow><Body>Always rules use iOS web-content filtering on the child’s iPhone, need Screen Time access there, and support up to 50 domains. Focus-only rules use Bloom’s Safari extension while Focus is on. Safari Private Browsing may be disabled while the iOS filter is active; other browser coverage should be checked on the device. The child can add their own rules but can’t remove parent-managed ones.</Body>
        {child.websiteRules.map((rule) => <View key={rule.id} style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Body>{rule.domain} · {rule.scope === 'always' ? 'Always' : 'During Focus'}</Body><Body>{rule.created_by === childId ? 'Added by child' : 'Parent-managed'}</Body></View>
          {confirmWebsiteRemoval === rule.id ? <View style={sharedStyles.column}><Body>Remove {rule.domain} ({rule.scope === 'always' ? 'always blocked' : 'blocked during Focus'}) for {name || 'this child'}?</Body><Button label="Confirm removal" secondary busy={busy} onPress={() => void run(async () => { await deleteWebsiteRule(childId, rule.id); setConfirmWebsiteRemoval(null); })} /><Button label="Keep rule" variant="tertiary" onPress={() => setConfirmWebsiteRemoval(null)} disabled={busy} /></View>
            : <Button label="Remove" secondary busy={busy} onPress={() => setConfirmWebsiteRemoval(rule.id)} />}
        </View>)}
        <Body>Rule applies to</Body>{(['always', 'focus'] as const).map((choice) => <Button key={choice} secondary label={`${websiteScope === choice ? '✓ ' : ''}${choice === 'always' ? 'Always' : 'During Focus'}`} onPress={() => setWebsiteScope(choice)} />)}
        <Field label="Website or URL" value={website} onChangeText={setWebsite} autoCapitalize="none" autoCorrect={false} keyboardType="url" placeholder="example.com" />
        {pendingWebsite ? <View style={sharedStyles.column}><Body>Add {pendingWebsite.domain} for {name || 'this child'} as {pendingWebsite.scope === 'always' ? 'an always-blocked website' : 'a website blocked during Focus'}?</Body><Button label="Confirm website rule" busy={busy} onPress={() => void run(async () => { await addWebsiteRule(childId, pendingWebsite.scope, pendingWebsite.domain); setWebsite(''); setPendingWebsite(null); })} /><Button label="Keep editing" variant="secondary" onPress={() => setPendingWebsite(null)} disabled={busy} /></View>
          : <Button label="Review website rule" busy={busy} disabled={!website.trim()} onPress={() => setPendingWebsite({ domain: website.trim(), scope: websiteScope })} />}
      </Panel>
      <Panel><Label>App blocking rules</Label><Body>Android and macOS sync parent-set app rules when Focus opens. On iPhone, apps remain selected on the child’s device in Apple’s Screen Time picker. Website rules for Safari are managed above.</Body>
        {child.rules.map((rule) => <View key={rule.id} style={sharedStyles.column}><Body>{rule.platform} · {rule.target_type} · {rule.target_identifier}</Body>
          {confirmRuleRemoval === rule.id ? <><Body>Remove this rule for {name || 'this child'}?</Body><Button label="Confirm removal" secondary busy={busy} onPress={() => void run(async () => { await deleteChildRule(childId, rule.id); setConfirmRuleRemoval(null); })} /><Button label="Keep rule" variant="tertiary" onPress={() => setConfirmRuleRemoval(null)} disabled={busy} /></>
            : <Button label="Remove rule" secondary busy={busy} onPress={() => setConfirmRuleRemoval(rule.id)} />}
        </View>)}
        <Body>Platform</Body>{(['android', 'ios', 'macos'] as const).map((choice) => <Button key={choice} secondary label={`${platform === choice ? '✓ ' : ''}${choice}`} onPress={() => setPlatform(choice)} />)}
        <Body>Type</Body>{(['app', 'website'] as const).map((choice) => <Button key={choice} secondary label={`${kind === choice ? '✓ ' : ''}${choice}`} onPress={() => setKind(choice)} />)}
        <Field label={kind === 'website' ? 'Website domain' : 'App identifier'} value={identifier} onChangeText={setIdentifier} autoCapitalize="none" autoCorrect={false} maxLength={500} />
        {platform === 'ios' && kind === 'app' && <Body>Apple hides app selections behind local tokens, so Bloom cannot enforce an account app rule by package name on iOS. Choose the app in Apple’s Screen Time picker on that device.</Body>}
        {platform === 'ios' && kind === 'website' && <Body>Safari website rules are managed in the section above. This older Focus rule stays available for existing synced settings.</Body>}
        {pendingRule ? <View style={sharedStyles.column}><Body>Block {pendingRule.identifier} for {name || 'this child'} on {pendingRule.platform}?</Body><Button label="Confirm blocking rule" busy={busy} onPress={() => void run(async () => { await addChildRule(childId, pendingRule.platform, pendingRule.kind, pendingRule.identifier); setIdentifier(''); setPendingRule(null); })} /><Button label="Keep editing" variant="secondary" onPress={() => setPendingRule(null)} disabled={busy} /></View>
          : <Button label="Review blocking rule" busy={busy} disabled={!identifier.trim() || (platform === 'ios' && kind === 'app')} onPress={() => setPendingRule({ platform, kind, identifier: identifier.trim() })} />}
      </Panel></>}
      </View>
    </View></>}
  </Screen>;
}

function WeeklyActivitySummary({ analytics }: { analytics: WorkoutAnalytics }) {
  return <Panel><Eyebrow>This week</Eyebrow>
    <Label>{analytics.weekly_workout_target === null ? `${analytics.workouts_completed} workouts completed` : `${analytics.workouts_completed} of ${analytics.weekly_workout_target} workouts`}</Label>
    {analytics.planned_workouts > 0 && <Body>{analytics.completed_planned_workouts} of {analytics.planned_workouts} scheduled workouts complete · {analytics.rest_days} rest days</Body>}
    {analytics.missed_planned_workouts > 0 && <Body>A scheduled day passed without a workout. It’s okay to adjust the plan or leave room for rest.</Body>}
    {analytics.weekly_credit_target_minutes !== null && <Body>{analytics.credits_earned_minutes.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} of {analytics.weekly_credit_target_minutes} goal minutes earned</Body>}
    <Body>{analytics.active_days} active days · {analytics.exercise_minutes} timed exercise minutes · {analytics.sets_completed} sets · {analytics.reps_completed} repetitions</Body>
  </Panel>;
}

const styles = StyleSheet.create({
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  backButton: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 15 },
  workspace: { gap: 16 },
  desktopWorkspace: { flexDirection: 'row', alignItems: 'flex-start' },
  column: { flex: 1, gap: 16 },
  desktopColumn: { minWidth: 320 },
  sectionTabs: { flexDirection: 'row', gap: 7 },
  sectionTab: { flex: 1, minHeight: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 14, paddingHorizontal: 5 },
  sectionTabText: { fontSize: 12, fontWeight: '700' },
});
