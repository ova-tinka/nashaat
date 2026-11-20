import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildDailyScreenTimeTotals, summarizeTodayPillars, summarizeWeeklyGoals } from '../src/lib/home-dashboard.ts';

test('weekly goal progress only counts goals that meet their configured target', () => {
  const goals = [
    { profile_id: 'test-profile', module_id: 'tasks', target_count: 4, unit: 'tasks', active_days: [], updated_at: '' },
    { profile_id: 'test-profile', module_id: 'study', target_count: 60, unit: 'minutes', active_days: [], updated_at: '' },
    { profile_id: 'test-profile', module_id: 'read', target_count: 3, unit: 'sessions', active_days: [], updated_at: '' },
  ];
  const actuals = [
    { module_id: 'tasks', actual_value: 4 },
    { module_id: 'study', actual_value: 59 },
    { module_id: 'read', actual_value: 5 },
  ];

  assert.deepEqual(summarizeWeeklyGoals(goals, actuals), {
    goals: [
      { ...goals[1], actualValue: 59, complete: false },
      { ...goals[2], actualValue: 5, complete: true },
      { ...goals[0], actualValue: 4, complete: true },
    ],
    completedCount: 2,
    totalCount: 3,
    percent: 67,
  });
});

test('weekly goal summary stays empty until real goals have been saved', () => {
  assert.deepEqual(summarizeWeeklyGoals([]), { goals: [], completedCount: 0, totalCount: 0, percent: 0 });
});

test('today pillar progress respects the profile time zone and each saved active day', () => {
  const goals = [
    { profile_id: 'test-profile', module_id: 'tasks', target_count: 2, unit: 'tasks', active_days: [0], updated_at: '' },
    { profile_id: 'test-profile', module_id: 'study', target_count: 60, unit: 'minutes', active_days: [0], updated_at: '' },
    { profile_id: 'test-profile', module_id: 'exercise', target_count: 1, unit: 'workouts', active_days: [0], updated_at: '' },
    { profile_id: 'test-profile', module_id: 'read', target_count: 2, unit: 'sessions', active_days: [6], updated_at: '' },
  ];
  const activity = [
    { moduleId: 'study', occurredAt: '2026-11-21T21:30:00.000Z' },
    { moduleId: 'tasks', occurredAt: '2026-11-21T20:30:00.000Z' },
  ];

  assert.deepEqual(summarizeTodayPillars(goals, activity, ['2026-11-21T21:45:00.000Z'],
    new Date('2026-11-21T22:00:00.000Z'), 'Asia/Qatar'), [
    { module_id: 'exercise', complete: true },
    { module_id: 'study', complete: true },
    { module_id: 'tasks', complete: false },
  ]);
});

test('daily screen-time totals count spent minutes in the active profile time zone', () => {
  const totals = buildDailyScreenTimeTotals([
    { amount_minutes: 20, entry_type: 'earned', created_at: '2026-11-21T20:30:00.000Z' },
    { amount_minutes: -15, entry_type: 'spent', created_at: '2026-11-21T20:00:00.000Z' },
    { amount_minutes: -5, entry_type: 'expired', created_at: '2026-11-21T20:45:00.000Z' },
    { amount_minutes: 8, entry_type: 'adjustment', created_at: '2026-11-21T20:50:00.000Z' },
    { amount_minutes: -60, entry_type: 'spent', created_at: '2026-11-13T20:30:00.000Z' },
    { amount_minutes: -30, entry_type: 'spent', created_at: 'not-a-date' },
    { amount_minutes: -22, entry_type: 'spent', created_at: '2026-11-21T20:40:00.000Z' },
  ], new Date('2026-11-21T22:00:00.000Z'), 'Asia/Qatar', 'en-US');

  assert.equal(totals.length, 7);
  assert.deepEqual(totals.map(({ dateKey }) => dateKey), [
    '2026-11-16', '2026-11-17', '2026-11-18', '2026-11-19', '2026-11-20', '2026-11-21', '2026-11-22',
  ]);
  assert.deepEqual(totals.map(({ minutes }) => minutes), [0, 0, 0, 0, 0, 37, 0]);
});

test('invalid time zones use UTC and days remain ordered chronologically', () => {
  const totals = buildDailyScreenTimeTotals([], new Date('2026-11-21T20:30:00.000Z'), 'invalid/time-zone', 'en-US');

  assert.deepEqual(totals.map(({ dateKey }) => dateKey), [
    '2026-11-15', '2026-11-16', '2026-11-17', '2026-11-18', '2026-11-19', '2026-11-20', '2026-11-21',
  ]);
});
