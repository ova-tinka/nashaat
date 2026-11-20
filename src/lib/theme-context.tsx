import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren, type SetStateAction } from 'react';
import { themes, type BloomTheme, type ThemeMode } from '../theme';

const themeStorageKey = 'bloom.appearance.mode.v1';

type ThemeContextValue = {
  mode: ThemeMode;
  theme: BloomTheme;
  setMode: (next: SetStateAction<ThemeMode>) => void;
};

const defaultValue: ThemeContextValue = {
  mode: 'light',
  theme: themes.light,
  setMode: () => undefined,
};

const ThemeContext = createContext<ThemeContextValue>(defaultValue);

export function ThemeProvider({ children, initialMode = 'light' }: PropsWithChildren<{ initialMode?: ThemeMode }>) {
  const [mode, setModeState] = useState<ThemeMode>(initialMode);
  useEffect(() => {
    let mounted = true;
    void AsyncStorage.getItem(themeStorageKey).then((saved) => {
      if (!mounted) return;
      if (saved === 'dark') {
        setModeState('light');
        void AsyncStorage.setItem(themeStorageKey, 'light').catch(() => undefined);
        return;
      }
      if (saved === 'light' || saved === 'highContrast') setModeState(saved);
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
  const value = useMemo(() => ({ mode, theme: themes[mode], setMode }), [mode, setMode]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useBloomTheme() {
  return useContext(ThemeContext);
}
