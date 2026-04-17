#!/usr/bin/env node

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_SOURCE_URL =
  'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
const DEFAULT_OUT_PATH = 'docs/db/seed-exercises-free-exercise-db.sql';

const VALID_DIFFICULTIES = new Set(['easy', 'medium', 'hard']);
const VALID_MEASUREMENT_TYPES = new Set([
  'reps_weight',
  'time_distance',
  'time_only',
  'reps_only',
]);

const DISTANCE_CARDIO_PATTERN =
  /\b(run|running|walk|walking|treadmill|cycl|bike|biking|rowing|rower|swim|hiking|ski|skating|elliptical)\b/i;

const WEIGHTED_EQUIPMENT = new Set([
  'barbell',
  'dumbbell',
  'kettlebells',
  'cable',
  'machine',
  'medicine ball',
  'e-z curl bar',
  'bands',
]);

function parseArgs(argv) {
  const options = {
    sourcePath: null,
    outPath: DEFAULT_OUT_PATH,
    download: false,
    sourceUrl: DEFAULT_SOURCE_URL,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    }

    if (arg === '--download') {
      options.download = true;
      continue;
    }

    if (arg === '--out') {
      options.outPath = requireValue(argv, i, '--out');
      i += 1;
      continue;
    }

    if (arg === '--source-url') {
      options.sourceUrl = requireValue(argv, i, '--source-url');
      i += 1;
      continue;
    }

    if (arg.startsWith('--')) {
      throw new Error(`Unknown option: ${arg}`);
    }

    if (options.sourcePath !== null) {
      throw new Error(`Unexpected extra positional argument: ${arg}`);
    }

    options.sourcePath = arg;
  }

  if (!options.download && !options.sourcePath) {
    throw new Error('Provide a local JSON path or pass --download.');
  }

  return options;
}

function requireValue(argv, index, flag) {
  const value = argv[index + 1];
  if (!value || value.startsWith('--')) {
    throw new Error(`${flag} requires a value.`);
  }
  return value;
}

function printUsage() {
  console.log(`Usage:
  node scripts/import-free-exercise-db.mjs <path-to-exercises.json> [--out docs/db/seed-exercises-free-exercise-db.sql]
  node scripts/import-free-exercise-db.mjs --download [--out docs/db/seed-exercises-free-exercise-db.sql]

Options:
  --download         Download the free-exercise-db combined JSON from GitHub.
  --source-url URL   Override the download URL.
  --out PATH         Output SQL seed path.
`);
}

async function loadSource(options) {
  if (options.download) {
    const response = await fetch(options.sourceUrl);
    if (!response.ok) {
      throw new Error(
        `Download failed with HTTP ${response.status}: ${options.sourceUrl}`,
      );
    }
    return {
      label: options.sourceUrl,
      json: await response.text(),
    };
  }

  return {
    label: options.sourcePath,
    json: await readFile(options.sourcePath, 'utf8'),
  };
}

function parseExerciseList(sourceJson) {
  const parsed = JSON.parse(sourceJson);
  if (Array.isArray(parsed)) return parsed;
  if (Array.isArray(parsed.exercises)) return parsed.exercises;
  throw new Error('Expected a JSON array or an object with an exercises array.');
}

function normalizeExercise(raw) {
  const name = normalizeText(raw.name);
  if (!name) return null;

  const primaryMuscles = normalizeStringArray(raw.primaryMuscles);
  const secondaryMuscles = normalizeStringArray(raw.secondaryMuscles);
  const muscleGroups = unique([...primaryMuscles, ...secondaryMuscles].map(titleCase));
  const category = normalizeText(raw.category).toLowerCase();
  const equipment = normalizeText(raw.equipment).toLowerCase();
  const steps = normalizeStringArray(raw.instructions);
  const difficultyLevel = normalizeDifficulty(raw.level);
  const measurementType = inferMeasurementType({
    name,
    category,
    equipment,
  });

  return {
    name,
    description: normalizeDescription({
      name,
      rawDescription: raw.description,
      category,
      equipment,
      muscleGroups,
    }),
    muscleGroups,
    steps,
    difficultyLevel,
    measurementType,
  };
}

function normalizeText(value) {
  if (value === null || value === undefined) return '';
  return String(value).replaceAll('\0', '').replace(/\s+/g, ' ').trim();
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map(normalizeText).filter(Boolean);
}

function unique(values) {
  const seen = new Set();
  const result = [];

  for (const value of values) {
    const key = value.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(value);
  }

  return result;
}

function titleCase(value) {
  return value
    .split(' ')
    .filter(Boolean)
    .map((word) =>
      word
        .split('-')
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
        .join('-'),
    )
    .join(' ');
}

function normalizeDifficulty(level) {
  const normalized = normalizeText(level).toLowerCase();
  if (normalized === 'beginner') return 'easy';
  if (normalized === 'intermediate') return 'medium';
  if (normalized === 'expert') return 'hard';
  return 'medium';
}

function inferMeasurementType({ name, category, equipment }) {
  if (category === 'cardio') {
    return DISTANCE_CARDIO_PATTERN.test(name) ? 'time_distance' : 'time_only';
  }

  if (category === 'stretching') return 'time_only';
  if (equipment === 'body only') return 'reps_only';
  if (WEIGHTED_EQUIPMENT.has(equipment)) return 'reps_weight';
  if (category === 'plyometrics') return 'reps_only';

  return 'reps_weight';
}

function normalizeDescription({ name, rawDescription, category, equipment, muscleGroups }) {
  const description = normalizeText(rawDescription);
  if (description) return description;

  const parts = [];
  if (category) parts.push(`${category.replaceAll('_', ' ')} exercise`);
  if (equipment && equipment !== 'body only' && equipment !== 'other') {
    parts.push(`using ${equipment}`);
  }
  if (equipment === 'body only') parts.push('using body weight');
  if (muscleGroups.length > 0) {
    parts.push(`targeting ${muscleGroups.slice(0, 3).join(', ')}`);
  }

  if (parts.length === 0) {
    return `${name} is an imported exercise from free-exercise-db.`;
  }

  return `${name} is a ${parts.join(' ')}.`;
}

function dedupeExercises(exercises) {
  const byName = new Map();
  let skipped = 0;

  for (const raw of exercises) {
    const exercise = normalizeExercise(raw);
    if (!exercise) {
      skipped += 1;
      continue;
    }

    const key = exercise.name.toLowerCase();
    if (byName.has(key)) {
      skipped += 1;
      continue;
    }

    byName.set(key, exercise);
  }

  return {
    rows: [...byName.values()].sort((a, b) => a.name.localeCompare(b.name)),
    skipped,
  };
}

function validateRows(rows) {
  const names = new Set();

  for (const [index, row] of rows.entries()) {
    if (!row.name) throw new Error(`Row ${index + 1} has an empty name.`);

    const nameKey = row.name.toLowerCase();
    if (names.has(nameKey)) {
      throw new Error(`Duplicate exercise name after normalization: ${row.name}`);
    }
    names.add(nameKey);

    if (!VALID_DIFFICULTIES.has(row.difficultyLevel)) {
      throw new Error(`Invalid difficulty for ${row.name}: ${row.difficultyLevel}`);
    }

    if (!VALID_MEASUREMENT_TYPES.has(row.measurementType)) {
      throw new Error(`Invalid measurement type for ${row.name}: ${row.measurementType}`);
    }

    if (!Array.isArray(row.steps)) {
      throw new Error(`Steps must be an array for ${row.name}`);
    }

    if (!Array.isArray(row.muscleGroups)) {
      throw new Error(`Muscle groups must be an array for ${row.name}`);
    }
  }
}

function sqlString(value) {
  return `'${normalizeText(value).replaceAll("'", "''")}'`;
}

function sqlTextArray(values) {
  if (!values.length) return 'ARRAY[]::text[]';
  return `ARRAY[${values.map(sqlString).join(', ')}]::text[]`;
}

function renderSql(rows, sourceLabel, skipped) {
  const values = rows
    .map(
      (row) =>
        `(${sqlString(row.name)}, ${sqlString(row.description)}, ${sqlTextArray(
          row.muscleGroups,
        )}, ${sqlTextArray(row.steps)}, ${sqlString(
          row.difficultyLevel,
        )}, ${sqlString(row.measurementType)}, NULL, true)`,
    )
    .join(',\n');

  return `-- Generated by scripts/import-free-exercise-db.mjs
-- Source: ${sourceLabel}
-- Rows: ${rows.length}
-- Skipped source records: ${skipped}
-- Media is intentionally not imported; exercise media should use the media table later.

INSERT INTO exercises (
  name,
  description,
  muscle_groups,
  steps,
  difficulty_level,
  measurement_type,
  media_id,
  is_system
) VALUES
${values}
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  muscle_groups = EXCLUDED.muscle_groups,
  steps = EXCLUDED.steps,
  difficulty_level = EXCLUDED.difficulty_level,
  measurement_type = EXCLUDED.measurement_type,
  media_id = COALESCE(exercises.media_id, EXCLUDED.media_id),
  is_system = EXCLUDED.is_system;
`;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const source = await loadSource(options);
  const exerciseList = parseExerciseList(source.json);
  const { rows, skipped } = dedupeExercises(exerciseList);

  validateRows(rows);

  if (rows.length === 0) {
    throw new Error('No valid exercises found in the source JSON.');
  }

  const outPath = path.resolve(options.outPath);
  await mkdir(path.dirname(outPath), { recursive: true });
  await writeFile(outPath, renderSql(rows, source.label, skipped));

  console.log(`Wrote ${rows.length} exercise(s) to ${options.outPath}`);
  if (skipped > 0) console.log(`Skipped ${skipped} duplicate or invalid source record(s).`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
