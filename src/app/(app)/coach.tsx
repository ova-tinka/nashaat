import { randomUUID } from 'expo-crypto';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { CoachProposalCard } from '../../components/coach-proposal';
import { useAuth } from '../../lib/auth';
import { loadCatalog, type Exercise } from '../../lib/bloom';
import { useBloom } from '../../lib/bloom-context';
import { clearCoachConversation, decideCoachProposal, loadCoach, saveCoachPreferences, sendCoachRequest, type CoachMessage, type CoachProposal, type CoachSettings } from '../../lib/coach';
import { colors } from '../../theme';

type Pending = { id: string; kind: 'chat' | 'weekly'; prompt: string };
export default function CoachScreen() {
  const { profileId, childProfile } = useAuth();
  const { refresh } = useBloom();
  const [settings, setSettings] = useState<CoachSettings | null>(null);
  const [messages, setMessages] = useState<CoachMessage[]>([]);
  const [proposals, setProposals] = useState<CoachProposal[]>([]);
  const [catalog, setCatalog] = useState<Exercise[]>([]);
  const [consent, setConsent] = useState(false);
  const [adult, setAdult] = useState(false);
  const [goals, setGoals] = useState('');
  const [equipment, setEquipment] = useState('');
  const [experience, setExperience] = useState<CoachSettings['experience']>('beginner');
  const [prompt, setPrompt] = useState('');
  const [pending, setPending] = useState<Pending | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);

  const load = useCallback(async () => {
    if (!profileId) return;
    try {
      const [data, items] = await Promise.all([loadCoach(profileId), loadCatalog()]);
      setSettings(data.settings); setMessages(data.messages); setProposals(data.proposals); setCatalog(items);
      setConsent(data.settings?.sharing_consent ?? false); setAdult(data.settings?.adult_attested ?? false);
      setGoals(data.settings?.goals ?? ''); setExperience(data.settings?.experience ?? 'beginner'); setEquipment((data.settings?.equipment ?? []).join(', '));
      setError(null);
    } catch { setError('Could not load coaching. Check your connection and try again.'); }
    finally { setLoading(false); }
  }, [profileId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));

  async function save() {
    const items = equipment.split(',').map((item) => item.trim()).filter(Boolean);
    if (items.length > 20 || items.some((item) => item.length > 60)) { setError('Use up to 20 equipment items of 60 characters each.'); return; }
    setBusy(true); setError(null); setNotice(null);
    try { await saveCoachPreferences(consent, childProfile ? false : adult, goals, experience, items); await load(); setNotice('Coaching preferences saved.'); }
    catch { setError('Could not save coaching preferences. Please try again.'); }
    finally { setBusy(false); }
  }
  async function send(kind: Pending['kind'], text: string) {
    const trimmed = text.trim();
    if (!trimmed || trimmed.length > 2000) { setError('Enter a message of up to 2,000 characters.'); return; }
    const request = pending ?? { id: randomUUID(), kind, prompt: trimmed };
    if (request.kind !== kind || request.prompt !== trimmed) { setError('Retry or clear your previous request first.'); return; }
    setPending(request); setBusy(true); setError(null); setNotice(null);
    try { await sendCoachRequest(request.id, request.kind, request.prompt); setPending(null); setPrompt(''); await load(); }
    catch { await load(); setError('Coaching is unavailable, consent is incomplete, or a request limit was reached. Retry the same request or start a new one.'); }
    finally { setBusy(false); }
  }
  async function decide(id: string, approve: boolean) {
    setBusy(true); setError(null); setNotice(null);
    try { await decideCoachProposal(id, approve); await load(); if (approve) await refresh(); setNotice(approve ? 'Workout plan saved.' : 'Proposal rejected.'); }
    catch { setError('Could not review this proposal. The plan may have changed or consent may have been withdrawn.'); }
    finally { setBusy(false); }
  }
  async function clearConversation() {
    setBusy(true); setError(null); setNotice(null);
    try { await clearCoachConversation(); setPending(null); setPrompt(''); setConfirmClear(false); await load(); setNotice('Conversation cleared. Your workout proposals are still available.'); }
    catch { setError('Could not clear the conversation. Wait for any request to finish and try again.'); }
    finally { setBusy(false); }
  }

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>AI coach</Eyebrow><Heading>Movement advice</Heading><Body>Ask for supportive ideas or review your recent workouts. Suggestions require approval before they change a plan.</Body></View>
    <Button label="Back to profile" secondary onPress={() => router.replace('/settings')} disabled={busy} />
    {loading && <ActivityIndicator color={colors.accent} />}{error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    {!loading && <>
      <Panel>
        <Label>Privacy and preferences</Label>
        <Body>If you consent, your message, goals, experience, equipment, plans, recent workouts, and recent chat are sent to Fireworks AI for coaching. Do not include names, contact details, medical records, or other identifying information.</Body>
        <View style={sharedStyles.row}><Body>I agree to this data sharing</Body><Switch accessibilityLabel="Consent to coaching data sharing" value={consent} onValueChange={setConsent} disabled={busy} /></View>
        {!childProfile && <View style={sharedStyles.row}><Body>I am an adult under my local law</Body><Switch accessibilityLabel="Confirm adult eligibility" value={adult} onValueChange={setAdult} disabled={busy} /></View>}
        {childProfile && <Body>A parent must also enable coaching, consent to data sharing, and confirm eligibility. Child coaching may not be available yet.</Body>}
        <Field label="Goals" value={goals} onChangeText={setGoals} maxLength={1000} multiline />
        <Field label="Equipment (comma separated)" value={equipment} onChangeText={setEquipment} maxLength={1000} />
        <Label>Experience</Label>
        {(['beginner', 'intermediate', 'experienced'] as const).map((choice) => <Button key={choice} label={`${experience === choice ? '✓ ' : ''}${choice}`} secondary onPress={() => setExperience(choice)} disabled={busy} />)}
        <Button label="Save preferences" onPress={() => void save()} busy={busy} />
      </Panel>
      {(settings?.sharing_consent || messages.length > 0) && <Panel>
        <Label>Conversation</Label>
        {messages.length === 0 && <Body>No messages yet.</Body>}
        {messages.map((message) => <View key={message.id} style={sharedStyles.column}><Label>{message.role === 'user' ? 'You' : 'Coach'}</Label><Body>{message.content}</Body></View>)}
        {messages.length > 0 && (confirmClear ? <>
          <Body>Clear your conversation? Workout proposals and plans will remain.</Body>
          <Button label="Confirm clear conversation" secondary onPress={() => void clearConversation()} busy={busy} />
          <Button label="Keep conversation" secondary onPress={() => setConfirmClear(false)} disabled={busy} />
        </> : <Button label="Clear conversation" secondary onPress={() => setConfirmClear(true)} disabled={busy} />)}
        {settings?.sharing_consent && <><Field label="Message the coach" value={prompt} onChangeText={setPrompt} maxLength={2000} multiline editable={!busy && (!pending || pending.kind === 'chat')} />
        <Button label={pending?.kind === 'chat' ? 'Retry message' : 'Send message'} onPress={() => void send('chat', prompt)} busy={busy} disabled={!prompt.trim() || Boolean(pending && pending.kind !== 'chat')} />
        <Button label={pending?.kind === 'weekly' ? 'Retry weekly review' : 'Review my recent workouts'} secondary onPress={() => void send('weekly', 'Please review my recent workouts and suggest a balanced next step.')} disabled={busy || Boolean(pending && pending.kind !== 'weekly')} />
        {pending && <Button label="Start a new request" secondary onPress={() => setPending(null)} disabled={busy} />}</>}
      </Panel>}
      {proposals.length > 0 && <><Label>Workout proposals</Label>{proposals.map((proposal) => <CoachProposalCard key={proposal.id} proposal={proposal} catalog={catalog} canApprove={!childProfile} busy={busy} onDecision={(approve) => void decide(proposal.id, approve)} />)}</>}
    </>}
  </Screen>;
}
