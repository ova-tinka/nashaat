import { router, useLocalSearchParams, type Href } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Platform, View } from 'react-native';
import { BloomWordmark, Body, Button, DesktopContent, ErrorText, Eyebrow, Field, Heading, Panel, Screen, sharedStyles } from '../components/bloom-ui';
import { useAuth } from '../lib/auth';
import { captureException } from '../lib/sentry';
import { supabase } from '../lib/supabase';
import { useBloomTheme } from '../lib/theme-context';

function readUrlRecoveryError(paramError?: string, paramDescription?: string): string | null {
  if (paramError || paramDescription) {
    return paramDescription || 'This password reset link is invalid or has expired. Request a new link.';
  }
  if (Platform.OS === 'web' && typeof window !== 'undefined') {
    const hash = window.location.hash.startsWith('#') ? window.location.hash.slice(1) : window.location.hash;
    const hashParams = new URLSearchParams(hash);
    const searchParams = new URLSearchParams(window.location.search);
    const error = hashParams.get('error') || searchParams.get('error');
    const description = hashParams.get('error_description') || searchParams.get('error_description');
    if (error || description) {
      return description || 'This password reset link is invalid or has expired. Request a new link.';
    }
  }
  return null;
}

export default function ResetPasswordScreen() {
  const { theme } = useBloomTheme();
  const { session, loading, passwordRecovery, clearPasswordRecovery } = useAuth();
  const params = useLocalSearchParams<{ error?: string; error_description?: string }>();
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [completed, setCompleted] = useState(false);

  const linkError = readUrlRecoveryError(
    Array.isArray(params.error) ? params.error[0] : params.error,
    Array.isArray(params.error_description) ? params.error_description[0] : params.error_description,
  );

  async function submitNewPassword() {
    if (!supabase) return;
    if (newPassword.length < 8) {
      setError('Enter a password with at least 8 characters.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password: newPassword });
      if (updateError) throw updateError;
      clearPasswordRecovery();
      setCompleted(true);
      setNewPassword('');
      setConfirmPassword('');
    } catch (caught) {
      captureException(caught, { flow: 'password_reset_update' });
      setError(caught instanceof Error ? caught.message : 'Could not update your password. The link may have expired.');
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return <Screen><ActivityIndicator color={theme.colors.action} /></Screen>;
  }

  return <Screen>
    <DesktopContent maxWidth={560}>
      <View style={sharedStyles.column}>
        <BloomWordmark size={30} />
        <Eyebrow>Account recovery</Eyebrow>
        <Heading>Reset your password</Heading>
      </View>

      {completed ? <Panel>
        <Body>Your password has been updated.</Body>
        <Button label={session ? 'Continue to Bloom' : 'Sign in'} onPress={() => router.replace((session ? '/' : '/sign-in') as Href)} />
      </Panel> : linkError ? <Panel>
        <ErrorText>{linkError}</ErrorText>
        <Body>Password reset links expire for your security. Request a fresh link from the sign-in screen.</Body>
        <Button label="Back to sign in" onPress={() => { clearPasswordRecovery(); router.replace('/sign-in' as Href); }} />
      </Panel> : !session && !passwordRecovery ? <Panel>
        <Body>Open the password reset link from your email to continue, or request a new reset email.</Body>
        <Button label="Back to sign in" onPress={() => router.replace('/sign-in' as Href)} />
      </Panel> : <Panel>
        <Body>Choose a new password for your Bloom account (at least 8 characters).</Body>
        <Field label="New password" value={newPassword} onChangeText={setNewPassword} secureTextEntry autoComplete="new-password" />
        <Field label="Confirm new password" value={confirmPassword} onChangeText={setConfirmPassword} secureTextEntry autoComplete="new-password" />
        {error && <ErrorText>{error}</ErrorText>}
        <Button label="Update password" onPress={() => void submitNewPassword()} busy={busy} disabled={!newPassword || !confirmPassword} />
        <Button label="Cancel" variant="tertiary" disabled={busy} onPress={() => { clearPasswordRecovery(); router.replace((session ? '/' : '/sign-in') as Href); }} />
      </Panel>}
    </DesktopContent>
  </Screen>;
}
