import assert from 'node:assert/strict';
import test from 'node:test';
import {
  defaultOnboardingState,
  ONBOARDING_STEPS,
  onboardingStorageKey,
  parseOnboardingState,
  recommendedFirstAction,
  shouldShowOnboarding,
} from '../src/lib/onboarding.ts';

test('onboarding storage key is scoped per profile to prevent cross-account bleed', () => {
  assert.notEqual(onboardingStorageKey('profile-a'), onboardingStorageKey('profile-b'));
});

test('parseOnboardingState handles missing/corrupt data and clamps step bounds', () => {
  assert.deepEqual(parseOnboardingState(null), defaultOnboardingState());
  assert.deepEqual(parseOnboardingState('not-json'), defaultOnboardingState());

  const parsed = parseOnboardingState(JSON.stringify({
    completed: true,
    completedAt: '2026-11-28T12:00:00Z',
    currentStep: 99,
    goals: ['study', 'invalid_goal', 'exercise'],
    usageMode: 'family',
    skippedPermissions: true,
  }));
  assert.equal(parsed.completed, true);
  assert.equal(parsed.currentStep, ONBOARDING_STEPS.length - 1);
  assert.deepEqual(parsed.goals, ['study', 'exercise']);
  assert.equal(parsed.usageMode, 'family');
  assert.equal(parsed.skippedPermissions, true);
});

test('shouldShowOnboarding skips child profiles and completed adult accounts', () => {
  const incomplete = defaultOnboardingState();
  const complete = { ...incomplete, completed: true, completedAt: '2026-11-28T12:00:00Z' };

  assert.equal(shouldShowOnboarding(incomplete, { childProfile: false }), true);
  assert.equal(shouldShowOnboarding(complete, { childProfile: false }), false);
  assert.equal(shouldShowOnboarding(incomplete, { childProfile: true }), false);
  assert.equal(shouldShowOnboarding(null, { childProfile: false }), false);
});

test('recommendedFirstAction prioritizes chosen pillar or focus', () => {
  assert.equal(recommendedFirstAction(['study']).pillar, 'study');
  assert.equal(recommendedFirstAction(['exercise']).pillar, 'exercise');
  assert.equal(recommendedFirstAction(['read']).pillar, 'read');
  assert.equal(recommendedFirstAction(['tasks']).pillar, 'tasks');
  assert.equal(recommendedFirstAction([]).route, '/focus');
});
