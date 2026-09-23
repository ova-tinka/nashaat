DROP FUNCTION IF EXISTS public.award_workout_points(UUID);

CREATE FUNCTION public.award_workout_points(
    p_workout_log_id UUID
)
RETURNS TABLE (
    points_earned INTEGER,
    points_total INTEGER,
    current_streak INTEGER,
    longest_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_workout_points INTEGER;
    v_user_id UUID := auth.uid();
    v_duration_minutes INTEGER;
    v_workout_logged_at TIMESTAMPTZ;
    v_timezone TEXT;

    v_last_workout_date DATE;
    v_old_streak INTEGER;
    v_old_longest_streak INTEGER;
    v_workout_date DATE;

    v_new_streak INTEGER;
    v_new_longest_streak INTEGER;

    v_awarded_points INTEGER;
    v_total_points INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in to receive workout points.';
    END IF;
      -- Verify that the workout exists and belongs to the signed-in user.
    SELECT duration_minutes
    INTO v_duration_minutes
    FROM public.workout_logs
    WHERE id = p_workout_log_id
      AND user_id = v_user_id;
    -- Verify that this workout belongs to the signed-in user.
    SELECT wl.logged_at
    INTO v_workout_logged_at
    FROM public.workout_logs AS wl
    WHERE wl.id = p_workout_log_id
      AND wl.user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workout not found or access denied.';
    END IF;

    -- Read and lock the profile while calculating the streak.
    SELECT
        p.timezone,
        p.last_workout_date,
        p.streak_count,
        p.longest_streak
    INTO
        v_timezone,
        v_last_workout_date,
        v_old_streak,
        v_old_longest_streak
    FROM public.profiles AS p
    WHERE p.id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found.';
    END IF;

    -- Use the user's saved timezone to determine the workout day.
    v_workout_date :=
        (v_workout_logged_at AT TIME ZONE COALESCE(v_timezone, 'UTC'))::date;
    -- A workout shorter than 10 minutes does not earn points.
    IF v_duration_minutes < 10 THEN
    SELECT
        p.points_total,
        p.streak_count,
        p.longest_streak
    INTO
        v_total_points,
        v_new_streak,
        v_new_longest_streak
    FROM public.profiles p
    WHERE p.id = v_user_id;

    RETURN QUERY
    SELECT
        0,
        v_total_points,
        v_new_streak,
        v_new_longest_streak;

    RETURN;
END IF;
    v_workout_points :=
    100
    + (
        FLOOR(
            LEAST(v_duration_minutes, 120) / 10.0
        )::INTEGER * 10
    );
    -- Award points once for this workout.
    INSERT INTO public.point_awards (
        user_id,
        points,
        reason_type,
        description,
        source_type,
        source_event_id,
        workout_log_id
    )
    VALUES (
        v_user_id,
        v_workout_points,
        'workout_completion',
        'Completed workout',
        'workout',
        p_workout_log_id,
        p_workout_log_id
    )
    ON CONFLICT (
        user_id,
        source_type,
        source_event_id,
        reason_type
    )
    DO NOTHING
    RETURNING points INTO v_awarded_points;

    -- Retry case: do not add points or change the streak again.
    IF v_awarded_points IS NULL THEN
        SELECT pa.points
        INTO v_awarded_points
        FROM public.point_awards AS pa
        WHERE pa.user_id = v_user_id
          AND pa.source_type = 'workout'
          AND pa.source_event_id = p_workout_log_id
          AND pa.reason_type = 'workout_completion';

        SELECT
            p.points_total,
            p.streak_count,
            p.longest_streak
        INTO
            v_total_points,
            v_new_streak,
            v_new_longest_streak
        FROM public.profiles AS p
        WHERE p.id = v_user_id;

        RETURN QUERY
        SELECT
            COALESCE(v_awarded_points, 0),
            v_total_points,
            v_new_streak,
            v_new_longest_streak;

        RETURN;
    END IF;

    -- Calculate the new streak.
    IF v_last_workout_date IS NULL THEN
        v_new_streak := 1;

    ELSIF v_last_workout_date = v_workout_date THEN
        -- Another workout on the same day: do not increase the streak.
        v_new_streak := v_old_streak;

    ELSIF v_last_workout_date = v_workout_date - 1 THEN
        -- Workout on the next day: continue the streak.
        v_new_streak := v_old_streak + 1;

    ELSIF v_last_workout_date < v_workout_date - 1 THEN
        -- One or more missed days: begin a new streak.
        v_new_streak := 1;

    ELSE
        -- Older workout submitted after a newer one: leave streak unchanged.
        v_new_streak := v_old_streak;
    END IF;

    v_new_longest_streak :=
        GREATEST(v_old_longest_streak, v_new_streak);

    -- Update profile points and streak values.
    UPDATE public.profiles AS p
    SET
        points_total = p.points_total + v_awarded_points,
        streak_count = v_new_streak,
        longest_streak = v_new_longest_streak,
        last_workout_date = GREATEST(
            COALESCE(p.last_workout_date, v_workout_date),
            v_workout_date
        ),
        updated_at = NOW()
    WHERE p.id = v_user_id
    RETURNING
        p.points_total,
        p.streak_count,
        p.longest_streak
    INTO
        v_total_points,
        v_new_streak,
        v_new_longest_streak;

    RETURN QUERY
    SELECT
        v_awarded_points,
        v_total_points,
        v_new_streak,
        v_new_longest_streak;
END;
$$;

REVOKE ALL
ON FUNCTION public.award_workout_points(UUID)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.award_workout_points(UUID)
TO authenticated;
