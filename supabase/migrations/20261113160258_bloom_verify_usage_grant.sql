begin;

-- Read-only: this function never creates, settles, extends, or debits a
-- reservation. The private key table is deliberately inaccessible directly.
create function bloom_private.verify_usage_grant(p_session_id uuid, p_device_key uuid)
returns table(session_id uuid, reserved_ms bigint, expiry_remaining_ms bigint)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_usage public.bloom_usage_sessions%rowtype;
  v_now timestamptz := clock_timestamp();
  v_remaining bigint;
begin
  if auth.uid() is null or v_profile is null or p_session_id is null or p_device_key is null then
    raise exception 'Screen-time reservation unavailable';
  end if;
  select s.* into v_usage from public.bloom_usage_sessions s
    where s.id = p_session_id and s.user_id = v_profile
      and s.settled_at is null and s.abandoned_at is null
      and exists (select 1 from bloom_private.usage_device_keys k
        where k.session_id = s.id and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8')));
  if not found then raise exception 'Screen-time reservation unavailable'; end if;
  v_remaining := least(v_usage.reserved_ms,
    greatest(0::bigint, floor(extract(epoch from (v_usage.access_expires_at - v_now)) * 1000)::bigint));
  return query select v_usage.id, v_usage.reserved_ms, v_remaining;
end;
$$;
revoke all on function bloom_private.verify_usage_grant(uuid, uuid) from public, anon;
grant execute on function bloom_private.verify_usage_grant(uuid, uuid) to authenticated;

create function public.bloom_verify_usage_grant(p_session_id uuid, p_device_key uuid)
returns table(session_id uuid, reserved_ms bigint, expiry_remaining_ms bigint)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.verify_usage_grant(p_session_id, p_device_key);
$$;
revoke all on function public.bloom_verify_usage_grant(uuid, uuid) from public, anon;
grant execute on function public.bloom_verify_usage_grant(uuid, uuid) to authenticated;

commit;
