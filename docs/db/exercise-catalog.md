# Exercise Catalog Data

Bloom stores its global exercise library in the `exercises` table. The curated seed supplies the MVP catalog; free-exercise-db metadata can enrich matching system exercises with source muscle groups, instructions, and images.

## Run Order

1. Apply the base schema in `docs/db/schema.sql`.
2. Apply the Supabase migration `supabase/migrations/20260417000002_exercise_catalog_fields.sql`.
3. Apply the Supabase migration `supabase/migrations/20260417000003_exercises_read_policy.sql`.
4. Apply the Supabase migration `supabase/migrations/20260418000000_exercise_catalog_field_transition.sql`.
5. Run the curated starter seed in `docs/db/seed-exercises.sql` when using the manual schema workflow.
6. Supabase applies `supabase/migrations/20261121170100_bloom_exercise_catalog_metadata.sql` to enrich matching system rows. In a manual workflow, run `docs/db/enrich-exercises-free-exercise-db.sql` after the seed instead; both files contain the same source metadata update.

## Generate Metadata Enrichment

Use a local copy of the free-exercise-db combined JSON:

```bash
node scripts/import-free-exercise-db.mjs path/to/exercises.json
```

Or explicitly allow the script to download the source JSON:

```bash
node scripts/import-free-exercise-db.mjs --download
```

The generated SQL updates matching system exercises only; it does not insert catalog rows. It writes the source primary muscle into `muscle_group`, all source primary and secondary muscles into `muscle_groups`, source instructions only when the app row has none, and the first valid source image only when the app row has no media link. Exercises without a valid source image leave media unchanged. It never assigns `measurement_type`, difficulty, or other fields the source does not provide. This preserves each exercise's existing measurement behavior and avoids inventing classifications.

The curated starter seed links media only for exact exercise-name matches. Use the generated enrichment SQL to refresh per-exercise source images and metadata for matching system exercises.

## Verify The App Can See Rows

After running the seed, check the actual row count:

```sql
SELECT count(*) FROM public.exercises;
```

If this count is greater than zero but the Bloom app still logs `loaded 0 exercise(s)`, run `supabase/migrations/20260417000003_exercises_read_policy.sql` in the Supabase SQL Editor. That policy allows the app's `anon` and `authenticated` roles to read the global exercise catalog.

## Data Source

The importer expects the combined JSON from:

```text
https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json
```

The repository's data and code are marked with the [Unlicense](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE.md), and its [README documents the raw image URL format](https://github.com/yuhonas/free-exercise-db/blob/main/README.md). The repository maintainer has said the images' origin and royalty-free status are unknown ([issue #2](https://github.com/yuhonas/free-exercise-db/issues/2)); review image rights before distributing them. The importer links to the first image listed for an exercise and does not copy files into Bloom Storage. The source does not define Bloom's `measurement_type`, so the importer leaves that field untouched.
