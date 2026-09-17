-- Nashat Task 3: award workout points once
-- Prerequisites:
--   * public.profiles.points_total exists
--   * public.point_awards exists
--   * public.workout_logs exists
-- Rule used here: a qualifying workout has duration_minutes >= 10.

CREATE OR REPLACE FUNCTION public.award_workout_points(
    p_workout_log_id UUID
)
RETURNS TABLE (
    points_earned INTEGER,
    points_total INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_duration_minutes INTEGER;
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

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workout not found or access denied.';
    END IF;

    -- A workout shorter than 10 minutes does not earn points.
    IF v_duration_minutes < 10 THEN
        SELECT p.points_total
        INTO v_total_points
        FROM public.profiles p
        WHERE p.id = v_user_id;

        RETURN QUERY SELECT 0, v_total_points;
        RETURN;
    END IF;

    -- Insert the award. The unique constraint on point_awards prevents
    -- the same workout-completion award from being inserted twice.
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
        100,
        'workout_completion',
        'Completed a qualifying workout',
        'workout',
        p_workout_log_id,
        p_workout_log_id
    )
    ON CONFLICT (user_id, source_type, source_event_id, reason_type)
    DO NOTHING
    RETURNING points INTO v_awarded_points;

    -- First processing: increase the total only if a new award was inserted.
    IF v_awarded_points IS NOT NULL THEN
        UPDATE public.profiles
        SET points_total = points_total + v_awarded_points,
            updated_at = NOW()
        WHERE id = v_user_id
        RETURNING points_total INTO v_total_points;

        RETURN QUERY SELECT v_awarded_points, v_total_points;
        RETURN;
    END IF;

    -- Retry: return the original award without adding points again.
    SELECT pa.points
    INTO v_awarded_points
    FROM public.point_awards pa
    WHERE pa.user_id = v_user_id
      AND pa.source_type = 'workout'
      AND pa.source_event_id = p_workout_log_id
      AND pa.reason_type = 'workout_completion';

    SELECT p.points_total
    INTO v_total_points
    FROM public.profiles p
    WHERE p.id = v_user_id;

    RETURN QUERY SELECT COALESCE(v_awarded_points, 0), v_total_points;
END;
$$;

REVOKE ALL ON FUNCTION public.award_workout_points(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.award_workout_points(UUID) TO authenticated;
