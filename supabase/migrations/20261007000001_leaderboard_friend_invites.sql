-- Make leaderboard creation atomic and let owners add accepted friends.

BEGIN;

CREATE OR REPLACE FUNCTION public.assert_accepted_friends(p_friend_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expected_count INTEGER;
  v_friend_count INTEGER;
BEGIN
  SELECT count(DISTINCT id) INTO v_expected_count
  FROM unnest(COALESCE(p_friend_ids, ARRAY[]::UUID[])) AS id
  WHERE id <> auth.uid();

  SELECT count(DISTINCT CASE
    WHEN f.requester_id = auth.uid() THEN f.addressee_id
    ELSE f.requester_id
  END) INTO v_friend_count
  FROM public.friendships AS f
  WHERE f.status = 'accepted'
    AND (f.requester_id = auth.uid() OR f.addressee_id = auth.uid())
    AND (f.requester_id = ANY(COALESCE(p_friend_ids, ARRAY[]::UUID[]))
      OR f.addressee_id = ANY(COALESCE(p_friend_ids, ARRAY[]::UUID[])));

  IF v_friend_count <> v_expected_count THEN
    RAISE EXCEPTION 'Every invitee must be an accepted friend';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_leaderboard_with_members(
  p_name TEXT,
  p_invite_code TEXT,
  p_friend_ids UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS public.leaderboards
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_leaderboard public.leaderboards;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF char_length(trim(COALESCE(p_name, ''))) NOT BETWEEN 1 AND 80 THEN
    RAISE EXCEPTION 'Leaderboard name must be between 1 and 80 characters';
  END IF;
  IF p_invite_code !~ '^[A-Z0-9]{6}$' THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  PERFORM public.assert_accepted_friends(p_friend_ids);

  INSERT INTO public.leaderboards (owner_id, name, invite_code, is_active)
  VALUES (v_user_id, trim(p_name), p_invite_code, TRUE)
  RETURNING * INTO v_leaderboard;

  INSERT INTO public.leaderboard_members (leaderboard_id, user_id)
  VALUES (v_leaderboard.id, v_user_id);

  INSERT INTO public.leaderboard_members (leaderboard_id, user_id)
  SELECT v_leaderboard.id, friend_id
  FROM (
    SELECT DISTINCT id AS friend_id
    FROM unnest(COALESCE(p_friend_ids, ARRAY[]::UUID[])) AS id
    WHERE id <> v_user_id
  ) AS invitees;

  RETURN v_leaderboard;
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_friends_to_leaderboard(
  p_leaderboard_id UUID,
  p_friend_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.leaderboards
    WHERE id = p_leaderboard_id AND owner_id = auth.uid() AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Only the active leaderboard owner may invite friends';
  END IF;

  PERFORM public.assert_accepted_friends(p_friend_ids);

  INSERT INTO public.leaderboard_members (leaderboard_id, user_id)
  SELECT p_leaderboard_id, friend_id
  FROM (
    SELECT DISTINCT id AS friend_id
    FROM unnest(COALESCE(p_friend_ids, ARRAY[]::UUID[])) AS id
    WHERE id <> auth.uid()
  ) AS invitees
  ON CONFLICT (leaderboard_id, user_id) DO NOTHING;
END;
$$;

DROP POLICY IF EXISTS leaderboards_insert_owner ON public.leaderboards;
DROP POLICY IF EXISTS leaderboard_members_insert_self ON public.leaderboard_members;

REVOKE ALL ON FUNCTION public.assert_accepted_friends(UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_leaderboard_with_members(TEXT, TEXT, UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.invite_friends_to_leaderboard(UUID, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_leaderboard_with_members(TEXT, TEXT, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_friends_to_leaderboard(UUID, UUID[]) TO authenticated;

COMMIT;
