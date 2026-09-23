BEGIN;

ALTER TABLE public.point_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievement_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_period_scores ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.point_awards FROM anon, authenticated;
REVOKE ALL ON TABLE public.achievement_definitions FROM anon, authenticated;
REVOKE ALL ON TABLE public.user_achievements FROM anon, authenticated;
REVOKE ALL ON TABLE public.leaderboard_period_scores FROM anon, authenticated;

GRANT SELECT ON TABLE public.point_awards TO authenticated;
GRANT SELECT ON TABLE public.achievement_definitions TO authenticated;
GRANT SELECT ON TABLE public.user_achievements TO authenticated;
GRANT SELECT ON TABLE public.leaderboard_period_scores TO authenticated;

DROP POLICY IF EXISTS point_awards_select_own ON public.point_awards;
CREATE POLICY point_awards_select_own
ON public.point_awards
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS achievement_definitions_select_active
ON public.achievement_definitions;
CREATE POLICY achievement_definitions_select_active
ON public.achievement_definitions
FOR SELECT
TO authenticated
USING (is_active = TRUE);

DROP POLICY IF EXISTS user_achievements_select_own
ON public.user_achievements;
CREATE POLICY user_achievements_select_own
ON public.user_achievements
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS leaderboard_period_scores_select_access
ON public.leaderboard_period_scores;
CREATE POLICY leaderboard_period_scores_select_access
ON public.leaderboard_period_scores
FOR SELECT
TO authenticated
USING (public.can_access_leaderboard(leaderboard_id, auth.uid()));

COMMIT;
