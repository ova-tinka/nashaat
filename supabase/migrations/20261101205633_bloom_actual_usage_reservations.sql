begin;

-- Reserve an expiry bucket on the server so a second device cannot spend the
-- same minutes while this device measures actual foreground usage offline.
create table public.bloom_usage_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  requested_ms bigint not null check (requested_ms between 1000 and 604800000),
  reserved_ms bigint not null check (reserved_ms between 1000 and 604800000),
  started_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  settled_at timestamptz,
  abandoned_at timestamptz,
  used_ms bigint check (used_ms is null or (used_ms >= 0 and used_ms <= reserved_ms)),
  unique (user_id, request_id),
  check ((settled_at is null) = (used_ms is null))
);
create unique index bloom_one_open_usage_session on public.bloom_usage_sessions(user_id) where settled_at is null and abandoned_at is null;
alter table public.bloom_usage_sessions enable row level security;
revoke all on public.bloom_usage_sessions from public, anon, authenticated;
grant select on public.bloom_usage_sessions to authenticated;
create policy bloom_usage_sessions_read on public.bloom_usage_sessions for select to authenticated
  using (user_id = (select auth.uid()) or bloom_private.is_parent_of(user_id));
create table bloom_private.usage_device_keys (
  session_id uuid primary key references public.bloom_usage_sessions(id) on delete cascade,
  key_hash bytea not null
);
revoke all on bloom_private.usage_device_keys from public, anon, authenticated;

create or replace function public.bloom_credit_balance()
returns numeric language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select coalesce((select sum(l.amount_minutes) from public.bloom_credit_ledger l
    where l.user_id = auth.uid() and l.expires_at > now()), 0)
    - coalesce((select sum(round(greatest(0, extract(epoch from (least(now(), s.ends_at) - s.started_at))) / 60, 4))
      from public.bloom_credit_sessions s where s.user_id = auth.uid() and s.settled_at is null and s.expires_at > now()), 0)
    - coalesce((select sum(s.reserved_ms::numeric / 60000) from public.bloom_usage_sessions s
      where s.user_id = auth.uid() and s.settled_at is null and s.expires_at > now()), 0);
$$;

create or replace function bloom_private.parent_child_balance(p_child_id uuid)
returns numeric language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
begin
  if auth.uid() is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  return coalesce((select sum(l.amount_minutes) from public.bloom_credit_ledger l where l.user_id = p_child_id and l.expires_at > now()), 0)
    - coalesce((select sum(round(greatest(0, extract(epoch from (least(now(), s.ends_at) - s.started_at))) / 60, 4))
      from public.bloom_credit_sessions s where s.user_id = p_child_id and s.settled_at is null and s.expires_at > now()), 0)
    - coalesce((select sum(s.reserved_ms::numeric / 60000) from public.bloom_usage_sessions s
      where s.user_id = p_child_id and s.settled_at is null and s.expires_at > now()), 0);
end;
$$;

create function bloom_private.start_usage_session(p_request_id uuid, p_device_key uuid, p_requested_ms bigint)
returns table(session_id uuid, reserved_ms bigint, expiry_remaining_ms bigint)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid(); v_settings public.bloom_settings%rowtype;
  v_usage public.bloom_usage_sessions%rowtype; v_countdown public.bloom_credit_sessions%rowtype;
  v_now timestamptz; v_balance numeric; v_bucket numeric; v_expiry timestamptz; v_reserved bigint;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  if p_request_id is null or p_device_key is null or p_requested_ms is null or p_requested_ms < 1000 or p_requested_ms > 604800000 then raise exception 'Choose a valid screen-time amount'; end if;
  select * into v_settings from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  v_now := clock_timestamp();
  select * into v_usage from public.bloom_usage_sessions where user_id = v_user and request_id = p_request_id for update;
  if found then
    if not exists (select 1 from bloom_private.usage_device_keys k where k.session_id = v_usage.id and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8'))) then raise exception 'Screen-time reservation belongs to another device'; end if;
    if v_usage.requested_ms <> p_requested_ms then raise exception 'Screen-time reservation request was already used'; end if;
    if v_usage.settled_at is not null or v_usage.expires_at <= v_now then raise exception 'Screen-time reservation has ended'; end if;
    return query select v_usage.id, v_usage.reserved_ms, floor(extract(epoch from (v_usage.expires_at - v_now)) * 1000)::bigint;
    return;
  end if;
  if not v_settings.credits_enabled or v_settings.credit_mode <> 'easy' then raise exception 'Actual-use mode is not enabled'; end if;
  select * into v_countdown from public.bloom_credit_sessions where user_id = v_user and settled_at is null for update;
  if found then
    if v_countdown.ends_at > v_now then raise exception 'A screen-time session is already running'; end if;
    perform bloom_private.settle_credit_session(v_user, v_countdown.id, v_now);
  end if;
  select * into v_usage from public.bloom_usage_sessions where user_id = v_user and settled_at is null and abandoned_at is null for update;
  if found then
    if v_usage.expires_at > v_now then raise exception 'A screen-time reservation is already active on another device'; end if;
    update public.bloom_usage_sessions set abandoned_at = v_now where id = v_usage.id;
  end if;
  select coalesce(sum(amount_minutes), 0) into v_balance from public.bloom_credit_ledger where user_id = v_user and expires_at > v_now;
  select l.expires_at, sum(l.amount_minutes) into v_expiry, v_bucket from public.bloom_credit_ledger l
    where l.user_id = v_user and l.expires_at > v_now group by l.expires_at
    having sum(l.amount_minutes) * 60000 >= 1000 order by l.expires_at limit 1;
  v_reserved := floor(greatest(0, least(p_requested_ms::numeric, v_balance * 60000, coalesce(v_bucket, 0) * 60000)))::bigint;
  if v_reserved < 1000 then raise exception 'No screen time is available'; end if;
  insert into public.bloom_usage_sessions(user_id, request_id, requested_ms, reserved_ms, expires_at)
    values (v_user, p_request_id, p_requested_ms, v_reserved, v_expiry) returning * into v_usage;
  insert into bloom_private.usage_device_keys(session_id, key_hash) values (v_usage.id, sha256(convert_to(p_device_key::text, 'UTF8')));
  return query select v_usage.id, v_usage.reserved_ms, floor(extract(epoch from (v_expiry - v_now)) * 1000)::bigint;
end;
$$;

create function bloom_private.finish_usage_session(p_session_id uuid, p_device_key uuid, p_used_ms bigint)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_user uuid := auth.uid(); v_usage public.bloom_usage_sessions%rowtype; v_now timestamptz;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  perform 1 from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  select * into v_usage from public.bloom_usage_sessions where id = p_session_id and user_id = v_user for update;
  if not found then raise exception 'Screen-time reservation not found'; end if;
  if p_device_key is null or not exists (select 1 from bloom_private.usage_device_keys k where k.session_id = v_usage.id and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8'))) then raise exception 'Screen-time reservation belongs to another device'; end if;
  if p_used_ms is null or p_used_ms < 0 or p_used_ms > v_usage.reserved_ms then raise exception 'Invalid usage amount'; end if;
  if v_usage.settled_at is not null then
    if v_usage.used_ms <> p_used_ms then raise exception 'Screen-time reservation was already settled'; end if;
    return;
  end if;
  v_now := clock_timestamp();
  if p_used_ms >= 6 then
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at, created_at)
      values (v_user, -trunc(p_used_ms::numeric / 60000, 4), 'spent', 'usage:' || v_usage.id::text, v_usage.expires_at,
        least(v_now, v_usage.expires_at - interval '1 microsecond'));
  end if;
  update public.bloom_usage_sessions set settled_at = v_now, used_ms = p_used_ms where id = v_usage.id;
end;
$$;
revoke all on function bloom_private.start_usage_session(uuid, uuid, bigint), bloom_private.finish_usage_session(uuid, uuid, bigint) from public, anon;
grant execute on function bloom_private.start_usage_session(uuid, uuid, bigint), bloom_private.finish_usage_session(uuid, uuid, bigint) to authenticated;
create function public.bloom_start_usage_session(p_request_id uuid, p_device_key uuid, p_requested_ms bigint)
returns table(session_id uuid, reserved_ms bigint, expiry_remaining_ms bigint) language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select * from bloom_private.start_usage_session(p_request_id, p_device_key, p_requested_ms); $$;
create function public.bloom_finish_usage_session(p_session_id uuid, p_device_key uuid, p_used_ms bigint)
returns void language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.finish_usage_session(p_session_id, p_device_key, p_used_ms); $$;
revoke all on function public.bloom_start_usage_session(uuid, uuid, bigint), public.bloom_finish_usage_session(uuid, uuid, bigint) from public, anon;
grant execute on function public.bloom_start_usage_session(uuid, uuid, bigint), public.bloom_finish_usage_session(uuid, uuid, bigint) to authenticated;

-- Every writer involved locks the user's settings first, making these checks
-- serialize with starts, parent adjustments and settings changes.
create function bloom_private.guard_open_usage_reservation()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if exists (select 1 from public.bloom_usage_sessions where user_id = new.user_id and settled_at is null and expires_at > clock_timestamp()) then
    raise exception 'Finish the active actual-use session first';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.guard_open_usage_reservation() from public, anon, authenticated;
create trigger bloom_guard_countdown_during_usage before insert on public.bloom_credit_sessions
  for each row execute function bloom_private.guard_open_usage_reservation();
create trigger bloom_guard_adjustment_during_usage before insert on public.bloom_credit_ledger
  for each row when (new.entry_type = 'adjustment') execute function bloom_private.guard_open_usage_reservation();

create or replace function bloom_private.guard_running_credit_session()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if (new.credit_mode, new.credit_timezone, new.super_daily_cap_minutes, new.credits_enabled)
       is distinct from (old.credit_mode, old.credit_timezone, old.super_daily_cap_minutes, old.credits_enabled)
     and (exists (select 1 from public.bloom_credit_sessions s where s.user_id = old.user_id and s.settled_at is null and s.ends_at > clock_timestamp())
       or exists (select 1 from public.bloom_usage_sessions s where s.user_id = old.user_id and s.settled_at is null and s.expires_at > clock_timestamp())) then
    raise exception 'Stop the active screen-time session before changing these settings';
  end if;
  return new;
end;
$$;

commit;
