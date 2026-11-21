import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const importer = path.join(root, 'scripts/import-free-exercise-db.mjs');

test('exercise import enriches matched system rows with source fields without inventing classifications', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'bloom-exercise-import-'));
  const sourcePath = path.join(directory, 'source.json');
  const outputPath = path.join(directory, 'seed.sql');
  const rows = [
    { id: 'Bodyweight_Squat', name: 'Bodyweight Squat', primaryMuscles: ['quadriceps'], secondaryMuscles: ['glutes'],
      instructions: ['Squat with control.'], level: 'beginner', category: 'strength', equipment: 'body only',
      images: ['Bodyweight_Squat/0.jpg'] },
    { id: 'Wall_Sit', name: 'Wall Sit', primaryMuscles: ['quadriceps'], secondaryMuscles: [],
      instructions: ['Hold the position.'], level: 'intermediate', category: 'strength', equipment: 'body only',
      images: ['Wall_Sit/0.jpg'] },
    { id: 'No_Image', name: 'No Image', primaryMuscles: [], secondaryMuscles: [],
      instructions: ['Move carefully.'], level: 'expert', category: 'strength', equipment: 'other', images: [] },
    { id: 'Mismatched_Id', name: 'Mismatched Image', primaryMuscles: ['chest'], secondaryMuscles: [],
      instructions: ['Move carefully.'], level: 'expert', category: 'strength', equipment: 'other',
      images: ['Different_Exercise/0.jpg'] },
  ];

  try {
    writeFileSync(sourcePath, JSON.stringify(rows));
    const result = spawnSync(process.execPath, [importer, sourcePath, '--out', outputPath], { cwd: root, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const sql = readFileSync(outputPath, 'utf8');

    assert.match(sql, /update public\.exercises as exercise/);
    assert.match(sql, /with source\(name, muscle_group, muscle_groups, instructions, media_link\)/);
    assert.match(sql, /'Quadriceps', ARRAY\['Quadriceps', 'Glutes'\]::text\[\]/);
    assert.match(sql, /ARRAY\['Squat with control\.'\]::text\[\]/);
    assert.match(sql, /'https:\/\/raw\.githubusercontent\.com\/yuhonas\/free-exercise-db\/main\/exercises\/Bodyweight_Squat\/0\.jpg'/);
    assert.match(sql, /'https:\/\/raw\.githubusercontent\.com\/yuhonas\/free-exercise-db\/main\/exercises\/Wall_Sit\/0\.jpg'/);
    assert.doesNotMatch(sql, /^\s*(?:measurement_type|difficulty_level)\s*=|INSERT INTO/im);
    assert.doesNotMatch(sql, /Different_Exercise\/0\.jpg/);
    assert.match(sql, /media_link = coalesce\(nullif\(trim\(exercise\.media_link\), ''\), source\.media_link\)/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
