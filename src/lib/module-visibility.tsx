import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from 'react';
import type { ModuleKey } from '../theme';
import { moduleIds, moduleVisibilityStorageKey, parseVisibleModules } from './module-visibility-state';

type ModuleVisibilityContextValue = {
  visibleModules: readonly ModuleKey[];
  loaded: boolean;
  setModuleVisibility: (moduleId: ModuleKey, visible: boolean) => void;
};

const defaultValue: ModuleVisibilityContextValue = {
  visibleModules: moduleIds,
  loaded: false,
  setModuleVisibility: () => undefined,
};

const ModuleVisibilityContext = createContext(defaultValue);

export function ModuleVisibilityProvider({ profileId, children }: PropsWithChildren<{ profileId: string }>) {
  const [state, setState] = useState<{ profileId: string | null; modules: ModuleKey[]; loaded: boolean }>({
    profileId: null,
    modules: [...moduleIds],
    loaded: false,
  });

  useEffect(() => {
    let active = true;
    void AsyncStorage.getItem(moduleVisibilityStorageKey(profileId)).then((saved) => {
      if (active) setState({ profileId, modules: parseVisibleModules(saved), loaded: true });
    }).catch(() => {
      if (active) setState({ profileId, modules: [...moduleIds], loaded: true });
    });
    return () => { active = false; };
  }, [profileId]);

  useEffect(() => {
    if (state.profileId !== profileId || !state.loaded) return;
    void AsyncStorage.setItem(moduleVisibilityStorageKey(profileId), JSON.stringify(state.modules)).catch(() => undefined);
  }, [profileId, state]);

  const setModuleVisibility = useCallback((moduleId: ModuleKey, visible: boolean) => {
    setState((current) => {
      const currentModules = current.profileId === profileId ? current.modules : [...moduleIds];
      const nextSet = new Set(currentModules);
      if (visible) nextSet.add(moduleId);
      else nextSet.delete(moduleId);
      const modules = moduleIds.filter((module) => nextSet.has(module));
      return { profileId, modules, loaded: true };
    });
  }, [profileId]);

  const value = useMemo(() => ({
    visibleModules: state.profileId === profileId ? state.modules : moduleIds,
    loaded: state.profileId === profileId && state.loaded,
    setModuleVisibility,
  }), [profileId, setModuleVisibility, state]);

  return <ModuleVisibilityContext.Provider value={value}>{children}</ModuleVisibilityContext.Provider>;
}

export function useModuleVisibility() {
  return useContext(ModuleVisibilityContext);
}
