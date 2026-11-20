begin;

create table public.bloom_weekly_pillar_goals (
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('exercise', 'study', 'read', 'tasks')),
  target_count integer not null check (target_count > 0),
  unit text not null check (unit in ('workouts', 'minutes', 'sessions', 'tasks')),
  active_days smallint[] not null check (cardinality(active_days) between 1 and 7
    and active_days <@ array[0,1,2,3,4,5,6]::smallint[]),
  updated_at timestamptz not null default clock_timestamp(),
  primary key(profile_id, module_id),
  check ((module_id = 'exercise' and unit = 'workouts' and target_count between 1 and 7)
    or (module_id = 'study' and unit = 'minutes' and target_count between 1 and 10080)
    or (module_id = 'read' and unit = 'sessions' and target_count between 1 and 100)
    or (module_id = 'tasks' and unit = 'tasks' and target_count between 1 and 500))
);
create index bloom_weekly_pillar_goals_profile_idx on public.bloom_weekly_pillar_goals(profile_id, module_id);
alter table public.bloom_weekly_pillar_goals enable row level security;
revoke all on public.bloom_weekly_pillar_goals from public, anon, authenticated;
grant select on public.bloom_weekly_pillar_goals to authenticated;
create policy bloom_weekly_pillar_goals_read on public.bloom_weekly_pillar_goals for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(profile_id, module_id));

create function bloom_private.save_weekly_pillar_goals(p_goals jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_goal jsonb;
  v_module text;
  v_target integer;
  v_unit text;
  v_days smallint[];
  v_seen text[] := '{}';
begin
  if v_profile is null then raise exception 'Sign in to manage weekly goals'; end if;
  if jsonb_typeof(p_goals) is distinct from 'array' or jsonb_array_length(p_goals) > 4 then raise exception 'Choose up to four weekly goals'; end if;
  for v_goal in select value from jsonb_array_elements(p_goals) loop
    v_module := v_goal->>'module_id';
    v_target := (v_goal->>'target_count')::integer;
    v_days := array(select value::smallint from jsonb_array_elements_text(v_goal->'active_days') value);
    if v_module not in ('exercise', 'study', 'read', 'tasks') or v_module = any(v_seen)
      or not bloom_private.has_module_access(v_profile, v_module)
      or v_days is null or cardinality(v_days) not between 1 and 7
      or exists (select 1 from unnest(v_days) d where d < 0 or d > 6)
      or cardinality(v_days) <> (select count(distinct d) from unnest(v_days) d) then
      raise exception 'Check the module and chosen days';
    end if;
    v_seen := array_append(v_seen, v_module);
    v_unit := case v_module when 'exercise' then 'workouts' when 'study' then 'minutes' when 'read' then 'sessions' else 'tasks' end;
    if (v_module = 'exercise' and v_target not between 1 and 7)
      or (v_module = 'study' and v_target not between 1 and 10080)
      or (v_module = 'read' and v_target not between 1 and 100)
      or (v_module = 'tasks' and v_target not between 1 and 500) then raise exception 'Check the weekly target'; end if;
  end loop;
  delete from public.bloom_weekly_pillar_goals where profile_id = v_profile;
  for v_goal in select value from jsonb_array_elements(p_goals) loop
    v_module := v_goal->>'module_id'; v_target := (v_goal->>'target_count')::integer;
    v_days := array(select value::smallint from jsonb_array_elements_text(v_goal->'active_days') value);
    v_unit := case v_module when 'exercise' then 'workouts' when 'study' then 'minutes' when 'read' then 'sessions' else 'tasks' end;
    insert into public.bloom_weekly_pillar_goals(profile_id, module_id, target_count, unit, active_days)
      values (v_profile, v_module, v_target, v_unit, v_days);
  end loop;
end;
$$;

create function public.bloom_save_weekly_pillar_goals(p_goals jsonb)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.save_weekly_pillar_goals(p_goals);
$$;

revoke all on function bloom_private.save_weekly_pillar_goals(jsonb) from public, anon, authenticated;
grant execute on function bloom_private.save_weekly_pillar_goals(jsonb) to authenticated;
revoke all on function public.bloom_save_weekly_pillar_goals(jsonb) from public, anon, authenticated;
grant execute on function public.bloom_save_weekly_pillar_goals(jsonb) to authenticated;

commit;
