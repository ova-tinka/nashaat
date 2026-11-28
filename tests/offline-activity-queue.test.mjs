import assert from 'node:assert/strict';
import test from 'node:test';
import {
  canSpendScreenTimeFromPendingQueue,
  enqueueOfflineActivity,
  loadOfflineQueue,
  syncOfflineQueue,
} from '../src/lib/offline-activity-queue.ts';

function memoryStorage() {
  const map = new Map();
  return {
    map,
    async getItem(key) {
      return map.has(key) ? (map.get(key) ?? null) : null;
    },
    async setItem(key, value) {
      map.set(key, value);
    },
  };
}

test('offline queue persists all 4 pillars, survives restart, reuses activityId, and isolates accounts', async () => {
  const storage = memoryStorage();
  const profileA = { profileId: 'prof-a', deviceId: 'dev-1' };
  const profileB = { profileId: 'prof-b', deviceId: 'dev-1' };

  await enqueueOfflineActivity(storage, profileA, 'act-ex', {
    kind: 'exercise_session',
    planId: 'plan-1',
    title: 'Morning Workout',
    startedAt: '2026-11-27T10:00:00Z',
    completedAt: '2026-11-27T10:20:00Z',
    durationSeconds: 1200,
    results: [{ exercise_id: 'ex-1', sets_completed: 2, reps_completed: 10 }],
  });
  await enqueueOfflineActivity(storage, profileA, 'act-study', {
    kind: 'study_session',
    moduleId: 'study',
    itemId: 'sub-1',
    itemTitle: 'Physics',
    sourceDeviceId: 'dev-1',
    sourceDeviceName: 'Mac',
    startedAt: '2026-11-27T11:00:00Z',
    completedAt: '2026-11-27T11:15:00Z',
    durationSeconds: 900,
  });
  await enqueueOfflineActivity(storage, profileA, 'act-read', {
    kind: 'read_session',
    moduleId: 'read',
    itemId: 'book-1',
    itemTitle: 'Dune',
    sourceDeviceId: 'dev-1',
    sourceDeviceName: 'Mac',
    startedAt: '2026-11-27T12:00:00Z',
    completedAt: '2026-11-27T12:10:00Z',
    durationSeconds: 600,
  });
  await enqueueOfflineActivity(storage, profileA, 'act-task', {
    kind: 'task_completion',
    itemId: 'task-1',
    itemTitle: 'Submit lab',
    completedAt: '2026-11-27T12:15:00Z',
  });

  assert.equal(canSpendScreenTimeFromPendingQueue(4), false);
  assert.equal((await loadOfflineQueue(storage, profileB)).length, 0);

  // Simulate interrupted sync on 3rd item, then reconnect retry reusing exact same activityId & frozen duration.
  const seenIds = [];
  let failThird = true;
  const firstPass = await syncOfflineQueue(storage, profileA, async (entry) => {
    seenIds.push(entry.activityId);
    if (entry.activityId === 'act-read' && failThird) {
      failThird = false;
      throw new Error('network dropped');
    }
    return 'accepted';
  });
  assert.equal(firstPass.accepted, 2);
  assert.equal(firstPass.remaining.length, 2);
  assert.equal(firstPass.remaining[0].activityId, 'act-read');
  assert.equal(firstPass.remaining[0].payload.durationSeconds, 600, 'Wait time must not inflate duration');

  const secondPass = await syncOfflineQueue(storage, profileA, async (entry) => {
    seenIds.push(entry.activityId);
    return entry.activityId === 'act-read' ? 'archived' : 'accepted';
  });
  assert.equal(secondPass.accepted, 1);
  assert.equal(secondPass.archived, 1);
  assert.equal(secondPass.remaining.length, 0);
  assert.deepEqual(seenIds, ['act-ex', 'act-study', 'act-read', 'act-read', 'act-task']);
});

test('enqueue during an in-flight flush is saved immediately and kept after sync', async () => {
  const storage = memoryStorage();
  const scope = { profileId: 'profile-race', deviceId: 'device-race' };
  const payload = (itemId) => ({
    kind: 'task_completion', itemId, itemTitle: itemId, completedAt: '2026-11-28T12:00:00Z',
  });
  await enqueueOfflineActivity(storage, scope, 'first', payload('first'));

  let releaseExecutor;
  let notifyExecutor;
  const executorStarted = new Promise((resolve) => { notifyExecutor = resolve; });
  const executorGate = new Promise((resolve) => { releaseExecutor = resolve; });
  const sync = syncOfflineQueue(storage, scope, async () => {
    notifyExecutor();
    await executorGate;
    return 'accepted';
  });
  await executorStarted;
  const enqueue = enqueueOfflineActivity(storage, scope, 'second', payload('second'));
  const enqueueResult = await Promise.race([
    enqueue.then(() => true, () => false),
    new Promise((resolve) => setTimeout(() => resolve(false), 250)),
  ]);
  releaseExecutor();
  await Promise.all([sync, enqueue]);

  assert.equal(enqueueResult, true, 'offline work should not wait for a network flush to finish');
  assert.deepEqual((await loadOfflineQueue(storage, scope)).map((entry) => entry.activityId), ['second']);
});

test('concurrent enqueues preserve distinct activities and deduplicate a repeated request', async () => {
  const storage = memoryStorage();
  const scope = { profileId: 'profile-concurrent', deviceId: 'device-concurrent' };
  const payload = (itemId) => ({
    kind: 'task_completion', itemId, itemTitle: itemId, completedAt: '2026-11-28T12:00:00Z',
  });

  await Promise.all([
    enqueueOfflineActivity(storage, scope, 'same', payload('same')),
    enqueueOfflineActivity(storage, scope, 'other', payload('other')),
    enqueueOfflineActivity(storage, scope, 'same', payload('same')),
  ]);

  assert.deepEqual((await loadOfflineQueue(storage, scope)).map((entry) => entry.activityId), ['same', 'other']);
});
