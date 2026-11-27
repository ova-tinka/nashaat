begin;

do $$
declare
  v_system_count integer;
  v_missing_meta integer;
  v_custom_id uuid;
begin
  select count(*) into v_system_count
  from public.exercises
  where is_system = true and bloom_owner_user_id is null;

  if v_system_count <> 62 then
    raise exception 'Expected 62 seeded system exercises, found %', v_system_count;
  end if;

  select count(*) into v_missing_meta
  from public.exercises
  where is_system = true
    and bloom_owner_user_id is null
    and (
      nullif(trim(coalesce(description, '')), '') is null
      or nullif(trim(coalesce(muscle_group, '')), '') is null
      or coalesce(cardinality(muscle_groups), 0) = 0
      or coalesce(cardinality(instructions), 0) = 0
    );

  if v_missing_meta <> 0 then
    raise exception 'Found % seeded system exercises missing required catalog metadata', v_missing_meta;
  end if;

  if not exists (
    select 1 from public.exercises
    where name = 'Bench Press' and is_system = true and bloom_owner_user_id is null
      and muscle_group = 'Chest' and cardinality(instructions) > 0
  ) then
    raise exception 'Representative curated exercise Bench Press is missing expected metadata';
  end if;

  if not exists (
    select 1 from public.exercises
    where name = 'Plank' and is_system = true and bloom_owner_user_id is null
      and muscle_group = 'Abdominals'
      and media_link = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/0.jpg'
      and cardinality(instructions) >= 4
  ) then
    raise exception 'Representative curated exercise Plank is missing expected metadata or artwork';
  end if;

  if not exists (
    select 1 from public.exercises
    where name = 'Romanian Deadlift' and is_system = true and bloom_owner_user_id is null
      and muscle_group = 'Hamstrings'
      and media_link = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/0.jpg'
  ) then
    raise exception 'Representative curated exercise Romanian Deadlift is missing expected metadata or artwork';
  end if;

  -- Create a synthetic user and a custom exercise sharing a curated name ('Plank').
  insert into auth.users(id, email)
  values ('00000000-0000-0000-0000-000000009001', 'seed-test@bloom.local');

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000009001', true);
  set local role authenticated;
  v_custom_id := public.bloom_create_custom_exercise('Plank', 'My custom plank variant', 'time_only');
  reset role;

  if v_custom_id is null then
    raise exception 'Failed to create custom exercise for reseed preservation test';
  end if;
end $$;

commit;
