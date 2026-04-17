-- Screen Time Economy: new profile fields + session_size on workout_plans

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS daily_phone_hours        INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_small_sessions    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS weekly_big_sessions      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_weekly_reset_at     TIMESTAMPTZ;

ALTER TABLE workout_plans
  ADD COLUMN IF NOT EXISTS session_size TEXT NOT NULL DEFAULT 'small'
    CHECK (session_size IN ('small', 'big'));
