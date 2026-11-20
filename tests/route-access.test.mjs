import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isChildRestrictedRoute, isFamilySpaceRoute } from '../src/lib/route-access.ts';

test('child approvals and management remain in Family Space context', () => {
  for (const route of ['/family', '/family-child', '/child-coaching', '/child-competitions']) {
    assert.equal(isFamilySpaceRoute(route), true, route);
    assert.equal(isFamilySpaceRoute(`${route}/nested`), true, `${route}/nested`);
  }
  assert.equal(isFamilySpaceRoute('/'), false);
  assert.equal(isFamilySpaceRoute('/family-history'), false);
});

test('child profiles cannot route to guardian family and approval surfaces', () => {
  for (const route of ['/family', '/family-child', '/child-coaching', '/child-competitions']) {
    assert.equal(isChildRestrictedRoute(route, true), true, route);
    assert.equal(isChildRestrictedRoute(`${route}/nested`, true), true, `${route}/nested`);
  }
});

test('personal activity and parent routes remain available to adult profiles', () => {
  for (const route of ['/', '/workouts', '/progress', '/settings', '/family', '/family-child']) {
    assert.equal(isChildRestrictedRoute(route, false), false, route);
  }
});

test('child module routes require explicit assignments while shared routes remain available', () => {
  for (const route of ['/exercise', '/study', '/read', '/tasks', '/workouts', '/library', '/new-plan', '/exercise/123', '/apps/exercise', '/apps/study']) {
    assert.equal(isChildRestrictedRoute(route, true), true, route);
  }
  for (const route of ['/', '/progress', '/activity', '/settings', '/devices', '/focus', '/apps']) {
    assert.equal(isChildRestrictedRoute(route, true), false, route);
  }
  for (const route of ['/exercise', '/workouts', '/library', '/new-plan', '/exercise/123', '/apps/exercise']) {
    assert.equal(isChildRestrictedRoute(route, true, ['exercise']), false, route);
  }
  assert.equal(isChildRestrictedRoute('/apps/study', true, ['exercise']), true);
  assert.equal(isChildRestrictedRoute('/session', true, []), false, 'an existing session can be safely completed');
});
