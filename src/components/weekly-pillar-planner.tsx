import { getAppLocale } from '../lib/locale-context';
import { useCallback, useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, Switch, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Body, Button, ErrorText, Eyebrow, Field, Label, Panel, ProgressBar, sharedStyles } from './bloom-ui';
import { loadWeeklyPillarActuals, loadWeeklyPillarGoals, saveWeeklyPillarGoals, type WeeklyPillarActual, type WeeklyPillarGoal } from '../lib/growth-modules';
import { useBloomTheme } from '../lib/theme-context';
import { suggestWeeklyCheckInSchedule, type WeeklyCheckIn, type WeeklyCoachedScheduleProposal, type WeeklyScheduleGoal } from '../lib/weekly-planner';
import type { ModuleKey } from '../theme';

const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const pillarDefinitions: { moduleId: ModuleKey; title: string; unit: WeeklyPillarGoal['unit']; defaultTarget: number; maximum: number; description: string }[] = [
  { moduleId: 'exercise', title: 'Exercise', unit: 'workouts', defaultTarget: 3, maximum: 7, description: 'Completed workouts this week.' },
  { moduleId: 'study', title: 'Study', unit: 'minutes', defaultTarget: 120, maximum: 10080, description: 'Focused minutes this week.' },
  { moduleId: 'read', title: 'Read', unit: 'sessions', defaultTarget: 3, maximum: 100, description: 'Completed reading sessions this week.' },
  { moduleId: 'tasks', title: 'Tasks', unit: 'tasks', defaultTarget: 5, maximum: 500, description: 'Completed task items this week.' },
];
type DraftGoal = { enabled: boolean; target: string; days: string };
function defaultDraft(definition: (typeof pillarDefinitions)[number]): DraftGoal {
  return { enabled: false, target: String(definition.defaultTarget), days: '1, 3, 5' };
}

function parseDays(value: string) {
  const parsed = value.split(',').map((part) => Number(part.trim()));
  if (!value.trim() || parsed.some((day) => !Number.isInteger(day) || day < 0 || day > 6)
    || new Set(parsed).size !== parsed.length) return null;
  return parsed.sort((left, right) => left - right);
}

export function WeeklyPillarPlanner({ allowedModules }: { allowedModules: ModuleKey[] }) {
  const { theme } = useBloomTheme();
  const modules = useMemo(() => pillarDefinitions.filter((entry) => allowedModules.includes(entry.moduleId)), [allowedModules]);
  const [drafts, setDrafts] = useState<Record<string, DraftGoal>>(() => Object.fromEntries(pillarDefinitions.map((item) => [item.moduleId, defaultDraft(item)])));
  const [savedGoals, setSavedGoals] = useState<WeeklyPillarGoal[]>([]);
  const [actuals, setActuals] = useState<WeeklyPillarActual[]>([]);
  const [proposal, setProposal] = useState<WeeklyCoachedScheduleProposal | null>(null);
  const [checkIn, setCheckIn] = useState<WeeklyCheckIn | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const [goals, nextActuals] = await Promise.all([loadWeeklyPillarGoals(), loadWeeklyPillarActuals()]);
      const nextDrafts = Object.fromEntries(pillarDefinitions.map((definition) => {
        const goal = goals.find((entry) => entry.module_id === definition.moduleId);
        return [definition.moduleId, goal ? { enabled: true, target: String(goal.target_count), days: goal.active_days.join(', ') } : defaultDraft(definition)];
      }));
      setDrafts(nextDrafts); setSavedGoals(goals); setActuals(nextActuals); setError(null);
    } catch { setError('Could not load your cross-pillar weekly plan.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));

  function update(moduleId: ModuleKey, value: Partial<DraftGoal>) {
    setDrafts((current) => ({ ...current, [moduleId]: { ...current[moduleId], ...value } }));
  }

  async function persist(goals: WeeklyScheduleGoal[], successMessage: string) {
    setBusy(true); setError(null); setNotice(null);
    try {
      const preserved = savedGoals.filter((goal) => !modules.some((m) => m.moduleId === goal.module_id));
      await saveWeeklyPillarGoals([...preserved, ...goals].map(({ module_id, target_count, active_days }) => ({ module_id, target_count, active_days })));
      setProposal(null); setCheckIn(null);
      await refresh();
      setNotice(successMessage);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save the weekly goals.');
    } finally { setBusy(false); }
  }

  async function save() {
    try {
      const goals = modules.flatMap((definition) => {
        const draft = drafts[definition.moduleId];
        if (!draft?.enabled) return [];
        const target = Number(draft.target);
        const activeDays = parseDays(draft.days);
        if (!Number.isInteger(target) || target < 1 || target > definition.maximum) {
          throw new Error(`${definition.title}: choose a weekly target from 1 to ${definition.maximum}.`);
        }
        if (!activeDays) throw new Error(`${definition.title}: choose one or more unique days from Sunday (0) to Saturday (6).`);
        return [{ module_id: definition.moduleId, target_count: target, unit: definition.unit, active_days: activeDays }];
      });
      await persist(goals, 'Weekly goals saved. Unscheduled days stay flexible for rest or recovery and are not marked as missed.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save the weekly goals.');
    }
  }

  function suggestSchedule(response: WeeklyCheckIn) {
    const goals = savedGoals.filter((goal) => modules.some((module) => module.moduleId === goal.module_id));
    setProposal(suggestWeeklyCheckInSchedule(goals.map(({ module_id, target_count, unit, active_days }) => ({
      module_id, target_count, unit, active_days,
    })), response));
    setCheckIn(response);
    setNotice(null);
  }

  function editProposal() {
    if (!proposal) return;
    const nextDrafts = { ...drafts };
    for (const goal of proposal.goals) {
      nextDrafts[goal.module_id] = {
        enabled: true,
        target: String(goal.target_count),
        days: goal.active_days.join(', '),
      };
    }
    setDrafts(nextDrafts);
    setProposal(null);
    setNotice('Suggested changes loaded. Review the targets and days, then save when ready.');
  }

  async function acceptProposal() {
    if (!proposal) return;
    await persist(proposal.goals, 'Balanced weekly plan saved. Your open recovery day remains flexible.');
  }

  return <Panel>
    <Eyebrow>Flexible weekly plan</Eyebrow>
    <Label>Goals across your assigned pillars</Label>
    <Body>Choose a weekly target and the days you want to make room for it. Other days are rest or flexible recovery time. You can change or turn off any goal; a missed planned day is not a failure.</Body>
    {loading && <ActivityIndicator color={modules.length === 1 ? theme.modules[modules[0].moduleId].deep : theme.colors.action} />}
    {error && <ErrorText>{error}</ErrorText>}
    {!loading && modules.map((definition) => {
      const draft = drafts[definition.moduleId];
      if (!draft) return null;
      const accent = theme.modules[definition.moduleId];
      return <View key={definition.moduleId} style={[sharedStyles.column, { borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 14 }]}>
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>{definition.title}</Label><Body>{definition.description}</Body></View>
          <Switch accessibilityLabel={`Include ${definition.title} in weekly plan`} value={draft.enabled} disabled={busy || Boolean(proposal)}
            onValueChange={(enabled) => update(definition.moduleId, { enabled })} trackColor={{ true: accent.accent }} />
        </View>
        {draft.enabled && <>
          {savedGoals.some((goal) => goal.module_id === definition.moduleId) && <>
            <Body>This week: {((actuals.find((actual) => actual.module_id === definition.moduleId)?.actual_value) ?? 0).toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} of {draft.target} {definition.unit} completed.</Body>
            <ProgressBar value={((actuals.find((actual) => actual.module_id === definition.moduleId)?.actual_value) ?? 0) / Math.max(1, Number(draft.target)) * 100}
              label={`${definition.title} weekly progress`} color={theme.modules[definition.moduleId].deep} />
          </>}
          <Field label={`Weekly ${definition.unit} goal`} value={draft.target} onChangeText={(target) => update(definition.moduleId, { target })}
            keyboardType="number-pad" editable={!busy && !proposal} />
          <Label>Choose active days</Label>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 7 }} accessibilityRole="group" accessibilityLabel={`${definition.title} active days`}>
            {days.map((day, dayIndex) => {
              const activeDays = parseDays(draft.days) ?? [];
              const selected = activeDays.includes(dayIndex);
              return <Pressable key={day} accessibilityRole="checkbox" accessibilityLabel={`${day} for ${definition.title}`}
                accessibilityState={{ checked: selected, disabled: busy || Boolean(proposal) }} disabled={busy || Boolean(proposal)}
                onPress={() => update(definition.moduleId, { days: (selected ? activeDays.filter((value) => value !== dayIndex) : [...activeDays, dayIndex]).sort((a, b) => a - b).join(', ') })}
              style={{ minWidth: 46, minHeight: 44, paddingHorizontal: 10, borderWidth: 1, borderRadius: 12, alignItems: 'center', justifyContent: 'center', borderColor: selected ? accent.deep : theme.colors.border, backgroundColor: selected ? accent.surface : theme.colors.surface }}>
                <Label>{day}</Label>
              </Pressable>;
            })}
          </View>
          {parseDays(draft.days) && <Body>Scheduled: {parseDays(draft.days)!.map((day) => days[day]).join(', ')} · {7 - parseDays(draft.days)!.length} rest or flexible {7 - parseDays(draft.days)!.length === 1 ? 'day' : 'days'}.</Body>}
        </>}
      </View>;
    })}
    {savedGoals.length > 0 && <Body>Currently saved for {savedGoals.length} pillar{savedGoals.length === 1 ? '' : 's'}.</Body>}
    {!loading && <Button label="Save weekly plan" onPress={() => void save()} busy={busy} disabled={busy || Boolean(proposal)} />}
    {!loading && savedGoals.some((goal) => modules.some((module) => module.moduleId === goal.module_id)) && !proposal &&
      <View style={[sharedStyles.column, { borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 14 }]}>
        <Eyebrow>Weekly check-in</Eyebrow>
        <Body>How did this plan feel across your active pillars? Your actuals below are context; your answer controls whether targets change. Suggestions are prepared on this device and saved only after you review them.</Body>
        {savedGoals.filter((goal) => modules.some((module) => module.moduleId === goal.module_id)).map((goal) => {
          const definition = pillarDefinitions.find((entry) => entry.moduleId === goal.module_id);
          if (!definition) return null;
          const actual = actuals.find((entry) => entry.module_id === goal.module_id)?.actual_value ?? 0;
          return <Body key={goal.module_id}>{definition.title}: {actual.toLocaleString(getAppLocale(), { maximumFractionDigits: 1 })} of {goal.target_count} {goal.unit}</Body>;
        })}
        {(['steady', 'hard_to_fit', 'too_much'] as const).map((answer) => <Button key={answer}
          label={`${checkIn === answer ? '✓ ' : ''}${answer === 'steady' ? 'Steady' : answer === 'hard_to_fit' ? 'Hard to fit' : 'Too much'}`}
          variant="tertiary" disabled={busy} onPress={() => setCheckIn(answer)} />)}
        {checkIn && <Button label="Review weekly suggestion" variant="secondary" onPress={() => suggestSchedule(checkIn)} disabled={busy} />}
      </View>}
    {proposal && <View style={[sharedStyles.column, { borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 14 }]}>
      <Eyebrow>Weekly coach suggestion · review before saving</Eyebrow>
      <Body>This proposal balances the saved goals across up to six days and leaves {days[proposal.recovery_day]} open for rest or recovery. It does not change your plan unless you accept it.</Body>
      {proposal.check_in === 'steady' && <Body>You said the plan felt steady. The suggestion keeps each weekly target and balances the planned days.</Body>}
      {proposal.check_in === 'hard_to_fit' && <Body>You said the plan was hard to fit. The suggestion keeps each weekly target and spreads planned days more evenly.</Body>}
      {proposal.check_in === 'too_much' && <Body>You said the plan felt like too much. The suggestion lowers targets by about 20% (with a minimum of one), then rebalances planned days. You can edit or decline it.</Body>}
      {proposal.goals.map((goal) => {
        const definition = pillarDefinitions.find((entry) => entry.moduleId === goal.module_id);
        if (!definition) return null;
        const previousTarget = savedGoals.find((saved) => saved.module_id === goal.module_id)?.target_count;
        return <View key={goal.module_id} style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>{definition.title} · {goal.target_count} {goal.unit}{previousTarget !== undefined && previousTarget !== goal.target_count ? ` (was ${previousTarget})` : ''}</Label><Body>{formatDays(goal.active_days)}</Body></View>
        </View>;
      })}
      <Button label="Accept schedule" onPress={() => void acceptProposal()} busy={busy} disabled={busy} />
      <Button label="Edit suggestion" variant="secondary" onPress={editProposal} disabled={busy} />
      <Button label="Decline" variant="tertiary" onPress={() => { setProposal(null); setCheckIn(null); setNotice('Suggestion declined. Your saved weekly plan is unchanged.'); }} disabled={busy} />
    </View>}
    {notice && <Body>{notice}</Body>}
  </Panel>;
}

function formatDays(activeDays: number[]) {
  return activeDays.slice().sort((left, right) => left - right).map((day) => days[day]).join(', ');
}
