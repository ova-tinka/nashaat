begin;

create table public.bloom_credit_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  mode text not null check (mode in ('hard', 'super_hard')),
  started_at timestamptz not null,
  ends_at timestamptz not null,
  expires_at timestamptz not null,
  settled_at timestamptz,
  unique (user_id, request_id),
  check (ends_at > started_at and ends_at <= expires_at),
  check (settled_at is null or (settled_at >= started_at and settled_at <= ends_at))
);
create unique index bloom_one_unsettled_credit_session on public.bloom_credit_sessions(user_id)
  where settled_at is null;
alter table public.bloom_credit_sessions enable row level security;
revoke all on public.bloom_credit_sessions from public, anon, authenticated;
grant select on public.bloom_credit_sessions to authenticated;
create policy bloom_credit_sessions_read on public.bloom_credit_sessions for select to authenticated
  using (user_id = (select auth.uid()));

-- Include an unsettled countdown in the balance, even after its timer has ended.
create or replace function public.bloom_credit_balance()
returns numeric language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select coalesce((select sum(l.amount_minutes) from public.bloom_credit_ledger l
    where l.user_id = auth.uid() and l.expires_at > now()), 0)
    - coalesce((select sum(round(greatest(0, extract(epoch from (least(now(), s.ends_at) - s.started_at))) / 60, 4))
      from public.bloom_credit_sessions s
      where s.user_id = auth.uid() and s.settled_at is null and s.expires_at > now()), 0);
$$;

create function bloom_private.settle_credit_session(p_user_id uuid, p_session_id uuid, p_now timestamptz)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_session public.bloom_credit_sessions%rowtype;
  v_finished timestamptz;
  v_spent numeric;
begin
  select * into v_session from public.bloom_credit_sessions s
    where s.id = p_session_id and s.user_id = p_user_id for update;
  if not found then raise exception 'Screen-time session not found'; end if;
  if v_session.settled_at is not null then return; end if;
  v_finished := greatest(v_session.started_at, least(p_now, v_session.ends_at));
  v_spent := round(extract(epoch from (v_finished - v_session.started_at)) / 60, 4);
  if v_spent > 0 then
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at, created_at)
      values (p_user_id, -v_spent, 'spent', 'countdown:' || v_session.id::text, v_session.expires_at, v_session.started_at);
  end if;
  update public.bloom_credit_sessions set settled_at = v_finished where id = v_session.id;
end;
$$;
revoke all on function bloom_private.settle_credit_session(uuid, uuid, timestamptz) from public, anon, authenticated;

create function bloom_private.start_credit_session(p_request_id uuid, p_minutes numeric)
returns table(session_id uuid, session_started_at timestamptz, session_ends_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_settings public.bloom_settings%rowtype;
  v_session public.bloom_credit_sessions%rowtype;
  v_now timestamptz;
  v_week_start timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_weekly_earned numeric;
  v_daily_spent numeric;
  v_daily_limit numeric;
  v_balance numeric;
  v_bucket numeric;
  v_expiry timestamptz;
  v_seconds integer;
  v_ends timestamptz;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  if p_request_id is null or p_minutes is null or p_minutes <= 0 or p_minutes > 1440 then
    raise exception 'Choose a valid screen-time duration';
  end if;
  select * into v_settings from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  v_now := clock_timestamp();

  select * into v_session from public.bloom_credit_sessions
    where user_id = v_user and request_id = p_request_id;
  if found then
    return query select v_session.id, v_session.started_at, v_session.ends_at;
    return;
  end if;
  if not v_settings.credits_enabled then raise exception 'Screen-time credits are turned off'; end if;
  if v_settings.credit_mode not in ('hard', 'super_hard') then
    raise exception 'Actual-use tracking is not available yet';
  end if;

  select * into v_session from public.bloom_credit_sessions
    where user_id = v_user and settled_at is null for update;
  if found then
    if v_session.ends_at > v_now then raise exception 'A screen-time session is already running'; end if;
    perform bloom_private.settle_credit_session(v_user, v_session.id, v_now);
  end if;

  v_week_start := (date_trunc('week', (v_now at time zone v_settings.credit_timezone) + interval '1 day')
    - interval '1 day') at time zone v_settings.credit_timezone;
  v_day_start := date_trunc('day', v_now at time zone v_settings.credit_timezone) at time zone v_settings.credit_timezone;
  v_day_end := (date_trunc('day', v_now at time zone v_settings.credit_timezone) + interval '1 day') at time zone v_settings.credit_timezone;
  select coalesce(sum(amount_minutes), 0) into v_weekly_earned from public.bloom_credit_ledger
    where user_id = v_user and (entry_type = 'earned' or (entry_type = 'adjustment' and amount_minutes > 0))
      and created_at >= v_week_start and created_at < v_now;
  select coalesce(-sum(amount_minutes), 0) into v_daily_spent from public.bloom_credit_ledger
    where user_id = v_user and entry_type = 'spent' and created_at >= v_day_start and created_at < v_day_end;
  v_daily_limit := v_weekly_earned / 7;
  if v_settings.credit_mode = 'super_hard' then
    v_daily_limit := least(v_daily_limit, v_settings.super_daily_cap_minutes);
  end if;
  select coalesce(sum(amount_minutes), 0) into v_balance from public.bloom_credit_ledger
    where user_id = v_user and expires_at > v_now;
  -- Spend the earliest expiry bucket first so expired credits cannot reappear.
  select l.expires_at, sum(l.amount_minutes) into v_expiry, v_bucket
    from public.bloom_credit_ledger l where l.user_id = v_user and l.expires_at > v_now
    group by l.expires_at having sum(l.amount_minutes) * 60 >= 1 order by l.expires_at limit 1;
  v_seconds := floor(greatest(0, least(p_minutes, v_balance, coalesce(v_bucket, 0), v_daily_limit - v_daily_spent)) * 60)::integer;
  if v_seconds < 1 then raise exception 'No screen time is available for today'; end if;
  v_ends := least(v_now + make_interval(secs => v_seconds), v_day_end, v_expiry);
  if v_ends <= v_now then raise exception 'No screen time is available for today'; end if;
  insert into public.bloom_credit_sessions(user_id, request_id, mode, started_at, ends_at, expires_at)
    values (v_user, p_request_id, v_settings.credit_mode, v_now, v_ends, v_expiry) returning * into v_session;
  return query select v_session.id, v_session.started_at, v_session.ends_at;
end;
$$;

create function bloom_private.stop_credit_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  perform 1 from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  perform bloom_private.settle_credit_session(v_user, p_session_id, clock_timestamp());
end;
$$;

create function bloom_private.guard_running_credit_session()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if (new.credit_mode, new.credit_timezone, new.super_daily_cap_minutes, new.credits_enabled)
       is distinct from (old.credit_mode, old.credit_timezone, old.super_daily_cap_minutes, old.credits_enabled)
     and exists (select 1 from public.bloom_credit_sessions s where s.user_id = old.user_id
       and s.settled_at is null and s.ends_at > clock_timestamp()) then
    raise exception 'Stop the active screen-time session before changing these settings';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.guard_running_credit_session() from public, anon, authenticated;
create trigger bloom_guard_running_credit_session before update on public.bloom_settings
  for each row execute function bloom_private.guard_running_credit_session();

revoke all on function bloom_private.start_credit_session(uuid, numeric), bloom_private.stop_credit_session(uuid) from public, anon;
grant execute on function bloom_private.start_credit_session(uuid, numeric), bloom_private.stop_credit_session(uuid) to authenticated;
create function public.bloom_start_credit_session(p_request_id uuid, p_minutes numeric)
returns table(session_id uuid, session_started_at timestamptz, session_ends_at timestamptz)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.start_credit_session(p_request_id, p_minutes);
$$;
create function public.bloom_stop_credit_session(p_session_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.stop_credit_session(p_session_id);
$$;
revoke all on function public.bloom_start_credit_session(uuid, numeric), public.bloom_stop_credit_session(uuid) from public, anon;
grant execute on function public.bloom_start_credit_session(uuid, numeric), public.bloom_stop_credit_session(uuid) to authenticated;

commit;
