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

    v_achievement RECORD;
    v_existing RECORD;

    v_progress INTEGER;
    v_workout_count INTEGER;
    v_current_streak INTEGER;
    v_joined_leaderboard INTEGER;

    v_newly_unlocked BOOLEAN;
    v_transaction_id UUID;
    v_awarded_points INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be signed in.';
    END IF;

    -- Lock profile while evaluating rewards.
    PERFORM 1
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found.';
    END IF;

    -- Current qualifying-workout rule.
    SELECT COUNT(*)::INTEGER
    INTO v_workout_count
    FROM public.workout_logs
    WHERE user_id = v_user_id
      AND duration_minutes BETWEEN 5 AND 180;

    SELECT COALESCE(streak_count, 0)
    INTO v_current_streak
    FROM public.profiles
    WHERE id = v_user_id;

    SELECT CASE
        WHEN EXISTS (
            SELECT 1
            FROM public.leaderboard_members
            WHERE user_id = v_user_id
        )
        THEN 1
        ELSE 0
    END
    INTO v_joined_leaderboard;

    FOR v_achievement IN
        SELECT *
        FROM public.achievement_definitions
        WHERE is_active = TRUE
        ORDER BY created_at
    LOOP

        CASE v_achievement.criteria_type
            WHEN 'qualifying_workout_count' THEN
                v_progress := v_workout_count;

            WHEN 'current_streak' THEN
                v_progress := v_current_streak;

            WHEN 'leaderboard_join' THEN
                v_progress := v_joined_leaderboard;

            WHEN 'weekly_leaderboard_win' THEN
                v_progress := 0;

            ELSE
                v_progress := 0;
        END CASE;

        v_progress :=
            LEAST(v_progress, v_achievement.target_value);

        v_newly_unlocked := FALSE;

        SELECT
            ua.id,
            ua.progress,
            ua.unlocked_at,
            ua.reward_granted_at
        INTO v_existing
        FROM public.user_achievements ua
        WHERE ua.user_id = v_user_id
          AND ua.achievement_id = v_achievement.id
        FOR UPDATE;

        IF NOT FOUND THEN

            INSERT INTO public.user_achievements (
                user_id,
                achievement_id,
                progress,
                unlocked_at
            )
            VALUES (
                v_user_id,
                v_achievement.id,
                v_progress,
                CASE
                    WHEN v_progress >= v_achievement.target_value
                    THEN NOW()
                    ELSE NULL
                END
            );

            IF v_progress >= v_achievement.target_value THEN
                v_newly_unlocked := TRUE;
            END IF;

        ELSE

            IF v_existing.unlocked_at IS NULL THEN

                IF v_progress >= v_achievement.target_value THEN

                    UPDATE public.user_achievements
                    SET
                        progress = v_achievement.target_value,
                        unlocked_at = NOW(),
                        updated_at = NOW()
                    WHERE user_id = v_user_id
                      AND achievement_id = v_achievement.id;

                    v_newly_unlocked := TRUE;

                ELSE

                    UPDATE public.user_achievements
                    SET
                        progress = v_progress,
                        updated_at = NOW()
                    WHERE user_id = v_user_id
                      AND achievement_id = v_achievement.id;

                END IF;

            END IF;

        END IF;

        IF v_newly_unlocked THEN

            -- POINT REWARD
            IF v_achievement.reward_type = 'points'
               AND v_achievement.reward_amount > 0 THEN

                v_awarded_points := NULL;

                INSERT INTO public.point_awards (
                    user_id,
                    points,
                    reason_type,
                    description,
                    source_type,
                    source_event_id
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
                    user_id,
                    source_type,
                    source_event_id,
                    reason_type
                )
                DO NOTHING
                RETURNING points
                INTO v_awarded_points;

                IF v_awarded_points IS NOT NULL THEN
                    UPDATE public.profiles
                    SET
                        points_total =
                            points_total + v_awarded_points,
                        updated_at = NOW()
                    WHERE id = v_user_id;
                END IF;

                UPDATE public.user_achievements
                SET
                    reward_granted_at = NOW(),
                    updated_at = NOW()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;

            -- SCREEN-TIME REWARD
            ELSIF v_achievement.reward_type = 'screen_time'
               AND v_achievement.reward_amount > 0 THEN

                INSERT INTO public.screen_time_transactions (
                    user_id,
                    amount_minutes,
                    transaction_type,
                    description,
                    reference_id
                )
                VALUES (
                    v_user_id,
                    v_achievement.reward_amount,
                    'earned',
                    'Achievement unlocked: ' || v_achievement.name,
                    v_achievement.id
                )
                RETURNING id
                INTO v_transaction_id;

                UPDATE public.profiles
                SET
                    screen_time_balance_minutes =
                        screen_time_balance_minutes
                        + v_achievement.reward_amount,
                    updated_at = NOW()
                WHERE id = v_user_id;

                UPDATE public.user_achievements
                SET
                    reward_granted_at = NOW(),
                    reward_transaction_id = v_transaction_id,
                    updated_at = NOW()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;

            -- RECOGNITION ONLY
            ELSE

                UPDATE public.user_achievements
                SET
                    reward_granted_at = NOW(),
                    updated_at = NOW()
                WHERE user_id = v_user_id
                  AND achievement_id = v_achievement.id;

            END IF;

            unlocked_achievement_id := v_achievement.id;
            achievement_code := v_achievement.code;
            achievement_name := v_achievement.name;
            unlocked_reward_type := v_achievement.reward_type::TEXT;
            unlocked_reward_amount := v_achievement.reward_amount;

            RETURN NEXT;

        END IF;

    END LOOP;

    RETURN;
END;
$$;

REVOKE ALL
ON FUNCTION public.evaluate_user_achievements()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.evaluate_user_achievements()
TO authenticated;