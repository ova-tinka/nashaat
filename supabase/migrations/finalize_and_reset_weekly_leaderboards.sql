CREATE OR REPLACE FUNCTION public.finalize_and_reset_weekly_leaderboards()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_period_start DATE;
    v_period_end DATE;
BEGIN
    /*
      This function is intended to run Monday at 00:00 UTC.

      Example:
      Current Monday = Sep 14

      Finished period:
      Sep 7 -> Sep 13
    */

    v_period_start :=
        date_trunc('week', NOW() AT TIME ZONE 'UTC')::date - 7;

    v_period_end :=
        date_trunc('week', NOW() AT TIME ZONE 'UTC')::date - 1;


    -- --------------------------------------------------
    -- STEP 1:
    -- Update an existing historical row if this function
    -- has already been run for this week.
    -- --------------------------------------------------

    UPDATE public.leaderboard_period_scores lps
    SET
        score = COALESCE(lm.weekly_score, 0),
        period_end = v_period_end,
        updated_at = NOW()
    FROM public.leaderboard_members lm
    WHERE lps.leaderboard_id = lm.leaderboard_id
      AND lps.user_id = lm.user_id
      AND lps.period_start = v_period_start;


    -- --------------------------------------------------
    -- STEP 2:
    -- Save scores that do not already exist in history.
    -- --------------------------------------------------

    INSERT INTO public.leaderboard_period_scores (
        leaderboard_id,
        user_id,
        period_start,
        period_end,
        score,
        updated_at
    )
    SELECT
        lm.leaderboard_id,
        lm.user_id,
        v_period_start,
        v_period_end,
        COALESCE(lm.weekly_score, 0),
        NOW()
    FROM public.leaderboard_members lm
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.leaderboard_period_scores lps
        WHERE lps.leaderboard_id = lm.leaderboard_id
          AND lps.user_id = lm.user_id
          AND lps.period_start = v_period_start
    );


    -- --------------------------------------------------
    -- STEP 3:
    -- ONLY AFTER saving the results,
    -- reset the live weekly scores.
    -- --------------------------------------------------

    UPDATE public.leaderboard_members
    SET weekly_score = 0;

END;
$$;