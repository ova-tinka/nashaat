import assert from 'node:assert/strict';
import test from 'node:test';
import { suggestBalancedWeeklySchedule, suggestWeeklyCheckInSchedule } from '../src/lib/weekly-planner.ts';

test('suggests a shared recovery day and preserves non-exercise weekly targets', () => {
  const proposal = suggestBalancedWeeklySchedule([
    { module_id: 'exercise', unit: 'workouts', target_count: 4, active_days: [1, 2, 3, 4, 5, 6, 0] },
    { module_id: 'study', unit: 'minutes', target_count: 120, active_days: [1, 2, 3, 4, 5] },
    { module_id: 'read', unit: 'sessions', target_count: 3, active_days: [2, 6] },
    { module_id: 'tasks', unit: 'tasks', target_count: 5, active_days: [1, 2, 3, 4, 5] },
  ]);

  assert.equal(proposal.recovery_day, 0);
  assert.equal(proposal.reduced_exercise_goal, false);
  assert.deepEqual(proposal.goals.map(({ target_count }) => target_count), [4, 120, 3, 5]);
  assert.ok(proposal.goals.every(({ active_days }) => !active_days.includes(proposal.recovery_day)));
  assert.ok(proposal.goals.every(({ active_days }) => active_days.length <= 6));
});

test('caps a proposed exercise goal at six workouts to reserve a recovery day', () => {
  const proposal = suggestBalancedWeeklySchedule([
    { module_id: 'exercise', unit: 'workouts', target_count: 7, active_days: [0, 1, 2, 3, 4, 5, 6] },
  ]);

  assert.equal(proposal.goals[0].target_count, 6);
  assert.equal(proposal.reduced_exercise_goal, true);
  assert.equal(proposal.goals[0].active_days.length, 6);
});

test('returns no schedule changes when there are no saved goals', () => {
  assert.deepEqual(suggestBalancedWeeklySchedule([]), {
    goals: [], recovery_day: 0, reduced_exercise_goal: false,
  });
});

test('weekly check-ins preserve goals when the plan feels steady or hard to fit', () => {
  const goals = [
    { module_id: 'exercise', unit: 'workouts', target_count: 7, active_days: [0, 1, 2, 3, 4, 5, 6] },
    { module_id: 'study', unit: 'minutes', target_count: 120, active_days: [1, 2, 3, 4, 5] },
  ];

  for (const checkIn of ['steady', 'hard_to_fit']) {
    const proposal = suggestWeeklyCheckInSchedule(goals, checkIn);
    assert.equal(proposal.check_in, checkIn);
    assert.deepEqual(proposal.goals.map(({ target_count }) => target_count), [7, 120]);
    assert.deepEqual(proposal.reduced_goal_modules, []);
    assert.ok(proposal.goals.every(({ active_days }) => !active_days.includes(proposal.recovery_day)));
  }
});

test('a too-much check-in lowers each goal by about 20%, keeps at least one, then balances days', () => {
  const proposal = suggestWeeklyCheckInSchedule([
    { module_id: 'exercise', unit: 'workouts', target_count: 7, active_days: [0, 1, 2, 3, 4, 5, 6] },
    { module_id: 'read', unit: 'sessions', target_count: 3, active_days: [1, 3, 5] },
    { module_id: 'tasks', unit: 'tasks', target_count: 1, active_days: [2] },
  ], 'too_much');

  assert.deepEqual(proposal.goals.map(({ target_count }) => target_count), [6, 2, 1]);
  assert.deepEqual(proposal.reduced_goal_modules, ['exercise', 'read']);
  assert.ok(proposal.goals.every(({ active_days }) => !active_days.includes(proposal.recovery_day)));
});
