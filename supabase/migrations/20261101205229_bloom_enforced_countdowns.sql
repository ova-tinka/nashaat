begin;

alter table public.bloom_credit_sessions add column enforced boolean not null default false;

-- An enforced lease cannot be stopped from a second device while its local
-- deadline is still open. The countdown expires on its original server deadline.
create or replace function bloom_private.stop_credit_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid(); v_session public.bloom_credit_sessions%rowtype;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  perform 1 from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  select * into v_session from public.bloom_credit_sessions where id = p_session_id and user_id = v_user for update;
  if not found then raise exception 'Screen-time session not found'; end if;
  if v_session.enforced and v_session.settled_at is null and v_session.ends_at > clock_timestamp() then
    raise exception 'This screen-time session runs until its scheduled end';
  end if;
  perform bloom_private.settle_credit_session(v_user, p_session_id, clock_timestamp());
end;
$$;

create function bloom_private.start_enforced_credit_session(p_request_id uuid, p_minutes numeric)
returns table(session_id uuid, remaining_ms bigint)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_id uuid; v_start timestamptz; v_end timestamptz; v_settled timestamptz;
begin
  select s.session_id, s.session_started_at, s.session_ends_at into v_id, v_start, v_end
    from bloom_private.start_credit_session(p_request_id, p_minutes) s;
  select settled_at into v_settled from public.bloom_credit_sessions where id = v_id for update;
  if v_settled is not null or v_end <= clock_timestamp() then raise exception 'Screen-time session has ended'; end if;
  update public.bloom_credit_sessions set enforced = true where id = v_id;
  return query select v_id, greatest(0, floor(extract(epoch from (v_end - clock_timestamp())) * 1000)::bigint);
end;
$$;
revoke all on function bloom_private.start_enforced_credit_session(uuid, numeric) from public, anon;
grant execute on function bloom_private.start_enforced_credit_session(uuid, numeric) to authenticated;

create function public.bloom_start_enforced_credit_session(p_request_id uuid, p_minutes numeric)
returns table(session_id uuid, remaining_ms bigint)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.start_enforced_credit_session(p_request_id, p_minutes);
$$;
revoke all on function public.bloom_start_enforced_credit_session(uuid, numeric) from public, anon;
grant execute on function public.bloom_start_enforced_credit_session(uuid, numeric) to authenticated;

commit;
