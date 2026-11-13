begin;

-- NULL means no timer was recorded, including workouts predating this feature.
alter table public.bloom_workout_sessions
  add column active_duration_seconds numeric,
  add column timer_started_at timestamptz,
  add constraint bloom_workout_timer_valid check (
    (active_duration_seconds is null or active_duration_seconds >= 0)
    and (timer_started_at is null or (active_duration_seconds is not null and status = 'in_progress'))
  );

-- Freeze the running interval atomically with completion or cancellation.
create function bloom_private.finish_workout_timer()
returns trigger language plpgsql set search_path = pg_catalog, pg_temp as $$
begin
  if old.status = 'in_progress' and new.status <> 'in_progress' and old.timer_started_at is not null then
    new.active_duration_seconds := old.active_duration_seconds
      + greatest(0, extract(epoch from (clock_timestamp() - old.timer_started_at)));
    new.timer_started_at := null;
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.finish_workout_timer() from public, anon, authenticated;
create trigger bloom_finish_workout_timer before update of status on public.bloom_workout_sessions
  for each row execute function bloom_private.finish_workout_timer();

create function bloom_private.set_workout_timer(p_session_id uuid, p_running boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_session public.bloom_workout_sessions%rowtype;
  v_now timestamptz;
begin
  if auth.uid() is null or p_running is null then raise exception 'Sign in and choose a timer state'; end if;
  select * into v_session from public.bloom_workout_sessions
    where id = p_session_id and user_id = auth.uid() for update;
  if not found then raise exception 'Workout session not found'; end if;
  if v_session.status <> 'in_progress' then raise exception 'Workout is no longer active'; end if;
  v_now := clock_timestamp();
  if p_running and v_session.timer_started_at is null then
    update public.bloom_workout_sessions set active_duration_seconds = coalesce(active_duration_seconds, 0),
      timer_started_at = v_now where id = v_session.id;
  elsif not p_running and v_session.timer_started_at is not null then
    update public.bloom_workout_sessions set active_duration_seconds = active_duration_seconds
      + greatest(0, extract(epoch from (v_now - timer_started_at))), timer_started_at = null
      where id = v_session.id;
  end if;
end;
$$;
revoke all on function bloom_private.set_workout_timer(uuid, boolean) from public, anon;
grant execute on function bloom_private.set_workout_timer(uuid, boolean) to authenticated;

create function public.bloom_set_workout_timer(p_session_id uuid, p_running boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.set_workout_timer(p_session_id, p_running);
$$;
revoke all on function public.bloom_set_workout_timer(uuid, boolean) from public, anon;
grant execute on function public.bloom_set_workout_timer(uuid, boolean) to authenticated;

commit;
