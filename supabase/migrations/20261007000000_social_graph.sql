-- Friend discovery and relationship mutations.
-- Existing friendship RLS already limits reads to participants. Writes now go
-- through authenticated RPCs so users cannot impersonate another requester or
-- mutate a relationship they do not control.

BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS friendships_unique_pair
  ON public.friendships (
    LEAST(requester_id, addressee_id),
    GREATEST(requester_id, addressee_id)
  );

CREATE OR REPLACE FUNCTION public.search_public_profiles(
  p_query TEXT,
  p_limit INTEGER DEFAULT 20
)
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
  WHERE auth.uid() IS NOT NULL
    AND p.id <> auth.uid()
    AND (
      p.username ILIKE '%' || trim(p_query) || '%'
      OR p.first_name ILIKE '%' || trim(p_query) || '%'
      OR p.last_name ILIKE '%' || trim(p_query) || '%'
    )
  ORDER BY COALESCE(p.username, p.first_name, p.last_name), p.id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
$$;

CREATE OR REPLACE FUNCTION public.send_friend_request(p_addressee_id UUID)
RETURNS public.friendships
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_id UUID := auth.uid();
  v_friendship public.friendships;
BEGIN
  IF v_requester_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_addressee_id IS NULL OR p_addressee_id = v_requester_id THEN
    RAISE EXCEPTION 'Choose another user';
  END IF;

  SELECT * INTO v_friendship
  FROM public.friendships
  WHERE (requester_id = v_requester_id AND addressee_id = p_addressee_id)
     OR (requester_id = p_addressee_id AND addressee_id = v_requester_id)
  FOR UPDATE;

  IF FOUND THEN
    IF v_friendship.status = 'rejected'
       AND v_friendship.requester_id = v_requester_id THEN
      UPDATE public.friendships
      SET status = 'pending', updated_at = now()
      WHERE id = v_friendship.id
      RETURNING * INTO v_friendship;
    END IF;
    RETURN v_friendship;
  END IF;

  INSERT INTO public.friendships (requester_id, addressee_id, status)
  VALUES (v_requester_id, p_addressee_id, 'pending')
  RETURNING * INTO v_friendship;
  RETURN v_friendship;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_to_friend_request(
  p_friendship_id UUID,
  p_status friendship_status_enum
)
RETURNS public.friendships
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_friendship public.friendships;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_status NOT IN ('accepted', 'rejected') THEN
    RAISE EXCEPTION 'Invalid friendship response';
  END IF;

  UPDATE public.friendships
  SET status = p_status, updated_at = now()
  WHERE id = p_friendship_id
    AND addressee_id = auth.uid()
    AND status = 'pending'
  RETURNING * INTO v_friendship;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending request not found';
  END IF;
  RETURN v_friendship;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_friendship(p_friendship_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  DELETE FROM public.friendships
  WHERE id = p_friendship_id
    AND (requester_id = auth.uid() OR addressee_id = auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Friendship not found';
  END IF;
END;
$$;

DROP POLICY IF EXISTS friendships_insert_requester ON public.friendships;
DROP POLICY IF EXISTS friendships_update_addressee ON public.friendships;
DROP POLICY IF EXISTS friendships_delete_participant ON public.friendships;

REVOKE ALL ON FUNCTION public.search_public_profiles(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.send_friend_request(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_to_friend_request(UUID, friendship_status_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.remove_friendship(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_friend_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_friend_request(UUID, friendship_status_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friendship(UUID) TO authenticated;

COMMIT;
