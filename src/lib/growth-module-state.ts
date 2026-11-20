import type { GrowthModuleId } from './growth-modules';

export function growthModuleSnapshotKey(profileId: string | null, moduleId: GrowthModuleId) {
  return profileId ? `${profileId}:${moduleId}` : null;
}
