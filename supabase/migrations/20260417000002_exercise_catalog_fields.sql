-- Extend exercises table for the full Nashaat exercise catalog.

ALTER TABLE exercises
ADD COLUMN IF NOT EXISTS difficulty_level TEXT
CHECK (difficulty_level IN ('easy', 'medium', 'hard'))
DEFAULT 'medium';

ALTER TABLE exercises
ADD COLUMN IF NOT EXISTS muscle_groups TEXT[] DEFAULT '{}';

ALTER TABLE exercises
ADD COLUMN IF NOT EXISTS steps TEXT[] DEFAULT '{}';

UPDATE exercises
SET muscle_groups = ARRAY[muscle_group]
WHERE muscle_group IS NOT NULL
  AND array_length(muscle_groups, 1) IS NULL;

CREATE INDEX IF NOT EXISTS idx_exercises_muscle_groups
ON exercises USING GIN (muscle_groups);

CREATE INDEX IF NOT EXISTS idx_exercises_difficulty
ON exercises (difficulty_level);

COMMENT ON COLUMN exercises.difficulty_level IS 'Easy, medium, or hard. Drives UI filtering.';
COMMENT ON COLUMN exercises.muscle_groups IS 'Array of targeted muscle groups, for example {Chest, Triceps}.';
COMMENT ON COLUMN exercises.steps IS 'Step-by-step instructions as an ordered text array.';
