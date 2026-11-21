import { useState } from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import type { AppCandidate } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { useBloomTheme } from '../lib/theme-context';
import { Body, Field, Label } from './bloom-ui';

/** The device's installed-app inventory is shared, but every caller owns its selection. */
export function FocusAppPicker({ apps, selected, onChange, requiredIds = [] }: { apps: AppCandidate[]; selected: string[]; onChange: (selected: string[]) => void; requiredIds?: string[] }) {
  const [search, setSearch] = useState('');
  const { theme } = useBloomTheme();
  const matches = apps.filter((app) => app.name.toLowerCase().includes(search.trim().toLowerCase()));
  return <>
    <Label>Choose apps · {new Set([...selected, ...requiredIds]).size} selected</Label>
    <Field label="Search apps" value={search} onChangeText={setSearch} />
    {matches.length === 0 && <Body>No matching apps on this device.</Body>}
    {matches.map((app) => {
      const required = requiredIds.includes(app.id);
      const checked = required || selected.includes(app.id);
      return <Pressable key={app.id} accessibilityRole="checkbox" accessibilityLabel={`${app.name}${required ? ', parent rule' : ''}`} accessibilityState={{ checked, disabled: required }} disabled={required}
        onPress={() => onChange(checked ? selected.filter((id) => id !== app.id) : [...selected, app.id])}
        style={[styles.app, { borderColor: theme.colors.border }]}>
        <Text style={{ color: theme.colors.ink }}>{checked ? '☑' : '☐'}  {app.name}{required ? ' · Parent rule' : ''}</Text>
      </Pressable>;
    })}
  </>;
}
const styles = StyleSheet.create({ app: { minHeight: 48, justifyContent: 'center', borderBottomWidth: StyleSheet.hairlineWidth } });
