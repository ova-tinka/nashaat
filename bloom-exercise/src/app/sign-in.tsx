import { Redirect } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Panel, Screen, sharedStyles } from '../components/bloom-ui';
import { useAuth } from '../lib/auth';
import { createTransientSupabaseClient, supabase } from '../lib/supabase';
import { getSavedChild, restoreChildSession } from '../lib/profile-switch';
import { colors } from '../theme';

export default function SignInScreen() {
  const { session, loading, configured } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [signingUp, setSigningUp] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [pairing, setPairing] = useState(false);
  const [pairingCode, setPairingCode] = useState('');
  const [linking, setLinking] = useState(false);
  const [linkCode, setLinkCode] = useState('');
  const [hasSavedChild, setHasSavedChild] = useState(false);

  useEffect(() => {
    let active = true;
    void getSavedChild().then((saved) => { if (active) setHasSavedChild(Boolean(saved)); }).catch(() => {});
    return () => { active = false; };
  }, []);

  if (loading) return <Screen><ActivityIndicator color={colors.accent} /></Screen>;
  if (session) return <Redirect href="/" />;

  async function submit() {
    if (!supabase) return;
    if (!email.trim() || !password) { setError('Enter your email and password.'); return; }
    setBusy(true); setError(null); setMessage(null);
    try {
      const result = signingUp
        ? await supabase.auth.signUp({ email: email.trim(), password })
        : await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (result.error) throw result.error;
      if (signingUp && !result.data.session) setMessage('Check your email to confirm your account, then sign in.');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not sign in. Please try again.');
    } finally { setBusy(false); }
  }

  async function pairDevice() {
    if (!supabase) return;
    const code = pairingCode.trim().toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(code)) { setError('Enter the complete pairing code from your parent.'); return; }
    setBusy(true); setError(null); setMessage(null);
    try {
      const before = await supabase.auth.getSession();
      if (before.error || before.data.session) throw new Error('Sign out before pairing this device.');
      const { data, error: invokeError } = await supabase.functions.invoke('bloom-pair-child', { body: { code } });
      if (invokeError || typeof data?.access_token !== 'string' || typeof data?.refresh_token !== 'string') throw new Error('Pairing failed. Ask a parent for a new code.');
      const after = await supabase.auth.getSession();
      if (after.error || after.data.session) throw new Error('Sign out before pairing this device.');
      const { error: sessionError } = await supabase.auth.setSession({ access_token: data.access_token, refresh_token: data.refresh_token });
      if (sessionError) throw sessionError;
      setPairingCode('');
    } catch { setError('Could not pair this device. Ask a parent for a new code and try again.'); }
    finally { setBusy(false); }
  }
  async function restoreChild() {
    setBusy(true); setError(null);
    try { await restoreChildSession(); setHasSavedChild(false); }
    catch { setError('Could not restore the child profile. Ask a parent for a new pairing code.'); }
    finally { setBusy(false); }
  }
  async function createLinkAccount() {
    if (!email.trim() || !password) { setError('Enter an email and password.'); return; }
    setBusy(true); setError(null); setMessage(null);
    try {
      const temporary = createTransientSupabaseClient();
      const result = await temporary.auth.signUp({ email: email.trim(), password });
      if (result.error) throw result.error;
      setMessage('If the account can be created, confirm its email if prompted, then choose “Link and sign in.”');
    } catch { setError('Could not create the account. Check the details and try again.'); }
    finally { setBusy(false); }
  }
  async function linkAccount() {
    if (!supabase) return;
    const code = linkCode.trim().toLowerCase();
    if (!email.trim() || !password || !/^[0-9a-f]{64}$/.test(code)) { setError('Enter the email, password, and complete link code.'); return; }
    setBusy(true); setError(null); setMessage(null);
    try {
      const temporary = createTransientSupabaseClient();
      const signedIn = await temporary.auth.signInWithPassword({ email: email.trim(), password });
      if (signedIn.error || !signedIn.data.user) throw new Error('Sign-in failed');
      const linked = await temporary.rpc('bloom_accept_child_account_link', { p_token: code });
      if (linked.error || typeof linked.data !== 'string') throw new Error('Link failed');
      const existing = await supabase.auth.getSession();
      if (existing.error || existing.data.session) throw new Error('Another account is active');
      const result = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (result.error) throw result.error;
      setLinkCode('');
    } catch { setError('Could not link the account. Confirm the email, use a new account without activity, and check the code.'); }
    finally { setBusy(false); }
  }

  return <Screen>
    <View style={sharedStyles.column}><Eyebrow>Bloom Exercise</Eyebrow><Heading>Movement that fits your life.</Heading><Body>Build a workout routine and make time for what matters.</Body></View>
    {!configured ? <Panel><ErrorText>Bloom cannot connect yet. Check the app configuration.</ErrorText></Panel> : linking ? <Panel>
      <Eyebrow>Link child email account</Eyebrow>
      <Body>Use a new email account with no existing Bloom activity. A parent provides the link code.</Body>
      <Field label="Email" value={email} onChangeText={setEmail} autoCapitalize="none" autoComplete="email" keyboardType="email-address" />
      <Field label="Password" value={password} onChangeText={setPassword} secureTextEntry autoComplete="new-password" />
      <Field label="Parent link code" value={linkCode} onChangeText={setLinkCode} autoCapitalize="none" autoCorrect={false} maxLength={64} />
      {error && <ErrorText>{error}</ErrorText>}{message && <Body>{message}</Body>}
      <Button label="Create new email account" secondary onPress={() => void createLinkAccount()} disabled={busy} />
      <Button label="Link and sign in" onPress={() => void linkAccount()} busy={busy} />
      <Button label="Back to sign in" secondary onPress={() => { setLinking(false); setLinkCode(''); setError(null); setMessage(null); }} disabled={busy} />
    </Panel> : pairing ? <Panel>
      <Eyebrow>Child device</Eyebrow>
      <Body>Enter the one-use code provided by your parent. Codes expire after 10 minutes.</Body>
      <Field label="Pairing code" value={pairingCode} onChangeText={setPairingCode} autoCapitalize="none" autoCorrect={false} maxLength={64} />
      {error && <ErrorText>{error}</ErrorText>}
      <Button label="Pair child device" onPress={() => void pairDevice()} busy={busy} />
      <Button label="Back to sign in" secondary onPress={() => { setPairing(false); setPairingCode(''); setError(null); }} disabled={busy} />
    </Panel> : <Panel>
      <Eyebrow>{signingUp ? 'Create your account' : 'Welcome back'}</Eyebrow>
      <Field label="Email" value={email} onChangeText={setEmail} autoCapitalize="none" autoComplete="email" keyboardType="email-address" />
      <Field label="Password" value={password} onChangeText={setPassword} secureTextEntry autoComplete={signingUp ? 'new-password' : 'current-password'} />
      {error && <ErrorText>{error}</ErrorText>}{message && <Body>{message}</Body>}
      <Button label={signingUp ? 'Create account' : 'Sign in'} onPress={() => void submit()} busy={busy} />
      <Button label={signingUp ? 'Already have an account? Sign in' : 'New to Bloom? Create an account'} secondary onPress={() => { setSigningUp(!signingUp); setError(null); setMessage(null); }} />
      <Button label="Pair child device" secondary onPress={() => { setPairing(true); setError(null); setMessage(null); }} disabled={busy} />
      <Button label="Link child email account" secondary onPress={() => { setLinking(true); setError(null); setMessage(null); }} disabled={busy} />
      {hasSavedChild && <Button label="Restore child profile" secondary onPress={() => void restoreChild()} disabled={busy} />}
    </Panel>}
  </Screen>;
}
