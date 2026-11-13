begin;

create table bloom_private.countdown_device_keys (
  session_id uuid primary key references public.bloom_credit_sessions(id) on delete cascade,
  key_hash bytea not null,
  requested_minutes numeric not null
);
revoke all on bloom_private.countdown_device_keys from public, anon, authenticated;

drop function public.bloom_start_enforced_credit_session(uuid, numeric);
drop function bloom_private.start_enforced_credit_session(uuid, numeric);

create function bloom_private.start_enforced_credit_session(p_request_id uuid, p_device_key uuid, p_minutes numeric)
returns table(session_id uuid, remaining_ms bigint)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid(); v_session public.bloom_credit_sessions%rowtype; v_id uuid; v_start timestamptz; v_end timestamptz;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  if p_request_id is null or p_device_key is null or p_minutes is null or p_minutes <= 0 or p_minutes > 1440 then raise exception 'Choose a valid screen-time duration'; end if;
  perform 1 from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  select * into v_session from public.bloom_credit_sessions where user_id = v_user and request_id = p_request_id for update;
  if found then
    if not exists (select 1 from bloom_private.countdown_device_keys k where k.session_id = v_session.id
      and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8')) and k.requested_minutes = p_minutes) then
      raise exception 'Screen-time session belongs to another device or request';
    end if;
    v_id := v_session.id; v_end := v_session.ends_at;
    if v_session.settled_at is not null then raise exception 'Screen-time session has ended'; end if;
  else
    select s.session_id, s.session_started_at, s.session_ends_at into v_id, v_start, v_end
      from bloom_private.start_credit_session(p_request_id, p_minutes) s;
    update public.bloom_credit_sessions set enforced = true where id = v_id;
    insert into bloom_private.countdown_device_keys(session_id, key_hash, requested_minutes)
      values (v_id, sha256(convert_to(p_device_key::text, 'UTF8')), p_minutes);
  end if;
  if v_end <= clock_timestamp() then raise exception 'Screen-time session has ended'; end if;
  return query select v_id, greatest(0, floor(extract(epoch from (v_end - clock_timestamp())) * 1000)::bigint);
end;
$$;
revoke all on function bloom_private.start_enforced_credit_session(uuid, uuid, numeric) from public, anon;
grant execute on function bloom_private.start_enforced_credit_session(uuid, uuid, numeric) to authenticated;
create function public.bloom_start_enforced_credit_session(p_request_id uuid, p_device_key uuid, p_minutes numeric)
returns table(session_id uuid, remaining_ms bigint)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.start_enforced_credit_session(p_request_id, p_device_key, p_minutes);
$$;
revoke all on function public.bloom_start_enforced_credit_session(uuid, uuid, numeric) from public, anon;
grant execute on function public.bloom_start_enforced_credit_session(uuid, uuid, numeric) to authenticated;

commit;
