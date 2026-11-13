import assert from 'node:assert/strict';
import test from 'node:test';
import { localCompetitionDate, parseCompetitionDate } from '../src/lib/competition-dates.ts';

test('competition dates round trip in the device time zone and reject invalid values', () => {
  const date = new Date(2030, 4, 17, 14, 35);
  assert.equal(parseCompetitionDate(localCompetitionDate(date)), date.toISOString());
  assert.equal(parseCompetitionDate('2030-02-30 10:30'), null);
  assert.equal(parseCompetitionDate('2030-01-01 25:00'), null);
  assert.equal(parseCompetitionDate('tomorrow'), null);
});
