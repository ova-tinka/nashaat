import type { ModuleKey } from '../theme';
import { moduleManifest } from './module-manifest';

export const moduleIds: readonly ModuleKey[] = moduleManifest.map((module) => module.id);

export function moduleVisibilityStorageKey(profileId: string) {
  return `bloom.visible-modules.v1:${profileId}`;
}

export function parseVisibleModules(value: string | null): ModuleKey[] {
  if (value === null) return [...moduleIds];

  try {
    const saved: unknown = JSON.parse(value);
    if (!Array.isArray(saved)) return [...moduleIds];

    const visible = new Set(saved.filter((module): module is ModuleKey =>
      typeof module === 'string' && moduleIds.includes(module as ModuleKey)));
    return moduleIds.filter((module) => visible.has(module));
  } catch {
    return [...moduleIds];
  }
}
