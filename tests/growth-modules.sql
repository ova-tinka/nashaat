begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000181'),
  ('00000000-0000-0000-0000-000000000182');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
do $$
declare
  v_subject uuid;
  v_subject_retry uuid;
  v_reading uuid;
  v_task uuid;
  v_session uuid;
  v_session_retry uuid;
  v_source_device uuid := '90000000-0000-0000-0000-000000000201';
  v_duration integer;
  v_artwork text;
  v_completed timestamptz;
  v_session_count integer;
begin
  v_subject := public.bloom_create_growth_item('study', 'subject', 'Biology', 'Cell structure', null, 240,
    '90000000-0000-0000-0000-000000000181');
  v_artwork := public.bloom_set_study_subject_artwork(v_subject, 'biology', false);
  if v_artwork <> 'biology' then raise exception 'Study subject artwork was not saved'; end if;
  v_artwork := public.bloom_set_study_subject_artwork(v_subject, 'history', true);
  if v_artwork <> 'biology' then raise exception 'Legacy artwork migration overwrote a server choice'; end if;
  v_artwork := public.bloom_set_study_subject_artwork(v_subject, 'history', false);
  if v_artwork <> 'history' then raise exception 'Study subject artwork could not be changed'; end if;
  if not exists (select 1 from public.bloom_growth_items where id = v_subject and artwork_id = 'history') then
    raise exception 'Study subject artwork was not stored on the shared subject record';
  end if;
  begin
    perform public.bloom_set_study_subject_artwork(v_subject, 'unknown-artwork', false);
    raise exception 'Invalid Study artwork was accepted';
  exception when sqlstate '22023' then null;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
  begin
    perform public.bloom_set_study_subject_artwork(v_subject, 'biology', false);
    raise exception 'A different profile changed Study subject artwork';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
  v_subject_retry := public.bloom_create_growth_item('study', 'subject', 'Biology', 'Cell structure', null, 240,
    '90000000-0000-0000-0000-000000000181');
  if v_subject is distinct from v_subject_retry then raise exception 'Item retry created a duplicate subject'; end if;
  v_reading := public.bloom_create_growth_item('read', 'reading', 'The Secret Garden', '', null, null,
    '90000000-0000-0000-0000-000000000182');
  v_task := public.bloom_create_growth_item('tasks', 'task', 'Prepare notes', '', current_date + 1, null,
    '90000000-0000-0000-0000-000000000183');

  v_session := public.bloom_start_growth_session('study', v_subject, v_source_device, 'Test iPhone · 000201', '90000000-0000-0000-0000-000000000184');
  v_session_retry := public.bloom_start_growth_session('study', v_subject, v_source_device, 'Test iPhone · 000201', '90000000-0000-0000-0000-000000000184');
  if v_session is distinct from v_session_retry then raise exception 'Session retry created a duplicate session'; end if;
  if not exists (select 1 from public.bloom_growth_sessions where id = v_session
      and source_device_id = v_source_device and source_device_name = 'Test iPhone · 000201') then
    raise exception 'Session did not retain its source device';
  end if;
  begin
    perform public.bloom_start_growth_session('study', v_subject, v_source_device, 'Different device', '90000000-0000-0000-0000-000000000184');
    raise exception using errcode = 'P0002', message = 'Session retry accepted a different source device';
  exception when raise_exception then if sqlerrm <> 'Request was already used for another session' then raise; end if; end;
  begin
    perform public.bloom_start_growth_session('study', v_subject, v_source_device, 'Test iPhone · 000201', '90000000-0000-0000-0000-000000000185');
    raise exception using errcode = 'P0002', message = 'A second active Study session was accepted';
  exception when raise_exception then if sqlerrm <> 'Finish or cancel the active session first' then raise; end if; end;
  select duration_seconds, completed_at into v_duration, v_completed from public.bloom_finish_growth_session(v_session);
  select duration_seconds into v_session_count from public.bloom_finish_growth_session(v_session);
  if v_duration < 0 or v_completed is null or v_duration is distinct from v_session_count then
    raise exception 'Session completion was not retry-safe';
  end if;

  perform set_config('bloom.expired_session', public.bloom_start_growth_session('study', v_subject, v_source_device, 'Test iPhone · 000201', '90000000-0000-0000-0000-000000000186')::text, true);

  perform public.bloom_update_growth_item(v_reading, 'The Secret Garden', '', null, 'active', 35.5);
  perform public.bloom_update_growth_item(v_task, 'Prepare notes', '', current_date + 1, 'completed', 100);
  if not exists (select 1 from public.bloom_growth_items where id = v_reading and progress_percent = 35.5)
    or not exists (select 1 from public.bloom_growth_items where id = v_task and state = 'completed') then
    raise exception 'Reading progress or task completion was not saved';
  end if;
  if has_table_privilege('authenticated', 'public.bloom_growth_items', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_growth_items', 'UPDATE')
    or has_table_privilege('authenticated', 'public.bloom_growth_sessions', 'INSERT') then
    raise exception 'Clients can bypass validated growth-module RPCs';
  end if;
  if has_function_privilege('anon', 'public.bloom_set_study_subject_artwork(uuid,text,boolean)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.bloom_set_study_subject_artwork(uuid,text,boolean)', 'EXECUTE') then
    raise exception 'Study subject artwork RPC privileges are not profile-scoped';
  end if;
  if (select count(*) from public.bloom_growth_sessions where profile_id = bloom_private.current_profile_id()) <> 2 then
    raise exception 'Idempotent Study session produced duplicate rows';
  end if;
  if not exists (select 1 from public.bloom_growth_overview() where module_id = 'study' and active_items = 1 and sessions_this_week = 1)
    or not exists (select 1 from public.bloom_growth_overview() where module_id = 'read' and active_items = 1 and average_read_progress = 35.5)
    or not exists (select 1 from public.bloom_growth_overview() where module_id = 'tasks' and completed_items = 1 and active_items = 0) then
    raise exception 'Cross-module progress summary was not calculated from saved records';
  end if;
  perform set_config('bloom.growth_subject', v_subject::text, true);
  perform set_config('bloom.growth_session', v_session::text, true);
end;
$$;

-- Age the session as the disposable schema owner; clients must not be able to edit session timestamps.
reset role;
update public.bloom_growth_sessions
set started_at = clock_timestamp() - interval '13 hours'
where id = current_setting('bloom.expired_session')::uuid;
set local role authenticated;
do $$
begin
  begin
    perform public.bloom_finish_growth_session(current_setting('bloom.expired_session')::uuid);
    raise exception using errcode = 'P0002', message = 'An expired session was completed';
  exception when raise_exception then if sqlerrm <> 'This session has expired; cancel it and start a new one' then raise; end if; end;
  perform public.bloom_cancel_growth_session(current_setting('bloom.expired_session')::uuid);
  if exists (select 1 from public.bloom_growth_sessions where id = current_setting('bloom.expired_session')::uuid and status = 'in_progress') then
    raise exception 'An expired session could not be cleared';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
do $$
begin
  if exists (select 1 from public.bloom_growth_items where id = current_setting('bloom.growth_subject')::uuid)
    or exists (select 1 from public.bloom_growth_sessions where id = current_setting('bloom.growth_session')::uuid) then
    raise exception 'Another profile can read private module records';
  end if;
  begin
    perform public.bloom_finish_growth_session(current_setting('bloom.growth_session')::uuid);
    raise exception using errcode = 'P0002', message = 'Another profile completed this session';
  exception when insufficient_privilege then null; end;
end;
$$;

reset role;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000183'),
  ('00000000-0000-0000-0000-000000000184'),
  ('00000000-0000-0000-0000-000000000185');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
do $$ declare v_house uuid; v_invite text;
begin
  v_house := public.bloom_create_household('Growth audit family');
  v_invite := public.bloom_create_child_invite(v_house);
  perform set_config('bloom.growth_audit_invite', v_invite, true);
end; $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000184', true);
select public.bloom_accept_child_invite(current_setting('bloom.growth_audit_invite'));
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
select * from public.bloom_set_child_module_assignments('00000000-0000-0000-0000-000000000184', array['study', 'read']::text[]);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000184', true);
do $$ declare v_subject uuid; v_reading uuid; v_session uuid;
begin
  v_subject := public.bloom_create_growth_item('study', 'subject', 'Child biology', '', null, 120,
    '90000000-0000-0000-0000-000000000187');
  v_reading := public.bloom_create_growth_item('read', 'reading', 'Child book', '', null, null,
    '90000000-0000-0000-0000-000000000188');
  perform public.bloom_update_reading_details(v_reading, 'Author', 'History', 120, 30, 'currently_reading');
  v_session := public.bloom_start_growth_session('study', v_subject, '90000000-0000-0000-0000-000000000201',
    'Child study device', '90000000-0000-0000-0000-000000000189');
  perform public.bloom_finish_growth_session(v_session);
end; $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
do $$ declare v_count integer;
begin
  select count(*) into v_count from public.bloom_parent_child_growth_activity('00000000-0000-0000-0000-000000000184');
  if v_count <> 2
    or not exists (select 1 from public.bloom_parent_child_growth_activity('00000000-0000-0000-0000-000000000184')
      where module_id = 'study' and activity_type = 'study_session' and title = 'Child biology')
    or not exists (select 1 from public.bloom_parent_child_growth_activity('00000000-0000-0000-0000-000000000184')
      where module_id = 'read' and activity_type = 'reading_progress' and title = 'Child book'
        and progress_percent = 25 and current_page = 30 and page_count = 120) then
    raise exception 'Parent growth activity did not return the assigned Study and Read summary';
  end if;
end; $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000185', true);
do $$ begin
  begin
    perform * from public.bloom_parent_child_growth_activity('00000000-0000-0000-0000-000000000184');
    raise exception using errcode = 'P0002', message = 'Outsider read child growth activity';
  exception when insufficient_privilege then null; end;
end; $$;
rollback;
