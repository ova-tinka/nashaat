begin;

create table public.bloom_coach_settings (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  sharing_consent boolean not null default false,
  adult_attested boolean not null default false,
  parent_enabled boolean not null default false,
  parent_sharing_consent boolean not null default false,
  minor_eligible_attested boolean not null default false,
  goals text not null default '' check (char_length(goals) <= 1000),
  experience text not null default 'beginner' check (experience in ('beginner', 'intermediate', 'experienced')),
  equipment text[] not null default '{}' check (cardinality(equipment) <= 20),
  updated_at timestamptz not null default now()
);
create table public.bloom_coach_messages (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  request_id uuid not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 4000),
  created_at timestamptz not null default now(),
  unique (request_id, role)
);
create index bloom_coach_messages_profile_idx on public.bloom_coach_messages(profile_id, created_at desc);
create table public.bloom_coach_proposals (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  request_id uuid not null unique,
  proposal jsonb not null,
  base_plan_id uuid references public.bloom_workout_plans(id) on delete set null,
  base_updated_at timestamptz,
  base_revision text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  result_plan_id uuid references public.bloom_workout_plans(id) on delete set null,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index bloom_coach_proposals_profile_idx on public.bloom_coach_proposals(profile_id, created_at desc);
create table bloom_private.coach_requests (
  id uuid primary key,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  request_kind text not null check (request_kind in ('chat', 'weekly')),
  prompt text not null,
  status text not null default 'pending' check (status in ('pending', 'completed', 'failed')),
  created_at timestamptz not null default now()
);
create index bloom_coach_requests_limit_idx on bloom_private.coach_requests(profile_id, created_at desc);
revoke all on bloom_private.coach_requests from public, anon, authenticated;

alter table public.bloom_coach_settings enable row level security;
alter table public.bloom_coach_messages enable row level security;
alter table public.bloom_coach_proposals enable row level security;
revoke all on public.bloom_coach_settings, public.bloom_coach_messages, public.bloom_coach_proposals from public, anon, authenticated;
grant select on public.bloom_coach_settings, public.bloom_coach_messages, public.bloom_coach_proposals to authenticated;
create policy bloom_coach_settings_own on public.bloom_coach_settings for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));
create policy bloom_coach_messages_own on public.bloom_coach_messages for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));
create policy bloom_coach_proposals_own on public.bloom_coach_proposals for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));

create function bloom_private.is_child_profile(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p_profile_id is not null and (exists (select 1 from public.bloom_child_profiles c where c.profile_id = p_profile_id)
    or exists (select 1 from public.bloom_household_members m where m.user_id = p_profile_id and m.role = 'child'));
$$;
revoke all on function bloom_private.is_child_profile(uuid) from public, anon, authenticated;
create function bloom_private.current_is_child()
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select bloom_private.is_child_profile(bloom_private.current_profile_id());
$$;
revoke all on function bloom_private.current_is_child() from public, anon;
grant execute on function bloom_private.current_is_child() to authenticated;
create or replace function public.bloom_current_profile()
returns jsonb language plpgsql stable security invoker set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if auth.uid() is null or v_profile is null then raise exception 'Profile unavailable'; end if;
  return jsonb_build_object('profile_id', v_profile, 'managed_child', bloom_private.is_managed_child(), 'child_profile', bloom_private.current_is_child());
end;
$$;

create function bloom_private.set_coach_preferences(p_consent boolean, p_adult_attested boolean, p_goals text, p_experience text, p_equipment text[])
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_equipment text[] := coalesce(p_equipment, '{}'::text[]);
begin
  if v_profile is null then raise exception 'Sign in to manage coaching'; end if;
  if p_consent is null or p_adult_attested is null or p_goals is null or char_length(p_goals) > 1000
    or p_experience is null or p_experience not in ('beginner', 'intermediate', 'experienced') or cardinality(v_equipment) > 20
    or exists (select 1 from unnest(v_equipment) e where e is null or char_length(trim(e)) not between 1 and 60) then
    raise exception 'Invalid coaching preferences';
  end if;
  if bloom_private.is_child_profile(v_profile) and p_adult_attested then raise exception 'A parent must manage child eligibility'; end if;
  insert into public.bloom_coach_settings(profile_id, sharing_consent, adult_attested, goals, experience, equipment)
    values (v_profile, p_consent, p_adult_attested, trim(p_goals), p_experience, v_equipment)
    on conflict (profile_id) do update set sharing_consent = excluded.sharing_consent, adult_attested = excluded.adult_attested,
      goals = excluded.goals, experience = excluded.experience, equipment = excluded.equipment, updated_at = clock_timestamp();
end;
$$;
create function public.bloom_set_coach_preferences(p_consent boolean, p_adult_attested boolean, p_goals text, p_experience text, p_equipment text[])
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.set_coach_preferences(p_consent, p_adult_attested, p_goals, p_experience, p_equipment);
$$;

create function bloom_private.set_child_coaching(p_child_id uuid, p_enabled boolean, p_eligible boolean, p_consent boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id)
    or not bloom_private.is_child_profile(p_child_id) then raise exception 'Parent access required'; end if;
  if p_enabled is null or p_eligible is null or p_consent is null
    or (p_enabled and (not p_eligible or not p_consent)) then raise exception 'Parent consent and eligibility are required'; end if;
  insert into public.bloom_coach_settings(profile_id, parent_enabled, minor_eligible_attested, parent_sharing_consent)
    values (p_child_id, p_enabled, p_enabled and p_eligible, p_enabled and p_consent)
    on conflict (profile_id) do update set parent_enabled = excluded.parent_enabled,
      minor_eligible_attested = excluded.minor_eligible_attested, parent_sharing_consent = excluded.parent_sharing_consent,
      updated_at = clock_timestamp();
end;
$$;
create function public.bloom_set_child_coaching(p_child_id uuid, p_enabled boolean, p_eligible boolean, p_consent boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.set_child_coaching(p_child_id, p_enabled, p_eligible, p_consent);
$$;
create function bloom_private.child_coaching_status(p_child_id uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_result jsonb;
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  select jsonb_build_object('enabled', s.parent_enabled, 'eligible', s.minor_eligible_attested, 'parent_consent', s.parent_sharing_consent)
    into v_result from public.bloom_coach_settings s where s.profile_id = p_child_id;
  return coalesce(v_result, '{"enabled":false,"eligible":false,"parent_consent":false}'::jsonb);
end;
$$;
create function public.bloom_child_coaching_status(p_child_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.child_coaching_status(p_child_id);
$$;
create function bloom_private.child_coach_proposals(p_child_id uuid)
returns table(id uuid, profile_id uuid, status text, created_at timestamptz, proposal jsonb)
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  return query select p.id, p.profile_id, p.status, p.created_at,
    jsonb_strip_nulls(jsonb_build_object('title', p.proposal->>'title', 'plan_id', p.proposal->>'plan_id',
      'explanation', format('The coach suggests %s with %s exercises on %s scheduled days.',
        case when p.proposal->>'plan_id' is null then 'a new workout' else 'changes to an existing workout' end,
        jsonb_array_length(p.proposal->'exercises'), jsonb_array_length(p.proposal->'scheduled_days')),
      'scheduled_days', p.proposal->'scheduled_days', 'exercises', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'exercise_id', e.item->>'exercise_id', 'sets', e.item->'sets', 'target', e.item->'target',
        'weight_kg', e.item->'weight_kg', 'distance_km', e.item->'distance_km',
        'custom', case when jsonb_typeof(e.item->'custom') = 'object' then jsonb_build_object(
          'name', e.item->'custom'->>'name', 'description', '', 'measurement_type', e.item->'custom'->>'measurement_type') else null end)))
        from jsonb_array_elements(p.proposal->'exercises') e(item))))
    from public.bloom_coach_proposals p where p.profile_id = p_child_id order by p.created_at desc limit 30;
end;
$$;
create function public.bloom_child_coach_proposals(p_child_id uuid)
returns table(id uuid, profile_id uuid, status text, created_at timestamptz, proposal jsonb)
language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.child_coach_proposals(p_child_id);
$$;

create function bloom_private.begin_coach_request(p_request_id uuid, p_kind text, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_settings public.bloom_coach_settings%rowtype;
  v_request bloom_private.coach_requests%rowtype; v_child boolean; v_context jsonb;
begin
  if v_profile is null then raise exception 'Sign in to use coaching'; end if;
  if p_request_id is null or p_kind is null or p_kind not in ('chat', 'weekly') or p_prompt is null
    or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Enter a message of up to 2000 characters'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-coach:' || v_profile::text, 0));
  select * into v_settings from public.bloom_coach_settings s where s.profile_id = v_profile for share;
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
    and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then
    raise exception 'Coaching consent and eligibility are required';
  end if;
  select * into v_request from bloom_private.coach_requests r where r.id = p_request_id for update;
  if found then
    if v_request.profile_id <> v_profile or v_request.prompt <> trim(p_prompt) or v_request.request_kind <> p_kind then
      raise exception 'Request ID was already used';
    end if;
    return jsonb_build_object('status', v_request.status);
  end if;
  if (select count(*) from bloom_private.coach_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.coach_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '1 minute') >= 2 then
    raise exception 'Coaching request limit reached';
  end if;
  if exists (select 1 from bloom_private.coach_requests r where r.profile_id = v_profile and r.status = 'pending'
    and r.created_at > clock_timestamp() - interval '2 minutes') then raise exception 'A coaching request is already running'; end if;
  update bloom_private.coach_requests set status = 'failed' where profile_id = v_profile and status = 'pending'
    and created_at <= clock_timestamp() - interval '2 minutes';
  insert into bloom_private.coach_requests(id, profile_id, request_kind, prompt) values (p_request_id, v_profile, p_kind, trim(p_prompt));
  insert into public.bloom_coach_messages(profile_id, request_id, role, content) values (v_profile, p_request_id, 'user', trim(p_prompt));
  select jsonb_build_object(
    'is_child', v_child, 'goals', v_settings.goals, 'experience', v_settings.experience, 'equipment', to_jsonb(v_settings.equipment),
    'plans', coalesce((select jsonb_agg(x.item) from (
      select jsonb_build_object('id', p.id, 'title', left(p.title, 100), 'scheduled_days', p.scheduled_days,
        'exercises', coalesce((select jsonb_agg(y.item) from (
          select jsonb_build_object('exercise_id', e.id, 'name', left(e.name, 100), 'sets', pe.sets,
            'measurement_type', e.measurement_type::text, 'target', coalesce(pe.target_reps, pe.target_seconds),
            'weight_kg', pe.target_weight_kg, 'distance_km', pe.target_distance_km) item
          from public.bloom_plan_exercises pe join public.exercises e on e.id = pe.exercise_id
          where pe.plan_id = p.id order by pe.position limit 20) y), '[]'::jsonb)) item
      from public.bloom_workout_plans p where p.user_id = v_profile order by p.updated_at desc limit 5) x), '[]'::jsonb),
    'recent_workouts', coalesce((select jsonb_agg(x.item) from (
      select jsonb_build_object('days_ago', greatest(0, floor(extract(epoch from (now() - s.completed_at)) / 86400)::integer),
        'plan_title', left(coalesce(s.plan_title_snapshot, 'Workout'), 100),
        'active_seconds', s.active_duration_seconds) item from public.bloom_workout_sessions s
      where s.user_id = v_profile and s.status = 'completed' and s.completed_at >= now() - interval '28 days'
      order by s.completed_at desc limit 30) x), '[]'::jsonb),
    'catalog', coalesce((select jsonb_agg(x.item) from (
      select jsonb_build_object('id', e.id, 'name', left(e.name, 100), 'measurement_type', e.measurement_type::text) item
      from public.exercises e where e.is_system = true or e.bloom_owner_user_id = v_profile order by e.name, e.id limit 100) x), '[]'::jsonb),
    'conversation', coalesce((select jsonb_agg(x.item order by x.created_at, x.id) from (
      select m.id, m.created_at, jsonb_build_object('role', m.role, 'content', m.content) item from public.bloom_coach_messages m
      where m.profile_id = v_profile and m.request_id <> p_request_id order by m.created_at desc, m.id desc limit 10) x), '[]'::jsonb)
  ) into v_context;
  return jsonb_build_object('status', 'pending', 'context', v_context);
end;
$$;
create function public.bloom_begin_coach_request(p_request_id uuid, p_kind text, p_prompt text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.begin_coach_request(p_request_id, p_kind, p_prompt);
$$;

create function bloom_private.validate_coach_proposal(p_profile_id uuid, p_proposal jsonb)
returns void language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_item jsonb; v_custom jsonb; v_id uuid; v_seen uuid[] := '{}'; v_measurement text;
  v_sets integer; v_target integer; v_weight numeric; v_distance numeric; v_day jsonb; v_days integer[] := '{}';
  v_is_child boolean := bloom_private.is_child_profile(p_profile_id);
begin
  if jsonb_typeof(p_proposal) is distinct from 'object' or octet_length(p_proposal::text) > 20000
    or char_length(trim(coalesce(p_proposal->>'title', ''))) not between 1 and 100
    or char_length(trim(coalesce(p_proposal->>'explanation', ''))) not between 1 and 1000
    or jsonb_typeof(p_proposal->'exercises') is distinct from 'array'
    or jsonb_array_length(p_proposal->'exercises') not between 1 and 20
    or jsonb_typeof(p_proposal->'scheduled_days') is distinct from 'array'
    or jsonb_array_length(p_proposal->'scheduled_days') > 7 then raise exception 'Invalid coaching proposal'; end if;
  if nullif(p_proposal->>'plan_id', '') is not null then
    if p_proposal->>'plan_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or not exists (select 1 from public.bloom_workout_plans p where p.id = (p_proposal->>'plan_id')::uuid and p.user_id = p_profile_id) then
      raise exception 'Plan not found';
    end if;
  end if;
  for v_day in select value from jsonb_array_elements(p_proposal->'scheduled_days') loop
    if jsonb_typeof(v_day) <> 'number' or v_day::text !~ '^[1-7]$' or (v_day::text)::integer = any(v_days) then
      raise exception 'Invalid workout schedule';
    end if;
    v_days := array_append(v_days, (v_day::text)::integer);
  end loop;
  for v_item in select value from jsonb_array_elements(p_proposal->'exercises') loop
    if jsonb_typeof(v_item) <> 'object' or coalesce(v_item->>'sets', '') !~ '^[0-9]{1,2}$'
      or coalesce(v_item->>'target', '') !~ '^[0-9]{1,5}$' then raise exception 'Invalid exercise target'; end if;
    v_sets := (v_item->>'sets')::integer; v_target := (v_item->>'target')::integer;
    if v_sets not between 1 and 5 or v_target < 1 then raise exception 'Invalid exercise target'; end if;
    v_custom := v_item->'custom';
    if nullif(v_item->>'exercise_id', '') is not null then
      if v_item->>'exercise_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        or (v_custom is not null and v_custom <> 'null'::jsonb) then raise exception 'Invalid exercise'; end if;
      v_id := (v_item->>'exercise_id')::uuid;
      if v_id = any(v_seen) then raise exception 'Duplicate exercise'; end if;
      v_seen := array_append(v_seen, v_id);
      select e.measurement_type::text into v_measurement from public.exercises e
        where e.id = v_id and (e.is_system = true or e.bloom_owner_user_id = p_profile_id);
      if not found then raise exception 'Exercise not found'; end if;
    else
      if jsonb_typeof(v_custom) is distinct from 'object'
        or char_length(trim(coalesce(v_custom->>'name', ''))) not between 1 and 100
        or char_length(coalesce(v_custom->>'description', '')) > 1000
        or coalesce(v_custom->>'measurement_type', '') not in ('reps_only', 'reps_weight', 'time_only', 'time_distance') then
        raise exception 'Invalid custom exercise';
      end if;
      v_measurement := v_custom->>'measurement_type';
    end if;
    if (v_measurement in ('reps_only', 'reps_weight') and v_target > case when v_is_child then 50 else 200 end)
      or (v_measurement in ('time_only', 'time_distance') and v_target > case when v_is_child then 1800 else 3600 end) then
      raise exception 'Exercise target is outside coaching limits';
    end if;
    v_weight := nullif(v_item->>'weight_kg', '')::numeric;
    v_distance := nullif(v_item->>'distance_km', '')::numeric;
    if v_weight is not null and (v_measurement <> 'reps_weight' or v_weight < 0 or v_weight > 100 or (v_is_child and v_weight > 0)) then
      raise exception 'Weight is outside coaching limits';
    end if;
    if v_distance is not null and (v_measurement <> 'time_distance' or v_distance <= 0 or v_distance > 100 or (v_is_child and v_distance > 10)) then
      raise exception 'Distance is outside coaching limits';
    end if;
  end loop;
end;
$$;
revoke all on function bloom_private.validate_coach_proposal(uuid, jsonb) from public, anon, authenticated;

create function bloom_private.coach_plan_revision(p_plan_id uuid)
returns text language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select encode(sha256(convert_to(jsonb_build_object('title', p.title, 'days', p.scheduled_days,
    'exercises', coalesce((select jsonb_agg(jsonb_build_object('id', e.exercise_id, 'position', e.position,
      'sets', e.sets, 'reps', e.target_reps, 'seconds', e.target_seconds, 'weight', e.target_weight_kg,
      'distance', e.target_distance_km) order by e.position) from public.bloom_plan_exercises e where e.plan_id = p.id), '[]'::jsonb))::text, 'UTF8')), 'hex')
  from public.bloom_workout_plans p where p.id = p_plan_id;
$$;
revoke all on function bloom_private.coach_plan_revision(uuid) from public, anon, authenticated;

create function bloom_private.finish_coach_request(p_request_id uuid, p_reply text, p_proposal jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_request bloom_private.coach_requests%rowtype; v_plan uuid; v_updated timestamptz; v_settings public.bloom_coach_settings%rowtype; v_clean jsonb;
begin
  select * into v_request from bloom_private.coach_requests r where r.id = p_request_id for update;
  if not found then raise exception 'Coaching request not found'; end if;
  if v_request.status = 'completed' then return; end if;
  if v_request.status <> 'pending' then raise exception 'Coaching request is no longer pending'; end if;
  if p_reply is null or char_length(trim(p_reply)) not between 1 and 4000 then raise exception 'Invalid coaching reply'; end if;
  select * into v_settings from public.bloom_coach_settings s where s.profile_id = v_request.profile_id for share;
  if not found or not v_settings.sharing_consent or (bloom_private.is_child_profile(v_request.profile_id)
    and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not bloom_private.is_child_profile(v_request.profile_id) and not v_settings.adult_attested) then
    raise exception 'Coaching consent was withdrawn';
  end if;
  if p_proposal is not null and p_proposal <> 'null'::jsonb then
    perform bloom_private.validate_coach_proposal(v_request.profile_id, p_proposal);
    if nullif(p_proposal->>'plan_id', '') is not null then
      v_plan := (p_proposal->>'plan_id')::uuid;
      select p.updated_at into v_updated from public.bloom_workout_plans p where p.id = v_plan and p.user_id = v_request.profile_id for share;
      if not found then raise exception 'Plan not found'; end if;
    end if;
    select jsonb_strip_nulls(jsonb_build_object('title', trim(p_proposal->>'title'), 'explanation', trim(p_proposal->>'explanation'),
      'plan_id', nullif(p_proposal->>'plan_id', ''), 'scheduled_days', p_proposal->'scheduled_days',
      'exercises', (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'exercise_id', nullif(e.item->>'exercise_id', ''), 'sets', (e.item->>'sets')::integer, 'target', (e.item->>'target')::integer,
        'weight_kg', nullif(e.item->>'weight_kg', '')::numeric, 'distance_km', nullif(e.item->>'distance_km', '')::numeric,
        'custom', case when jsonb_typeof(e.item->'custom') = 'object' then jsonb_build_object(
          'name', trim(e.item->'custom'->>'name'), 'description', left(coalesce(e.item->'custom'->>'description', ''), 1000),
          'measurement_type', e.item->'custom'->>'measurement_type') else null end)))
        from jsonb_array_elements(p_proposal->'exercises') e(item)))) into v_clean;
    insert into public.bloom_coach_proposals(profile_id, request_id, proposal, base_plan_id, base_updated_at, base_revision)
      values (v_request.profile_id, v_request.id, v_clean, v_plan, v_updated, bloom_private.coach_plan_revision(v_plan));
  end if;
  insert into public.bloom_coach_messages(profile_id, request_id, role, content)
    values (v_request.profile_id, v_request.id, 'assistant', trim(p_reply));
  update bloom_private.coach_requests set status = 'completed' where id = p_request_id;
end;
$$;
create function public.bloom_finish_coach_request(p_request_id uuid, p_reply text, p_proposal jsonb)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.finish_coach_request(p_request_id, p_reply, p_proposal);
$$;
create function bloom_private.fail_coach_request(p_request_id uuid)
returns void language sql security definer set search_path = pg_catalog, pg_temp as $$
  update bloom_private.coach_requests set status = 'failed' where id = p_request_id and status = 'pending';
$$;
create function public.bloom_fail_coach_request(p_request_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.fail_coach_request(p_request_id);
$$;

create function bloom_private.decide_coach_proposal(p_proposal_id uuid, p_approve boolean)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_caller uuid := bloom_private.current_profile_id(); v_proposal public.bloom_coach_proposals%rowtype;
  v_settings public.bloom_coach_settings%rowtype; v_child boolean; v_item jsonb; v_custom jsonb;
  v_id uuid; v_entries jsonb := '[]'::jsonb; v_days smallint[]; v_result uuid;
begin
  if v_caller is null or p_approve is null then raise exception 'Sign in to review proposals'; end if;
  select * into v_proposal from public.bloom_coach_proposals p where p.id = p_proposal_id for update;
  if not found or (v_proposal.profile_id <> v_caller and not bloom_private.is_parent_of(v_proposal.profile_id)) then
    raise exception 'Proposal not found';
  end if;
  v_child := bloom_private.is_child_profile(v_proposal.profile_id);
  if p_approve and ((v_child and not bloom_private.is_parent_of(v_proposal.profile_id))
    or (not v_child and v_caller <> v_proposal.profile_id)) then raise exception 'Approval is not authorized'; end if;
  if v_proposal.status = 'approved' and p_approve then return v_proposal.result_plan_id; end if;
  if v_proposal.status = 'rejected' and not p_approve then return null; end if;
  if v_proposal.status <> 'pending' then raise exception 'Proposal was already reviewed'; end if;
  if not p_approve then
    update public.bloom_coach_proposals set status = 'rejected', decided_at = clock_timestamp() where id = p_proposal_id;
    return null;
  end if;
  select * into v_settings from public.bloom_coach_settings s where s.profile_id = v_proposal.profile_id for share;
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
    and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then raise exception 'Coaching consent was withdrawn'; end if;
  perform bloom_private.validate_coach_proposal(v_proposal.profile_id, v_proposal.proposal);
  if nullif(v_proposal.proposal->>'plan_id', '') is not null then
    if v_proposal.base_plan_id is null then raise exception 'The original plan is no longer available'; end if;
    perform 1 from public.bloom_workout_plans p where p.id = v_proposal.base_plan_id and p.user_id = v_proposal.profile_id for update;
    if not found then raise exception 'The original plan is no longer available'; end if;
    perform 1 from public.bloom_plan_exercises e where e.plan_id = v_proposal.base_plan_id order by e.position for update;
    if bloom_private.coach_plan_revision(v_proposal.base_plan_id) is distinct from v_proposal.base_revision then
      raise exception 'The plan changed since this proposal was created';
    end if;
  end if;
  for v_item in select value from jsonb_array_elements(v_proposal.proposal->'exercises') loop
    v_custom := v_item->'custom';
    if jsonb_typeof(v_custom) = 'object' then
      insert into public.exercises(id, name, description, measurement_type, is_system, bloom_owner_user_id)
        values (gen_random_uuid(), trim(v_custom->>'name'), nullif(trim(v_custom->>'description'), ''),
          (jsonb_populate_record(null::public.exercises, jsonb_build_object('measurement_type', v_custom->>'measurement_type'))).measurement_type,
          false, v_proposal.profile_id) returning id into v_id;
    else v_id := (v_item->>'exercise_id')::uuid;
    end if;
    v_entries := v_entries || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('exercise_id', v_id,
      'sets', (v_item->>'sets')::integer, 'target', (v_item->>'target')::integer,
      'weight_kg', nullif(v_item->>'weight_kg', '')::numeric, 'distance_km', nullif(v_item->>'distance_km', '')::numeric)));
  end loop;
  select coalesce(array_agg((value::text)::smallint), '{}'::smallint[]) into v_days
    from jsonb_array_elements(v_proposal.proposal->'scheduled_days');
  if v_proposal.base_plan_id is null then
    v_result := public.bloom_create_plan_for_user(v_proposal.profile_id, v_proposal.proposal->>'title', v_entries);
  else
    v_result := bloom_private.update_workout_plan(v_proposal.profile_id, v_proposal.base_plan_id, v_proposal.proposal->>'title', v_entries);
  end if;
  update public.bloom_workout_plans set scheduled_days = v_days, source = 'ai_generated', updated_at = clock_timestamp()
    where id = v_result and user_id = v_proposal.profile_id;
  update public.bloom_coach_proposals set status = 'approved', result_plan_id = v_result, decided_at = clock_timestamp() where id = p_proposal_id;
  return v_result;
end;
$$;
create function public.bloom_decide_coach_proposal(p_proposal_id uuid, p_approve boolean)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.decide_coach_proposal(p_proposal_id, p_approve);
$$;

revoke all on function bloom_private.set_coach_preferences(boolean, boolean, text, text, text[]),
  bloom_private.set_child_coaching(uuid, boolean, boolean, boolean), bloom_private.child_coaching_status(uuid), bloom_private.child_coach_proposals(uuid),
  bloom_private.begin_coach_request(uuid, text, text), bloom_private.decide_coach_proposal(uuid, boolean),
  public.bloom_set_coach_preferences(boolean, boolean, text, text, text[]), public.bloom_set_child_coaching(uuid, boolean, boolean, boolean),
  public.bloom_child_coaching_status(uuid), public.bloom_child_coach_proposals(uuid), public.bloom_begin_coach_request(uuid, text, text), public.bloom_decide_coach_proposal(uuid, boolean)
  from public, anon;
grant execute on function bloom_private.set_coach_preferences(boolean, boolean, text, text, text[]),
  bloom_private.set_child_coaching(uuid, boolean, boolean, boolean), bloom_private.child_coaching_status(uuid), bloom_private.child_coach_proposals(uuid),
  bloom_private.begin_coach_request(uuid, text, text), bloom_private.decide_coach_proposal(uuid, boolean),
  public.bloom_set_coach_preferences(boolean, boolean, text, text, text[]), public.bloom_set_child_coaching(uuid, boolean, boolean, boolean),
  public.bloom_child_coaching_status(uuid), public.bloom_child_coach_proposals(uuid), public.bloom_begin_coach_request(uuid, text, text), public.bloom_decide_coach_proposal(uuid, boolean)
  to authenticated;
revoke all on function bloom_private.finish_coach_request(uuid, text, jsonb), bloom_private.fail_coach_request(uuid),
  public.bloom_finish_coach_request(uuid, text, jsonb), public.bloom_fail_coach_request(uuid) from public, anon, authenticated;
grant execute on function bloom_private.finish_coach_request(uuid, text, jsonb), bloom_private.fail_coach_request(uuid),
  public.bloom_finish_coach_request(uuid, text, jsonb), public.bloom_fail_coach_request(uuid) to service_role;

commit;
