


CREATE UNIQUE INDEX IF NOT EXISTS uq_point_awards_streak_milestone
ON public.point_awards (
    user_id,
    source_type,
    reason_type
)
WHERE reason_type = 'streak_bonus'
  AND source_type LIKE 'streak_milestone_%';


CREATE OR REPLACE FUNCTION public.award_streak_milestone_points(
    p_workout_log_id UUID
)
RETURNS TABLE (
    streak_days INTEGER,
    bonus_points INTEGER,
    points_total INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();

    v_streak INTEGER;
    v_last_workout_date DATE;
    v_logged_at TIMESTAMPTZ;
    v_timezone TEXT;

    v_workout_local_date DATE;

    v_bonus INTEGER := 0;
    v_awarded INTEGER;
    v_total INTEGER;

    v_source_type TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    -- Verify the workout belongs to this user and load the
    -- already-updated streak state.
    SELECT
        p.streak_count,
        p.last_workout_date,
        COALESCE(NULLIF(p.timezone, ''), 'UTC'),
        p.points_total,
        wl.logged_at
    INTO
        v_streak,
        v_last_workout_date,
        v_timezone,
        v_total,
        v_logged_at
    FROM public.workout_logs wl
    JOIN public.profiles p
      ON p.id = wl.user_id
    WHERE wl.id = p_workout_log_id
      AND wl.user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workout not found or access denied.';
    END IF;

    -- Convert the workout timestamp into the user's calendar day.
    v_workout_local_date :=
        (v_logged_at AT TIME ZONE v_timezone)::DATE;

    -- The streak RPC must have processed this workout first.
    IF v_last_workout_date IS DISTINCT FROM v_workout_local_date THEN
        RETURN QUERY
        SELECT v_streak, 0, v_total;
        RETURN;
    END IF;

    -- Our agreed milestone rewards.
    v_bonus :=
        CASE v_streak
            WHEN 3   THEN 25
            WHEN 7   THEN 50
            WHEN 14  THEN 100
            WHEN 30  THEN 200
            WHEN 60  THEN 300
            WHEN 100 THEN 500
            WHEN 180 THEN 750
            WHEN 365 THEN 1000
            ELSE 0
        END;

    -- Not a milestone.
    IF v_bonus = 0 THEN
        RETURN QUERY
        SELECT v_streak, 0, v_total;
        RETURN;
    END IF;

    v_source_type :=
        'streak_milestone_' || v_streak::TEXT;

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
        v_bonus,
        'streak_bonus',
        v_streak || '-day streak milestone',
        v_source_type,
        p_workout_log_id,
        p_workout_log_id
    )
    ON CONFLICT DO NOTHING
    RETURNING points
    INTO v_awarded;

    -- Only increase total if a NEW milestone award was inserted.
    IF v_awarded IS NOT NULL THEN
        UPDATE public.profiles
        SET
            points_total = points_total + v_awarded,
            updated_at = NOW()
        WHERE id = v_user_id
        RETURNING public.profiles.points_total
        INTO v_total;

        RETURN QUERY
        SELECT v_streak, v_awarded, v_total;

        RETURN;
    END IF;

    -- If this exact RPC is retried for the same workout,
    -- return the original result without adding points again.
    SELECT pa.points
    INTO v_awarded
    FROM public.point_awards pa
    WHERE pa.user_id = v_user_id
      AND pa.reason_type = 'streak_bonus'
      AND pa.source_type = v_source_type
      AND pa.source_event_id = p_workout_log_id;

    SELECT p.points_total
    INTO v_total
    FROM public.profiles p
    WHERE p.id = v_user_id;

    RETURN QUERY
    SELECT
        v_streak,
        COALESCE(v_awarded, 0),
        v_total;
END;
$$;


REVOKE ALL
ON FUNCTION public.award_streak_milestone_points(UUID)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.award_streak_milestone_points(UUID)
TO authenticated;