import { getAppLocale } from '../../../lib/locale-context';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { loadCreditLedger, type CreditLedgerEntry } from '../../../lib/bloom';
import { useBloom } from '../../../lib/bloom-context';
import { useBloomTheme } from '../../../lib/theme-context';

function entryLabel(entry: CreditLedgerEntry) {
  if (entry.growth_module_id) {
    const moduleName = entry.growth_module_id === 'read' ? 'Read' : entry.growth_module_id === 'tasks' ? 'Tasks' : 'Study';
    return `${moduleName} reward`;
  }
  if (entry.workout_session_id) return 'Exercise workout';
  return entry.entry_type === 'adjustment' ? 'Balance adjustment' : 'Screen-time access';
}

function entryKind(entry: CreditLedgerEntry) {
  return entry.entry_type === 'earned' ? 'Earned' : entry.entry_type === 'spent' ? 'Used' : entry.entry_type === 'expired' ? 'Expired' : 'Adjusted';
}

export default function CreditHistoryScreen() {
  const { theme } = useBloomTheme();
  const { creditsEnabled, creditBalance } = useBloom();
  const [entries, setEntries] = useState<CreditLedgerEntry[] | null>(null);
  const [failed, setFailed] = useState(false);

  const refresh = useCallback(() => {
    setFailed(false);
    void loadCreditLedger().then(setEntries).catch(() => { setEntries([]); setFailed(true); });
  }, []);
  useFocusEffect(useCallback(() => { refresh(); }, [refresh]));

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Shared screen-time credits</Eyebrow>
      <Heading>Credit history</Heading>
      <Body>Review the latest changes recorded in your shared credit ledger.</Body>
      <Button label="Back" variant="tertiary" onPress={() => router.back()} />
    </View>
    <Panel>
      <Eyebrow>Current balance</Eyebrow>
      <Label>{creditsEnabled ? `${creditBalance.toLocaleString(getAppLocale(), { maximumFractionDigits: 2 })} minutes` : 'Credits are turned off'}</Label>
    </Panel>
    {!entries && !failed && <ActivityIndicator color={theme.colors.action} />}
    {failed && <Panel><ErrorText>Credit history could not be loaded.</ErrorText><Button label="Try again" variant="secondary" onPress={refresh} /></Panel>}
    {entries && !failed && entries.length === 0 && <Panel><Body>No credit transactions have been recorded yet.</Body></Panel>}
    {entries?.map((entry) => {
      const positive = entry.amount_minutes > 0;
      return <Panel key={entry.id}>
        <View style={sharedStyles.row}>
          <View style={[styles.icon, { backgroundColor: positive ? theme.colors.surfaceTinted : theme.colors.surfaceSoft }]}>
            <MaterialIcons name={positive ? 'south-west' : 'north-east'} size={18} color={positive ? theme.colors.success : theme.colors.action} />
          </View>
          <View style={sharedStyles.grow}>
            <Label>{entryLabel(entry)}</Label>
            <Body>{entryKind(entry)} · {new Date(entry.created_at).toLocaleString(getAppLocale())}</Body>
            {entry.expires_at && entry.entry_type === 'earned' && <Body>Expires {new Date(entry.expires_at).toLocaleDateString(getAppLocale())}</Body>}
          </View>
          <Label>{positive ? '+' : ''}{entry.amount_minutes.toLocaleString(getAppLocale())} min</Label>
        </View>
      </Panel>;
    })}
    {entries && !failed && entries.length === 100 && <Body>Showing the latest 100 transactions.</Body>}
  </Screen>;
}

const styles = StyleSheet.create({
  icon: { width: 38, height: 38, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
});
