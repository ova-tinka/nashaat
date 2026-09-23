CREATE OR REPLACE FUNCTION public.finalize_and_reset_weekly_leaderboards()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
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


    -- Save each period exactly once. A retry must not overwrite finalized
    -- scores with the already-reset live score.
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
    ON CONFLICT (leaderboard_id, user_id, period_start) DO NOTHING;

    UPDATE public.leaderboard_members
    SET weekly_score = 0;

END;
$$;

REVOKE ALL
ON FUNCTION public.finalize_and_reset_weekly_leaderboards()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.finalize_and_reset_weekly_leaderboards()
TO service_role;
