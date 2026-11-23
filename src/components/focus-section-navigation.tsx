import { LocalizedText as Text } from './bloom-ui';
import { Pressable, StyleSheet, View } from 'react-native';
import { useBloomTheme } from '../lib/theme-context';

export type FocusSettingsSection = 'focus' | 'apps' | 'websites' | 'rules';

const sections: { key: FocusSettingsSection; label: string }[] = [
  { key: 'focus', label: 'Focus' },
  { key: 'apps', label: 'Apps' },
  { key: 'websites', label: 'Websites' },
  { key: 'rules', label: 'Rules' },
];

export function FocusSectionNavigation({ selected, onSelect }: {
  selected: FocusSettingsSection;
  onSelect: (section: FocusSettingsSection) => void;
}) {
  const { theme } = useBloomTheme();
  return <View accessibilityRole="tablist" accessibilityLabel="Focus settings" style={styles.list}>
    {sections.map((section) => {
      const active = selected === section.key;
      return <Pressable
        key={section.key}
        accessibilityRole="tab"
        accessibilityLabel={section.label}
        accessibilityState={{ selected: active }}
        onPress={() => onSelect(section.key)}
        style={({ pressed }) => [styles.tab, { backgroundColor: active ? theme.colors.surfaceTinted : 'transparent', borderColor: active ? theme.colors.focusRing : 'transparent' }, pressed && styles.pressed]}>
        <Text style={[styles.label, { color: active ? theme.colors.action : theme.colors.inkMuted }]}>{section.label}</Text>
      </Pressable>;
    })}
  </View>;
}

const styles = StyleSheet.create({
  list: { flexDirection: 'row', gap: 4, padding: 4, borderRadius: 18, alignSelf: 'stretch' },
  tab: { flex: 1, minWidth: 0, minHeight: 42, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 14, paddingHorizontal: 4 },
  label: { fontSize: 13, fontWeight: '700', textAlign: 'center' },
  pressed: { opacity: 0.74 },
});
