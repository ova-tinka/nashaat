begin;

create function bloom_private.weekly_pillar_actuals()
returns table(module_id text, actual_value numeric)
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_timezone text;
  v_week_start timestamptz;
begin
  if v_profile is null then raise exception 'Sign in to view weekly activity'; end if;
  select coalesce(nullif(s.credit_timezone, ''), 'UTC') into v_timezone
    from public.bloom_settings s where s.user_id = v_profile;
  v_timezone := coalesce(v_timezone, 'UTC');
  v_week_start := date_trunc('week', clock_timestamp() at time zone v_timezone) at time zone v_timezone;

  if bloom_private.has_module_access(v_profile, 'exercise') then
    return query select 'exercise'::text, count(*)::numeric
      from public.bloom_workout_sessions s
      where s.user_id = v_profile and s.status = 'completed'
        and s.completed_at >= v_week_start and s.completed_at < clock_timestamp();
  end if;
  if bloom_private.has_module_access(v_profile, 'study') then
    return query select 'study'::text, round(coalesce(sum(s.duration_seconds), 0)::numeric / 60, 1)
      from public.bloom_growth_sessions s
      where s.profile_id = v_profile and s.module_id = 'study' and s.status = 'completed'
        and s.completed_at >= v_week_start and s.completed_at < clock_timestamp();
  end if;
  if bloom_private.has_module_access(v_profile, 'read') then
    return query select 'read'::text, count(*)::numeric
      from public.bloom_growth_sessions s
      where s.profile_id = v_profile and s.module_id = 'read' and s.status = 'completed'
        and s.completed_at >= v_week_start and s.completed_at < clock_timestamp();
  end if;
  if bloom_private.has_module_access(v_profile, 'tasks') then
    return query select 'tasks'::text, count(*)::numeric
      from public.bloom_growth_items i
      where i.profile_id = v_profile and i.module_id = 'tasks' and i.item_type = 'task'
        and i.state = 'completed' and i.completed_at >= v_week_start and i.completed_at < clock_timestamp();
  end if;
end;
$$;
revoke all on function bloom_private.weekly_pillar_actuals() from public, anon, authenticated;
grant execute on function bloom_private.weekly_pillar_actuals() to authenticated;

create function public.bloom_weekly_pillar_actuals()
returns table(module_id text, actual_value numeric)
language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.weekly_pillar_actuals();
$$;
revoke all on function public.bloom_weekly_pillar_actuals() from public, anon;
grant execute on function public.bloom_weekly_pillar_actuals() to authenticated;

commit;
