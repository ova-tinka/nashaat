BEGIN;

-- A workout session is opened before the workout starts. Its plan data is
-- snapshotted so later client edits cannot change the completion rules.
CREATE TABLE IF NOT EXISTS public.workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    workout_plan_id UUID REFERENCES public.workout_plans(id) ON DELETE SET NULL,
    plan_exercises JSONB NOT NULL DEFAULT '[]'::jsonb,
    session_size TEXT NOT NULL DEFAULT 'small'
        CHECK (session_size IN ('small', 'big')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    completed_at TIMESTAMPTZ,
    workout_log_id UUID REFERENCES public.workout_logs(id) ON DELETE SET NULL,
    points_earned INTEGER NOT NULL DEFAULT 0,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    weekly_score INTEGER NOT NULL DEFAULT 0,
    newly_unlocked_achievements JSONB NOT NULL DEFAULT '[]'::jsonb
);

ALTER TABLE public.workout_sessions
    ADD COLUMN IF NOT EXISTS points_earned INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS current_streak INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS longest_streak INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS weekly_score INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS newly_unlocked_achievements JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.workout_logs
    ADD COLUMN IF NOT EXISTS workout_session_id UUID;

-- This setting is already consumed by the Flutter blocking flow; keep it in
-- the database before narrowing profile update privileges.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS strict_blocking_only BOOLEAN NOT NULL DEFAULT TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS workout_logs_session_unique
    ON public.workout_logs(workout_session_id)
    WHERE workout_session_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS workout_sessions_one_open_per_user
    ON public.workout_sessions(user_id)
    WHERE completed_at IS NULL;

ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.workout_sessions FROM PUBLIC, anon, authenticated;

-- The client may read its own history, but cannot create or mutate a log.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.workout_logs
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.workout_logs TO authenticated;
DROP POLICY IF EXISTS workout_logs_own_rows ON public.workout_logs;
CREATE POLICY workout_logs_select_own
ON public.workout_logs
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- The ledger is append-only from the application perspective. Its writes are
-- performed by SECURITY DEFINER functions below.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.screen_time_transactions
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.screen_time_transactions TO authenticated;
DROP POLICY IF EXISTS screen_time_transactions_own_rows
ON public.screen_time_transactions;
CREATE POLICY screen_time_transactions_select_own
ON public.screen_time_transactions
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- weekly_score is derived data and must not be client-controlled.
REVOKE UPDATE ON TABLE public.leaderboard_members FROM authenticated;
GRANT SELECT, INSERT ON TABLE public.leaderboard_members TO authenticated;
DROP POLICY IF EXISTS leaderboard_members_update_self
ON public.leaderboard_members;

-- Restrict profile updates to user settings. Reward, balance, streak, and
-- reset columns are writable only by trusted server-side functions.
REVOKE UPDATE ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT UPDATE (
    username,
    first_name,
    last_name,
    weekly_exercise_target_minutes,
    timezone,
    fcm_token,
    avatar_media_id,
    status,
    daily_phone_hours,
    weekly_small_sessions,
    weekly_big_sessions,
    strict_blocking_only,
    updated_at
) ON TABLE public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.start_workout_session(
    p_workout_plan_id UUID DEFAULT NULL
)
RETURNS TABLE (
    session_id UUID,
    started_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_now TIMESTAMPTZ := clock_timestamp();
    v_session public.workout_sessions%ROWTYPE;
    v_plan_exercises JSONB := '[]'::jsonb;
    v_session_size TEXT := 'small';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    -- An abandoned session cannot block a new workout forever.
    UPDATE public.workout_sessions AS ws
    SET completed_at = v_now
    WHERE ws.user_id = v_user_id
      AND ws.completed_at IS NULL
      AND ws.started_at < v_now - INTERVAL '24 hours';

    -- Starting twice during a retry returns the same server session.
    SELECT *
    INTO v_session
    FROM public.workout_sessions
    WHERE user_id = v_user_id
      AND completed_at IS NULL
    ORDER BY started_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        RETURN QUERY SELECT v_session.id, v_session.started_at;
        RETURN;
    END IF;

    IF p_workout_plan_id IS NOT NULL THEN
        SELECT wp.exercises, wp.session_size
        INTO v_plan_exercises, v_session_size
        FROM public.workout_plans AS wp
        WHERE wp.id = p_workout_plan_id
          AND wp.user_id = v_user_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Workout plan not found or access denied.';
        END IF;
    END IF;

    INSERT INTO public.workout_sessions (
        user_id,
        workout_plan_id,
        plan_exercises,
        session_size,
        started_at
    )
    VALUES (
        v_user_id,
        p_workout_plan_id,
        COALESCE(v_plan_exercises, '[]'::jsonb),
        COALESCE(v_session_size, 'small'),
        v_now
    )
    RETURNING public.workout_sessions.id,
              public.workout_sessions.started_at
    INTO v_session.id, v_session.started_at;

    RETURN QUERY SELECT v_session.id, v_session.started_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.evaluate_user_achievements()
RETURNS TABLE (
    unlocked_achievement_id UUID,
    achievement_code TEXT,
    achievement_name TEXT,
    unlocked_reward_type TEXT,
    unlocked_reward_amount INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile public.profiles%ROWTYPE;
    v_achievement RECORD;
    v_existing RECORD;
    v_progress INTEGER;
    v_workout_count INTEGER;
    v_current_streak INTEGER;
    v_joined_leaderboard INTEGER;
    v_local_today DATE;
    v_newly_unlocked BOOLEAN;
    v_transaction_id UUID;
    v_awarded_points INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    SELECT * INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found.';
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_workout_count
    FROM public.workout_logs
    WHERE user_id = v_user_id
      AND duration_minutes >= 5;

    v_local_today := (
        clock_timestamp() AT TIME ZONE COALESCE(NULLIF(v_profile.timezone, ''), 'UTC')
    )::date;
    v_current_streak := CASE
        WHEN v_profile.last_workout_date IS NULL
          OR v_profile.last_workout_date < v_local_today - 1
            THEN 0
        ELSE COALESCE(v_profile.streak_count, 0)
    END;

    SELECT CASE WHEN EXISTS (
        SELECT 1
        FROM public.leaderboard_members
        WHERE user_id = v_user_id
    ) THEN 1 ELSE 0 END
    INTO v_joined_leaderboard;

    FOR v_achievement IN
        SELECT *
        FROM public.achievement_definitions
        WHERE is_active = TRUE
        ORDER BY created_at
    LOOP
        v_progress := CASE v_achievement.criteria_type
            WHEN 'qualifying_workout_count' THEN v_workout_count
            WHEN 'current_streak' THEN v_current_streak
            WHEN 'leaderboard_join' THEN v_joined_leaderboard
            WHEN 'weekly_leaderboard_win' THEN 0
            ELSE 0
        END;
        v_progress := LEAST(v_progress, v_achievement.target_value);
        v_newly_unlocked := FALSE;

        SELECT ua.id, ua.progress, ua.unlocked_at
        INTO v_existing
        FROM public.user_achievements AS ua
        WHERE ua.user_id = v_user_id
          AND ua.achievement_id = v_achievement.id
        FOR UPDATE;

        IF NOT FOUND THEN
            INSERT INTO public.user_achievements (
                user_id, achievement_id, progress, unlocked_at
            )
            VALUES (
                v_user_id,
                v_achievement.id,
                v_progress,
                CASE WHEN v_progress >= v_achievement.target_value
                     THEN clock_timestamp() ELSE NULL END
            );
            v_newly_unlocked := v_progress >= v_achievement.target_value;
        ELSIF v_existing.unlocked_at IS NULL THEN
            IF v_progress >= v_achievement.target_value THEN
                UPDATE public.user_achievements
                SET progress = v_achievement.target_value,
                    unlocked_at = clock_timestamp(),
                    updated_at = clock_timestamp()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;
                v_newly_unlocked := TRUE;
            ELSE
                UPDATE public.user_achievements
                SET progress = v_progress, updated_at = clock_timestamp()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;
            END IF;
        END IF;

        IF v_newly_unlocked THEN
            IF v_achievement.reward_type = 'points'
               AND v_achievement.reward_amount > 0 THEN
                v_awarded_points := NULL;
                INSERT INTO public.point_awards (
                    user_id, points, reason_type, description,
                    source_type, source_event_id
                )
                VALUES (
                    v_user_id,
                    v_achievement.reward_amount,
                    'achievement_bonus',
                    'Achievement unlocked: ' || v_achievement.name,
                    'achievement',
                    v_achievement.id
                )
                ON CONFLICT (
                    user_id, source_type, source_event_id, reason_type
                ) DO NOTHING
                RETURNING points INTO v_awarded_points;

                IF v_awarded_points IS NOT NULL THEN
                    UPDATE public.profiles
                    SET points_total = points_total + v_awarded_points,
                        updated_at = clock_timestamp()
                    WHERE id = v_user_id;
                END IF;

                UPDATE public.user_achievements
                SET reward_granted_at = clock_timestamp(),
                    updated_at = clock_timestamp()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;
            ELSIF v_achievement.reward_type = 'screen_time'
                  AND v_achievement.reward_amount > 0 THEN
                INSERT INTO public.screen_time_transactions (
                    user_id, amount_minutes, transaction_type,
                    description, reference_id
                )
                VALUES (
                    v_user_id,
                    v_achievement.reward_amount,
                    'earned',
                    'Achievement unlocked: ' || v_achievement.name,
                    v_achievement.id
                )
                RETURNING id INTO v_transaction_id;

                UPDATE public.profiles
                SET screen_time_balance_minutes =
                        screen_time_balance_minutes + v_achievement.reward_amount,
                    updated_at = clock_timestamp()
                WHERE id = v_user_id;

                UPDATE public.user_achievements
                SET reward_granted_at = clock_timestamp(),
                    reward_transaction_id = v_transaction_id,
                    updated_at = clock_timestamp()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;
            ELSE
                UPDATE public.user_achievements
                SET reward_granted_at = clock_timestamp(),
                    updated_at = clock_timestamp()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;
            END IF;

            unlocked_achievement_id := v_achievement.id;
            achievement_code := v_achievement.code;
            achievement_name := v_achievement.name;
            unlocked_reward_type := v_achievement.reward_type::text;
            unlocked_reward_amount := v_achievement.reward_amount;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

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
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_week_start TIMESTAMPTZ;
    v_week_end TIMESTAMPTZ;
    v_workouts_count INTEGER;
    v_total_minutes INTEGER;
    v_workout_points INTEGER;
    v_duration_points INTEGER;
    v_streak_bonus INTEGER;
    v_current_streak INTEGER;
    v_weekly_score INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    v_week_start := date_trunc('week', clock_timestamp() AT TIME ZONE 'UTC')
        AT TIME ZONE 'UTC';
    v_week_end := v_week_start + INTERVAL '7 days';

    SELECT COUNT(*)::INTEGER,
           COALESCE(SUM(LEAST(wl.duration_minutes, 180)), 0)::INTEGER
    INTO v_workouts_count, v_total_minutes
    FROM public.workout_logs AS wl
    WHERE wl.user_id = v_user_id
      AND wl.duration_minutes >= 5
      AND wl.logged_at >= v_week_start
      AND wl.logged_at < v_week_end;

    SELECT CASE
        WHEN p.last_workout_date IS NULL
          OR p.last_workout_date < (
              clock_timestamp() AT TIME ZONE COALESCE(NULLIF(p.timezone, ''), 'UTC')
          )::date - 1
            THEN 0
        ELSE COALESCE(p.streak_count, 0)
    END
    INTO v_current_streak
    FROM public.profiles AS p
    WHERE p.id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found.';
    END IF;

    v_workout_points := v_workouts_count * 10;
    v_duration_points := FLOOR(v_total_minutes / 10.0)::INTEGER;
    v_streak_bonus := CASE WHEN v_current_streak >= 7 THEN 5 ELSE 0 END;
    v_weekly_score := v_workout_points + v_duration_points + v_streak_bonus;

    UPDATE public.leaderboard_members
    SET weekly_score = v_weekly_score
    WHERE user_id = v_user_id;

    RETURN QUERY SELECT v_weekly_score, v_workouts_count, v_total_minutes,
        v_workout_points, v_duration_points, v_streak_bonus,
        v_week_start, v_week_end;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_workout_session(
    p_session_id UUID,
    p_completed_exercises JSONB,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    workout_log_id UUID,
    earned_screen_time_minutes INTEGER,
    points_earned INTEGER,
    points_total INTEGER,
    current_streak INTEGER,
    longest_streak INTEGER,
    weekly_score INTEGER,
    newly_unlocked_achievements JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_now TIMESTAMPTZ := clock_timestamp();
    v_session public.workout_sessions%ROWTYPE;
    v_profile public.profiles%ROWTYPE;
    v_log_id UUID;
    v_duration_minutes INTEGER;
    v_workout_date DATE;
    v_planned_total INTEGER := 0;
    v_completed_total INTEGER := 0;
    v_weekly_phone_minutes INTEGER := 0;
    v_free_minutes INTEGER := 0;
    v_total_units INTEGER := 0;
    v_small_reward INTEGER := 0;
    v_earned_minutes INTEGER := 0;
    v_points_before INTEGER := 0;
    v_workout_points INTEGER := 0;
    v_awarded_points INTEGER;
    v_milestone_awarded INTEGER;
    v_old_streak INTEGER := 0;
    v_new_streak INTEGER := 0;
    v_new_longest_streak INTEGER := 0;
    v_weekly_score INTEGER := 0;
    v_unlocked JSONB := '[]'::jsonb;
    v_session_size TEXT;
    v_timezone TEXT;
    v_final_points_total INTEGER := 0;
    v_final_current_streak INTEGER := 0;
    v_final_longest_streak INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;
    IF jsonb_typeof(p_completed_exercises) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Completed exercises must be a JSON array.';
    END IF;

    SELECT *
    INTO v_session
    FROM public.workout_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workout session not found or access denied.';
    END IF;

    -- Completion is retry-safe. A repeated request returns the original log
    -- instead of creating another reward or ledger entry.
    IF v_session.completed_at IS NOT NULL THEN
        SELECT wl.id,
               wl.earned_screen_time_minutes,
               COALESCE((
                   SELECT SUM(pa.points) FILTER (
                       WHERE pa.reason_type IN ('workout_completion', 'streak_bonus')
                   )
                   FROM public.point_awards AS pa
                   WHERE pa.workout_log_id = wl.id
               ), 0)::INTEGER
        INTO v_log_id, v_earned_minutes, v_awarded_points
        FROM public.workout_logs AS wl
        WHERE wl.workout_session_id = v_session.id
           OR wl.id = v_session.workout_log_id
        ORDER BY wl.logged_at DESC
        LIMIT 1;

        IF v_log_id IS NULL THEN
            RAISE EXCEPTION 'Completed workout session has no log.';
        END IF;

        SELECT p.points_total, p.streak_count, p.longest_streak
        INTO points_total, current_streak, longest_streak
        FROM public.profiles AS p
        WHERE p.id = auth.uid();

        workout_log_id := v_log_id;
        earned_screen_time_minutes := v_earned_minutes;
        points_earned := v_session.points_earned;
        current_streak := v_session.current_streak;
        longest_streak := v_session.longest_streak;
        weekly_score := v_session.weekly_score;
        newly_unlocked_achievements := v_session.newly_unlocked_achievements;
        RETURN NEXT;
        RETURN;
    END IF;

    v_duration_minutes := CEIL(
        EXTRACT(EPOCH FROM (v_now - v_session.started_at)) / 60.0
    )::INTEGER;
    IF v_duration_minutes < 5 THEN
        RAISE EXCEPTION 'A workout must last at least 5 minutes.';
    END IF;

    -- Validate completion against the server-side plan snapshot. Values are
    -- grouped by exercise ID before capping, so duplicate client entries cannot
    -- inflate the completed-set count.
    SELECT COALESCE(SUM(
        GREATEST(COALESCE(NULLIF(item->>'sets', '')::INTEGER, 0), 0)
    ), 0)::INTEGER
    INTO v_planned_total
    FROM jsonb_array_elements(v_session.plan_exercises) AS entries(item);

    WITH completed AS (
        SELECT item->>'exercise_id' AS exercise_id,
               SUM(GREATEST(
                   COALESCE(NULLIF(item->>'sets_completed', '')::INTEGER, 0), 0
               ))::INTEGER AS sets_completed
        FROM jsonb_array_elements(p_completed_exercises) AS entries(item)
        GROUP BY item->>'exercise_id'
    ), planned AS (
        SELECT item->>'exercise_id' AS exercise_id,
               SUM(GREATEST(
                   COALESCE(NULLIF(item->>'sets', '')::INTEGER, 0), 0
               ))::INTEGER AS sets
        FROM jsonb_array_elements(v_session.plan_exercises) AS entries(item)
        GROUP BY item->>'exercise_id'
    )
    SELECT COALESCE(SUM(LEAST(completed.sets_completed, planned.sets)), 0)::INTEGER
    INTO v_completed_total
    FROM completed
    JOIN planned USING (exercise_id);

    IF v_planned_total > 0 AND v_completed_total * 2 < v_planned_total THEN
        RAISE EXCEPTION 'Complete at least 50%% of the workout plan.';
    END IF;

    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found.';
    END IF;

    v_timezone := COALESCE(NULLIF(v_profile.timezone, ''), 'UTC');
    v_workout_date := (v_now AT TIME ZONE v_timezone)::date;
    v_old_streak := COALESCE(v_profile.streak_count, 0);
    v_points_before := COALESCE(v_profile.points_total, 0);
    v_session_size := COALESCE(v_session.session_size, 'small');

    v_weekly_phone_minutes := COALESCE(v_profile.daily_phone_hours, 0) * 7 * 60;
    v_free_minutes := FLOOR(v_weekly_phone_minutes * 0.20)::INTEGER;
    v_total_units := COALESCE(v_profile.weekly_small_sessions, 0)
        + (COALESCE(v_profile.weekly_big_sessions, 0) * 2);
    IF v_total_units > 0 THEN
        v_small_reward := FLOOR(
            (v_weekly_phone_minutes - v_free_minutes)::NUMERIC / v_total_units
        )::INTEGER;
    END IF;
    v_earned_minutes := CASE
        WHEN v_session_size = 'big' THEN v_small_reward * 2
        ELSE v_small_reward
    END;

    INSERT INTO public.workout_logs (
        user_id,
        workout_plan_id,
        workout_session_id,
        duration_minutes,
        earned_screen_time_minutes,
        completed_exercises,
        notes,
        logged_at
    )
    VALUES (
        v_user_id,
        v_session.workout_plan_id,
        v_session.id,
        v_duration_minutes,
        v_earned_minutes,
        p_completed_exercises,
        p_notes,
        v_now
    )
    RETURNING id INTO v_log_id;

    UPDATE public.workout_sessions
    SET completed_at = v_now, workout_log_id = v_log_id
    WHERE id = v_session.id;

    -- Base workout points and streak changes are server-derived and idempotent.
    v_workout_points := 100 + FLOOR(LEAST(v_duration_minutes, 120) / 10.0)::INTEGER * 10;
    INSERT INTO public.point_awards (
        user_id, points, reason_type, description,
        source_type, source_event_id, workout_log_id
    )
    VALUES (
        v_user_id,
        v_workout_points,
        'workout_completion',
        'Completed workout',
        'workout',
        v_log_id,
        v_log_id
    )
    ON CONFLICT (user_id, source_type, source_event_id, reason_type)
    DO NOTHING
    RETURNING points INTO v_awarded_points;
    v_awarded_points := COALESCE(v_awarded_points, 0);

    IF v_profile.last_workout_date IS NULL THEN
        v_new_streak := 1;
    ELSIF v_profile.last_workout_date = v_workout_date THEN
        v_new_streak := v_old_streak;
    ELSIF v_profile.last_workout_date = v_workout_date - 1 THEN
        v_new_streak := v_old_streak + 1;
    ELSIF v_profile.last_workout_date < v_workout_date - 1 THEN
        v_new_streak := 1;
    ELSE
        v_new_streak := v_old_streak;
    END IF;
    v_new_longest_streak := GREATEST(
        COALESCE(v_profile.longest_streak, 0), v_new_streak
    );

    UPDATE public.profiles AS p
    SET points_total = p.points_total + v_awarded_points,
        streak_count = v_new_streak,
        longest_streak = v_new_longest_streak,
        last_workout_date = GREATEST(
            COALESCE(p.last_workout_date, v_workout_date), v_workout_date
        ),
        updated_at = v_now
    WHERE p.id = v_user_id;

    v_milestone_awarded := 0;
    IF v_new_streak IN (3, 7, 14, 30, 60, 100, 180, 365) THEN
        INSERT INTO public.point_awards (
            user_id, points, reason_type, description,
            source_type, source_event_id, workout_log_id
        )
        VALUES (
            v_user_id,
            CASE v_new_streak
                WHEN 3 THEN 25 WHEN 7 THEN 50 WHEN 14 THEN 100
                WHEN 30 THEN 200 WHEN 60 THEN 300 WHEN 100 THEN 500
                WHEN 180 THEN 750 WHEN 365 THEN 1000
            END,
            'streak_bonus',
            v_new_streak || '-day streak milestone',
            'streak_milestone_' || v_new_streak::TEXT,
            v_log_id,
            v_log_id
        )
        ON CONFLICT DO NOTHING
        RETURNING points INTO v_milestone_awarded;
        IF v_milestone_awarded IS NOT NULL THEN
            UPDATE public.profiles AS p
            SET points_total = p.points_total + v_milestone_awarded,
                updated_at = v_now
            WHERE p.id = v_user_id;
        END IF;
    END IF;

    IF v_earned_minutes > 0 THEN
        INSERT INTO public.screen_time_transactions (
            user_id, amount_minutes, transaction_type,
            description, reference_id
        )
        VALUES (
            v_user_id,
            v_earned_minutes,
            'earned',
            'Completed workout',
            v_log_id
        );
        UPDATE public.profiles
        SET screen_time_balance_minutes =
                screen_time_balance_minutes + v_earned_minutes,
            updated_at = v_now
        WHERE id = v_user_id;
    END IF;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', unlocked_achievement_id,
        'code', achievement_code,
        'name', achievement_name,
        'reward_type', unlocked_reward_type,
        'reward_amount', unlocked_reward_amount
    )), '[]'::jsonb)
    INTO v_unlocked
    FROM public.evaluate_user_achievements();

    SELECT r.weekly_score
    INTO v_weekly_score
    FROM public.recalculate_my_weekly_leaderboard_score() AS r
    LIMIT 1;

    SELECT p.points_total, p.streak_count, p.longest_streak
    INTO v_final_points_total, v_final_current_streak, v_final_longest_streak
    FROM public.profiles AS p
    WHERE p.id = v_user_id;

    UPDATE public.workout_sessions AS ws
    SET points_earned = v_final_points_total - v_points_before,
        current_streak = v_final_current_streak,
        longest_streak = v_final_longest_streak,
        weekly_score = COALESCE(v_weekly_score, 0),
        newly_unlocked_achievements = v_unlocked
    WHERE ws.id = v_session.id;

    workout_log_id := v_log_id;
    earned_screen_time_minutes := v_earned_minutes;
    points_earned := v_final_points_total - v_points_before;
    points_total := v_final_points_total;
    current_streak := v_final_current_streak;
    longest_streak := v_final_longest_streak;
    weekly_score := COALESCE(v_weekly_score, 0);
    newly_unlocked_achievements := v_unlocked;
    RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.credit_weekly_free_screen_time()
RETURNS TABLE (balance_minutes INTEGER, minutes_changed INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile public.profiles%ROWTYPE;
    v_timezone TEXT;
    v_current_week DATE;
    v_last_week DATE;
    v_free_minutes INTEGER;
    v_old_balance INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    SELECT * INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found.'; END IF;

    v_timezone := COALESCE(NULLIF(v_profile.timezone, ''), 'UTC');
    v_current_week := date_trunc(
        'week', clock_timestamp() AT TIME ZONE v_timezone
    )::date;
    v_last_week := CASE WHEN v_profile.last_weekly_reset_at IS NULL THEN NULL
        ELSE date_trunc(
            'week', v_profile.last_weekly_reset_at AT TIME ZONE v_timezone
        )::date
    END;
    v_old_balance := COALESCE(v_profile.screen_time_balance_minutes, 0);

    IF v_last_week IS NOT NULL AND v_last_week >= v_current_week THEN
        RETURN QUERY SELECT v_old_balance, 0;
        RETURN;
    END IF;

    v_free_minutes := FLOOR(
        COALESCE(v_profile.daily_phone_hours, 0) * 7 * 60 * 0.20
    )::INTEGER;

    UPDATE public.profiles
    SET last_weekly_reset_at = clock_timestamp(),
        screen_time_balance_minutes = v_free_minutes,
        updated_at = clock_timestamp()
    WHERE id = v_user_id;

    IF v_free_minutes > 0 THEN
        INSERT INTO public.screen_time_transactions (
            user_id, amount_minutes, transaction_type, description
        )
        VALUES (
            v_user_id,
            v_free_minutes,
            'earned',
            'Weekly free screen time (20% baseline)'
        );
    END IF;

    RETURN QUERY SELECT v_free_minutes, v_free_minutes - v_old_balance;
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_screen_time_minute()
RETURNS TABLE (balance_minutes INTEGER, minutes_changed INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_balance INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    SELECT screen_time_balance_minutes
    INTO v_balance
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found.'; END IF;

    IF COALESCE(v_balance, 0) <= 0 THEN
        RETURN QUERY SELECT 0, 0;
        RETURN;
    END IF;

    UPDATE public.profiles
    SET screen_time_balance_minutes = screen_time_balance_minutes - 1,
        updated_at = clock_timestamp()
    WHERE id = v_user_id;

    INSERT INTO public.screen_time_transactions (
        user_id, amount_minutes, transaction_type, description
    )
    VALUES (v_user_id, -1, 'spent', 'Screen time used');

    RETURN QUERY SELECT v_balance - 1, -1;
END;
$$;

-- Keep the stored streak value in sync even when a user does not open the app.
-- Read paths still calculate an effective streak, so a delayed job cannot make
-- a stale value visible during the hour before this runs.
CREATE OR REPLACE FUNCTION public.reset_expired_streaks()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_reset_count INTEGER;
BEGIN
    WITH expired AS (
        UPDATE public.profiles AS p
        SET streak_count = 0,
            updated_at = clock_timestamp()
        WHERE p.streak_count > 0
          AND (
              p.last_workout_date IS NULL
              OR p.last_workout_date < (
                  clock_timestamp() AT TIME ZONE
                  COALESCE(NULLIF(p.timezone, ''), 'UTC')
              )::date - 1
          )
        RETURNING p.id
    )
    SELECT COUNT(*)::INTEGER INTO v_reset_count FROM expired;

    RETURN v_reset_count;
END;
$$;

-- Only the completion path may award workout/streak points directly.
REVOKE ALL ON FUNCTION public.award_workout_points(UUID)
FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.award_streak_milestone_points(UUID)
FROM PUBLIC, authenticated;
REVOKE ALL ON FUNCTION public.start_workout_session(UUID)
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.complete_workout_session(UUID, JSONB, TEXT)
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.credit_weekly_free_screen_time()
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_screen_time_minute()
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reset_expired_streaks()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.start_workout_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_workout_session(UUID, JSONB, TEXT)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.credit_weekly_free_screen_time()
TO authenticated;
GRANT EXECUTE ON FUNCTION public.consume_screen_time_minute()
TO authenticated;

DO $do$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_namespace WHERE nspname = 'cron'
    ) THEN
        EXECUTE $cron$
            SELECT cron.schedule(
                'hourly-streak-reset',
                '0 * * * *',
                'SELECT public.reset_expired_streaks();'
            )
            WHERE NOT EXISTS (
                SELECT 1 FROM cron.job
                WHERE jobname = 'hourly-streak-reset'
            )
        $cron$;
    END IF;
END;
$do$;

-- Public leaderboard streaks should not remain non-zero forever after a user
-- stops exercising. The stored streak is retained for historical continuity,
-- but this read path exposes the effective current streak.
CREATE OR REPLACE FUNCTION public.get_public_profile(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    streak_count INTEGER
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT p.id,
           p.username,
           p.first_name,
           p.last_name,
           CASE
               WHEN p.last_workout_date IS NULL
                 OR p.last_workout_date < (
                     clock_timestamp() AT TIME ZONE
                     COALESCE(NULLIF(p.timezone, ''), 'UTC')
                 )::date - 1
                   THEN 0
               ELSE COALESCE(p.streak_count, 0)
           END
    FROM public.profiles AS p
    WHERE p.id = p_user_id;
$$;

REVOKE ALL ON FUNCTION public.evaluate_user_achievements() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.evaluate_user_achievements() TO authenticated;
REVOKE ALL ON FUNCTION public.recalculate_my_weekly_leaderboard_score()
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.recalculate_my_weekly_leaderboard_score()
TO authenticated;

COMMIT;
