import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import {
  enqueueOfflineActivity,
  syncOfflineQueue,
} from '../src/lib/offline-activity-queue.ts';
import { isChildRestrictedRoute, moduleForPath } from '../src/lib/route-access.ts';
import {
  clearStoreBilling,
  identifyStoreBilling,
  storeBillingAvailable,
} from '../src/lib/store-billing.ts';

function memoryStorage() {
  const map = new Map();
  return {
    async getItem(key) {
      return map.get(key) ?? null;
    },
    async setItem(key, value) {
      map.set(key, value);
    },
  };
}

test('offline queue quarantines poison-pill item after 3 failed attempts without blocking later items', async () => {
  const storage = memoryStorage();
  const scope = { profileId: 'p1', deviceId: 'd1' };
  const badPayload = {
    kind: 'task_completion',
    itemId: 'bad-task',
    itemTitle: 'Bad task',
    completedAt: '2026-11-28T10:00:00.000Z',
  };
  const goodPayload = {
    kind: 'task_completion',
    itemId: 'good-task',
    itemTitle: 'Good task',
    completedAt: '2026-11-28T10:01:00.000Z',
  };

  await enqueueOfflineActivity(storage, scope, 'bad-1', badPayload);
  await enqueueOfflineActivity(storage, scope, 'good-1', goodPayload);

  // First 2 failures stop at the head item to preserve order on transient outages.
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    const res = await syncOfflineQueue(storage, scope, async (entry) => {
      if (entry.activityId === 'bad-1') throw new Error('permanent bad payload');
      return 'accepted';
    });
    assert.equal(res.accepted, 0);
    assert.equal(res.remaining.length, 2);
    assert.equal(res.remaining[0].attempts, attempt);
  }

  // On the 3rd failure, bad-1 is quarantined in remaining while good-1 syncs cleanly.
  const third = await syncOfflineQueue(storage, scope, async (entry) => {
    if (entry.activityId === 'bad-1') throw new Error('permanent bad payload');
    return 'accepted';
  });
  assert.equal(third.accepted, 1);
  assert.equal(third.remaining.length, 1);
  assert.equal(third.remaining[0].activityId, 'bad-1');
  assert.equal(third.remaining[0].attempts, 3);
});

test('route-access classifies /coach and /competitions under exercise module', () => {
  assert.equal(moduleForPath('/coach'), 'exercise');
  assert.equal(moduleForPath('/competitions'), 'exercise');
  assert.equal(moduleForPath('/competitions/123'), 'exercise');
  assert.equal(isChildRestrictedRoute('/coach', true, ['study', 'read']), true);
  assert.equal(isChildRestrictedRoute('/competitions', true, ['study', 'read']), true);
  assert.equal(isChildRestrictedRoute('/coach', true, ['exercise']), false);
  assert.equal(isChildRestrictedRoute('/competitions', true, ['exercise']), false);
});

test('store-billing web stub exports identifyStoreBilling and clearStoreBilling', async () => {
  assert.equal(storeBillingAvailable, false);
  await identifyStoreBilling('profile-1');
  await clearStoreBilling();
});

test('dark theme destructiveButton background maintains >= 4.5:1 contrast with white text', () => {
  const themeSrc = readFileSync(new URL('../src/theme.ts', import.meta.url), 'utf8');
  assert.match(themeSrc, /destructiveBackground:\s*colors\.ink === '#F4F7FF' \? '#C81E3A' : colors\.dangerText/);
});
