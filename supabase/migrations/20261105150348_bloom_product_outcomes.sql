begin;

-- Internal reporting only. The caller must already have permission to read
-- the underlying records; the function is not exposed through the Data API.
create function bloom_private.product_outcomes(p_week_start date)
returns table(metric text, numerator numeric, denominator numeric, value numeric, status text, note text)
language plpgsql stable security invoker set search_path = pg_catalog, pg_temp as $$
declare
  v_start timestamptz;
  v_end timestamptz;
  v_workouts bigint;
  v_workout_users bigint;
  v_cohort bigint;
  v_returned bigint;
  v_enrolled bigint;
  v_activated bigint;
  v_households bigint;
  v_active_households bigint;
  v_earned numeric;
  v_spent numeric;
  v_excluded_buckets bigint;
begin
  if p_week_start is null or extract(dow from p_week_start) <> 0 then
    raise exception 'Choose a Sunday as the start of the reporting week';
  end if;
  v_start := p_week_start::timestamp at time zone 'UTC';
  v_end := (p_week_start + 7)::timestamp at time zone 'UTC';
  if v_end > now() then raise exception 'Choose a completed reporting week'; end if;

  select count(*), count(distinct s.user_id)
    into v_workouts, v_workout_users
  from public.bloom_workout_sessions s
  where s.status = 'completed' and s.completed_at >= v_start and s.completed_at < v_end;

  with first_workouts as (
    select s.user_id, min(s.completed_at) as first_at
    from public.bloom_workout_sessions s where s.status = 'completed'
    group by s.user_id
  ), cohort as (
    select f.user_id from first_workouts f where f.first_at >= v_start and f.first_at < v_end
  )
  select count(*), count(*) filter (where exists (
    select 1 from public.bloom_workout_sessions s where s.user_id = c.user_id and s.status = 'completed'
      and s.completed_at >= v_start + interval '21 days' and s.completed_at < v_start + interval '28 days'
  )) into v_cohort, v_returned from cohort c;

  select count(*), count(*) filter (where exists (
    select 1 from public.bloom_workout_sessions s where s.user_id = b.user_id and s.status = 'completed'
      and s.completed_at >= b.created_at and s.completed_at < b.created_at + interval '7 days'
  )) into v_enrolled, v_activated
  from public.bloom_settings b where b.created_at >= v_start and b.created_at < v_end;

  with members as (
    select m.household_id, m.user_id, m.role, m.joined_at
    from public.bloom_household_members m where m.joined_at < v_end
  ), eligible as (
    select m.household_id from members m group by m.household_id
    having bool_or(m.role = 'parent') and bool_or(m.role = 'child')
  ), active_members as (
    select distinct m.household_id, m.role from members m
    join public.bloom_workout_sessions s on s.user_id = m.user_id
    where s.status = 'completed' and s.completed_at >= v_start and s.completed_at < v_end
      and s.completed_at >= m.joined_at
  ), active_households as (
    select a.household_id from active_members a group by a.household_id
    having bool_or(a.role = 'parent') and bool_or(a.role = 'child')
  )
  select count(*), count(a.household_id) into v_households, v_active_households
  from eligible e left join active_households a on a.household_id = e.household_id;

  -- Credit is fungible inside an expiry bucket. Only count buckets whose
  -- funding is unambiguously earned and whose sessions have all settled.
  with buckets as (
    select l.user_id, l.expires_at,
      coalesce(sum(l.amount_minutes) filter (where l.entry_type = 'earned'), 0) as earned,
      coalesce(-sum(l.amount_minutes) filter (where l.entry_type = 'spent'), 0) as spent,
      bool_or(l.entry_type = 'adjustment') as adjusted
    from public.bloom_credit_ledger l
    where l.expires_at >= v_start and l.expires_at < v_end
    group by l.user_id, l.expires_at
    having coalesce(sum(l.amount_minutes) filter (where l.entry_type = 'earned'), 0) > 0
  ), classified as (
    select b.*, (b.adjusted or exists (
      select 1 from public.bloom_usage_sessions s
      where s.user_id = b.user_id and s.expires_at = b.expires_at and s.settled_at is null
    ) or exists (
      select 1 from public.bloom_credit_sessions s
      where s.user_id = b.user_id and s.expires_at = b.expires_at and s.settled_at is null
    )) as excluded
    from buckets b
  )
  select coalesce(sum(c.earned) filter (where not c.excluded), 0),
    coalesce(sum(c.spent) filter (where not c.excluded), 0),
    count(*) filter (where c.excluded)
  into v_earned, v_spent, v_excluded_buckets from classified c;

  return query values
    ('workouts_per_workout_active_user'::text, v_workouts::numeric, v_workout_users::numeric,
      case when v_workout_users > 0 then v_workouts::numeric / v_workout_users end,
      case when v_workout_users > 0 then 'available' else 'no_data' end,
      'Workout-active means at least one completed workout in this UTC week.'::text),
    ('week_four_workout_retention', case when now() >= v_start + interval '28 days' then v_returned::numeric end,
      v_cohort::numeric, case when now() >= v_start + interval '28 days' and v_cohort > 0 then v_returned::numeric / v_cohort end,
      case when now() < v_start + interval '28 days' then 'pending' when v_cohort = 0 then 'no_data' else 'available' end,
      'Cohort: first completed workout in this UTC week; return: another completed workout during days 21–27 of the cohort week.'),
    ('first_workout_within_seven_days', case when now() >= v_end + interval '7 days' then v_activated::numeric end,
      v_enrolled::numeric, case when now() >= v_end + interval '7 days' and v_enrolled > 0 then v_activated::numeric / v_enrolled end,
      case when now() < v_end + interval '7 days' then 'pending' when v_enrolled = 0 then 'no_data' else 'available' end,
      'Cohort: Bloom settings first created in this UTC week; activation: a completed workout within seven days.'),
    ('household_workout_participation', v_active_households::numeric, v_households::numeric,
      case when v_households > 0 then v_active_households::numeric / v_households end,
      case when v_households > 0 then 'available' else 'no_data' end,
      'Currently linked households with both roles; both a parent and a child completed a workout in the week. Unlinked historical members are unavailable.'),
    ('screen_time_change_from_baseline', null::numeric, null::numeric, null::numeric, 'not_available',
      'A comparable pre-Bloom discretionary screen-time baseline is not collected; countdown time is not actual use.'),
    ('planned_workout_completion', null::numeric, null::numeric, null::numeric, 'not_available',
      'Past schedules are not retained when a plan is edited or deleted.'),
    ('earned_credit_use', v_spent, v_earned,
      case when v_earned > 0 then v_spent / v_earned end,
      case when v_earned = 0 and v_excluded_buckets > 0 then 'incomplete' when v_earned = 0 then 'no_data'
        when v_excluded_buckets > 0 then 'partial' else 'available' end,
      format('Spent versus workout-earned minutes in buckets expiring in this UTC week; %s buckets excluded for parent adjustments or unsettled sessions. Countdown spending is not actual use.', v_excluded_buckets)),
    ('workout_recovery', null::numeric, null::numeric, null::numeric, 'not_available',
      'Past missed planned workouts cannot be reconstructed reliably after schedule changes.');
end;
$$;

revoke all on function bloom_private.product_outcomes(date) from public, anon, authenticated, service_role;

commit;
