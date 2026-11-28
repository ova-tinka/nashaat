import { getAppLocale } from '../lib/locale-context';
import { useCallback, useMemo, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Label, Panel, sharedStyles } from './bloom-ui';
import { loadGrowthRewards, reviewGrowthReward, saveGrowthRewardRule, type GrowthModuleId, type GrowthRewardEvent, type GrowthRewardRule } from '../lib/growth-modules';
import { useBloomTheme } from '../lib/theme-context';

const moduleLabels: Record<GrowthModuleId, string> = { study: 'Study', read: 'Read', tasks: 'Tasks' };
const allModules: GrowthModuleId[] = ['study', 'read', 'tasks'];

function initialRule(profileId: string, moduleId: GrowthModuleId, approvalByDefault: boolean): GrowthRewardRule {
  return {
    profile_id: profileId, module_id: moduleId, enabled: false, reward_minutes: 5,
    daily_cap_minutes: 30, weekly_cap_minutes: 120, minimum_session_minutes: 5,
    require_parent_approval: approvalByDefault, updated_at: null,
  };
}

function parseMinutes(value: string, max: number) {
  if (!/^\d+(\.\d{1,2})?$/.test(value.trim())) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 && parsed <= max ? parsed : null;
}

export function GrowthRewardControls({
  profileId,
  editable,
  approvalByDefault = false,
  allowedModules = allModules,
  heading = 'Study, Read & Tasks rewards',
}: {
  profileId: string;
  editable: boolean;
  approvalByDefault?: boolean;
  allowedModules?: GrowthModuleId[];
  heading?: string;
}) {
  const { theme } = useBloomTheme();
  const [savedRules, setSavedRules] = useState<GrowthRewardRule[]>([]);
  const [drafts, setDrafts] = useState<Record<string, GrowthRewardRule>>({});
  const [textDrafts, setTextDrafts] = useState<Record<string, { reward: string; daily: string; weekly: string; minimum: string }>>({});
  const [events, setEvents] = useState<GrowthRewardEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [savingModule, setSavingModule] = useState<GrowthModuleId | null>(null);
  const [reviewing, setReviewing] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const modules = useMemo(() => allModules.filter((moduleId) => allowedModules.includes(moduleId)), [allowedModules]);

  const refresh = useCallback(async () => {
    try {
      const data = await loadGrowthRewards(profileId);
      const nextDrafts = Object.fromEntries(modules.map((moduleId) => {
        const rule = data.rules.find((entry) => entry.module_id === moduleId)
          ?? initialRule(profileId, moduleId, approvalByDefault);
        return [moduleId, rule];
      }));
      setSavedRules(data.rules);
      setDrafts(nextDrafts);
      setTextDrafts(Object.fromEntries(modules.map((moduleId) => {
        const rule = nextDrafts[moduleId];
        return [moduleId, {
          reward: String(rule.reward_minutes),
          daily: String(rule.daily_cap_minutes),
          weekly: String(rule.weekly_cap_minutes),
          minimum: String(rule.minimum_session_minutes),
        }];
      })));
      setEvents(data.events);
      setError(null);
    } catch {
      setError('Could not load these growth reward rules.');
    } finally {
      setLoading(false);
    }
  }, [approvalByDefault, modules, profileId]);

  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));

  function update(moduleId: GrowthModuleId, changes: Partial<GrowthRewardRule>) {
    setDrafts((current) => ({ ...current, [moduleId]: { ...current[moduleId], ...changes } }));
  }

  function updateText(moduleId: GrowthModuleId, field: 'reward' | 'daily' | 'weekly' | 'minimum', value: string) {
    setTextDrafts((current) => ({ ...current, [moduleId]: { ...current[moduleId], [field]: value } }));
  }

  async function save(moduleId: GrowthModuleId) {
    const rule = drafts[moduleId];
    const texts = textDrafts[moduleId];
    if (!rule || !texts) return;
    const reward = parseMinutes(texts.reward, 1440);
    const daily = parseMinutes(texts.daily, 1440);
    const weekly = parseMinutes(texts.weekly, 10080);
    const minimum = texts.minimum.trim() === '' ? NaN : Number(texts.minimum);
    if (!reward || !daily || !weekly || !Number.isFinite(minimum) || minimum < 0 || minimum > 720) {
      setError('Use a reward and caps above 0, with a session minimum from 0 to 720 minutes.');
      return;
    }
    setSavingModule(moduleId); setError(null); setNotice(null);
    try {
      await saveGrowthRewardRule({ ...rule, reward_minutes: reward, daily_cap_minutes: daily,
        weekly_cap_minutes: weekly, minimum_session_minutes: minimum });
      setNotice(`${moduleLabels[moduleId]} reward rules saved.`);
      await refresh();
    } catch {
      setError('Could not save these rules. Check module access and try again.');
    } finally {
      setSavingModule(null);
    }
  }

  async function review(event: GrowthRewardEvent, approve: boolean) {
    setReviewing(event.id); setError(null); setNotice(null);
    try {
      const awarded = await reviewGrowthReward(event.id, approve);
      setNotice(approve
        ? awarded > 0 ? `Reward approved: ${awarded} screen-time minutes added.` : 'No credit was added; current rules, approval status, or caps did not allow it.'
        : 'Reward declined.');
      await refresh();
    } catch {
      setError('Could not review this reward. Refresh the family profile and try again.');
    } finally {
      setReviewing(null);
    }
  }

  const dirty = (moduleId: GrowthModuleId) => {
    const draft = drafts[moduleId];
    const texts = textDrafts[moduleId];
    const saved = savedRules.find((rule) => rule.module_id === moduleId) ?? initialRule(profileId, moduleId, approvalByDefault);
    return draft && texts && (draft.enabled !== saved.enabled || texts.reward !== String(saved.reward_minutes)
      || texts.daily !== String(saved.daily_cap_minutes) || texts.weekly !== String(saved.weekly_cap_minutes)
      || texts.minimum !== String(saved.minimum_session_minutes)
      || draft.require_parent_approval !== saved.require_parent_approval);
  };

  return <Panel>
    <Eyebrow>Screen-time rewards</Eyebrow>
    <Label>{heading}</Label>
    <Body>These rules decide how each activity adds minutes to your shared balance. Study and Read sessions must meet the minimum time. Tasks earn minutes only when completed; Focus time does not add a second reward. Daily and weekly limits apply to each activity.</Body>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <ErrorText>{error}</ErrorText>}
    {notice && <Body>{notice}</Body>}
    {!loading && modules.map((moduleId) => {
      const rule = drafts[moduleId];
      const texts = textDrafts[moduleId];
      if (!rule || !texts) return null;
      return <View key={moduleId} style={[sharedStyles.column, { borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 14 }]}>
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>{moduleLabels[moduleId]}</Label><Body>{rule.enabled ? `${texts.reward || rule.reward_minutes} min per eligible completion` : 'Rewards off'}</Body></View>
          <Switch accessibilityLabel={`${moduleLabels[moduleId]} rewards`} value={rule.enabled} disabled={!editable || savingModule !== null}
            onValueChange={(enabled) => update(moduleId, { enabled })} trackColor={{ true: theme.colors.action }} />
        </View>
        <Field label="Minutes per completion" value={texts.reward} keyboardType="decimal-pad" editable={editable && savingModule === null}
          onChangeText={(value) => updateText(moduleId, 'reward', value)} />
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Field label="Daily cap (minutes)" value={texts.daily} keyboardType="decimal-pad" editable={editable && savingModule === null}
            onChangeText={(value) => updateText(moduleId, 'daily', value)} /></View>
          <View style={sharedStyles.grow}><Field label="Weekly cap (minutes)" value={texts.weekly} keyboardType="decimal-pad" editable={editable && savingModule === null}
            onChangeText={(value) => updateText(moduleId, 'weekly', value)} /></View>
        </View>
        {moduleId !== 'tasks' && <Field label="Minimum Study/Read session (minutes)" value={texts.minimum} keyboardType="decimal-pad" editable={editable && savingModule === null}
          onChangeText={(value) => updateText(moduleId, 'minimum', value)} />}
        {approvalByDefault && <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>Parent approval</Label><Body>{rule.require_parent_approval ? 'Each reward waits for your review.' : 'Eligible rewards are added automatically.'}</Body></View>
          <Switch accessibilityLabel={`Require parent approval for ${moduleLabels[moduleId]} rewards`} value={rule.require_parent_approval}
            disabled={!editable || savingModule !== null} onValueChange={(require_parent_approval) => update(moduleId, { require_parent_approval })}
            trackColor={{ true: theme.colors.action }} />
        </View>}
        {editable && <Button label={dirty(moduleId) ? `Save ${moduleLabels[moduleId]} rules` : `${moduleLabels[moduleId]} rules saved`}
          disabled={!dirty(moduleId) || savingModule !== null} busy={savingModule === moduleId}
          variant={dirty(moduleId) ? 'primary' : 'secondary'} onPress={() => void save(moduleId)} />}
      </View>;
    })}
    {events.some((event) => modules.includes(event.module_id)) && <View style={[sharedStyles.column, { borderTopWidth: 1, borderTopColor: theme.colors.border, paddingTop: 14 }]}>
      <Eyebrow>Recent eligible completions</Eyebrow>
      {events.filter((event) => modules.includes(event.module_id)).map((event) => <View key={event.id} style={sharedStyles.column}>
        <Body>{moduleLabels[event.module_id]} · {event.source_type === 'session' ? 'completed session' : 'completed task'} · {event.status === 'awarded'
          ? `+${event.awarded_minutes} min` : event.status.replaceAll('_', ' ')}</Body>
        <Body>{new Date(event.created_at).toLocaleString(getAppLocale())}</Body>
        {editable && approvalByDefault && event.status === 'pending' && <View style={sharedStyles.row}>
          <Button label="Approve" disabled={reviewing !== null} busy={reviewing === event.id} onPress={() => void review(event, true)} />
          <Button label="Decline" variant="secondary" disabled={reviewing !== null} onPress={() => void review(event, false)} />
        </View>}
      </View>)}
    </View>}
  </Panel>;
}
