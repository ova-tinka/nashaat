CREATE OR REPLACE FUNCTION public.recalculate_my_weekly_leaderboard_score()
RETURNS TABLE (
    weekly_score INTEGER,
    workouts_count INTEGER,
    total_minutes INTEGER,
    workout_points INTEGER,
    duration_points INTEGER,
    streak_bonus INTEGER,
    week_start TIMESTAMPTZ,
    week_end TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_week_start TIMESTAMPTZ;
    v_week_end TIMESTAMPTZ;
    v_workouts_count INTEGER := 0;
    v_total_minutes INTEGER := 0;
    v_workout_points INTEGER := 0;
    v_duration_points INTEGER := 0;
    v_streak_bonus INTEGER := 0;
    v_current_streak INTEGER := 0;
    v_weekly_score INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    -- Current week starts Monday 00:00 UTC.
    v_week_start := date_trunc('week', NOW() AT TIME ZONE 'UTC')
        AT TIME ZONE 'UTC';
    v_week_end := v_week_start + INTERVAL '7 days';

    -- Workouts of at least 10 minutes qualify; credit at most 180 minutes each.
    SELECT COUNT(*)::INTEGER,
           COALESCE(SUM(LEAST(wl.duration_minutes, 180)), 0)::INTEGER
    INTO v_workouts_count, v_total_minutes
    FROM public.workout_logs wl
    WHERE wl.user_id = v_user_id
      AND wl.duration_minutes >= 10
      AND wl.logged_at >= v_week_start
      AND wl.logged_at < v_week_end;

    SELECT COALESCE(p.streak_count, 0)
    INTO v_current_streak
    FROM public.profiles p
    WHERE p.id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found.';
    END IF;

    v_workout_points := v_workouts_count * 10;
    v_duration_points := FLOOR(v_total_minutes / 10.0)::INTEGER;
    IF v_current_streak >= 7 THEN
        v_streak_bonus := 5;
    END IF;
    v_weekly_score := v_workout_points + v_duration_points + v_streak_bonus;

    UPDATE public.leaderboard_members lm
    SET weekly_score = v_weekly_score
    WHERE lm.user_id = v_user_id;

    RETURN QUERY SELECT v_weekly_score, v_workouts_count, v_total_minutes,
                        v_workout_points, v_duration_points, v_streak_bonus,
                        v_week_start, v_week_end;
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_my_weekly_leaderboard_score()
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.recalculate_my_weekly_leaderboard_score()
TO authenticated;
