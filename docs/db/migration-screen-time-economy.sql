-- Migration: Screen Time Economy
-- Adds phone-usage setup fields to profiles and session_size to workout_plans.
--
-- Run this in the Supabase SQL editor.

-- profiles: new economy columns
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS daily_phone_hours        INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_small_sessions    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_big_sessions      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_weekly_reset_at     TIMESTAMPTZ;

-- workout_plans: session size (small earns 1× reward, big earns 2×)
ALTER TABLE workout_plans
  ADD COLUMN IF NOT EXISTS session_size TEXT NOT NULL DEFAULT 'small'
    CHECK (session_size IN ('small', 'big'));
