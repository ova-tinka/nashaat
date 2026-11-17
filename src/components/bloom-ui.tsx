import type { PropsWithChildren } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View, type TextInputProps } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors } from '../theme';
import { isMacDesktop } from '../lib/macos-blocking';

export function Screen({ children }: PropsWithChildren) {
  return <SafeAreaView style={styles.safe} edges={['top']}><ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.outer}><View style={[styles.content, isMacDesktop() && styles.desktopContent]}>{children}</View></ScrollView></SafeAreaView>;
}

export function Panel({ children }: PropsWithChildren) {
  return <View style={styles.panel}>{children}</View>;
}

export function Eyebrow({ children }: PropsWithChildren) {
  return <Text style={styles.eyebrow}>{children}</Text>;
}

export function Heading({ children }: PropsWithChildren) {
  return <Text style={styles.heading} accessibilityRole="header">{children}</Text>;
}

export function Label({ children }: PropsWithChildren) {
  return <Text style={styles.label}>{children}</Text>;
}

export function Body({ children }: PropsWithChildren) {
  return <Text style={styles.body}>{children}</Text>;
}

export function ErrorText({ children }: PropsWithChildren) {
  return <Text accessibilityRole="alert" style={styles.error}>{children}</Text>;
}

export function Button({ label, accessibilityLabel, onPress, secondary = false, disabled = false, busy = false }: {
  label: string; accessibilityLabel?: string; onPress: () => void; secondary?: boolean; disabled?: boolean; busy?: boolean;
}) {
  return <Pressable accessibilityRole="button" accessibilityLabel={accessibilityLabel ?? label} accessibilityState={{ disabled: disabled || busy }} disabled={disabled || busy} onPress={onPress} style={({ pressed }) => [styles.button, secondary && styles.secondary, (disabled || busy) && styles.disabled, pressed && styles.pressed]}>
    {busy ? <ActivityIndicator color={secondary ? colors.text : colors.accentInk} /> : <Text style={[styles.buttonText, secondary && styles.secondaryText]}>{label}</Text>}
  </Pressable>;
}

export function Field({ label, ...props }: TextInputProps & { label: string }) {
  return <View style={styles.field}><Text style={styles.fieldLabel}>{label}</Text><TextInput accessibilityLabel={label} placeholderTextColor={colors.muted} selectionColor={colors.accent} {...props} style={[styles.input, props.style]} /></View>;
}

export const sharedStyles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  column: { gap: 12 },
  grow: { flex: 1 },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: colors.border },
});

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  outer: { flexGrow: 1, alignItems: 'center', paddingHorizontal: 20, paddingTop: 18, paddingBottom: 36 },
  content: { width: '100%', maxWidth: 740, gap: 18 },
  desktopContent: { maxWidth: 960, gap: 22 },
  panel: { borderRadius: 20, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card, padding: 18, gap: 12 },
  eyebrow: { color: colors.muted, fontSize: 11, fontWeight: '700', letterSpacing: 2, textTransform: 'uppercase' },
  heading: { color: colors.text, fontSize: 30, lineHeight: 36, fontWeight: '800', letterSpacing: -0.7 },
  label: { color: colors.text, fontSize: 16, lineHeight: 23, fontWeight: '700' },
  body: { color: colors.body, fontSize: 14, lineHeight: 21 },
  error: { color: colors.danger, fontSize: 14, lineHeight: 20 },
  button: { minHeight: 48, borderRadius: 14, backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 16 },
  secondary: { backgroundColor: colors.raised, borderWidth: 1, borderColor: colors.border },
  disabled: { opacity: 0.55 },
  pressed: { opacity: 0.8 },
  buttonText: { color: colors.accentInk, fontSize: 15, fontWeight: '800', textAlign: 'center' },
  secondaryText: { color: colors.text },
  field: { gap: 7 },
  fieldLabel: { color: colors.text, fontSize: 13, fontWeight: '700' },
  input: { minHeight: 48, borderWidth: 1, borderColor: colors.border, borderRadius: 12, paddingHorizontal: 13, color: colors.text, backgroundColor: colors.background, fontSize: 16 },
});
