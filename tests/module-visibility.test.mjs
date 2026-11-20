import assert from 'node:assert/strict';
import { test } from 'node:test';
import { moduleIds, moduleVisibilityStorageKey, parseVisibleModules } from '../src/lib/module-visibility-state.ts';

test('all available pillars are initially visible', () => {
  assert.deepEqual(parseVisibleModules(null), ['exercise', 'study', 'read', 'tasks']);
});

test('visibility choices are unique, ordered, and limited to known Bloom pillars', () => {
  assert.deepEqual(parseVisibleModules('["read","tasks","read","other"]'), ['read', 'tasks']);
});

test('an empty saved list keeps all pillars hidden without hiding Home', () => {
  assert.deepEqual(parseVisibleModules('[]'), []);
  assert.deepEqual(moduleIds, ['exercise', 'study', 'read', 'tasks']);
});

test('invalid local preferences safely restore the default pillar list', () => {
  assert.deepEqual(parseVisibleModules('not-json'), ['exercise', 'study', 'read', 'tasks']);
  assert.deepEqual(parseVisibleModules('{"read":true}'), ['exercise', 'study', 'read', 'tasks']);
});

test('device preferences are scoped to the active profile', () => {
  assert.equal(moduleVisibilityStorageKey('profile-one'), 'bloom.visible-modules.v1:profile-one');
  assert.notEqual(moduleVisibilityStorageKey('profile-one'), moduleVisibilityStorageKey('profile-two'));
});
