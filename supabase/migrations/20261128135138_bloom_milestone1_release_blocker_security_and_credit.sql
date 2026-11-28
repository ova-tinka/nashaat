begin;

revoke all on function public.finalize_and_reset_weekly_leaderboards() from public, anon, authenticated;
grant execute on function public.finalize_and_reset_weekly_leaderboards() to service_role;

create or replace function bloom_private.cancel_enforced_credit_session(
  p_request_id uuid,
  p_device_key uuid
) returns void
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_session public.bloom_credit_sessions%rowtype;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  if p_request_id is null or p_device_key is null then raise exception 'Invalid screen-time request'; end if;

  perform 1 from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;

  select * into v_session from public.bloom_credit_sessions
  where user_id = v_user and request_id = p_request_id for update;
  if not found then return; end if;
  if not exists (
    select 1 from bloom_private.countdown_device_keys k
    where k.session_id = v_session.id
      and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8'))
  ) then
    raise exception 'Screen-time session belongs to another device or request';
  end if;
  if v_session.settled_at is null then
    perform bloom_private.settle_credit_session(v_user, v_session.id, clock_timestamp());
  end if;
end;
$$;
revoke all on function bloom_private.cancel_enforced_credit_session(uuid, uuid) from public, anon, authenticated;
grant execute on function bloom_private.cancel_enforced_credit_session(uuid, uuid) to authenticated;

create or replace function public.bloom_cancel_enforced_credit_session(p_request_id uuid, p_device_key uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.cancel_enforced_credit_session(p_request_id, p_device_key);
$$;
revoke all on function public.bloom_cancel_enforced_credit_session(uuid, uuid) from public, anon;
grant execute on function public.bloom_cancel_enforced_credit_session(uuid, uuid) to authenticated;

commit;
