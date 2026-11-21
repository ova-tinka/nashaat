export const palette = {
  ink: '#141B35',
  inkMuted: '#586784',
  inkSubtle: '#65738B',
  canvas: '#F7F9FF',
  surface: '#FFFFFF',
  surfaceSoft: '#EDF2FA',
  surfaceTinted: '#EDF3FB',
  border: '#DFE6F1',
  borderStrong: '#C6D0E0',
  exercise: '#19D96B',
  exerciseDeep: '#087A42',
  study: '#247BFF',
  studyDeep: '#1E5EBE',
  read: '#9155F7',
  readDeep: '#6D35C7',
  tasks: '#E743C8',
  tasksDeep: '#B21D93',
  info: '#247BFF',
  success: '#117A48',
  warning: '#B87914',
  danger: '#C14360',
  focusRing: '#247BFF',
} as const;

export const spacing = {
  none: 0,
  space1: 4,
  space2: 8,
  space3: 12,
  space4: 16,
  space5: 20,
  space6: 24,
  space8: 32,
  space10: 40,
  space12: 48,
  space16: 64,
} as const;

export const radii = {
  control: 10,
  input: 12,
  card: 20,
  hero: 24,
  sheet: 28,
  pill: 999,
} as const;

export const typeScale = {
  display: { fontSize: 32, lineHeight: 38 },
  page: { fontSize: 26, lineHeight: 32 },
  section: { fontSize: 20, lineHeight: 26 },
  card: { fontSize: 17, lineHeight: 23 },
  body: { fontSize: 15, lineHeight: 22 },
  supporting: { fontSize: 13, lineHeight: 19 },
  caption: { fontSize: 11, lineHeight: 16 },
} as const;

export const fontWeights = {
  regular: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
  extrabold: '800',
} as const;

// The repository has no bundled display font yet. Components use each platform's
// native sans family so system text scaling and platform fallback remain intact.
export const fontFamilies = {
  display: 'native-sans',
  body: 'native-sans',
  mono: 'monospace',
} as const;

export const shadows = {
  card: { color: '#223460', offset: { width: 0, height: 4 }, opacity: 0.06, radius: 16, elevation: 2 },
  raised: { color: '#223460', offset: { width: 0, height: 10 }, opacity: 0.1, radius: 30, elevation: 5 },
  sheet: { color: '#121E3E', offset: { width: 0, height: -8 }, opacity: 0.12, radius: 32, elevation: 8 },
} as const;

export const motion = {
  press: 140,
  interaction: 180,
  card: 220,
  sheetMin: 240,
  sheetMax: 320,
  progress: 300,
} as const;

export type ThemeMode = 'light' | 'dark' | 'highContrast';

export type ModuleKey = 'exercise' | 'study' | 'read' | 'tasks';

export type ThemeColors = {
  canvas: string;
  surface: string;
  surfaceSoft: string;
  surfaceTinted: string;
  ink: string;
  inkMuted: string;
  inkSubtle: string;
  border: string;
  borderStrong: string;
  action: string;
  actionHover: string;
  onAction: string;
  info: string;
  infoText: string;
  success: string;
  successText: string;
  warning: string;
  warningText: string;
  danger: string;
  dangerText: string;
  focusRing: string;
  overlay: string;
};

export type ModuleTheme = { accent: string; deep: string; text: string; surface: string };

export type ThemeComponentTokens = {
  card: { background: string; border: string };
  button: {
    primaryBackground: string;
    primaryText: string;
    secondaryBackground: string;
    secondaryBorder: string;
    secondaryText: string;
    tertiaryText: string;
    destructiveBackground: string;
    destructiveText: string;
    focusBorder: string;
  };
  field: {
    background: string;
    text: string;
    border: string;
    focusBorder: string;
    errorBorder: string;
    placeholder: string;
    label: string;
    helper: string;
    error: string;
  };
};

export type ThemeShadowTokens = {
  card: { color: string; offset: { width: number; height: number }; opacity: number; radius: number; elevation: number };
  raised: { color: string; offset: { width: number; height: number }; opacity: number; radius: number; elevation: number };
  sheet: { color: string; offset: { width: number; height: number }; opacity: number; radius: number; elevation: number };
};

function componentTokens(colors: ThemeColors): ThemeComponentTokens {
  return {
    card: { background: colors.surface, border: colors.border },
    button: {
      primaryBackground: colors.action,
      primaryText: colors.onAction,
      secondaryBackground: colors.surfaceSoft,
      secondaryBorder: colors.border,
      secondaryText: colors.ink,
      tertiaryText: colors.action,
      destructiveBackground: colors.dangerText,
      destructiveText: '#FFFFFF',
      focusBorder: colors.focusRing,
    },
    field: {
      background: colors.surface,
      text: colors.ink,
      border: colors.borderStrong,
      focusBorder: colors.focusRing,
      errorBorder: colors.dangerText,
      placeholder: colors.inkMuted,
      label: colors.ink,
      helper: colors.inkMuted,
      error: colors.dangerText,
    },
  };
}

export type BloomTheme = {
  colors: ThemeColors;
  modules: Record<ModuleKey, ModuleTheme>;
  components: ThemeComponentTokens;
  shadows: ThemeShadowTokens;
};

const lightColors: ThemeColors = {
    canvas: palette.canvas,
    surface: palette.surface,
    surfaceSoft: palette.surfaceSoft,
    surfaceTinted: palette.surfaceTinted,
    ink: palette.ink,
    inkMuted: palette.inkMuted,
    inkSubtle: palette.inkSubtle,
    border: palette.border,
    borderStrong: palette.borderStrong,
    action: palette.studyDeep,
    actionHover: '#154B9A',
    onAction: '#FFFFFF',
    info: palette.info,
    infoText: palette.studyDeep,
    success: palette.success,
    successText: '#08723C',
    warning: palette.warning,
    warningText: '#78500C',
    danger: palette.danger,
    dangerText: '#B5314F',
    focusRing: palette.focusRing,
    overlay: 'rgba(16, 21, 43, 0.42)',
};

export const lightTheme: BloomTheme = {
  colors: lightColors,
  modules: {
    exercise: { accent: palette.exercise, deep: palette.exerciseDeep, text: '#086239', surface: '#EAF9F0' },
    study: { accent: palette.study, deep: palette.studyDeep, text: palette.studyDeep, surface: '#EDF4FF' },
    read: { accent: palette.read, deep: palette.readDeep, text: palette.readDeep, surface: '#F2ECFF' },
    tasks: { accent: palette.tasks, deep: palette.tasksDeep, text: palette.tasksDeep, surface: '#FBE3F6' },
  },
  components: componentTokens(lightColors),
  shadows,
};

const darkColors: ThemeColors = {
    canvas: '#10162B',
    surface: '#18213A',
    surfaceSoft: '#222C49',
    surfaceTinted: '#282D50',
    ink: '#F4F6FF',
    inkMuted: '#C0C8E0',
    inkSubtle: '#9DA9C8',
    border: '#34415F',
    borderStrong: '#536181',
    action: '#8DB3FF',
    actionHover: '#A8C5FF',
    onAction: '#101A33',
    info: '#8DB3FF',
    infoText: '#B6CEFF',
    success: '#62D991',
    successText: '#8BE8AD',
    warning: '#E5B75E',
    warningText: '#F1CC82',
    danger: '#F08AA0',
    dangerText: '#FFB5C3',
    focusRing: '#A8C5FF',
    overlay: 'rgba(4, 8, 20, 0.68)',
};

export const darkTheme: BloomTheme = {
  colors: darkColors,
  modules: {
    exercise: { accent: '#59E77A', deep: '#A5F3B4', text: '#A5F3B4', surface: '#203A31' },
    study: { accent: '#72A9FF', deep: '#B6D0FF', text: '#B6D0FF', surface: '#1E304E' },
    read: { accent: '#B795FF', deep: '#D2BDFF', text: '#D2BDFF', surface: '#302747' },
    tasks: { accent: '#FF66CC', deep: '#FFADE1', text: '#FFADE1', surface: '#41213B' },
  },
  components: componentTokens(darkColors),
  shadows: {
    card: { color: '#050914', offset: { width: 0, height: 4 }, opacity: 0.24, radius: 16, elevation: 3 },
    raised: { color: '#050914', offset: { width: 0, height: 10 }, opacity: 0.34, radius: 30, elevation: 6 },
    sheet: { color: '#030611', offset: { width: 0, height: -8 }, opacity: 0.45, radius: 32, elevation: 10 },
  },
};

const highContrastColors: ThemeColors = {
    canvas: '#FFFFFF',
    surface: '#FFFFFF',
    surfaceSoft: '#F3F4F6',
    surfaceTinted: '#EEF2F7',
    ink: '#000000',
    inkMuted: '#252B36',
    inkSubtle: '#424B5A',
    border: '#596273',
    borderStrong: '#202938',
    action: '#003E8C',
    actionHover: '#002F6C',
    onAction: '#FFFFFF',
    info: '#005FCC',
    infoText: '#003E8C',
    success: '#08723C',
    successText: '#075B31',
    warning: '#78500C',
    warningText: '#624108',
    danger: '#B5314F',
    dangerText: '#92253F',
    focusRing: '#005FCC',
    overlay: 'rgba(0, 0, 0, 0.56)',
};

export const highContrastTheme: BloomTheme = {
  colors: highContrastColors,
  modules: {
    exercise: { accent: '#08723C', deep: '#075B31', text: '#075B31', surface: '#E8F7EC' },
    study: { accent: '#003E8C', deep: '#002F6C', text: '#002F6C', surface: '#E8F0FC' },
    read: { accent: '#5630B1', deep: '#41248C', text: '#41248C', surface: '#F0EBFC' },
    tasks: { accent: '#A90080', deep: '#80005D', text: '#80005D', surface: '#FDEAF8' },
  },
  components: componentTokens(highContrastColors),
  shadows: {
    card: { color: '#000000', offset: { width: 0, height: 0 }, opacity: 0, radius: 0, elevation: 0 },
    raised: { color: '#000000', offset: { width: 0, height: 0 }, opacity: 0, radius: 0, elevation: 0 },
    sheet: { color: '#000000', offset: { width: 0, height: 0 }, opacity: 0, radius: 0, elevation: 0 },
  },
};

export const themes: Record<ThemeMode, BloomTheme> = {
  light: lightTheme,
  dark: darkTheme,
  highContrast: highContrastTheme,
};

// Compatibility aliases let existing screens adopt the light baseline
// incrementally while shared components and the gallery use semantic tokens.
export const colors = {
  background: lightTheme.colors.canvas,
  card: lightTheme.colors.surface,
  raised: lightTheme.colors.surfaceSoft,
  border: lightTheme.colors.border,
  text: lightTheme.colors.ink,
  body: lightTheme.colors.inkMuted,
  muted: lightTheme.colors.inkMuted,
  subtle: lightTheme.colors.inkSubtle,
  accent: lightTheme.colors.action,
  accentInk: lightTheme.colors.onAction,
  reward: lightTheme.colors.warningText,
  danger: lightTheme.colors.dangerText,
  success: lightTheme.colors.successText,
  info: lightTheme.colors.infoText,
  focus: lightTheme.colors.focusRing,
};

export function contrastRatio(foreground: string, background: string): number {
  const luminance = (hex: string) => {
    const normalized = hex.replace('#', '');
    const channels = [0, 2, 4].map((index) => parseInt(normalized.slice(index, index + 2), 16) / 255);
    const linear = channels.map((channel) => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4);
    return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
  };
  const values = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return Number(((values[0] + 0.05) / (values[1] + 0.05)).toFixed(2));
}
