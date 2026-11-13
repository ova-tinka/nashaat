import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createBlockingRulesCoordinator } from '../src/lib/blocking-rules-coordinator.ts';

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

test('a delayed old-account fetch cannot replace a newer account', async () => {
  const old = deferred();
  const applied = [];
  const coordinator = createBlockingRulesCoordinator();
  const first = coordinator.sync('old', () => old.promise, async (rules) => { applied.push(rules); return 'ok'; });
  const second = coordinator.sync('new', async () => 'new rules', async (rules) => { applied.push(rules); return 'ok'; });
  await second;
  old.resolve('old rules');
  assert.equal(await first, null);
  assert.deepEqual(applied, ['new rules']);
});

test('a new account is applied after an already-started old native write', async () => {
  const started = deferred();
  const finish = deferred();
  const applied = [];
  const coordinator = createBlockingRulesCoordinator();
  const first = coordinator.sync('old', async () => 'old rules', async (rules) => { started.resolve(); await finish.promise; applied.push(rules); return 'ok'; });
  await started.promise;
  const second = coordinator.sync('new', async () => 'new rules', async (rules) => { applied.push(rules); return 'ok'; });
  finish.resolve();
  assert.equal(await first, null);
  await second;
  assert.deepEqual(applied, ['old rules', 'new rules']);
});

test('sign-out invalidates pending fetch and failures preserve last applied rules', async () => {
  const pending = deferred();
  const applied = [];
  const coordinator = createBlockingRulesCoordinator();
  await coordinator.sync('owner', async () => 'last rules', async (rules) => { applied.push(rules); return 'ok'; });
  const late = coordinator.sync('owner', () => pending.promise, async (rules) => { applied.push(rules); return 'ok'; });
  coordinator.cancel('owner');
  pending.resolve('stale rules');
  assert.equal(await late, null);
  await assert.rejects(coordinator.sync('owner', async () => { throw Error('offline'); }, async (rules) => { applied.push(rules); return 'ok'; }));
  assert.deepEqual(applied, ['last rules']);
});

test('returning to an account reapplies its rules and rechecks health', async () => {
  const applied = [];
  const coordinator = createBlockingRulesCoordinator();
  for (const account of ['a', 'b', 'a']) {
    await coordinator.sync(account, async () => account, async (rules) => { applied.push(rules); return 'ok'; });
  }
  assert.deepEqual(applied, ['a', 'b', 'a']);
});
