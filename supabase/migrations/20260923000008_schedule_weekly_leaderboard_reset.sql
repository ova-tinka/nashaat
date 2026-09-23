DO $do$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_namespace
        WHERE nspname = 'cron'
    ) THEN
        EXECUTE $cron$
            SELECT cron.schedule(
                'weekly-leaderboard-reset',
                '0 0 * * 1',
                'SELECT public.finalize_and_reset_weekly_leaderboards();'
            )
            WHERE NOT EXISTS (
                SELECT 1
                FROM cron.job
                WHERE jobname = 'weekly-leaderboard-reset'
            )
        $cron$;
    END IF;
END;
$do$;
