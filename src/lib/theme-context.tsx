import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren, type SetStateAction } from 'react';
import { Platform } from 'react-native';
import { themes, type BloomTheme, type ThemeMode } from '../theme';

const themeStorageKey = 'bloom.appearance.mode.v1';
const displayScaleStorageKey = 'bloom.appearance.display-scale.v1';
export type DisplayScale = 1 | 1.15 | 1.3;

type ThemeContextValue = {
  mode: ThemeMode;
  theme: BloomTheme;
  setMode: (next: SetStateAction<ThemeMode>) => void;
  displayScale: DisplayScale;
  setDisplayScale: (next: SetStateAction<DisplayScale>) => void;
};

const defaultValue: ThemeContextValue = {
  mode: 'light',
  theme: themes.light,
  setMode: () => undefined,
  displayScale: 1,
  setDisplayScale: () => undefined,
};

const ThemeContext = createContext<ThemeContextValue>(defaultValue);

export function ThemeProvider({ children, initialMode = 'light' }: PropsWithChildren<{ initialMode?: ThemeMode }>) {
  const [mode, setModeState] = useState<ThemeMode>(initialMode);
  const [displayScale, setDisplayScaleState] = useState<DisplayScale>(1);
  useEffect(() => {
    let mounted = true;
    void Promise.all([
      AsyncStorage.getItem(themeStorageKey).catch(() => null),
      AsyncStorage.getItem(displayScaleStorageKey).catch(() => null),
    ]).then(([saved, savedScale]) => {
      if (!mounted) return;
      if (saved === 'light' || saved === 'dark' || saved === 'highContrast') setModeState(saved);
      if (savedScale === '1.15') setDisplayScaleState(1.15);
      else if (savedScale === '1.3') setDisplayScaleState(1.3);
    }).catch(() => undefined);
    return () => { mounted = false; };
  }, []);
  const setMode = useCallback((next: SetStateAction<ThemeMode>) => {
    setModeState((current) => {
      const resolved = typeof next === 'function' ? next(current) : next;
      void AsyncStorage.setItem(themeStorageKey, resolved).catch(() => undefined);
      return resolved;
    });
  }, []);
  const setDisplayScale = useCallback((next: SetStateAction<DisplayScale>) => {
    setDisplayScaleState((current) => {
      const resolved = typeof next === 'function' ? next(current) : next;
      void AsyncStorage.setItem(displayScaleStorageKey, String(resolved)).catch(() => undefined);
      return resolved;
    });
  }, []);
  useEffect(() => {
    if (Platform.OS !== 'web' || typeof document === 'undefined') return;
    const rootStyle = document.documentElement.style;
    const previousZoom = rootStyle.zoom;
    rootStyle.zoom = String(displayScale);
    return () => { rootStyle.zoom = previousZoom; };
  }, [displayScale]);
  const value = useMemo(() => ({ mode, theme: themes[mode], setMode, displayScale, setDisplayScale }),
    [displayScale, mode, setDisplayScale, setMode]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useBloomTheme() {
  return useContext(ThemeContext);
}
