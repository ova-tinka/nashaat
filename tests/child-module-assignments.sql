begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000131'),
  ('00000000-0000-0000-0000-000000000132'),
  ('00000000-0000-0000-0000-000000000133');
insert into public.exercises(id, name, measurement_type, is_system)
  values ('10000000-0000-0000-0000-000000000131', 'Assignment exercise', 'reps_only', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000131', true);
select set_config('bloom.assignment_house', public.bloom_create_household('Assignment family')::text, true);
select set_config('bloom.assignment_invite', public.bloom_create_child_invite(current_setting('bloom.assignment_house')::uuid), true);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000132', true);
select public.bloom_accept_child_invite(current_setting('bloom.assignment_invite'));
do $$ begin
  if exists (select 1 from public.bloom_my_module_assignments()) then raise exception 'A child received modules without explicit assignment'; end if;
  if has_table_privilege('authenticated', 'public.bloom_child_module_assignments', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_child_module_assignments', 'UPDATE')
    or has_table_privilege('authenticated', 'public.bloom_child_module_assignments', 'DELETE') then
    raise exception 'Clients can write module assignments directly';
  end if;
  begin
    perform public.bloom_create_workout_plan('Unassigned plan', '[{"exercise_id":"10000000-0000-0000-0000-000000000131","sets":1,"target":5}]'::jsonb);
    raise exception using errcode = 'P0002', message = 'Unassigned child created an exercise plan';
  exception when insufficient_privilege then null; end;
  begin
    perform public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000132', array['exercise']::text[]);
    raise exception using errcode = 'P0002', message = 'Child changed their own module assignments';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000133', true);
do $$ begin
  begin
    perform * from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132');
    raise exception using errcode = 'P0002', message = 'Outsider read child module assignments';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000131', true);
do $$ declare v_access record;
begin
  select * into v_access from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132') where module_id = 'exercise';
  if not found or v_access.assigned or v_access.updated_by is not null then raise exception 'New child assignment state is not explicitly unassigned'; end if;
  begin
    perform public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000132', array['linux']::text[]);
    raise exception using errcode = 'P0002', message = 'Invalid module assignment was accepted';
  exception when raise_exception then if sqlerrm <> 'Choose each supported module no more than once' then raise; end if; end;
  begin
    perform public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000132', array['exercise', 'exercise']::text[]);
    raise exception using errcode = 'P0002', message = 'Duplicate module assignment was accepted';
  exception when raise_exception then if sqlerrm <> 'Choose each supported module no more than once' then raise; end if; end;
  if (select count(*) from public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000132', array['exercise', 'study']::text[]) where assigned) <> 2 then
    raise exception 'Guardian assignment was not saved';
  end if;
  if (select count(*) from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132')) <> 4 then
    raise exception 'Guardian view did not return a complete module list';
  end if;
  if not exists (select 1 from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132')
    where module_id = 'exercise' and assigned and updated_by = '00000000-0000-0000-0000-000000000131' and updated_at is not null)
    or not exists (select 1 from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132')
      where module_id = 'study' and assigned and updated_by = '00000000-0000-0000-0000-000000000131' and updated_at is not null)
    or exists (select 1 from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132') where module_id in ('read', 'tasks') and assigned) then
    raise exception 'Module assignment audit fields or unassigned state are incorrect';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000132', true);
do $$ declare v_plan uuid; v_session uuid;
begin
  if (select count(*) from public.bloom_my_module_assignments()) <> 2
    or not exists (select 1 from public.bloom_my_module_assignments() where module_id = 'exercise')
    or not exists (select 1 from public.bloom_my_module_assignments() where module_id = 'study') then
    raise exception 'Guardian-assigned modules were not returned';
  end if;
  if not bloom_private.has_module_access(bloom_private.current_profile_id(), 'exercise') then
    raise exception 'Assigned child does not pass the server module access check';
  end if;
  if not bloom_private.has_module_access(bloom_private.current_profile_id(), 'study') then
    raise exception 'Assigned Study access was denied';
  end if;
  perform public.bloom_create_growth_item('study', 'subject', 'Assigned subject', '', null, 60,
    '90000000-0000-0000-0000-000000000191');
  begin
    perform public.bloom_create_growth_item('read', 'reading', 'Unassigned reading', '', null, null,
      '90000000-0000-0000-0000-000000000192');
    raise exception using errcode = 'P0002', message = 'Child created an unassigned module item';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000131', true);
  if not (select assigned from public.bloom_child_module_assignments('00000000-0000-0000-0000-000000000132') where module_id = 'study') then
    raise exception 'Parent module list did not expose its assigned Study module';
  end if;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000132', true);
  v_plan := public.bloom_create_workout_plan('Assigned plan', '[{"exercise_id":"10000000-0000-0000-0000-000000000131","sets":1,"target":5}]'::jsonb);
  select session_id into v_session from public.bloom_start_workout(v_plan);
  if v_session is null then raise exception 'Assigned child could not start Exercise'; end if;
  perform set_config('bloom.assignment_session', v_session::text, true);
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000131', true);
select * from public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000132', array[]::text[]);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000132', true);
do $$ begin
  if exists (select 1 from public.bloom_my_module_assignments()) then raise exception 'Guardian revocation retained Exercise access'; end if;
  if not exists (select 1 from public.bloom_workout_sessions where id = current_setting('bloom.assignment_session')::uuid) then
    raise exception 'Child cannot access an already-started session to finish it';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000131', true);
select public.bloom_leave_or_remove_child(current_setting('bloom.assignment_house')::uuid, '00000000-0000-0000-0000-000000000132');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000132', true);
do $$ begin
  if exists (select 1 from public.bloom_my_module_assignments()) then raise exception 'Family unlink retained module access'; end if;
end $$;

rollback;
