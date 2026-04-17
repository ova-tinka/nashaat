# Exercise Catalog Data

Nashaat stores the global exercise library in the `exercises` table. The curated seed is small enough for MVP development, while the generated free-exercise-db seed can be used when the app needs a larger real catalog.

## Run Order

1. Apply the base schema in `docs/db/schema.sql`.
2. Apply the Supabase migration `supabase/migrations/20260417000002_exercise_catalog_fields.sql`.
3. Run the curated starter seed in `docs/db/seed-exercises.sql`.
4. Optionally run the generated large seed in `docs/db/seed-exercises-free-exercise-db.sql`.

## Generate The Large Seed

Use a local copy of the free-exercise-db combined JSON:

```bash
node scripts/import-free-exercise-db.mjs path/to/exercises.json
```

Or explicitly allow the script to download the source JSON:

```bash
node scripts/import-free-exercise-db.mjs --download
```

The generated SQL inserts global exercises with `is_system = true`, leaves `media_id = NULL`, and uses `ON CONFLICT (name) DO UPDATE` so it can be rerun safely.

## Data Source

The importer expects the combined JSON from:

```text
https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json
```

Media files are not imported in this pass. Exercise images or videos should be added later through the existing `media` table and Supabase Storage.
