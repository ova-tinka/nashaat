import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateExerciseRecords, calculateExerciseStreak } from '../src/lib/exercise-records.ts';

const exerciseId = '10000000-0000-0000-0000-000000000001';

test('personal bests use completed exercise results and keep units per measurement', () => {
  const result = calculateExerciseRecords([
    { completed_at: '2026-11-01T10:00:00Z', plan_snapshot: [{ exercise_id: exerciseId, name: 'Push up', measurement_type: 'reps_only' }],
      exercise_results: [{ exercise_id: exerciseId, sets_completed: 3, reps_completed: 8 }] },
    { completed_at: '2026-11-08T10:00:00Z', plan_snapshot: [{ exercise_id: exerciseId, name: 'Push up', measurement_type: 'reps_only' }],
      exercise_results: [{ exercise_id: exerciseId, sets_completed: 2, reps_completed: 12 }] },
    { completed_at: '2026-11-15T10:00:00Z', plan_snapshot: [{ exercise_id: exerciseId, name: 'Push up', measurement_type: 'reps_only' }],
      exercise_results: [{ exercise_id: exerciseId, sets_completed: 2, reps_completed: 10 }] },
  ]);

  assert.equal(result.bests.length, 1);
  assert.equal(result.bests[0].value, 12);
  assert.equal(result.bests[0].unit, 'reps');
  assert.equal(result.achievements.filter((item) => item.title.startsWith('New')).length, 1);
  assert.equal(result.achievements.find((item) => item.title.startsWith('New')).achievedAt, '2026-11-08T10:00:00Z');
});

test('records weight, duration, and distance separately and ignores malformed results', () => {
  const result = calculateExerciseRecords([
    { completed_at: '2026-11-02T10:00:00Z', plan_snapshot: [
      { exercise_id: 'weight', name: 'Row', measurement_type: 'reps_weight' },
      { exercise_id: 'timed', name: 'Plank', measurement_type: 'time_only' },
      { exercise_id: 'distance', name: 'Run', measurement_type: 'time_distance' },
    ], exercise_results: [
      { exercise_id: 'weight', sets_completed: 3, reps_completed: 8, weight_kg: 20 },
      { exercise_id: 'timed', sets_completed: 2, duration_seconds: 45 },
      { exercise_id: 'distance', sets_completed: 2, duration_seconds: 300, distance_km: 0.8 },
      { exercise_id: 'missing', sets_completed: 1, reps_completed: 5 },
    ] },
  ]);
  const actual = result.bests.map(({ metric, value, unit }) => ({ metric, value, unit })).sort((a, b) => a.metric.localeCompare(b.metric));
  assert.deepEqual(actual, [
    { metric: 'Distance per set', value: 0.8, unit: 'km' },
    { metric: 'Duration per set', value: 45, unit: 'sec' },
    { metric: 'Duration per set', value: 300, unit: 'sec' },
    { metric: 'Repetitions per set', value: 8, unit: 'reps' },
    { metric: 'Weight', value: 20, unit: 'kg' },
  ].sort((a, b) => a.metric.localeCompare(b.metric)));
});

test('workout streaks count unique consecutive days in the profile time zone', () => {
  const result = calculateExerciseStreak([
    { completed_at: '2026-11-17T10:00:00Z' },
    { completed_at: '2026-11-18T09:00:00Z' },
    { completed_at: '2026-11-18T18:00:00Z' },
    { completed_at: '2026-11-19T10:00:00Z' },
  ], 'UTC', new Date('2026-11-20T12:00:00Z'));

  assert.deepEqual(result, { currentDays: 3, longestDays: 3 });
});

test('workout streaks retain the longest run after the current run ends', () => {
  const result = calculateExerciseStreak([
    { completed_at: '2026-11-10T10:00:00Z' },
    { completed_at: '2026-11-11T10:00:00Z' },
    { completed_at: '2026-11-12T10:00:00Z' },
    { completed_at: '2026-11-18T10:00:00Z' },
  ], 'UTC', new Date('2026-11-20T12:00:00Z'));

  assert.deepEqual(result, { currentDays: 0, longestDays: 3 });
});
