import { useCallback, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Body, Button, ErrorText, Eyebrow, Field, Label, Panel, sharedStyles } from './bloom-ui';
import { deleteGrowthMemory, loadGrowthMemory, saveGrowthMemory, type GrowthMemory, type GrowthMemoryDomain } from '../lib/growth-memory';
import { useBloomTheme } from '../lib/theme-context';

const domains: { id: GrowthMemoryDomain; name: string; prompt: string }[] = [
  { id: 'exercise', name: 'Exercise', prompt: 'Goals, preferences, access needs, or recovery boundaries' },
  { id: 'study', name: 'Study', prompt: 'Topics, learning preferences, or study constraints' },
  { id: 'read', name: 'Read', prompt: 'Reading interests, preferred formats, or context' },
  { id: 'tasks', name: 'Tasks', prompt: 'Planning preferences or recurring constraints' },
];
const emptyMemory = (profileId: string): GrowthMemory => ({
  profile_id: profileId, enabled: false, shared_domains: [],
  summaries: { exercise: '', study: '', read: '', tasks: '' }, updated_at: null,
});

export function GrowthMemoryControls({ profileId, onStatusChange }: { profileId: string; onStatusChange?: (enabled: boolean | null) => void }) {
  const { theme } = useBloomTheme();
  const [draft, setDraft] = useState<GrowthMemory>(() => emptyMemory(profileId));
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try { const memory = await loadGrowthMemory(profileId); setDraft(memory); onStatusChange?.(memory.enabled); setError(null); }
    catch { onStatusChange?.(null); setError('Could not load your shared memory settings.'); }
    finally { setLoading(false); }
  }, [onStatusChange, profileId]);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));

  function updateSummary(domain: GrowthMemoryDomain, summary: string) {
    setDraft((current) => ({ ...current, summaries: { ...current.summaries, [domain]: summary } }));
  }
  function toggleDomain(domain: GrowthMemoryDomain, enabled: boolean) {
    setDraft((current) => ({ ...current, shared_domains: enabled
      ? [...new Set([...current.shared_domains, domain])]
      : current.shared_domains.filter((value) => value !== domain) }));
  }

  async function save() {
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthMemory({ enabled: draft.enabled, shared_domains: draft.shared_domains,
        summaries: Object.fromEntries(domains.map(({ id }) => [id, draft.summaries[id] ?? ''])) });
      setNotice(draft.enabled ? 'Memory settings saved. Only selected domains can be shared with approved AI features.' : 'Memory is saved but off, so AI features cannot use it.');
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error && cause.message.includes('4,000')
        ? 'Keep the combined summaries under 4,000 characters.' : 'Could not save your memory settings. Check each summary and try again.');
    } finally { setBusy(false); }
  }

  async function clear() {
    setBusy(true); setError(null); setNotice(null);
    try {
      await deleteGrowthMemory(); setDraft(emptyMemory(profileId)); onStatusChange?.(false); setConfirmDelete(false);
      setNotice('All shared memory summaries and permissions were deleted.');
    } catch { setError('Could not delete your shared memory.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>Personal memory</Eyebrow>
    <Label>Shared growth summaries</Label>
    <Body>When enabled, approved AI features can use only the domains you select, and only when that feature has separate consent. No domains are shared until you choose them. Family members cannot read this memory. You can edit or delete it any time.</Body>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    <View style={sharedStyles.row}>
      <View style={sharedStyles.grow}><Label>Enable shared memory</Label><Body>{draft.enabled ? 'Selected summaries may be used by AI features.' : 'Off. No summary is shared with AI.'}</Body></View>
      <Switch accessibilityLabel="Enable shared growth memory" value={draft.enabled} disabled={loading || busy}
        onValueChange={(enabled) => setDraft((current) => ({ ...current, enabled }))} trackColor={{ true: theme.colors.action }} />
    </View>
    {domains.map(({ id, name, prompt: summaryPrompt }) => <View key={id} style={sharedStyles.column}>
      <View style={sharedStyles.row}>
        <View style={sharedStyles.grow}><Label>{name} summary</Label><Body>{summaryPrompt}</Body></View>
        <Switch accessibilityLabel={`Share ${name} summary with AI`} value={draft.shared_domains.includes(id)} disabled={loading || busy}
          onValueChange={(enabled) => toggleDomain(id, enabled)} trackColor={{ true: theme.colors.action }} />
      </View>
      <Field label={`${name} summary (1,200 characters max)`} value={draft.summaries[id] ?? ''} onChangeText={(value) => updateSummary(id, value)}
        maxLength={1200} multiline editable={!loading && !busy} />
    </View>)}
    {!loading && <Button label="Save memory settings" onPress={() => void save()} busy={busy} disabled={busy} />}
    {draft.updated_at && <Body>Last saved {new Date(draft.updated_at).toLocaleString()}.</Body>}
    {draft.updated_at && !confirmDelete && <Button label="Delete all shared memory" variant="secondary" disabled={busy || loading} onPress={() => setConfirmDelete(true)} />}
    {confirmDelete && <View style={sharedStyles.column}>
      <Body>Delete all four domain summaries and sharing permissions?</Body>
      <Button label="Confirm delete memory" variant="destructive" busy={busy} disabled={loading} onPress={() => void clear()} />
      <Button label="Keep memory" variant="secondary" disabled={busy} onPress={() => setConfirmDelete(false)} />
    </View>}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}
