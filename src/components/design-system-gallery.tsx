import { useState } from 'react';
import { Pressable, Text, View, useWindowDimensions } from 'react-native';
import { router } from 'expo-router';
import {
  BloomMark,
  BloomWordmark,
  Body,
  Button,
  EmptyState,
  Eyebrow,
  Field,
  Heading,
  Label,
  ModuleTile,
  Panel,
  ProgressBar,
  Screen,
  StatusBanner,
  type ButtonVariant,
} from './bloom-ui';
import { useBloomTheme } from '../lib/theme-context';
import { contrastRatio, fontFamilies, fontWeights, motion, radii, spacing, typeScale, type ModuleKey, type ThemeMode } from '../theme';

const moduleExamples: { key: ModuleKey; subtitle: string }[] = [
  { key: 'exercise', subtitle: 'Move · Train · Build' },
  { key: 'study', subtitle: 'Focus · Learn · Grow' },
  { key: 'read', subtitle: 'Read · Explore · Think' },
  { key: 'tasks', subtitle: 'Plan · Do · Finish' },
];

const themeOptions: { mode: ThemeMode; label: string }[] = [
  { mode: 'light', label: 'Light' },
  { mode: 'dark', label: 'Dark' },
  { mode: 'highContrast', label: 'High contrast' },
];

const buttonVariants: { variant: ButtonVariant; label: string }[] = [
  { variant: 'primary', label: 'Primary' },
  { variant: 'secondary', label: 'Secondary' },
  { variant: 'tertiary', label: 'Tertiary' },
  { variant: 'destructive', label: 'Destructive' },
];

export function DesignSystemGallery() {
  const { mode, setMode, theme } = useBloomTheme();
  const { width } = useWindowDimensions();
  const [selectedModule, setSelectedModule] = useState<ModuleKey>('exercise');
  const [selectedToken, setSelectedToken] = useState('canvas');
  const [busy, setBusy] = useState(false);
  const [showFieldError, setShowFieldError] = useState(false);
  const [largeType, setLargeType] = useState(false);
  const [rtl, setRtl] = useState(false);
  const [feedback, setFeedback] = useState('');
  const compact = width < 650;

  const tokenSwatches = [
    { name: 'Canvas', value: theme.colors.canvas, foreground: theme.colors.ink, background: theme.colors.canvas, purpose: 'Primary ink on app canvas' },
    { name: 'Surface', value: theme.colors.surface, foreground: theme.colors.ink, background: theme.colors.surface, purpose: 'Primary ink on card surface' },
    { name: 'Soft surface', value: theme.colors.surfaceSoft, foreground: theme.colors.ink, background: theme.colors.surfaceSoft, purpose: 'Primary ink on secondary surface' },
    { name: 'Primary text', value: theme.colors.ink, foreground: theme.colors.ink, background: theme.colors.surface, purpose: 'Primary text on surface' },
    { name: 'Body text', value: theme.colors.inkMuted, foreground: theme.colors.inkMuted, background: theme.colors.surface, purpose: 'Body text on surface' },
    { name: 'Strong border', value: theme.colors.borderStrong, foreground: theme.colors.borderStrong, background: theme.colors.surface, threshold: 3, purpose: 'Non-text edge contrast' },
    { name: 'Primary button', value: theme.components.button.primaryBackground, foreground: theme.components.button.primaryText, background: theme.components.button.primaryBackground, purpose: 'Button label on action' },
    { name: 'Success text', value: theme.colors.successText, foreground: theme.colors.successText, background: theme.colors.surface, purpose: 'Success text on surface' },
    { name: 'Warning text', value: theme.colors.warningText, foreground: theme.colors.warningText, background: theme.colors.surface, purpose: 'Warning text on surface' },
    { name: 'Error text', value: theme.colors.dangerText, foreground: theme.colors.dangerText, background: theme.colors.surface, purpose: 'Error text on surface' },
    { name: 'Focus ring', value: theme.colors.focusRing, foreground: theme.colors.focusRing, background: theme.colors.surface, threshold: 3, purpose: 'Non-text focus indicator' },
  ];
  const actionContrast = contrastRatio(theme.components.button.primaryText, theme.components.button.primaryBackground);
  const moduleContrast = contrastRatio(theme.modules[selectedModule].text, theme.modules[selectedModule].surface);
  const bodyContrast = contrastRatio(theme.colors.inkMuted, theme.colors.surface);
  const subtleContrast = contrastRatio(theme.colors.inkSubtle, theme.colors.surface);

  return <Screen>
    <View style={[styles.header, compact && styles.headerCompact]}>
      <View style={styles.headerText}>
        <BloomWordmark size={30} />
        <Eyebrow>Phase A · Token and component review</Eyebrow>
        <Heading>Design system gallery</Heading>
        <Body>Interactive previews for Bloom’s shared visual foundations. Values here are design samples, not account data.</Body>
      </View>
      <Button label="Back" variant="secondary" onPress={() => router.back()} />
    </View>

    <Panel>
      <Eyebrow>Theme preview</Eyebrow>
      <Label>Choose a token set</Label>
      <View style={styles.segmentRow} accessibilityRole="tablist" accessibilityLabel="Theme preview">
        {themeOptions.map((option) => {
          const active = mode === option.mode;
          return <Pressable
            key={option.mode}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            onPress={() => setMode(option.mode)}
            style={[styles.segment, { backgroundColor: active ? theme.colors.action : theme.colors.surface, borderColor: active ? theme.colors.action : theme.colors.border }]}>
            <Text style={{ color: active ? theme.colors.onAction : theme.colors.ink, fontWeight: active ? '700' : '600' }}>{option.label}</Text>
          </Pressable>;
        })}
      </View>
      <Body>Dark and high-contrast palettes are authored separately. The app’s default review baseline remains light.</Body>
    </Panel>

    <View style={[styles.twoColumn, compact && styles.oneColumn]}>
      <Panel>
        <Eyebrow>Brand</Eyebrow>
        <Label>Four-petal mark and wordmark</Label>
        <View style={styles.brandRow}>
          {[24, 48, 72].map((size) => <View key={size} style={styles.brandSample}>
            <BloomMark size={size} />
            <Body>{size}px</Body>
          </View>)}
          <View style={styles.brandSample}>
            <BloomMark size={48} monochrome />
            <Body>Mono</Body>
          </View>
        </View>
        <Body>Module order: Exercise green, Study blue, Read violet, Tasks magenta.</Body>
      </Panel>

      <Panel>
        <Eyebrow>Module identities</Eyebrow>
        <Label>Select a module tile</Label>
        <View style={styles.moduleGrid}>
          {moduleExamples.map((item) => <View key={item.key} style={[styles.moduleCell, compact && styles.moduleCellCompact]}>
            <ModuleTile
              module={item.key}
              subtitle={item.subtitle}
              selected={selectedModule === item.key}
              onPress={() => setSelectedModule(item.key)}
            />
          </View>)}
        </View>
        <Body>Selected module: {selectedModule}. Each tile has a name and icon so color is never the only cue.</Body>
      </Panel>
    </View>

    <Panel>
      <Eyebrow>Semantic color tokens</Eyebrow>
      <Label>Tap a swatch to inspect contrast</Label>
      <View style={styles.swatchGrid}>
        {tokenSwatches.map((token) => {
          const { name, value, foreground, background, purpose } = token;
          const selected = selectedToken === name;
          const ratio = contrastRatio(foreground, background);
          const threshold = 'threshold' in token ? token.threshold ?? 4.5 : 4.5;
          return <Pressable
            key={name}
            accessibilityRole="button"
            accessibilityLabel={`${name}, ${value}, ${purpose}, contrast ${ratio} to 1`}
            accessibilityState={{ selected }}
            onPress={() => setSelectedToken(name)}
            style={[styles.swatch, { backgroundColor: theme.colors.surface, borderColor: selected ? theme.colors.focusRing : theme.colors.border }]}>
            <View style={[styles.swatchColor, { backgroundColor: value, borderColor: theme.colors.border }]} />
            <View style={styles.swatchText}>
              <Text style={{ color: theme.colors.ink, fontWeight: '700' }}>{name}</Text>
              <Text style={{ color: theme.colors.inkMuted, fontSize: 12 }}>{value}</Text>
              <Text style={{ color: ratio >= threshold ? theme.colors.successText : theme.colors.warningText, fontSize: 12 }}>{ratio}:1 · {purpose}</Text>
            </View>
          </Pressable>;
        })}
      </View>
      <Body>Selected module text contrast: {moduleContrast}:1 · {moduleContrast >= 4.5 ? 'AA text pass' : 'review required'}.</Body>
      <Body>Body text: {bodyContrast}:1 · subtle text: {subtleContrast}:1. Use subtle ink only where its contrast is appropriate.</Body>
      <Body>Contrast figures compare the current theme’s primary ink against each swatch. Use deep semantic aliases for small text on vivid accents.</Body>
      <View style={styles.mappingList}>
        {[
          ['palette.studyDeep', 'colors.action', 'components.button.primaryBackground'],
          ['palette.canvas', 'colors.canvas', 'Screen background'],
          ['palette.borderStrong', 'colors.borderStrong', 'components.field.border'],
          ['palette.focusRing', 'colors.focusRing', 'Button and field focus border'],
        ].map(([primitive, semantic, component]) => <View key={primitive} style={[styles.mappingRow, { borderColor: theme.colors.border }]}>
          <Text style={{ color: theme.colors.inkMuted, fontSize: 12 }}>{primitive}</Text>
          <Text style={{ color: theme.colors.action, fontSize: 12 }}>→ {semantic}</Text>
          <Text style={{ color: theme.colors.ink, fontSize: 12 }}>→ {component}</Text>
        </View>)}
      </View>
    </Panel>

    <View style={[styles.twoColumn, compact && styles.oneColumn]}>
      <Panel>
        <Eyebrow>Actions</Eyebrow>
        <Label>Button variants and states</Label>
        <View style={styles.buttonGrid}>
          {buttonVariants.map((item) => <View key={item.variant} style={styles.buttonCell}>
            <Button variant={item.variant} label={item.label} onPress={() => setFeedback(`${item.label} action pressed`)} />
          </View>)}
          <View style={styles.buttonCell}><Button variant="secondary" label="Disabled" disabled onPress={() => undefined} /></View>
          <View style={styles.buttonCell}><Button variant="primary" label={busy ? 'Loading' : 'Busy state'} busy={busy} onPress={() => setBusy(true)} /></View>
        </View>
        <Body>Primary button text contrast: {actionContrast}:1 · {actionContrast >= 4.5 ? 'AA text pass' : 'review required'}</Body>
        <Button label={busy ? 'Finish loading preview' : 'Toggle loading state'} variant="tertiary" onPress={() => setBusy(!busy)} />
        {feedback ? <StatusBanner tone="success" title="Interaction feedback" message={feedback} /> : null}
      </Panel>

      <Panel>
        <Eyebrow>Form controls</Eyebrow>
        <Label>Focus, helper and error states</Label>
        <Field label="Subject" placeholder="e.g. Biology" helperText="A short hint stays close to its field." />
        <Field
          label="Required field"
          placeholder="Enter a title"
          value=""
          onChangeText={() => setShowFieldError(false)}
          error={showFieldError ? 'Add a title before continuing.' : undefined}
        />
        <Button label={showFieldError ? 'Clear example error' : 'Show example error'} variant="secondary" onPress={() => setShowFieldError(!showFieldError)} />
      </Panel>
    </View>

    <Panel>
      <Eyebrow>Progress and status</Eyebrow>
      <Label>Shared state components</Label>
      <View style={styles.progressExample}>
        <View style={styles.progressHeader}><Body>Example progress · preview only</Body><Label>62%</Label></View>
        <ProgressBar value={62} label="Example progress preview, 62 percent" color={theme.modules[selectedModule].deep} />
      </View>
      <StatusBanner tone="info" title="Offline preview state" message="Last sync time would appear here. New activity stays pending until the server accepts it." />
      <StatusBanner tone="warning" title="Permission needed" message="Show the real operating-system permission state and the next available step." />
      <EmptyState title="No activity yet" message="The first completed activity will appear here after it syncs." actionLabel="Browse modules" onAction={() => setFeedback('Empty-state action pressed')} />
    </Panel>

    <Panel>
      <Eyebrow>Typography and layout accessibility</Eyebrow>
      <Label>Preview text scaling and direction</Label>
      <View style={styles.segmentRow}>
        <Button label={largeType ? 'Use standard sample' : 'Enlarge sample'} variant="secondary" onPress={() => setLargeType(!largeType)} />
        <Button label={rtl ? 'Use left-to-right' : 'Preview right-to-left'} variant="tertiary" onPress={() => setRtl(!rtl)} />
      </View>
      <View style={[styles.directionSample, { flexDirection: rtl ? 'row-reverse' : 'row', borderColor: theme.colors.border }]}>
        <BloomMark size={32} />
        <View style={styles.directionText}>
          <Text style={{ color: theme.colors.ink, fontSize: largeType ? 24 : 17, lineHeight: largeType ? 32 : 23, fontWeight: fontWeights.bold, textAlign: rtl ? 'right' : 'left', writingDirection: rtl ? 'rtl' : 'ltr' }}>
            {rtl ? 'مساحة للنمو كل يوم' : 'Room to grow, every day'}
          </Text>
          <Text style={{ color: theme.colors.inkMuted, fontSize: largeType ? 18 : 15, lineHeight: largeType ? 28 : 22, textAlign: rtl ? 'right' : 'left', writingDirection: rtl ? 'rtl' : 'ltr' }}>
            {rtl ? 'تظهر الإجراءات بوضوح مع تكبير النص.' : 'Actions stay clear as text grows.'}
          </Text>
        </View>
      </View>
      <View style={styles.typeScaleList}>
        {Object.entries(typeScale).map(([name, token]) => <View key={name} style={styles.typeSample}>
          <Text style={{ color: theme.colors.inkMuted, fontSize: 12 }}>{name} · {token.fontSize}/{token.lineHeight}</Text>
          <Text style={{ color: theme.colors.ink, fontSize: token.fontSize, lineHeight: token.lineHeight, fontWeight: name === 'display' || name === 'page' ? fontWeights.extrabold : fontWeights.medium }}>
            Bloom grows with practice
          </Text>
        </View>)}
      </View>
      <Body>Font token: {fontFamilies.display}, with native system sans fallback and system text scaling.</Body>
      <Body>Primary controls keep a 48px minimum height. Full RTL localization and screen-reader review remain part of the final accessibility pass.</Body>
    </Panel>

    <Panel>
      <Eyebrow>Spacing, shape and depth</Eyebrow>
      <Label>4px spacing scale and shared geometry</Label>
      <View style={styles.spacingList}>
        {Object.entries(spacing).filter(([, value]) => value > 0).map(([name, value]) => <View key={name} style={styles.spacingRow}>
          <Text style={{ width: 74, color: theme.colors.inkMuted, fontSize: 12 }}>{name} · {value}px</Text>
          <View style={{ width: Math.min(Number(value) * 2, 128), height: 8, borderRadius: radii.pill, backgroundColor: theme.colors.action }} />
        </View>)}
      </View>
      <View style={styles.shapeRow}>
        {[radii.control, radii.input, radii.card, radii.hero].map((radius) => <View key={radius} style={[styles.shapeSample, { borderRadius: radius, backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
          <Text style={{ color: theme.colors.inkMuted, fontSize: 12 }}>{radius}px</Text>
        </View>)}
      </View>
      <View style={styles.motionRow}>
        <Text style={{ color: theme.colors.inkMuted }}>Motion tokens · press {motion.press}ms · card {motion.card}ms · sheet {motion.sheetMin}–{motion.sheetMax}ms</Text>
      </View>
    </Panel>
  </Screen>;
}

const styles = {
  header: { flexDirection: 'row' as const, alignItems: 'flex-start' as const, justifyContent: 'space-between' as const, gap: spacing.space4 },
  headerCompact: { flexDirection: 'column' as const },
  headerText: { flex: 1, gap: spacing.space3 },
  segmentRow: { flexDirection: 'row' as const, flexWrap: 'wrap' as const, gap: spacing.space2, alignItems: 'center' as const },
  segment: { minHeight: 44, borderWidth: 1, borderRadius: radii.pill, paddingHorizontal: spacing.space4, alignItems: 'center' as const, justifyContent: 'center' as const },
  twoColumn: { flexDirection: 'row' as const, gap: spacing.space4, alignItems: 'flex-start' as const },
  oneColumn: { flexDirection: 'column' as const },
  brandRow: { flexDirection: 'row' as const, alignItems: 'center' as const, flexWrap: 'wrap' as const, gap: spacing.space5, paddingVertical: spacing.space3 },
  brandSample: { minWidth: 58, alignItems: 'center' as const, gap: spacing.space2 },
  moduleGrid: { flexDirection: 'row' as const, flexWrap: 'wrap' as const, gap: spacing.space2 },
  moduleCell: { flexGrow: 1, flexBasis: '46%', minWidth: 170 },
  moduleCellCompact: { flexBasis: '100%' },
  swatchGrid: { flexDirection: 'row' as const, flexWrap: 'wrap' as const, gap: spacing.space2 },
  swatch: { flexDirection: 'row' as const, alignItems: 'center' as const, gap: spacing.space2, width: '48%' as const, minWidth: 215, borderWidth: 1, borderRadius: radii.input, padding: spacing.space2 },
  swatchColor: { width: 42, height: 42, borderWidth: 1, borderRadius: radii.control },
  swatchText: { flex: 1, gap: 2 },
  mappingList: { marginTop: spacing.space3, gap: spacing.space1 },
  mappingRow: { borderBottomWidth: 1, paddingVertical: spacing.space2, gap: spacing.space1 },
  buttonGrid: { flexDirection: 'row' as const, flexWrap: 'wrap' as const, gap: spacing.space2 },
  buttonCell: { flexGrow: 1, flexBasis: '46%', minWidth: 130 },
  progressExample: { gap: spacing.space2 },
  progressHeader: { flexDirection: 'row' as const, justifyContent: 'space-between' as const, alignItems: 'center' as const },
  directionSample: { flexDirection: 'row' as const, alignItems: 'center' as const, gap: spacing.space3, borderWidth: 1, borderRadius: radii.card, padding: spacing.space4 },
  directionText: { flex: 1, gap: spacing.space1 },
  typeScaleList: { gap: spacing.space3, marginTop: spacing.space4 },
  typeSample: { gap: spacing.space1 },
  spacingList: { gap: spacing.space2 },
  spacingRow: { flexDirection: 'row' as const, alignItems: 'center' as const, gap: spacing.space3 },
  shapeRow: { flexDirection: 'row' as const, flexWrap: 'wrap' as const, gap: spacing.space2, marginTop: spacing.space4 },
  shapeSample: { width: 74, height: 52, borderWidth: 1, alignItems: 'center' as const, justifyContent: 'center' as const },
  motionRow: { marginTop: spacing.space4 },
};
