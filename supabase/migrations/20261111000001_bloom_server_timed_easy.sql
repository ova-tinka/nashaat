begin;

-- Easy grants are now access windows measured by the database clock. The
-- credit bucket expiry remains separate from the end of the access window.
alter table public.bloom_usage_sessions
  add column access_expires_at timestamptz,
  add column billing_started_at timestamptz;

update public.bloom_usage_sessions
set access_expires_at = least(
  expires_at,
  started_at + make_interval(secs => reserved_ms::double precision / 1000)
);

alter table public.bloom_usage_sessions
  alter column access_expires_at set not null;

create function bloom_private.populate_usage_access_expiry()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if new.access_expires_at is null then
    new.access_expires_at := least(new.expires_at,
      new.started_at + make_interval(secs => new.reserved_ms::double precision / 1000));
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.populate_usage_access_expiry() from public, anon, authenticated;
create trigger bloom_usage_access_expiry before insert or update on public.bloom_usage_sessions
  for each row execute function bloom_private.populate_usage_access_expiry();

create function bloom_private.settle_usage_session(p_user_id uuid, p_session_id uuid, p_now timestamptz)
returns bigint language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_usage public.bloom_usage_sessions%rowtype;
  v_end timestamptz;
  v_used_ms bigint;
  v_spent numeric;
begin
  select * into v_usage from public.bloom_usage_sessions
    where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception 'Screen-time reservation not found'; end if;
  if v_usage.settled_at is not null then return v_usage.used_ms; end if;

  if v_usage.billing_started_at is null then
    -- Existing foreground-measured grants cannot be reconstructed reliably.
    -- Close them without retroactively charging an unverifiable interval.
    v_used_ms := 0;
  else
    v_end := greatest(v_usage.billing_started_at, least(p_now, v_usage.access_expires_at));
    v_used_ms := least(v_usage.reserved_ms,
      floor(greatest(0, extract(epoch from (v_end - v_usage.billing_started_at)) * 1000))::bigint);
  end if;
  v_spent := trunc(v_used_ms::numeric / 60000, 4);
  if v_spent > 0 then
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at, created_at)
      values (p_user_id, -v_spent, 'spent', 'usage:' || v_usage.id::text, v_usage.expires_at,
        least(p_now, v_usage.expires_at - interval '1 microsecond'))
      on conflict (user_id, idempotency_key) do nothing;
  end if;
  update public.bloom_usage_sessions set settled_at = p_now, used_ms = v_used_ms where id = v_usage.id;
  return v_used_ms;
end;
$$;
revoke all on function bloom_private.settle_usage_session(uuid, uuid, timestamptz) from public, anon, authenticated;

create or replace function public.bloom_credit_balance()
returns numeric language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select coalesce((select sum(l.amount_minutes) from public.bloom_credit_ledger l
    where l.user_id = auth.uid() and l.expires_at > now()), 0)
    - coalesce((select sum(
        case when s.access_expires_at > now() then s.reserved_ms::numeric / 60000
          when s.billing_started_at is null then 0
          else least(s.reserved_ms::numeric,
            floor(greatest(0, extract(epoch from (least(now(), s.access_expires_at) - s.billing_started_at)) * 1000))) / 60000 end
      ) from public.bloom_usage_sessions s
      where s.user_id = auth.uid() and s.settled_at is null and s.expires_at > now()), 0)
    - coalesce((select sum(round(greatest(0, extract(epoch from (least(now(), s.ends_at) - s.started_at))) / 60, 4))
      from public.bloom_credit_sessions s where s.user_id = auth.uid() and s.settled_at is null and s.expires_at > now()), 0);
$$;

create or replace function bloom_private.parent_child_balance(p_child_id uuid)
returns numeric language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
begin
  if auth.uid() is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  return coalesce((select sum(l.amount_minutes) from public.bloom_credit_ledger l
      where l.user_id = p_child_id and l.expires_at > now()), 0)
    - coalesce((select sum(case when s.access_expires_at > now() then s.reserved_ms::numeric / 60000
          when s.billing_started_at is null then 0
          else least(s.reserved_ms::numeric,
            floor(greatest(0, extract(epoch from (least(now(), s.access_expires_at) - s.billing_started_at)) * 1000))) / 60000 end)
      from public.bloom_usage_sessions s where s.user_id = p_child_id and s.settled_at is null and s.expires_at > now()), 0)
    - coalesce((select sum(round(greatest(0, extract(epoch from (least(now(), s.ends_at) - s.started_at))) / 60, 4))
      from public.bloom_credit_sessions s where s.user_id = p_child_id and s.settled_at is null and s.expires_at > now()), 0);
end;
$$;

create or replace function bloom_private.start_usage_session(p_request_id uuid, p_device_key uuid, p_requested_ms bigint)
returns table(session_id uuid, reserved_ms bigint, expiry_remaining_ms bigint)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_settings public.bloom_settings%rowtype;
  v_usage public.bloom_usage_sessions%rowtype;
  v_countdown public.bloom_credit_sessions%rowtype;
  v_now timestamptz;
  v_balance numeric;
  v_bucket numeric;
  v_expiry timestamptz;
  v_reserved bigint;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  if p_request_id is null or p_device_key is null or p_requested_ms is null or p_requested_ms < 1000 or p_requested_ms > 604800000 then
    raise exception 'Choose a valid screen-time amount';
  end if;
  select * into v_settings from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  v_now := clock_timestamp();

  select * into v_usage from public.bloom_usage_sessions where user_id = v_user and request_id = p_request_id for update;
  if found then
    if not exists (select 1 from bloom_private.usage_device_keys k where k.session_id = v_usage.id
      and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8'))) then
      raise exception 'Screen-time reservation belongs to another device';
    end if;
    if v_usage.requested_ms <> p_requested_ms then raise exception 'Screen-time reservation request was already used'; end if;
    if v_usage.settled_at is not null then raise exception 'Screen-time reservation has ended'; end if;
    if v_usage.access_expires_at <= v_now then
      perform bloom_private.settle_usage_session(v_user, v_usage.id, v_now);
      return query select v_usage.id, v_usage.reserved_ms, 0::bigint;
      return;
    end if;
    return query select v_usage.id, v_usage.reserved_ms,
      floor(extract(epoch from (v_usage.access_expires_at - v_now)) * 1000)::bigint;
    return;
  end if;

  if not v_settings.credits_enabled or v_settings.credit_mode <> 'easy' then raise exception 'Easy mode is not enabled'; end if;
  select * into v_countdown from public.bloom_credit_sessions where user_id = v_user and settled_at is null for update;
  if found then
    if v_countdown.ends_at > v_now then raise exception 'A screen-time session is already running'; end if;
    perform bloom_private.settle_credit_session(v_user, v_countdown.id, v_now);
  end if;
  for v_usage in select * from public.bloom_usage_sessions
      where user_id = v_user and settled_at is null for update
  loop
    if v_usage.access_expires_at > v_now then raise exception 'A screen-time reservation is already active on another device'; end if;
    perform bloom_private.settle_usage_session(v_user, v_usage.id, v_now);
  end loop;

  select coalesce(sum(amount_minutes), 0) into v_balance from public.bloom_credit_ledger
    where user_id = v_user and expires_at > v_now;
  select l.expires_at, sum(l.amount_minutes) into v_expiry, v_bucket from public.bloom_credit_ledger l
    where l.user_id = v_user and l.expires_at > v_now group by l.expires_at
    having sum(l.amount_minutes) * 60000 >= 1000 order by l.expires_at limit 1;
  v_reserved := floor(greatest(0, least(p_requested_ms::numeric, v_balance * 60000, coalesce(v_bucket, 0) * 60000)))::bigint;
  if v_reserved < 1000 then raise exception 'No screen time is available'; end if;
  insert into public.bloom_usage_sessions(user_id, request_id, requested_ms, reserved_ms, started_at, expires_at, access_expires_at, billing_started_at)
    values (v_user, p_request_id, p_requested_ms, v_reserved, v_now, v_expiry,
      least(v_expiry, v_now + make_interval(secs => v_reserved::double precision / 1000)), v_now)
    returning * into v_usage;
  insert into bloom_private.usage_device_keys(session_id, key_hash)
    values (v_usage.id, sha256(convert_to(p_device_key::text, 'UTF8')));
  return query select v_usage.id, v_usage.reserved_ms,
    floor(extract(epoch from (v_usage.access_expires_at - v_now)) * 1000)::bigint;
end;
$$;

drop function if exists public.bloom_finish_usage_session(uuid, uuid, bigint);
drop function if exists bloom_private.finish_usage_session(uuid, uuid, bigint);
create function bloom_private.finish_usage_session(p_session_id uuid, p_device_key uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_usage public.bloom_usage_sessions%rowtype;
begin
  if v_user is null then raise exception 'Sign in to use screen time'; end if;
  perform 1 from public.bloom_settings where user_id = v_user for update;
  if not found then raise exception 'Screen-time settings not found'; end if;
  select * into v_usage from public.bloom_usage_sessions
    where id = p_session_id and user_id = v_user for update;
  if not found then raise exception 'Screen-time reservation not found'; end if;
  if p_device_key is null or not exists (select 1 from bloom_private.usage_device_keys k where k.session_id = v_usage.id
      and k.key_hash = sha256(convert_to(p_device_key::text, 'UTF8'))) then
    raise exception 'Screen-time reservation belongs to another device';
  end if;
  perform bloom_private.settle_usage_session(v_user, v_usage.id, clock_timestamp());
end;
$$;
revoke all on function bloom_private.start_usage_session(uuid, uuid, bigint), bloom_private.finish_usage_session(uuid, uuid) from public, anon;
grant execute on function bloom_private.start_usage_session(uuid, uuid, bigint), bloom_private.finish_usage_session(uuid, uuid) to authenticated;

create or replace function public.bloom_start_usage_session(p_request_id uuid, p_device_key uuid, p_requested_ms bigint)
returns table(session_id uuid, reserved_ms bigint, expiry_remaining_ms bigint)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.start_usage_session(p_request_id, p_device_key, p_requested_ms);
$$;

create function public.bloom_finish_usage_session(p_session_id uuid, p_device_key uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.finish_usage_session(p_session_id, p_device_key);
$$;

-- Keep old clients callable during rollout, but deliberately ignore their
-- self-reported duration. The database clock is authoritative for every row.
create or replace function public.bloom_finish_usage_session(p_session_id uuid, p_device_key uuid, p_used_ms bigint)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.finish_usage_session(p_session_id, p_device_key);
$$;

revoke all on function public.bloom_start_usage_session(uuid, uuid, bigint),
  public.bloom_finish_usage_session(uuid, uuid), public.bloom_finish_usage_session(uuid, uuid, bigint)
  from public, anon;
grant execute on function public.bloom_start_usage_session(uuid, uuid, bigint),
  public.bloom_finish_usage_session(uuid, uuid), public.bloom_finish_usage_session(uuid, uuid, bigint)
  to authenticated;

create or replace function bloom_private.guard_open_usage_reservation()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_usage public.bloom_usage_sessions%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  for v_usage in select * from public.bloom_usage_sessions
      where user_id = new.user_id and settled_at is null for update
  loop
    if v_usage.access_expires_at > v_now then raise exception 'Finish the active screen-time session first'; end if;
    perform bloom_private.settle_usage_session(new.user_id, v_usage.id, v_now);
  end loop;
  return new;
end;
$$;
revoke all on function bloom_private.guard_open_usage_reservation() from public, anon, authenticated;

create or replace function bloom_private.guard_running_credit_session()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_usage public.bloom_usage_sessions%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if (new.credit_mode, new.credit_timezone, new.super_daily_cap_minutes, new.credits_enabled)
       is distinct from (old.credit_mode, old.credit_timezone, old.super_daily_cap_minutes, old.credits_enabled) then
    if exists (select 1 from public.bloom_credit_sessions s where s.user_id = old.user_id
        and s.settled_at is null and s.ends_at > v_now) then
      raise exception 'Stop the active screen-time session before changing these settings';
    end if;
    for v_usage in select * from public.bloom_usage_sessions
        where user_id = old.user_id and settled_at is null for update
    loop
      if v_usage.access_expires_at > v_now then raise exception 'Stop the active screen-time session before changing these settings'; end if;
      perform bloom_private.settle_usage_session(old.user_id, v_usage.id, v_now);
    end loop;
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.guard_running_credit_session() from public, anon, authenticated;

comment on column public.bloom_usage_sessions.access_expires_at is
  'Server-authoritative end of the Easy access window: min(started_at + reserved_ms, credit bucket expires_at).';
comment on column public.bloom_usage_sessions.billing_started_at is
  'Null for pre-migration foreground-measured grants, which close without retroactive debit; set from the server clock for new grants.';
comment on function public.bloom_finish_usage_session(uuid, uuid, bigint) is
  'Compatibility overload. p_used_ms is ignored; settlement uses server elapsed time.';

commit;
