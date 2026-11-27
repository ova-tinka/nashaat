begin;

alter table public.bloom_workout_sessions
  add column if not exists offline_self_reported boolean not null default false,
  add column if not exists client_activity_id uuid;

create unique index if not exists bloom_workout_sessions_offline_id_idx
  on public.bloom_workout_sessions(user_id, client_activity_id)
  where client_activity_id is not null;

alter table public.bloom_growth_sessions
  add column if not exists offline_self_reported boolean not null default false;

create or replace function bloom_private.record_growth_reward()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid;
  v_module text;
  v_source_type text;
  v_source_id uuid;
  v_rule public.bloom_growth_reward_rules%rowtype;
  v_credit public.bloom_settings%rowtype;
  v_event_id uuid;
begin
  if tg_table_name = 'bloom_growth_sessions' then
    if old.status = new.status or new.status <> 'completed' then return new; end if;
    if new.offline_self_reported is true then return new; end if;
    v_profile := new.profile_id; v_module := new.module_id; v_source_type := 'session'; v_source_id := new.id;
  else
    if old.state = new.state or new.state <> 'completed' or new.module_id <> 'tasks' or new.item_type <> 'task' then return new; end if;
    v_profile := new.profile_id; v_module := new.module_id; v_source_type := 'task'; v_source_id := new.id;
  end if;
  select * into v_rule from public.bloom_growth_reward_rules r
    where r.profile_id = v_profile and r.module_id = v_module;
  if not found or not v_rule.enabled then return new; end if;
  select * into v_credit from public.bloom_settings s where s.user_id = v_profile;
  if not found or not v_credit.credits_enabled then return new; end if;
  if v_source_type = 'session' then
    if new.duration_seconds < v_rule.minimum_session_minutes * 60 then return new; end if;
  end if;
  if v_rule.require_parent_approval and not bloom_private.is_child_profile(v_profile) then return new; end if;
  insert into public.bloom_growth_reward_events(profile_id, module_id, source_type, source_id, requested_minutes)
    values (v_profile, v_module, v_source_type, v_source_id, v_rule.reward_minutes)
    on conflict (profile_id, module_id, source_type, source_id) do nothing returning id into v_event_id;
  if v_event_id is null then return new; end if;
  if not v_rule.require_parent_approval then perform bloom_private.award_growth_reward(v_event_id); end if;
  return new;
end;
$$;

create or replace function bloom_private.sync_offline_workout(
  p_activity_id uuid,
  p_plan_id uuid,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_seconds integer,
  p_results jsonb
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_existing public.bloom_workout_sessions%rowtype;
  v_plan public.bloom_workout_plans%rowtype;
  v_snapshot jsonb;
  v_session_id uuid;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'exercise') then
    raise exception 'Exercise access is required' using errcode = '42501';
  end if;
  if p_activity_id is null or p_started_at is null or p_completed_at is null
    or p_completed_at < p_started_at
    or p_duration_seconds is null or p_duration_seconds not between 1 and 43200
    or p_results is null or jsonb_typeof(p_results) <> 'array'
    or jsonb_array_length(p_results) not between 1 and 100 then
    raise exception 'Invalid offline workout activity';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-offline-workout:' || v_profile::text || ':' || p_activity_id::text, 0));

  select * into v_existing
  from public.bloom_workout_sessions s
  where s.user_id = v_profile and s.client_activity_id = p_activity_id;
  if found then
    return jsonb_build_object(
      'session_id', v_existing.id,
      'status', 'accepted',
      'duplicate', true,
      'credits_earned_minutes', 0,
      'duration_seconds', v_existing.active_duration_seconds
    );
  end if;

  select * into v_plan
  from public.bloom_workout_plans p
  where p.id = p_plan_id and p.user_id = v_profile;

  if found then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'exercise_id', pe.exercise_id,
          'name', e.name,
          'measurement_type', e.measurement_type,
          'sets', pe.sets,
          'target_reps', pe.target_reps,
          'target_seconds', pe.target_seconds,
          'target_weight_kg', pe.target_weight_kg,
          'target_distance_km', pe.target_distance_km
        )
        order by pe.position
      ),
      '[]'::jsonb
    ) into v_snapshot
    from public.bloom_plan_exercises pe
    join public.exercises e on e.id = pe.exercise_id
    where pe.plan_id = v_plan.id;
  else
    v_snapshot := '[]'::jsonb;
  end if;

  insert into public.bloom_workout_sessions(
    user_id,
    plan_id,
    plan_snapshot,
    status,
    started_at,
    completed_at,
    active_duration_seconds,
    credits_enabled_at_completion,
    credits_earned_minutes,
    exercise_results,
    offline_self_reported,
    client_activity_id
  ) values (
    v_profile,
    case when v_plan.id is not null then v_plan.id else null end,
    coalesce(v_snapshot, '[]'::jsonb),
    'completed',
    p_started_at,
    p_completed_at,
    p_duration_seconds,
    false,
    0,
    p_results,
    true,
    p_activity_id
  )
  returning id into v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'status', 'accepted',
    'duplicate', false,
    'credits_earned_minutes', 0,
    'duration_seconds', p_duration_seconds
  );
end;
$$;

create or replace function bloom_private.sync_offline_growth_session(
  p_activity_id uuid,
  p_module_id text,
  p_item_id uuid,
  p_source_device_id uuid,
  p_source_device_name text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_seconds integer
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_existing public.bloom_growth_sessions%rowtype;
  v_item public.bloom_growth_items%rowtype;
  v_session_id uuid;
begin
  if v_profile is null or p_module_id not in ('study', 'read')
    or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'Module access is required' using errcode = '42501';
  end if;
  if p_activity_id is null or p_item_id is null or p_source_device_id is null
    or p_source_device_name is null or char_length(trim(p_source_device_name)) not between 1 and 80
    or p_started_at is null or p_completed_at is null or p_completed_at < p_started_at
    or p_duration_seconds is null or p_duration_seconds not between 1 and 43200 then
    raise exception 'Invalid offline session activity';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-session:' || v_profile::text || ':' || p_activity_id::text, 0));

  select * into v_existing
  from public.bloom_growth_sessions s
  where s.profile_id = v_profile and s.request_id = p_activity_id;
  if found then
    return jsonb_build_object(
      'session_id', v_existing.id,
      'status', 'accepted',
      'duplicate', true,
      'credits_earned_minutes', 0,
      'duration_seconds', v_existing.duration_seconds
    );
  end if;

  select * into v_item
  from public.bloom_growth_items i
  where i.id = p_item_id and i.profile_id = v_profile and i.module_id = p_module_id;
  if not found then
    raise exception 'Item not found' using errcode = '42501';
  end if;

  insert into public.bloom_growth_sessions(
    profile_id,
    module_id,
    item_id,
    source_device_id,
    source_device_name,
    request_id,
    status,
    started_at,
    completed_at,
    duration_seconds,
    offline_self_reported
  ) values (
    v_profile,
    p_module_id,
    p_item_id,
    p_source_device_id,
    trim(p_source_device_name),
    p_activity_id,
    'completed',
    p_started_at,
    p_completed_at,
    p_duration_seconds,
    true
  )
  returning id into v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'status', 'accepted',
    'duplicate', false,
    'credits_earned_minutes', 0,
    'duration_seconds', p_duration_seconds
  );
end;
$$;

create or replace function bloom_private.sync_offline_task_completion(
  p_activity_id uuid,
  p_item_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'tasks') then
    raise exception 'Tasks access is required' using errcode = '42501';
  end if;
  if p_activity_id is null or p_item_id is null then
    raise exception 'Invalid offline task completion';
  end if;

  select * into v_item
  from public.bloom_growth_items i
  where i.id = p_item_id
    and i.profile_id = v_profile
    and i.module_id = 'tasks'
    and i.item_type = 'task'
  for update;
  if not found then
    raise exception 'Task not found' using errcode = '42501';
  end if;

  if v_item.state = 'archived' then
    return jsonb_build_object('item_id', v_item.id, 'status', 'archived', 'duplicate', false);
  end if;
  if v_item.state = 'completed' then
    return jsonb_build_object('item_id', v_item.id, 'status', 'accepted', 'duplicate', true);
  end if;

  update public.bloom_growth_items
  set state = 'completed',
      completed_at = coalesce(completed_at, clock_timestamp()),
      progress_percent = 100,
      updated_at = clock_timestamp()
  where id = v_item.id;

  return jsonb_build_object('item_id', v_item.id, 'status', 'accepted', 'duplicate', false);
end;
$$;

create or replace function public.bloom_sync_offline_workout(
  p_activity_id uuid,
  p_plan_id uuid,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_seconds integer,
  p_results jsonb
) returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.sync_offline_workout(p_activity_id, p_plan_id, p_started_at, p_completed_at, p_duration_seconds, p_results);
$$;

create or replace function public.bloom_sync_offline_growth_session(
  p_activity_id uuid,
  p_module_id text,
  p_item_id uuid,
  p_source_device_id uuid,
  p_source_device_name text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_seconds integer
) returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.sync_offline_growth_session(p_activity_id, p_module_id, p_item_id, p_source_device_id, p_source_device_name, p_started_at, p_completed_at, p_duration_seconds);
$$;

create or replace function public.bloom_sync_offline_task_completion(
  p_activity_id uuid,
  p_item_id uuid
) returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.sync_offline_task_completion(p_activity_id, p_item_id);
$$;

revoke all on function bloom_private.sync_offline_workout(uuid, uuid, timestamptz, timestamptz, integer, jsonb),
  bloom_private.sync_offline_growth_session(uuid, text, uuid, uuid, text, timestamptz, timestamptz, integer),
  bloom_private.sync_offline_task_completion(uuid, uuid),
  public.bloom_sync_offline_workout(uuid, uuid, timestamptz, timestamptz, integer, jsonb),
  public.bloom_sync_offline_growth_session(uuid, text, uuid, uuid, text, timestamptz, timestamptz, integer),
  public.bloom_sync_offline_task_completion(uuid, uuid)
  from public, anon;

grant execute on function bloom_private.sync_offline_workout(uuid, uuid, timestamptz, timestamptz, integer, jsonb),
  bloom_private.sync_offline_growth_session(uuid, text, uuid, uuid, text, timestamptz, timestamptz, integer),
  bloom_private.sync_offline_task_completion(uuid, uuid),
  public.bloom_sync_offline_workout(uuid, uuid, timestamptz, timestamptz, integer, jsonb),
  public.bloom_sync_offline_growth_session(uuid, text, uuid, uuid, text, timestamptz, timestamptz, integer),
  public.bloom_sync_offline_task_completion(uuid, uuid)
  to authenticated;

commit;
