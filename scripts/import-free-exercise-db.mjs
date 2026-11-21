#!/usr/bin/env node

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_SOURCE_URL =
  'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
const SOURCE_IMAGE_BASE_URL =
  'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
const DEFAULT_OUT_PATH = 'docs/db/enrich-exercises-free-exercise-db.sql';

function parseArgs(argv) {
  const options = {
    sourcePath: null,
    outPath: DEFAULT_OUT_PATH,
    download: false,
    sourceUrl: DEFAULT_SOURCE_URL,
    sourceLabel: null,
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

    if (arg === '--source-label') {
      options.sourceLabel = requireValue(argv, i, '--source-label');
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
  node scripts/import-free-exercise-db.mjs <path-to-exercises.json> [--out docs/db/enrich-exercises-free-exercise-db.sql]
  node scripts/import-free-exercise-db.mjs --download [--out docs/db/enrich-exercises-free-exercise-db.sql]

Options:
  --download         Download the free-exercise-db combined JSON from GitHub.
  --source-url URL   Override the download URL.
  --source-label TXT Label recorded in the generated SQL.
  --out PATH         Output SQL metadata update path.
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
      label: options.sourceLabel ?? options.sourceUrl,
      json: await response.text(),
    };
  }

  return {
    label: options.sourceLabel ?? options.sourcePath,
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
  const primaryMuscleGroup = primaryMuscles.length ? titleCase(primaryMuscles[0]) : null;
  const instructions = normalizeStringArray(raw.instructions);
  const mediaLink = normalizeImageUrl(raw.id, raw.images);

  return {
    name,
    primaryMuscleGroup,
    muscleGroups,
    mediaLink,
    instructions,
  };
}

function normalizeImageUrl(exerciseId, images) {
  const id = normalizeText(exerciseId);
  const firstImage = normalizeText(Array.isArray(images) ? images[0] : null);
  if (!id || !firstImage) return null;

  const [directory, fileName, ...extraSegments] = firstImage.split('/');
  if (directory !== id || extraSegments.length > 0
    || !/^[a-z0-9_-]+$/i.test(directory)
    || !/^\d+\.(?:jpe?g|png|webp)$/i.test(fileName ?? '')) return null;

  return `${SOURCE_IMAGE_BASE_URL}${encodeURIComponent(directory)}/${encodeURIComponent(fileName)}`;
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

    if (!Array.isArray(row.instructions)) {
      throw new Error(`Instructions must be an array for ${row.name}`);
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
  const safeSourceLabel = normalizeText(sourceLabel).replace(/[\r\n]+/g, ' ');
  const values = rows
    .map((row) => `  (${sqlString(row.name)}, ${row.primaryMuscleGroup ? sqlString(row.primaryMuscleGroup) : 'NULL'}, ${sqlTextArray(row.muscleGroups)}, ${sqlTextArray(row.instructions)}, ${row.mediaLink ? sqlString(row.mediaLink) : 'NULL'})`)
    .join(',\n');

  return `-- Generated by scripts/import-free-exercise-db.mjs
-- Source: ${safeSourceLabel}
-- Rows: ${rows.length}
-- Skipped source records: ${skipped}
-- Updates matching system exercises only; source fields absent from the app schema are left untouched.
-- The source has no measurement_type, so this importer never assigns or changes one.
-- Image URLs are external; the upstream maintainer has not verified their rights or origin.

with source(name, muscle_group, muscle_groups, instructions, media_link) as (
values
${values}
)
update public.exercises as exercise
set muscle_group = coalesce(source.muscle_group, exercise.muscle_group),
    muscle_groups = case when cardinality(source.muscle_groups) > 0 then source.muscle_groups else exercise.muscle_groups end,
    instructions = case when coalesce(cardinality(exercise.instructions), 0) = 0 and cardinality(source.instructions) > 0
      then source.instructions else exercise.instructions end,
    media_link = coalesce(nullif(trim(exercise.media_link), ''), source.media_link)
from source
where exercise.is_system is true and exercise.name = source.name;
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

  console.log(`Wrote metadata for ${rows.length} source exercise(s) to ${options.outPath}`);
  if (skipped > 0) console.log(`Skipped ${skipped} duplicate or invalid source record(s).`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
