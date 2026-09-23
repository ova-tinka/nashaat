-- Enable row-level security for the application tables.
--
-- The policies below protect rows across users while preserving the current
-- client-side repository contract. Sensitive writes (balances, transactions,
-- rewards, and leaderboard scores) remain candidates for RPC hardening.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_active_leaderboard(p_leaderboard_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.leaderboards
    WHERE id = p_leaderboard_id
      AND is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION public.is_leaderboard_member(
  p_leaderboard_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.leaderboard_members
    WHERE leaderboard_id = p_leaderboard_id
      AND user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.can_access_leaderboard(
  p_leaderboard_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.leaderboards
    WHERE id = p_leaderboard_id
      AND (
        owner_id = p_user_id
        OR public.is_leaderboard_member(p_leaderboard_id, p_user_id)
      )
  );
$$;

-- Invite-code lookup is exact-match and returns only an active leaderboard.
-- It avoids exposing every private leaderboard through a broad SELECT policy.
CREATE OR REPLACE FUNCTION public.find_active_leaderboard_by_invite(
  p_invite_code TEXT
)
RETURNS SETOF public.leaderboards
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.leaderboards
  WHERE invite_code = p_invite_code
    AND is_active = true;
$$;

-- Only non-sensitive profile fields are exposed for leaderboard display.
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
SET search_path = public
AS $$
  SELECT p.id, p.username, p.first_name, p.last_name, p.streak_count
  FROM public.profiles AS p
  WHERE p.id = p_user_id;
$$;

REVOKE ALL ON FUNCTION public.is_active_leaderboard(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_leaderboard_member(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_access_leaderboard(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_active_leaderboard_by_invite(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_profile(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_active_leaderboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_leaderboard_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_leaderboard(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_active_leaderboard_by_invite(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_profile(UUID) TO authenticated;

ALTER TABLE public.app_usage_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocking_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_breaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.screen_time_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_usage_insights_own_rows ON public.app_usage_insights;
CREATE POLICY app_usage_insights_own_rows
ON public.app_usage_insights
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS blocking_rules_own_rows ON public.blocking_rules;
CREATE POLICY blocking_rules_own_rows
ON public.blocking_rules
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS emergency_breaks_select_own ON public.emergency_breaks;
CREATE POLICY emergency_breaks_select_own
ON public.emergency_breaks
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS emergency_breaks_insert_own ON public.emergency_breaks;
CREATE POLICY emergency_breaks_insert_own
ON public.emergency_breaks
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

GRANT SELECT ON public.exercises TO anon, authenticated;
DROP POLICY IF EXISTS "Exercise catalog is publicly readable" ON public.exercises;
CREATE POLICY "Exercise catalog is publicly readable"
ON public.exercises
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS friendships_select_participant ON public.friendships;
CREATE POLICY friendships_select_participant
ON public.friendships
FOR SELECT TO authenticated
USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DROP POLICY IF EXISTS friendships_insert_requester ON public.friendships;
CREATE POLICY friendships_insert_requester
ON public.friendships
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS friendships_update_addressee ON public.friendships;
CREATE POLICY friendships_update_addressee
ON public.friendships
FOR UPDATE TO authenticated
USING (auth.uid() = addressee_id)
WITH CHECK (auth.uid() = addressee_id);

DROP POLICY IF EXISTS friendships_delete_participant ON public.friendships;
CREATE POLICY friendships_delete_participant
ON public.friendships
FOR DELETE TO authenticated
USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DROP POLICY IF EXISTS leaderboard_members_select_access ON public.leaderboard_members;
CREATE POLICY leaderboard_members_select_access
ON public.leaderboard_members
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  OR public.can_access_leaderboard(leaderboard_id, auth.uid())
);

DROP POLICY IF EXISTS leaderboard_members_insert_self ON public.leaderboard_members;
CREATE POLICY leaderboard_members_insert_self
ON public.leaderboard_members
FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND public.is_active_leaderboard(leaderboard_id)
);

DROP POLICY IF EXISTS leaderboard_members_update_self ON public.leaderboard_members;
CREATE POLICY leaderboard_members_update_self
ON public.leaderboard_members
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS leaderboards_select_access ON public.leaderboards;
CREATE POLICY leaderboards_select_access
ON public.leaderboards
FOR SELECT TO authenticated
USING (public.can_access_leaderboard(id, auth.uid()));

DROP POLICY IF EXISTS leaderboards_insert_owner ON public.leaderboards;
CREATE POLICY leaderboards_insert_owner
ON public.leaderboards
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS leaderboards_update_owner ON public.leaderboards;
CREATE POLICY leaderboards_update_owner
ON public.leaderboards
FOR UPDATE TO authenticated
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS leaderboards_delete_owner ON public.leaderboards;
CREATE POLICY leaderboards_delete_owner
ON public.leaderboards
FOR DELETE TO authenticated
USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS media_own_rows ON public.media;
CREATE POLICY media_own_rows
ON public.media
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own
ON public.notifications
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own
ON public.notifications
FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
CREATE POLICY profiles_select_own
ON public.profiles
FOR SELECT TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own
ON public.profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS screen_time_transactions_own_rows ON public.screen_time_transactions;
CREATE POLICY screen_time_transactions_own_rows
ON public.screen_time_transactions
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_rewards_own_rows ON public.user_rewards;
CREATE POLICY user_rewards_own_rows
ON public.user_rewards
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS workout_logs_own_rows ON public.workout_logs;
CREATE POLICY workout_logs_own_rows
ON public.workout_logs
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS workout_plans_own_rows ON public.workout_plans;
CREATE POLICY workout_plans_own_rows
ON public.workout_plans
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

COMMIT;
