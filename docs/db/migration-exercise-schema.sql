-- Migration: Extend exercises table for Nashaat full feature set
-- Run after the base schema.sql

-- Add difficulty_level column
ALTER TABLE exercises
ADD COLUMN IF NOT EXISTS difficulty_level TEXT CHECK (difficulty_level IN ('easy', 'medium', 'hard')) DEFAULT 'medium';

-- Add muscle_groups array column (replaces/extends the existing muscle_group text column)
ALTER TABLE exercises
ADD COLUMN IF NOT EXISTS muscle_groups TEXT[] DEFAULT '{}';

-- Add steps column for instructional steps
ALTER TABLE exercises
ADD COLUMN IF NOT EXISTS steps TEXT[] DEFAULT '{}';

-- Backfill muscle_groups from existing muscle_group column where present
UPDATE exercises
SET muscle_groups = ARRAY[muscle_group]
WHERE muscle_group IS NOT NULL AND array_length(muscle_groups, 1) IS NULL;

-- Add index for muscle_groups array filtering
CREATE INDEX IF NOT EXISTS idx_exercises_muscle_groups ON exercises USING GIN (muscle_groups);

-- Add index for difficulty_level filtering
CREATE INDEX IF NOT EXISTS idx_exercises_difficulty ON exercises (difficulty_level);

-- Update comments
COMMENT ON COLUMN exercises.difficulty_level IS 'Easy, Medium, or Hard. Drives UI filtering.';
COMMENT ON COLUMN exercises.muscle_groups IS 'Array of targeted muscle groups (e.g., {Chest, Triceps}).';
COMMENT ON COLUMN exercises.steps IS 'Step-by-step instructions as an ordered text array.';
