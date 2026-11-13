begin;

-- Read-only verification of an already-running enforced countdown. It never
-- creates, settles, extends, or debits a session.
create function bloom_private.verify_countdown_grant(p_request_id uuid, p_device_key uuid)
returns table(request_id uuid, session_id uuid, remaining_ms bigint)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_session public.bloom_credit_sessions%rowtype;
  v_now timestamptz := clock_timestamp();
  v_remaining bigint;
begin
  if auth.uid() is null or v_profile is null or p_request_id is null or p_device_key is null then
    raise exception 'Screen-time session unavailable';
  end if;
  select s.* into v_session from public.bloom_credit_sessions s
    where s.user_id = v_profile and s.request_id = p_request_id and s.enforced and s.settled_at is null
      and exists (select 1 from bloom_private.countdown_device_keys k
        where k.session_id = s.id and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8')));
  if not found then raise exception 'Screen-time session unavailable'; end if;
  v_remaining := least(86400000::bigint,
    greatest(0::bigint, floor(extract(epoch from (v_session.ends_at - v_now)) * 1000)::bigint));
  return query select v_session.request_id, v_session.id, v_remaining;
end;
$$;
revoke all on function bloom_private.verify_countdown_grant(uuid, uuid) from public, anon;
grant execute on function bloom_private.verify_countdown_grant(uuid, uuid) to authenticated;

create function public.bloom_verify_countdown_grant(p_request_id uuid, p_device_key uuid)
returns table(request_id uuid, session_id uuid, remaining_ms bigint)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.verify_countdown_grant(p_request_id, p_device_key);
$$;
revoke all on function public.bloom_verify_countdown_grant(uuid, uuid) from public, anon;
grant execute on function public.bloom_verify_countdown_grant(uuid, uuid) to authenticated;

commit;
