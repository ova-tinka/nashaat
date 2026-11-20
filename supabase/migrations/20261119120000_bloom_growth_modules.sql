begin;

create table public.bloom_growth_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  item_type text not null check (item_type in ('subject', 'reading', 'task')),
  title text not null check (char_length(trim(title)) between 1 and 120),
  notes text not null default '' check (char_length(notes) <= 2000),
  state text not null default 'active' check (state in ('active', 'completed', 'archived')),
  completed_at timestamptz,
  due_date date,
  target_minutes integer check (target_minutes is null or target_minutes between 1 and 10080),
  progress_percent numeric(5,2) not null default 0 check (progress_percent between 0 and 100),
  request_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (profile_id, request_id),
  check (state <> 'completed' or completed_at is not null),
  check (
    (module_id = 'study' and item_type = 'subject' and target_minutes is not null and due_date is null)
    or (module_id = 'read' and item_type = 'reading' and target_minutes is null and due_date is null)
    or (module_id = 'tasks' and item_type = 'task' and target_minutes is null)
  )
);
create index bloom_growth_items_profile_module_state_idx
  on public.bloom_growth_items(profile_id, module_id, state, updated_at desc);

create table public.bloom_growth_sessions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read')),
  item_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  source_device_id uuid not null,
  source_device_name text not null check (char_length(trim(source_device_name)) between 1 and 80),
  request_id uuid not null,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'cancelled')),
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds between 0 and 43200),
  unique (profile_id, request_id),
  check ((status = 'completed') = (completed_at is not null)),
  check ((status = 'completed') = (duration_seconds is not null))
);
create unique index bloom_growth_one_running_session_idx
  on public.bloom_growth_sessions(profile_id, module_id) where status = 'in_progress';
create index bloom_growth_sessions_profile_module_idx
  on public.bloom_growth_sessions(profile_id, module_id, started_at desc);

alter table public.bloom_growth_items enable row level security;
alter table public.bloom_growth_sessions enable row level security;
revoke all on public.bloom_growth_items, public.bloom_growth_sessions from public, anon, authenticated;
grant select on public.bloom_growth_items, public.bloom_growth_sessions to authenticated;

create policy bloom_growth_items_read on public.bloom_growth_items for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(profile_id, module_id));
create policy bloom_growth_sessions_read on public.bloom_growth_sessions for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(profile_id, module_id));

create or replace function bloom_private.module_is_available(p_module_id text)
returns boolean language sql immutable security definer set search_path = pg_catalog, pg_temp as $$
  select p_module_id in ('exercise', 'study', 'read', 'tasks');
$$;
revoke all on function bloom_private.module_is_available(text) from public, anon, authenticated;

create function bloom_private.create_growth_item(
  p_module_id text, p_item_type text, p_title text, p_notes text, p_due_date date,
  p_target_minutes integer, p_request_id uuid
) returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to save this item'; end if;
  if p_module_id not in ('study', 'read', 'tasks') or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'This module is not assigned to the active profile' using errcode = '42501';
  end if;
  if p_request_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 120
    or p_notes is null or char_length(p_notes) > 2000 then raise exception 'Check the item details'; end if;
  if (p_module_id = 'study' and (p_item_type <> 'subject' or p_due_date is not null or p_target_minutes is null or p_target_minutes not between 1 and 10080))
    or (p_module_id = 'read' and (p_item_type <> 'reading' or p_due_date is not null or p_target_minutes is not null))
    or (p_module_id = 'tasks' and (p_item_type <> 'task' or p_target_minutes is not null)) then
    raise exception 'Item type or details are not valid for this module';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-item:' || v_profile::text || ':' || p_request_id::text, 0));
  select * into v_item from public.bloom_growth_items i where i.profile_id = v_profile and i.request_id = p_request_id;
  if found then
    if (v_item.module_id, v_item.item_type, v_item.title, v_item.notes, v_item.due_date, v_item.target_minutes)
      is distinct from (p_module_id, p_item_type, trim(p_title), p_notes, p_due_date, p_target_minutes) then
      raise exception 'Request was already used for a different item';
    end if;
    return v_item.id;
  end if;
  insert into public.bloom_growth_items(profile_id, module_id, item_type, title, notes, due_date, target_minutes, request_id)
    values (v_profile, p_module_id, p_item_type, trim(p_title), p_notes, p_due_date, p_target_minutes, p_request_id)
    returning * into v_item;
  return v_item.id;
end;
$$;

create function bloom_private.update_growth_item(
  p_item_id uuid, p_title text, p_notes text, p_due_date date,
  p_state text, p_progress_percent numeric
) returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to update this item'; end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_item.module_id) then
    raise exception 'Item not found or module access is not assigned' using errcode = '42501';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 1 and 120 or p_notes is null or char_length(p_notes) > 2000
    or p_state not in ('active', 'completed', 'archived') or p_progress_percent is null or p_progress_percent not between 0 and 100 then
    raise exception 'Check the item details';
  end if;
  if v_item.module_id <> 'tasks' and p_due_date is not null then raise exception 'Due dates are only available for Tasks'; end if;
  update public.bloom_growth_items set title = trim(p_title), notes = p_notes, due_date = p_due_date,
    completed_at = case when p_state = 'completed' then coalesce(v_item.completed_at, clock_timestamp()) else null end,
    state = p_state, progress_percent = p_progress_percent, updated_at = clock_timestamp()
    where id = p_item_id;
end;
$$;

create function bloom_private.start_growth_session(
  p_module_id text, p_item_id uuid, p_source_device_id uuid, p_source_device_name text, p_request_id uuid
)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_session public.bloom_growth_sessions%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to start a session'; end if;
  if p_module_id not in ('study', 'read') or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'This module is not assigned to the active profile' using errcode = '42501';
  end if;
  if p_request_id is null or p_source_device_id is null or p_source_device_name is null
    or char_length(trim(p_source_device_name)) not between 1 and 80 then
    raise exception 'A valid session request and source device are required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-session:' || v_profile::text || ':' || p_request_id::text, 0));
  select * into v_session from public.bloom_growth_sessions s where s.profile_id = v_profile and s.request_id = p_request_id;
  if found then
    if (v_session.module_id, v_session.item_id, v_session.source_device_id, v_session.source_device_name)
      is distinct from (p_module_id, p_item_id, p_source_device_id, trim(p_source_device_name)) then
      raise exception 'Request was already used for another session';
    end if;
    return v_session.id;
  end if;
  perform 1 from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = p_module_id and i.state = 'active' for share;
  if not found then raise exception 'Choose an active subject or reading item'; end if;
  if exists (select 1 from public.bloom_growth_sessions s where s.profile_id = v_profile and s.module_id = p_module_id and s.status = 'in_progress') then
    raise exception 'Finish or cancel the active session first';
  end if;
  insert into public.bloom_growth_sessions(profile_id, module_id, item_id, source_device_id, source_device_name, request_id)
    values (v_profile, p_module_id, p_item_id, p_source_device_id, trim(p_source_device_name), p_request_id)
    returning id into v_session.id;
  return v_session.id;
end;
$$;

create function bloom_private.finish_growth_session(p_session_id uuid)
returns table(duration_seconds integer, completed_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_session public.bloom_growth_sessions%rowtype; v_now timestamptz;
begin
  if v_profile is null then raise exception 'Sign in to finish this session'; end if;
  select * into v_session from public.bloom_growth_sessions s where s.id = p_session_id and s.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_session.module_id) then
    raise exception 'Session not found or module access is not assigned' using errcode = '42501';
  end if;
  if v_session.status = 'completed' then return query select v_session.duration_seconds, v_session.completed_at; return; end if;
  if v_session.status <> 'in_progress' then raise exception 'This session was cancelled'; end if;
  v_now := clock_timestamp();
  if v_now - v_session.started_at > interval '12 hours' then raise exception 'This session has expired; cancel it and start a new one'; end if;
  update public.bloom_growth_sessions s set status = 'completed', completed_at = v_now,
    duration_seconds = greatest(0, floor(extract(epoch from v_now - s.started_at))::integer)
    where s.id = p_session_id returning s.duration_seconds, s.completed_at into duration_seconds, completed_at;
  return next;
end;
$$;

create function bloom_private.cancel_growth_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_module text;
begin
  if v_profile is null then raise exception 'Sign in to cancel this session'; end if;
  select s.module_id into v_module from public.bloom_growth_sessions s
    where s.id = p_session_id and s.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_module) then
    raise exception 'Session not found or module access is not assigned' using errcode = '42501';
  end if;
  update public.bloom_growth_sessions set status = 'cancelled' where id = p_session_id and status = 'in_progress';
end;
$$;

create function bloom_private.growth_overview()
returns table(module_id text, active_items integer, completed_items integer, sessions_this_week integer,
  minutes_this_week numeric, average_read_progress numeric, due_today integer)
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_timezone text;
  v_local_now timestamp;
  v_week_start timestamptz;
  v_local_date date;
begin
  if v_profile is null then raise exception 'Sign in to view module progress'; end if;
  select coalesce(nullif(s.credit_timezone, ''), 'UTC') into v_timezone
    from public.bloom_settings s where s.user_id = v_profile;
  v_timezone := coalesce(v_timezone, 'UTC');
  v_local_now := timezone(v_timezone, clock_timestamp());
  v_local_date := v_local_now::date;
  v_week_start := date_trunc('week', v_local_now) at time zone v_timezone;

  return query
  with modules as (
    select unnest(array['study', 'read', 'tasks']::text[]) as id
  ), items as (
    select i.module_id,
      count(*) filter (where i.state = 'active')::integer as active_count,
      count(*) filter (where i.state = 'completed')::integer as completed_count,
      round(avg(i.progress_percent) filter (where i.state = 'active' and i.module_id = 'read'), 1) as read_progress,
      count(*) filter (where i.module_id = 'tasks' and i.state = 'active' and i.due_date <= v_local_date)::integer as due_count
    from public.bloom_growth_items i where i.profile_id = v_profile group by i.module_id
  ), sessions as (
    select s.module_id, count(*)::integer as session_count,
      round(coalesce(sum(s.duration_seconds), 0) / 60.0, 1) as minutes
    from public.bloom_growth_sessions s
    where s.profile_id = v_profile and s.status = 'completed' and s.started_at >= v_week_start
    group by s.module_id
  )
  select m.id, coalesce(i.active_count, 0), coalesce(i.completed_count, 0), coalesce(s.session_count, 0),
    coalesce(s.minutes, 0), i.read_progress, coalesce(i.due_count, 0)
  from modules m
  left join items i on i.module_id = m.id
  left join sessions s on s.module_id = m.id
  where bloom_private.has_module_access(v_profile, m.id)
  order by array_position(array['study', 'read', 'tasks']::text[], m.id);
end;
$$;

create function public.bloom_create_growth_item(p_module_id text, p_item_type text, p_title text, p_notes text,
  p_due_date date, p_target_minutes integer, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_growth_item(p_module_id, p_item_type, p_title, p_notes, p_due_date, p_target_minutes, p_request_id);
$$;
create function public.bloom_update_growth_item(p_item_id uuid, p_title text, p_notes text, p_due_date date,
  p_state text, p_progress_percent numeric)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_growth_item(p_item_id, p_title, p_notes, p_due_date, p_state, p_progress_percent);
$$;
create function public.bloom_start_growth_session(
  p_module_id text, p_item_id uuid, p_source_device_id uuid, p_source_device_name text, p_request_id uuid
)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.start_growth_session(p_module_id, p_item_id, p_source_device_id, p_source_device_name, p_request_id);
$$;
create function public.bloom_finish_growth_session(p_session_id uuid)
returns table(duration_seconds integer, completed_at timestamptz)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.finish_growth_session(p_session_id);
$$;
create function public.bloom_cancel_growth_session(p_session_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.cancel_growth_session(p_session_id);
$$;
create function public.bloom_growth_overview()
returns table(module_id text, active_items integer, completed_items integer, sessions_this_week integer,
  minutes_this_week numeric, average_read_progress numeric, due_today integer)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.growth_overview();
$$;

revoke all on function bloom_private.create_growth_item(text, text, text, text, date, integer, uuid),
  bloom_private.update_growth_item(uuid, text, text, date, text, numeric),
  bloom_private.start_growth_session(text, uuid, uuid, text, uuid), bloom_private.finish_growth_session(uuid),
  bloom_private.cancel_growth_session(uuid), bloom_private.growth_overview() from public, anon, authenticated;
grant execute on function bloom_private.create_growth_item(text, text, text, text, date, integer, uuid),
  bloom_private.update_growth_item(uuid, text, text, date, text, numeric),
  bloom_private.start_growth_session(text, uuid, uuid, text, uuid), bloom_private.finish_growth_session(uuid),
  bloom_private.cancel_growth_session(uuid), bloom_private.growth_overview() to authenticated;
revoke all on function public.bloom_create_growth_item(text, text, text, text, date, integer, uuid),
  public.bloom_update_growth_item(uuid, text, text, date, text, numeric),
  public.bloom_start_growth_session(text, uuid, uuid, text, uuid), public.bloom_finish_growth_session(uuid),
  public.bloom_cancel_growth_session(uuid), public.bloom_growth_overview() from public, anon;
grant execute on function public.bloom_create_growth_item(text, text, text, text, date, integer, uuid),
  public.bloom_update_growth_item(uuid, text, text, date, text, numeric),
  public.bloom_start_growth_session(text, uuid, uuid, text, uuid), public.bloom_finish_growth_session(uuid),
  public.bloom_cancel_growth_session(uuid), public.bloom_growth_overview() to authenticated;

commit;
