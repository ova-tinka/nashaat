import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import BloomBlocking from '../../modules/bloom-blocking/src/BloomBlockingModule';
import type { AppAccessDecision, AppCandidate } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { useBloomTheme } from '../lib/theme-context';
import { canonicalWebsiteDomain } from '../lib/website-domain';
import { Body, Button, ErrorText, Field, Label } from './bloom-ui';

/** Explain the native decision without implying Bloom controls other device policies. */
export function FocusAppAccess({ profileId, apps }: { profileId: string; apps: AppCandidate[] }) {
  const { theme } = useBloomTheme();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');
  const [chosen, setChosen] = useState<{ kind: 'app' | 'website'; id: string; name: string } | null>(null);
  const [website, setWebsite] = useState('');
  const [decision, setDecision] = useState<AppAccessDecision | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    if (!open || !chosen) return;
    function refresh() {
      try {
        setDecision(chosen!.kind === 'app' ? BloomBlocking.getAppAccessDecision(profileId, chosen!.id) : BloomBlocking.getWebsiteAccessDecision(profileId, chosen!.id));
        setError(null);
      }
      catch { setDecision(null); setError('Could not check this app. Sync this device and try again.'); }
    }
    refresh();
    const timer = setInterval(refresh, 5000);
    return () => clearInterval(timer);
  }, [chosen, open, profileId]);
  const matches = search.trim().length >= 2 ? apps.filter((app) => app.name.toLowerCase().includes(search.trim().toLowerCase())).slice(0, 40) : [];
  return <View style={styles.group}>
    <Button label={open ? 'Hide app access check' : 'Check app or website access'} variant="secondary" onPress={() => setOpen((value) => !value)} />
    {open && <>
      <Field label="Search installed apps" value={search} onChangeText={(value) => { setSearch(value); setChosen(null); setDecision(null); }} />
      {search.trim().length < 2 && <Body>Enter at least two characters to find an app.</Body>}
      {search.trim().length >= 2 && matches.length === 0 && <Body>No matching apps on this device.</Body>}
      {matches.map((app) => <Pressable key={app.id} accessibilityRole="button" accessibilityLabel={`Check ${app.name}`} onPress={() => setChosen({ kind: 'app', ...app })} style={[styles.row, { borderColor: theme.colors.border }]}><Text style={{ color: theme.colors.ink }}>{app.name}</Text></Pressable>)}
      <Field label="Website domain" value={website} onChangeText={setWebsite} autoCapitalize="none" autoCorrect={false} keyboardType="url" />
      <Button label="Check website" variant="secondary" onPress={() => {
        const host = canonicalWebsiteDomain(website);
        if (!host) { setError('Enter a valid website domain.'); setChosen(null); setDecision(null); return; }
        setError(null); setDecision(null); setChosen({ kind: 'website', id: host, name: host });
      }} />
      {error && <ErrorText>{error}</ErrorText>}
      {chosen && <View style={styles.group}>
        <Label>{chosen.name}</Label>
        {decision && <>
          {chosen.kind === 'website' ? <Body>Website checks apply only in supported browsers. A browser’s own app rules can also apply; if its address cannot be read, Bloom may block the whole browser.</Body> : <Body>Website restrictions may also apply when this app is a supported browser.</Body>}
          {!decision.enforceable && <Body>Bloom cannot confirm enforcement on this device. The configured rules are shown below.</Body>}
          {decision.blocked ? <><Body>{decision.enforceable ? 'Blocked by:' : 'Configured blocking reasons:'}</Body>{decision.reasons.map((reason, index) => <Body key={`${index}:${reason}`}>• {reason}</Body>)}</>
            : <Body>No active Bloom restriction applies to this selection. Device or account restrictions outside Bloom may still apply.</Body>}
        </>}
      </View>}
    </>}
  </View>;
}
const styles = StyleSheet.create({ group: { gap: 8 }, row: { minHeight: 44, justifyContent: 'center', borderBottomWidth: StyleSheet.hairlineWidth } });
