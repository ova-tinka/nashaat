import assert from 'node:assert/strict';
import test from 'node:test';
import { suggestStudyPracticeDifficulty } from '../src/lib/study-practice.ts';

const answer = (selfAssessedCorrect, createdAt) => ({
  created_at: createdAt,
  metadata: { self_assessed_correct: selfAssessedCorrect },
});

test('defaults to steady until there are two self-rated answers', () => {
  assert.equal(suggestStudyPracticeDifficulty([]), 'steady');
  assert.equal(suggestStudyPracticeDifficulty([answer(true, '2026-11-18T10:00:00Z')]), 'steady');
});

test('raises the next-question suggestion after recent successful answers', () => {
  assert.equal(suggestStudyPracticeDifficulty([
    answer(false, '2026-11-19T10:00:00Z'),
    answer(true, '2026-11-20T10:00:00Z'),
    answer(true, '2026-11-18T10:00:00Z'),
  ]), 'challenge');
});

test('lowers the next-question suggestion after recent difficult answers', () => {
  assert.equal(suggestStudyPracticeDifficulty([
    answer(true, '2026-11-17T10:00:00Z'),
    answer(false, '2026-11-20T10:00:00Z'),
    answer(false, '2026-11-19T10:00:00Z'),
    answer(false, '2026-11-18T10:00:00Z'),
  ]), 'gentle');
});

test('ignores answers without a self-rating and evaluates the three newest answers', () => {
  assert.equal(suggestStudyPracticeDifficulty([
    answer(true, '2026-11-20T10:00:00Z'),
    { created_at: '2026-11-21T10:00:00Z', metadata: {} },
    answer(false, '2026-11-19T10:00:00Z'),
    answer(false, '2026-11-18T10:00:00Z'),
  ]), 'steady');
});
