begin;

-- Study, Read, and Tasks use the existing server-authoritative ledger. A rule
-- is per profile and module; every completion is capped and keyed to its source.
alter table public.bloom_credit_ledger
  add column growth_module_id text check (growth_module_id is null or growth_module_id in ('study', 'read', 'tasks')),
  add column growth_source_type text check (growth_source_type is null or growth_source_type in ('session', 'task')),
  add column growth_source_id uuid,
  add constraint bloom_growth_ledger_source_valid check (
    (growth_module_id is null and growth_source_type is null and growth_source_id is null)
    or (growth_module_id is not null and growth_source_type is not null and growth_source_id is not null
      and workout_session_id is null and entry_type = 'earned')
  );
create unique index bloom_one_earn_per_growth_source_idx
  on public.bloom_credit_ledger(user_id, growth_module_id, growth_source_type, growth_source_id)
  where growth_source_id is not null;

create table public.bloom_growth_reward_rules (
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  enabled boolean not null default false,
  reward_minutes numeric(10, 2) not null default 5 check (reward_minutes > 0 and reward_minutes <= 1440),
  daily_cap_minutes numeric(10, 2) not null default 30 check (daily_cap_minutes > 0 and daily_cap_minutes <= 1440),
  weekly_cap_minutes numeric(10, 2) not null default 120 check (weekly_cap_minutes > 0 and weekly_cap_minutes <= 10080),
  minimum_session_minutes numeric(7, 2) not null default 5 check (minimum_session_minutes between 0 and 720),
  require_parent_approval boolean not null default false,
  updated_by uuid not null references public.bloom_profiles(id) on delete cascade,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (profile_id, module_id)
);

create table public.bloom_growth_reward_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  source_type text not null check (source_type in ('session', 'task')),
  source_id uuid not null,
  requested_minutes numeric(10, 2) not null check (requested_minutes > 0 and requested_minutes <= 1440),
  status text not null default 'pending' check (status in ('pending', 'awarded', 'capped', 'rejected')),
  reviewed_by uuid references public.bloom_profiles(id) on delete set null,
  reviewed_at timestamptz,
  awarded_minutes numeric(10, 2) not null default 0 check (awarded_minutes >= 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (profile_id, module_id, source_type, source_id),
  check ((reviewed_by is null) = (reviewed_at is null)),
  check ((status = 'awarded') = (awarded_minutes > 0))
);
create index bloom_growth_reward_events_profile_idx
  on public.bloom_growth_reward_events(profile_id, status, created_at desc);

alter table public.bloom_growth_reward_rules enable row level security;
alter table public.bloom_growth_reward_events enable row level security;
revoke all on public.bloom_growth_reward_rules, public.bloom_growth_reward_events from public, anon, authenticated;
grant select on public.bloom_growth_reward_rules, public.bloom_growth_reward_events to authenticated;
create policy bloom_growth_reward_rules_read on public.bloom_growth_reward_rules for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(profile_id));
create policy bloom_growth_reward_events_read on public.bloom_growth_reward_events for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(profile_id));

create function bloom_private.award_growth_reward(p_event_id uuid, p_reviewer uuid default null)
returns numeric language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_event public.bloom_growth_reward_events%rowtype;
  v_rule public.bloom_growth_reward_rules%rowtype;
  v_credit public.bloom_settings%rowtype;
  v_event_time timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_week_start timestamptz;
  v_week_end timestamptz;
  v_today_earned numeric := 0;
  v_week_earned numeric := 0;
  v_award numeric := 0;
  v_eligible boolean := false;
begin
  select * into v_event from public.bloom_growth_reward_events e where e.id = p_event_id for update;
  if not found or v_event.status <> 'pending' then return coalesce(v_event.awarded_minutes, 0); end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-reward:' || v_event.profile_id::text || ':' || v_event.module_id, 0));
  select * into v_rule from public.bloom_growth_reward_rules r
    where r.profile_id = v_event.profile_id and r.module_id = v_event.module_id for share;
  select * into v_credit from public.bloom_settings s where s.user_id = v_event.profile_id for share;
  if not found or not v_credit.credits_enabled or not coalesce(v_rule.enabled, false)
    or (v_rule.require_parent_approval and p_reviewer is null)
    or (p_reviewer is not null and not v_rule.require_parent_approval) then
    update public.bloom_growth_reward_events set status = 'rejected', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;

  if v_event.source_type = 'session' then
    select s.completed_at into v_event_time from public.bloom_growth_sessions s
      where s.id = v_event.source_id and s.profile_id = v_event.profile_id
        and s.module_id = v_event.module_id and s.status = 'completed'
        and s.duration_seconds >= v_rule.minimum_session_minutes * 60;
    v_eligible := found;
  else
    select i.completed_at into v_event_time from public.bloom_growth_items i
      where i.id = v_event.source_id and i.profile_id = v_event.profile_id
        and i.module_id = v_event.module_id and i.module_id = 'tasks'
        and i.item_type = 'task' and i.state = 'completed';
    v_eligible := found;
  end if;
  if not v_eligible or v_event_time is null then
    update public.bloom_growth_reward_events set status = 'rejected', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;

  v_event_time := least(v_event_time, v_event.created_at);
  v_day_start := date_trunc('day', v_event_time at time zone v_credit.credit_timezone) at time zone v_credit.credit_timezone;
  v_day_end := v_day_start + interval '1 day';
  v_week_start := date_trunc('week', v_event_time at time zone v_credit.credit_timezone) at time zone v_credit.credit_timezone;
  v_week_end := bloom_private.credit_week_end(v_event_time, v_credit.credit_timezone);
  if v_week_end <= clock_timestamp() then
    update public.bloom_growth_reward_events set status = 'capped', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;
  select coalesce(sum(l.amount_minutes), 0) into v_today_earned from public.bloom_credit_ledger l
    where l.user_id = v_event.profile_id and l.entry_type = 'earned'
      and l.growth_module_id = v_event.module_id and l.created_at >= v_day_start and l.created_at < v_day_end;
  select coalesce(sum(l.amount_minutes), 0) into v_week_earned from public.bloom_credit_ledger l
    where l.user_id = v_event.profile_id and l.entry_type = 'earned'
      and l.growth_module_id = v_event.module_id and l.created_at >= v_week_start and l.created_at < v_week_end;
  v_award := round(greatest(0, least(v_event.requested_minutes, v_rule.reward_minutes,
    v_rule.daily_cap_minutes - v_today_earned, v_rule.weekly_cap_minutes - v_week_earned)), 2);
  if v_award <= 0 then
    update public.bloom_growth_reward_events set status = 'capped', reviewed_by = p_reviewer,
      reviewed_at = case when p_reviewer is null then null else clock_timestamp() end where id = p_event_id;
    return 0;
  end if;
  insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at,
    created_at, growth_module_id, growth_source_type, growth_source_id)
  values (v_event.profile_id, v_award, 'earned',
    'growth:' || v_event.module_id || ':' || v_event.source_type || ':' || v_event.source_id::text,
    v_week_end, v_event_time, v_event.module_id, v_event.source_type, v_event.source_id)
  on conflict (user_id, idempotency_key) do nothing;
  if not found then
    select l.amount_minutes into v_award from public.bloom_credit_ledger l
      where l.user_id = v_event.profile_id and l.idempotency_key =
        'growth:' || v_event.module_id || ':' || v_event.source_type || ':' || v_event.source_id::text;
  end if;
  update public.bloom_growth_reward_events set status = 'awarded', awarded_minutes = v_award,
    reviewed_by = p_reviewer, reviewed_at = case when p_reviewer is null then null else clock_timestamp() end
    where id = p_event_id;
  return v_award;
end;
$$;

create function bloom_private.record_growth_reward()
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

create trigger bloom_reward_growth_session
  after update of status on public.bloom_growth_sessions
  for each row when (old.status = 'in_progress' and new.status = 'completed')
  execute function bloom_private.record_growth_reward();
create trigger bloom_reward_growth_task
  after update of state on public.bloom_growth_items
  for each row when (old.state <> 'completed' and new.state = 'completed' and new.module_id = 'tasks' and new.item_type = 'task')
  execute function bloom_private.record_growth_reward();

create function bloom_private.save_growth_reward_rules(
  p_profile_id uuid, p_module_id text, p_enabled boolean, p_reward_minutes numeric,
  p_daily_cap_minutes numeric, p_weekly_cap_minutes numeric, p_minimum_session_minutes numeric,
  p_require_parent_approval boolean
) returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_child boolean;
begin
  if v_profile is null or p_profile_id is null then raise exception 'Sign in to manage growth rewards'; end if;
  if p_profile_id <> v_profile and not bloom_private.is_parent_of(p_profile_id) then
    raise exception 'Family access required' using errcode = '42501';
  end if;
  v_child := bloom_private.is_child_profile(p_profile_id);
  if p_profile_id = v_profile and v_child then raise exception 'A parent manages rewards for this profile' using errcode = '42501'; end if;
  if not bloom_private.has_module_access(p_profile_id, p_module_id) then
    raise exception 'This module is not assigned to the profile' using errcode = '42501';
  end if;
  if p_module_id not in ('study', 'read', 'tasks') or p_enabled is null or p_reward_minutes is null
    or p_reward_minutes <= 0 or p_reward_minutes > 1440 or p_daily_cap_minutes is null
    or p_daily_cap_minutes <= 0 or p_daily_cap_minutes > 1440 or p_weekly_cap_minutes is null
    or p_weekly_cap_minutes <= 0 or p_weekly_cap_minutes > 10080 or p_minimum_session_minutes is null
    or p_minimum_session_minutes < 0 or p_minimum_session_minutes > 720 or p_require_parent_approval is null
    or (p_require_parent_approval and not v_child) then raise exception 'Check the growth reward rules'; end if;
  insert into public.bloom_growth_reward_rules(profile_id, module_id, enabled, reward_minutes,
    daily_cap_minutes, weekly_cap_minutes, minimum_session_minutes, require_parent_approval, updated_by)
  values (p_profile_id, p_module_id, p_enabled, p_reward_minutes, p_daily_cap_minutes,
    p_weekly_cap_minutes, p_minimum_session_minutes, p_require_parent_approval, v_profile)
  on conflict (profile_id, module_id) do update set enabled = excluded.enabled,
    reward_minutes = excluded.reward_minutes, daily_cap_minutes = excluded.daily_cap_minutes,
    weekly_cap_minutes = excluded.weekly_cap_minutes, minimum_session_minutes = excluded.minimum_session_minutes,
    require_parent_approval = excluded.require_parent_approval, updated_by = excluded.updated_by,
    updated_at = clock_timestamp();
end;
$$;

create function bloom_private.review_growth_reward(p_event_id uuid, p_approve boolean)
returns numeric language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_event public.bloom_growth_reward_events%rowtype; v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null or p_event_id is null or p_approve is null then raise exception 'Check the reward review'; end if;
  select * into v_event from public.bloom_growth_reward_events e where e.id = p_event_id for update;
  if not found or not bloom_private.is_parent_of(v_event.profile_id) or not bloom_private.is_child_profile(v_event.profile_id) then
    raise exception 'Parent access required' using errcode = '42501';
  end if;
  if v_event.status <> 'pending' then return v_event.awarded_minutes; end if;
  if p_approve then return bloom_private.award_growth_reward(p_event_id, v_profile); end if;
  update public.bloom_growth_reward_events set status = 'rejected', reviewed_by = v_profile,
    reviewed_at = clock_timestamp() where id = p_event_id;
  return 0;
end;
$$;

create function public.bloom_save_growth_reward_rules(
  p_profile_id uuid, p_module_id text, p_enabled boolean, p_reward_minutes numeric,
  p_daily_cap_minutes numeric, p_weekly_cap_minutes numeric, p_minimum_session_minutes numeric,
  p_require_parent_approval boolean
) returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.save_growth_reward_rules(p_profile_id, p_module_id, p_enabled, p_reward_minutes,
    p_daily_cap_minutes, p_weekly_cap_minutes, p_minimum_session_minutes, p_require_parent_approval);
$$;
create function public.bloom_review_growth_reward(p_event_id uuid, p_approve boolean)
returns numeric language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.review_growth_reward(p_event_id, p_approve);
$$;

revoke all on function bloom_private.award_growth_reward(uuid, uuid), bloom_private.record_growth_reward(),
  bloom_private.save_growth_reward_rules(uuid, text, boolean, numeric, numeric, numeric, numeric, boolean),
  bloom_private.review_growth_reward(uuid, boolean) from public, anon, authenticated;
grant execute on function bloom_private.save_growth_reward_rules(uuid, text, boolean, numeric, numeric, numeric, numeric, boolean),
  bloom_private.review_growth_reward(uuid, boolean) to authenticated;
revoke all on function public.bloom_save_growth_reward_rules(uuid, text, boolean, numeric, numeric, numeric, numeric, boolean),
  public.bloom_review_growth_reward(uuid, boolean) from public, anon;
grant execute on function public.bloom_save_growth_reward_rules(uuid, text, boolean, numeric, numeric, numeric, numeric, boolean),
  public.bloom_review_growth_reward(uuid, boolean) to authenticated;

commit;
