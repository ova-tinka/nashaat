import test from 'node:test';
import assert from 'node:assert/strict';
import { dateKeyInTimeZone, formatDateOnly } from '../src/lib/date-utils.ts';

test('date keys use the configured profile timezone across UTC date boundaries', () => {
  const instant = Date.parse('2026-11-19T21:30:00.000Z');
  assert.equal(dateKeyInTimeZone(instant, 'Asia/Qatar'), '2026-11-20');
  assert.equal(dateKeyInTimeZone(instant, 'America/Los_Angeles'), '2026-11-19');
});

test('invalid timezone settings fall back to UTC without crashing the task list', () => {
  assert.equal(dateKeyInTimeZone(Date.parse('2026-11-19T21:30:00.000Z'), 'invalid/timezone'), '2026-11-19');
});

test('date-only display does not shift the calendar date to another timezone', () => {
  assert.equal(formatDateOnly('2026-11-20', 'en-US'), 'Nov 20, 2026');
  assert.equal(formatDateOnly('not-a-date', 'en-US'), 'not-a-date');
});
