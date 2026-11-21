import type { ComponentProps, PropsWithChildren } from 'react';
import { createContext, useContext, useState } from 'react';
import { ActivityIndicator, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View, useWindowDimensions, type TextInputProps } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { SafeAreaView } from 'react-native-safe-area-context';
import { radii, spacing, typeScale, type ModuleKey } from '../theme';
import { useBloomTheme } from '../lib/theme-context';
import { isMacDesktop } from '../lib/macos-blocking';

const moduleDetails: Record<ModuleKey, { title: string; icon: ComponentProps<typeof MaterialIcons>['name'] }> = {
  exercise: { title: 'Exercise', icon: 'fitness-center' },
  study: { title: 'Study', icon: 'school' },
  read: { title: 'Read', icon: 'menu-book' },
  tasks: { title: 'Tasks', icon: 'check-box' },
};

export const BloomFloatingDockContext = createContext(false);

export function BloomMark({ size = 32, monochrome = false }: { size?: number; monochrome?: boolean }) {
  const { theme } = useBloomTheme();
  const petalSize = size * 0.43;
  const gap = size * 0.055;
  const petals = monochrome
    ? [theme.colors.ink, theme.colors.ink, theme.colors.ink, theme.colors.ink]
    : ['#9460F5', '#9460F5', '#9460F5', '#9460F5'];
  return <View accessibilityRole="image" accessibilityLabel="Bloom" style={{ width: size, height: size, flexDirection: 'row', flexWrap: 'wrap', alignContent: 'center', justifyContent: 'center', gap }}>
    {petals.map((color, index) => <View key={index} style={{ width: petalSize, height: petalSize, borderRadius: size * 0.17, backgroundColor: color }} />)}
  </View>;
}

export function BloomWordmark({ size = 32 }: { size?: number }) {
  const { theme } = useBloomTheme();
  return <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.space2 }}>
    <BloomMark size={size} />
    <Text style={{ color: theme.colors.ink, fontSize: size * 0.72, lineHeight: size * 0.9, fontWeight: '800', letterSpacing: -0.8 }}>Bloom</Text>
  </View>;
}

export function Screen({ children, safeAreaTop = true }: PropsWithChildren<{ safeAreaTop?: boolean }>) {
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const floatingDock = useContext(BloomFloatingDockContext);
  return <SafeAreaView style={[styles.safe, { backgroundColor: theme.colors.canvas }]} edges={safeAreaTop ? ['top'] : []}>
    <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={[styles.outer, desktop && styles.desktopOuter, floatingDock && styles.floatingDockOuter]}>
      <View style={[styles.content, desktop && styles.desktopContent]}>{children}</View>
    </ScrollView>
  </SafeAreaView>;
}

export function useIsDesktopLayout() {
  const { width } = useWindowDimensions();
  return width >= 1024 && (isMacDesktop() || Platform.OS === 'web');
}

export function Panel({ children }: PropsWithChildren) {
  const { theme } = useBloomTheme();
  const shadow = theme.shadows.card;
  return <View style={[styles.panel, {
    borderColor: theme.components.card.border,
    backgroundColor: theme.components.card.background,
    shadowColor: shadow.color,
    shadowOffset: shadow.offset,
    shadowOpacity: shadow.opacity,
    shadowRadius: shadow.radius,
    elevation: shadow.elevation,
  }]}>{children}</View>;
}

export function Eyebrow({ children }: PropsWithChildren) {
  const { theme } = useBloomTheme();
  return <Text style={[styles.eyebrow, { color: theme.colors.inkMuted }]}>{children}</Text>;
}

export function Heading({ children }: PropsWithChildren) {
  const { theme } = useBloomTheme();
  return <Text style={[styles.heading, { color: theme.colors.ink }]} accessibilityRole="header">{children}</Text>;
}

export function Label({ children }: PropsWithChildren) {
  const { theme } = useBloomTheme();
  return <Text style={[styles.label, { color: theme.colors.ink }]}>{children}</Text>;
}

export function Body({ children }: PropsWithChildren) {
  const { theme } = useBloomTheme();
  return <Text style={[styles.body, { color: theme.colors.inkMuted }]}>{children}</Text>;
}

export function ErrorText({ children }: PropsWithChildren) {
  const { theme } = useBloomTheme();
  return <Text accessibilityRole="alert" style={[styles.error, { color: theme.colors.dangerText }]}>{children}</Text>;
}

export type ButtonVariant = 'primary' | 'secondary' | 'tertiary' | 'destructive';

export function Button({ label, accessibilityLabel, accessibilityHint, onPress, variant, secondary = false, disabled = false, busy = false }: {
  label: string;
  accessibilityLabel?: string;
  accessibilityHint?: string;
  onPress: () => void;
  variant?: ButtonVariant;
  /** Kept for existing call sites; prefer `variant="secondary"` in new screens. */
  secondary?: boolean;
  disabled?: boolean;
  busy?: boolean;
}) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  const [hovered, setHovered] = useState(false);
  const resolvedVariant = variant ?? (secondary ? 'secondary' : 'primary');
  const variants = {
    primary: { backgroundColor: theme.components.button.primaryBackground, borderColor: theme.components.button.primaryBackground, textColor: theme.components.button.primaryText },
    secondary: { backgroundColor: theme.components.button.secondaryBackground, borderColor: theme.components.button.secondaryBorder, textColor: theme.components.button.secondaryText },
    tertiary: { backgroundColor: 'transparent', borderColor: 'transparent', textColor: theme.components.button.tertiaryText },
    destructive: { backgroundColor: theme.components.button.destructiveBackground, borderColor: theme.components.button.destructiveBackground, textColor: theme.components.button.destructiveText },
  } satisfies Record<ButtonVariant, { backgroundColor: string; borderColor: string; textColor: string }>;
  const selected = variants[resolvedVariant];
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={accessibilityLabel ?? label}
    accessibilityHint={accessibilityHint}
    accessibilityState={{ disabled: disabled || busy, busy }}
    disabled={disabled || busy}
    onFocus={() => setFocused(true)}
    onBlur={() => setFocused(false)}
    onHoverIn={() => setHovered(true)}
    onHoverOut={() => setHovered(false)}
    onPress={onPress}
    style={({ pressed }) => [
      styles.button,
      { backgroundColor: selected.backgroundColor, borderColor: focused ? theme.components.button.focusBorder : selected.borderColor },
      resolvedVariant === 'tertiary' && styles.tertiaryButton,
      focused && styles.focused,
      hovered && !disabled && !busy && styles.hovered,
      (disabled || busy) && styles.disabled,
      pressed && !disabled && !busy && styles.pressed,
    ]}>
    {busy
      ? <ActivityIndicator color={selected.textColor} />
      : <Text style={[styles.buttonText, { color: selected.textColor }]}>{label}</Text>}
  </Pressable>;
}

export function Field({ label, helperText, error, ...props }: TextInputProps & { label: string; helperText?: string; error?: string }) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  const { onFocus, onBlur, ...inputProps } = props;
  return <View style={styles.field}>
    <Text style={[styles.fieldLabel, { color: theme.components.field.label }]}>{label}</Text>
    <TextInput
      accessibilityLabel={label}
      accessibilityHint={error ?? helperText}
      placeholderTextColor={theme.components.field.placeholder}
      selectionColor={theme.components.field.focusBorder}
      {...inputProps}
      onFocus={(event) => { setFocused(true); onFocus?.(event); }}
      onBlur={(event) => { setFocused(false); onBlur?.(event); }}
      style={[
        styles.input,
        { color: theme.components.field.text, borderColor: error ? theme.components.field.errorBorder : focused ? theme.components.field.focusBorder : theme.components.field.border, backgroundColor: theme.components.field.background },
        focused && styles.focusedInput,
        inputProps.style,
      ]}
    />
    {error
      ? <Text accessibilityRole="alert" style={[styles.fieldHelp, { color: theme.components.field.error }]}>{error}</Text>
      : helperText ? <Text style={[styles.fieldHelp, { color: theme.components.field.helper }]}>{helperText}</Text> : null}
  </View>;
}

export function ModuleTile({ module, subtitle, onPress, selected = false, disabled = false, dense = false }: {
  module: ModuleKey;
  subtitle: string;
  onPress: () => void;
  selected?: boolean;
  disabled?: boolean;
  dense?: boolean;
}) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  const [hovered, setHovered] = useState(false);
  const details = moduleDetails[module];
  const moduleTheme = theme.modules[module];
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={`${details.title}. ${subtitle}`}
    accessibilityState={{ selected, disabled }}
    disabled={disabled}
    onFocus={() => setFocused(true)}
    onBlur={() => setFocused(false)}
    onHoverIn={() => setHovered(true)}
    onHoverOut={() => setHovered(false)}
    onPress={onPress}
    style={({ pressed }) => [
      styles.moduleTile,
      dense && styles.moduleTileDense,
      { backgroundColor: moduleTheme.surface, borderColor: focused ? theme.colors.focusRing : selected ? moduleTheme.deep : theme.colors.border },
      selected && styles.moduleSelected,
      focused && styles.focused,
      hovered && !disabled && styles.hovered,
      disabled && styles.moduleTileDisabled,
      pressed && !disabled && styles.pressed,
    ]}>
    <View style={[styles.moduleIcon, dense && styles.moduleIconDense, { backgroundColor: theme.colors.surface }]}>
      <MaterialIcons name={details.icon} size={dense ? 18 : 22} color={moduleTheme.deep} />
    </View>
    <Text style={[styles.moduleTitle, dense && styles.moduleTitleDense, { color: theme.colors.ink }]}>{details.title}</Text>
    <Text style={[styles.moduleSubtitle, dense && styles.moduleSubtitleDense, { color: theme.colors.inkMuted }]}>{subtitle}</Text>
  </Pressable>;
}

export function FeatureTile({ title, subtitle, icon, onPress, accentColor, backgroundColor, disabled = false }: {
  title: string;
  subtitle: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
  onPress: () => void;
  accentColor?: string;
  backgroundColor?: string;
  disabled?: boolean;
}) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={`${title}. ${subtitle}`}
    accessibilityHint={`Open ${title}.`}
    accessibilityState={{ disabled }}
    disabled={disabled}
    onFocus={() => setFocused(true)}
    onBlur={() => setFocused(false)}
    onPress={onPress}
    style={({ pressed }) => [styles.featureTile, {
      backgroundColor: backgroundColor ?? theme.colors.surface,
      borderColor: focused ? theme.colors.focusRing : theme.colors.border,
    }, focused && styles.focused, disabled && styles.disabled, pressed && !disabled && styles.pressed]}>
    <View style={styles.featureTileTop}>
      <View style={[styles.featureIcon, { backgroundColor: theme.colors.surfaceSoft }]}>
        <MaterialIcons name={icon} size={19} color={accentColor ?? theme.colors.action} />
      </View>
      <MaterialIcons name="arrow-forward" size={17} color={accentColor ?? theme.colors.action} />
    </View>
    <Text style={[styles.featureTitle, { color: theme.colors.ink }]}>{title}</Text>
    <Text style={[styles.featureSubtitle, { color: theme.colors.inkMuted }]} numberOfLines={2}>{subtitle}</Text>
  </Pressable>;
}

export function EmptyState({ title, message, actionLabel, onAction }: {
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  const { theme } = useBloomTheme();
  return <View style={[styles.emptyState, { borderColor: theme.colors.border, backgroundColor: theme.colors.surfaceSoft }]}>
    <Text accessibilityRole="header" style={[styles.emptyTitle, { color: theme.colors.ink }]}>{title}</Text>
    <Text style={[styles.emptyMessage, { color: theme.colors.inkMuted }]}>{message}</Text>
    {actionLabel && onAction ? <Button label={actionLabel} variant="secondary" onPress={onAction} /> : null}
  </View>;
}

export type BannerTone = 'info' | 'success' | 'warning' | 'danger';

export function StatusBanner({ tone = 'info', title, message }: { tone?: BannerTone; title: string; message: string }) {
  const { theme } = useBloomTheme();
  const toneColors = {
    info: theme.colors.infoText,
    success: theme.colors.successText,
    warning: theme.colors.warningText,
    danger: theme.colors.dangerText,
  } satisfies Record<BannerTone, string>;
  const accent = toneColors[tone];
  return <View accessibilityRole="summary" style={[styles.banner, { backgroundColor: theme.colors.surfaceSoft, borderStartColor: accent, borderColor: theme.colors.border }]}>
    <Text style={[styles.bannerTitle, { color: accent }]}>{title}</Text>
    <Text style={[styles.bannerMessage, { color: theme.colors.inkMuted }]}>{message}</Text>
  </View>;
}

export function ProgressBar({ value, label, color }: { value: number; label: string; color?: string }) {
  const { theme } = useBloomTheme();
  const clamped = Math.min(100, Math.max(0, value));
  return <View
    accessible
    accessibilityRole="progressbar"
    accessibilityLabel={label}
    accessibilityValue={{ min: 0, max: 100, now: clamped }}
    style={[styles.progressTrack, { backgroundColor: theme.colors.surfaceSoft }]}>
    <View style={[styles.progressFill, { width: `${clamped}%`, backgroundColor: color ?? theme.colors.action }]} />
  </View>;
}

export const sharedStyles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.space3 },
  column: { gap: spacing.space3 },
  grow: { flex: 1 },
});

const styles = StyleSheet.create({
  safe: { flex: 1 },
  outer: { flexGrow: 1, alignItems: 'center', paddingHorizontal: spacing.space5, paddingTop: spacing.space4, paddingBottom: spacing.space8 },
  desktopOuter: { paddingHorizontal: 40, paddingTop: 28, paddingBottom: 40 },
  floatingDockOuter: { paddingBottom: 128 },
  content: { width: '100%', maxWidth: 740, gap: spacing.space4 },
  desktopContent: { maxWidth: 1200, gap: spacing.space6 },
  panel: { borderRadius: radii.card, borderWidth: 1, padding: spacing.space5, gap: spacing.space3 },
  eyebrow: { fontSize: typeScale.caption.fontSize, lineHeight: typeScale.caption.lineHeight, fontWeight: '700', letterSpacing: 1.2, textTransform: 'uppercase', writingDirection: 'auto' },
  heading: { fontSize: typeScale.page.fontSize, lineHeight: typeScale.page.lineHeight, fontWeight: '800', letterSpacing: -0.5, writingDirection: 'auto' },
  label: { fontSize: 16, lineHeight: 23, fontWeight: '700', writingDirection: 'auto' },
  body: { fontSize: typeScale.body.fontSize, lineHeight: typeScale.body.lineHeight, writingDirection: 'auto' },
  error: { fontSize: typeScale.supporting.fontSize, lineHeight: typeScale.supporting.lineHeight, writingDirection: 'auto' },
  button: { minHeight: 48, borderRadius: radii.input, borderWidth: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: spacing.space4 },
  tertiaryButton: { borderWidth: 0 },
  focused: { borderWidth: 2 },
  hovered: { opacity: 0.94 },
  disabled: { opacity: 0.48 },
  pressed: { opacity: 0.82 },
  buttonText: { fontSize: 15, lineHeight: 20, fontWeight: '700', textAlign: 'center', writingDirection: 'auto' },
  focusedInput: { borderWidth: 2 },
  field: { gap: spacing.space2 },
  fieldLabel: { fontSize: typeScale.supporting.fontSize, lineHeight: typeScale.supporting.lineHeight, fontWeight: '700', writingDirection: 'auto' },
  input: { minHeight: 48, borderWidth: 1, borderRadius: radii.input, paddingHorizontal: spacing.space3, fontSize: 16, writingDirection: 'auto' },
  fieldHelp: { fontSize: typeScale.supporting.fontSize, lineHeight: typeScale.supporting.lineHeight, writingDirection: 'auto' },
  moduleTile: { minHeight: 148, borderWidth: 1, borderRadius: radii.card, padding: spacing.space4, gap: spacing.space2 },
  moduleTileDense: { minHeight: 108, padding: spacing.space3, gap: 4 },
  moduleTileDisabled: { opacity: 0.82 },
  moduleSelected: { borderWidth: 2 },
  moduleIcon: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 12, marginBottom: spacing.space1 },
  moduleIconDense: { width: 30, height: 30, borderRadius: 10, marginBottom: 0 },
  moduleTitle: { fontSize: 17, lineHeight: 22, fontWeight: '800', writingDirection: 'auto' },
  moduleTitleDense: { fontSize: 15, lineHeight: 20 },
  moduleSubtitle: { fontSize: 13, lineHeight: 18, writingDirection: 'auto' },
  moduleSubtitleDense: { fontSize: 11, lineHeight: 15 },
  featureTile: { flexGrow: 1, minHeight: 132, borderWidth: 1, borderRadius: radii.card, padding: spacing.space4, gap: spacing.space2 },
  featureTileTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  featureIcon: { width: 36, height: 36, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  featureTitle: { fontSize: 15, lineHeight: 20, fontWeight: '800', writingDirection: 'auto' },
  featureSubtitle: { fontSize: 12, lineHeight: 17, writingDirection: 'auto' },
  emptyState: { borderWidth: 1, borderStyle: 'dashed', borderRadius: radii.card, padding: spacing.space5, gap: spacing.space2, alignItems: 'flex-start' },
  emptyTitle: { fontSize: 17, lineHeight: 23, fontWeight: '700', writingDirection: 'auto' },
  emptyMessage: { fontSize: typeScale.body.fontSize, lineHeight: typeScale.body.lineHeight, writingDirection: 'auto' },
  banner: { borderWidth: 1, borderStartWidth: 4, borderRadius: radii.input, padding: spacing.space4, gap: spacing.space1 },
  bannerTitle: { fontSize: 14, lineHeight: 20, fontWeight: '700', writingDirection: 'auto' },
  bannerMessage: { fontSize: 13, lineHeight: 19, writingDirection: 'auto' },
  progressTrack: { height: 10, borderRadius: radii.pill, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: radii.pill },
});
