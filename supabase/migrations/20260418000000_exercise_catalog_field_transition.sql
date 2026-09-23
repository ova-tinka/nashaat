-- Transition the exercise catalog to the field names used by the workout app.
--
-- This is intentionally additive. The legacy steps column remains available
-- for older clients and imports, while media_id remains the canonical
-- Supabase Storage relationship.

ALTER TABLE public.exercises
  ADD COLUMN IF NOT EXISTS instructions TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS media_link TEXT;

-- Preserve existing step-by-step instructions when the legacy column exists.
-- Some hosted databases already have the new fields but never had `steps`.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'exercises'
      AND column_name = 'steps'
  ) THEN
    EXECUTE $migration$
      UPDATE public.exercises AS exercise
      SET instructions = COALESCE(exercise.steps, ARRAY[]::TEXT[])
      WHERE COALESCE(cardinality(exercise.instructions), 0) = 0
        AND COALESCE(cardinality(exercise.steps), 0) > 0
    $migration$;
  END IF;
END
$$;

COMMENT ON COLUMN public.exercises.instructions IS
  'Step-by-step instructions as an ordered text array.';

COMMENT ON COLUMN public.exercises.media_link IS
  'Absolute external media URL. Supabase Storage media remains referenced by media_id.';
