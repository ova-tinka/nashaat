import test from 'node:test';
import assert from 'node:assert/strict';
import { growthModuleSnapshotKey } from '../src/lib/growth-module-state.ts';

test('growth snapshots are scoped to both the active profile and module', () => {
  const study = growthModuleSnapshotKey('profile-a', 'study');
  assert.equal(study, 'profile-a:study');
  assert.notEqual(study, growthModuleSnapshotKey('profile-b', 'study'));
  assert.notEqual(study, growthModuleSnapshotKey('profile-a', 'read'));
  assert.equal(growthModuleSnapshotKey(null, 'study'), null);
});
