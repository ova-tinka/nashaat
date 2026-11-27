import assert from 'node:assert/strict';
import test from 'node:test';
import { createProfileQueryCoordinator, loadSectionsIndependently } from '../src/lib/bloom-data-cache.ts';

test('settings initialize once per profile and ordinary refreshes perform zero settings writes', async () => {
  const coordinator = createProfileQueryCoordinator();
  let settingsWrites = 0;

  async function refresh() {
    await coordinator.ensureInitializedOnce('prof-1', async () => {
      settingsWrites += 1;
    });
  }

  await Promise.all([refresh(), refresh(), refresh()]);
  await refresh();
  await refresh();
  assert.equal(settingsWrites, 1, 'Expected exactly 1 initialization write across concurrent and repeated refreshes');
});

test('concurrent requests deduplicate by profile and invalidate cleanly after writes', async () => {
  const coordinator = createProfileQueryCoordinator();
  let calls = 0;
  const loader = async () => {
    calls += 1;
    await new Promise((r) => setTimeout(r, 15));
    return { balance: calls * 10 };
  };

  const [a, b] = await Promise.all([
    coordinator.runDeduplicated('prof-1', 'wallet', loader, true),
    coordinator.runDeduplicated('prof-1', 'wallet', loader, true),
  ]);
  assert.equal(calls, 1);
  assert.equal(a.balance, 10);
  assert.equal(b.balance, 10);

  // Cached hit avoids another query until invalidated.
  const c = await coordinator.runDeduplicated('prof-1', 'wallet', loader, true);
  assert.equal(calls, 1);
  assert.equal(c.balance, 10);

  coordinator.invalidate('prof-1', ['wallet']);
  const d = await coordinator.runDeduplicated('prof-1', 'wallet', loader, true);
  assert.equal(calls, 2);
  assert.equal(d.balance, 20);
});

test('loadSectionsIndependently preserves successful sections when one section fails', async () => {
  const result = await loadSectionsIndependently({
    wallet: async () => ({ balance: 42 }),
    analytics: async () => {
      throw new Error('analytics timeout');
    },
    plans: async () => ['plan-1'],
  });

  assert.deepEqual(result.values.wallet, { balance: 42 });
  assert.deepEqual(result.values.plans, ['plan-1']);
  assert.equal(result.values.analytics, undefined);
  assert.ok(result.errors.analytics instanceof Error);
});
