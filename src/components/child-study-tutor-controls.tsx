import { useCallback, useMemo, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Body, Button, ErrorText, Eyebrow, Label, Panel, sharedStyles } from './bloom-ui';
import { loadChildDocumentAiStatus, loadChildGrowthAiStatus, saveChildDocumentAiPreferences, saveChildGrowthAiPreferences, type ChildGrowthAiStatus } from '../lib/growth-ai';
import { useBloomTheme } from '../lib/theme-context';

const off: ChildGrowthAiStatus = { enabled: false, eligible: false, parent_consent: false };

export function ChildGrowthAiConsentControls({ childId, childName, moduleId }: {
  childId: string; childName: string; moduleId: 'study' | 'read';
}) {
  const featureName = moduleId === 'study' ? 'Study tutor' : 'AI reading reflection prompts';
  const { theme } = useBloomTheme();
  const [saved, setSaved] = useState<ChildGrowthAiStatus>(off);
  const [draft, setDraft] = useState<ChildGrowthAiStatus>(off);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirm, setConfirm] = useState(false);
  const refresh = useCallback(async () => {
    try {
      const status = await loadChildGrowthAiStatus(childId, moduleId);
      setSaved(status); setDraft(status); setError(null);
    } catch { setError(`Could not load the ${featureName} consent status.`); }
    finally { setLoading(false); }
  }, [childId, featureName, moduleId]);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));
  const dirty = useMemo(() => draft.enabled !== saved.enabled || draft.eligible !== saved.eligible
    || draft.parent_consent !== saved.parent_consent, [draft, saved]);

  async function save() {
    setBusy(true); setError(null); setNotice(null); setConfirm(false);
    try {
      await saveChildGrowthAiPreferences(childId, moduleId, draft.enabled, draft.eligible, draft.parent_consent);
      setNotice(draft.enabled ? `${featureName} enabled for ${childName}. Their questions and responses stay private.` : `${featureName} disabled for this profile.`);
      await refresh();
    } catch {
      setError(`Could not save ${featureName} consent. Enabling it requires both parent consent and an eligibility attestation.`);
    } finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>AI consent</Eyebrow>
    <Label>{featureName} for {childName}</Label>
    <Body>{moduleId === 'study'
      ? 'The child must also consent in their Study profile. Their tutor questions and answers are private and are not shown in Family Space.'
      : 'The child must also consent in their Read profile. Reading titles, notes, and any shared memory they opted into are sent only for a single prompt; saved reflections stay private and are not shown in Family Space.'}</Body>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    <View style={sharedStyles.row}>
      <View style={sharedStyles.grow}><Label>Enable {featureName}</Label><Body>{draft.enabled ? 'Available after the child consents.' : 'Off for this profile.'}</Body></View>
      <Switch accessibilityLabel={`Enable ${featureName} for ${childName}`} value={draft.enabled} disabled={busy || loading}
        onValueChange={(enabled) => { setDraft((current) => ({ ...current, enabled })); setConfirm(false); }} trackColor={{ true: theme.colors.action }} />
    </View>
    {draft.enabled && <>
      <View style={sharedStyles.row}>
        <View style={sharedStyles.grow}><Label>Parent eligibility attestation</Label><Body>Confirm that the child is eligible to use this AI feature.</Body></View>
        <Switch accessibilityLabel={`Attest ${featureName} eligibility for ${childName}`} value={draft.eligible} disabled={busy || loading}
          onValueChange={(eligible) => { setDraft((current) => ({ ...current, eligible })); setConfirm(false); }} trackColor={{ true: theme.colors.action }} />
      </View>
      <View style={sharedStyles.row}>
        <View style={sharedStyles.grow}><Label>Parent sharing consent</Label><Body>{moduleId === 'study'
          ? 'Allow Study questions to go to Bloom’s approved AI provider.'
          : 'Allow reading titles, notes, and any opted-in shared memory to go to Bloom’s approved AI provider for one reflection question.'}</Body></View>
        <Switch accessibilityLabel={`Consent to ${featureName} for ${childName}`} value={draft.parent_consent} disabled={busy || loading}
          onValueChange={(parent_consent) => { setDraft((current) => ({ ...current, parent_consent })); setConfirm(false); }} trackColor={{ true: theme.colors.action }} />
      </View>
    </>}
    {dirty && !confirm && <Button label={`Review ${featureName} consent`} variant="secondary" disabled={busy || loading} onPress={() => setConfirm(true)} />}
    {confirm && <View style={sharedStyles.column}>
      <Body>{draft.enabled
        ? `Confirm enabling ${featureName} for ${childName}. The child must consent, and their private data stays in their profile.`
        : `Confirm turning off ${featureName} for ${childName}.`}</Body>
      <Button label={`Confirm ${featureName} settings`} busy={busy} onPress={() => void save()} />
      <Button label="Keep current settings" variant="secondary" disabled={busy} onPress={() => setConfirm(false)} />
    </View>}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

export function ChildStudyDocumentControls({ childId, childName }: { childId: string; childName: string }) {
  const { theme } = useBloomTheme();
  const [saved, setSaved] = useState<ChildGrowthAiStatus>(off);
  const [draft, setDraft] = useState<ChildGrowthAiStatus>(off);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirm, setConfirm] = useState(false);
  const refresh = useCallback(async () => {
    try { const status = await loadChildDocumentAiStatus(childId); setSaved(status); setDraft(status); setError(null); }
    catch { setError('Could not load document-help consent.'); }
    finally { setLoading(false); }
  }, [childId]);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));
  const dirty = useMemo(() => draft.enabled !== saved.enabled || draft.eligible !== saved.eligible
    || draft.parent_consent !== saved.parent_consent, [draft, saved]);

  async function save() {
    setBusy(true); setError(null); setNotice(null); setConfirm(false);
    try {
      await saveChildDocumentAiPreferences(childId, draft.enabled, draft.eligible, draft.parent_consent);
      setNotice(draft.enabled ? `Document help enabled for ${childName}. They must also consent in Study.` : 'Document help disabled for this profile.');
      await refresh();
    } catch { setError('Could not save document-help consent. Enabling it requires parent consent and an eligibility attestation.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>AI consent</Eyebrow>
    <Label>Private Study document help for {childName}</Label>
    <Body>The child must also agree to send their question and relevant document excerpts to Bloom’s approved AI provider. Document answers stay in their private Study history.</Body>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Enable document help</Label><Body>{draft.enabled ? 'Available after the child consents.' : 'Off for this profile.'}</Body></View>
      <Switch accessibilityLabel={`Enable document help for ${childName}`} value={draft.enabled} disabled={busy || loading}
        onValueChange={(enabled) => { setDraft((current) => ({ ...current, enabled })); setConfirm(false); }} trackColor={{ true: theme.colors.action }} /></View>
    {draft.enabled && <>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Parent eligibility attestation</Label><Body>Confirm this child is eligible for document help.</Body></View>
        <Switch accessibilityLabel={`Attest document help eligibility for ${childName}`} value={draft.eligible} disabled={busy || loading}
          onValueChange={(eligible) => { setDraft((current) => ({ ...current, eligible })); setConfirm(false); }} trackColor={{ true: theme.colors.action }} /></View>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Parent document-sharing consent</Label><Body>Allow relevant excerpts and questions to be processed.</Body></View>
        <Switch accessibilityLabel={`Consent to document help for ${childName}`} value={draft.parent_consent} disabled={busy || loading}
          onValueChange={(parent_consent) => { setDraft((current) => ({ ...current, parent_consent })); setConfirm(false); }} trackColor={{ true: theme.colors.action }} /></View>
    </>}
    {dirty && !confirm && <Button label="Review document-help consent" variant="secondary" disabled={busy || loading} onPress={() => setConfirm(true)} />}
    {confirm && <View style={sharedStyles.column}><Body>Confirm document-help settings for {childName}. The child must consent separately and can delete documents and answers.</Body>
      <Button label="Confirm document settings" busy={busy} onPress={() => void save()} />
      <Button label="Keep current settings" variant="secondary" disabled={busy} onPress={() => setConfirm(false)} /></View>}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}
