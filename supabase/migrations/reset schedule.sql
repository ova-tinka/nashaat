SELECT cron.schedule(
    'weekly-leaderboard-reset',
    '0 0 * * 1',
    $$ SELECT public.finalize_and_reset_weekly_leaderboards(); $$
);