begin;

-- Keep existing growth item IDs as stable roots while adding optional structure.
alter table public.bloom_growth_items
  add column parent_id uuid references public.bloom_growth_items(id) on delete cascade;
alter table public.bloom_growth_items
  drop constraint bloom_growth_items_item_type_check,
  drop constraint bloom_growth_items_check1,
  drop constraint bloom_growth_items_check,
  add constraint bloom_growth_items_item_type_check check (item_type in (
    'subject', 'course', 'lesson', 'assignment', 'reading',
    'project', 'milestone', 'task', 'checklist'
  )),
  add constraint bloom_growth_items_module_type_valid check (
    (module_id = 'study' and item_type in ('subject', 'course', 'lesson', 'assignment') and due_date is null)
    or (module_id = 'read' and item_type = 'reading' and due_date is null and target_minutes is null)
    or (module_id = 'tasks' and item_type in ('project', 'milestone', 'task', 'checklist') and target_minutes is null)
  ),
  add constraint bloom_growth_items_completed_at_valid check (state <> 'completed' or completed_at is not null),
  add constraint bloom_growth_items_target_only_subjects check (
    (item_type = 'subject' and target_minutes is not null)
    or (item_type <> 'subject' and target_minutes is null)
  );
create index bloom_growth_items_parent_idx on public.bloom_growth_items(profile_id, parent_id, state, updated_at desc);

create function bloom_private.create_growth_child(
  p_parent_id uuid, p_item_type text, p_title text, p_notes text,
  p_due_date date, p_request_id uuid
) returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_parent public.bloom_growth_items%rowtype;
  v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to add this item'; end if;
  select * into v_parent from public.bloom_growth_items i
    where i.id = p_parent_id and i.profile_id = v_profile for share;
  if not found or not bloom_private.has_module_access(v_profile, v_parent.module_id) then
    raise exception 'Parent item not found or module access is not assigned' using errcode = '42501';
  end if;
  if p_request_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 120
    or p_notes is null or char_length(p_notes) > 2000 then raise exception 'Check the item details'; end if;
  if not (
    (v_parent.module_id = 'study' and ((v_parent.item_type = 'subject' and p_item_type = 'course')
      or (v_parent.item_type = 'course' and p_item_type in ('lesson', 'assignment'))
      or (v_parent.item_type = 'lesson' and p_item_type = 'assignment')))
    or (v_parent.module_id = 'tasks' and ((v_parent.item_type = 'project' and p_item_type = 'milestone')
      or (v_parent.item_type = 'milestone' and p_item_type = 'task')
      or (v_parent.item_type = 'task' and p_item_type = 'checklist')))
  ) then raise exception 'This item cannot be added under the selected parent'; end if;
  if p_due_date is not null and v_parent.module_id <> 'tasks' then raise exception 'Due dates are only available for Tasks'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-item:' || v_profile::text || ':' || p_request_id::text, 0));
  select * into v_item from public.bloom_growth_items i where i.profile_id = v_profile and i.request_id = p_request_id;
  if found then
    if (v_item.parent_id, v_item.module_id, v_item.item_type, v_item.title, v_item.notes, v_item.due_date)
      is distinct from (p_parent_id, v_parent.module_id, p_item_type, trim(p_title), p_notes, p_due_date) then
      raise exception 'Request was already used for a different item';
    end if;
    return v_item.id;
  end if;
  insert into public.bloom_growth_items(profile_id, module_id, item_type, parent_id, title, notes, due_date, request_id)
    values (v_profile, v_parent.module_id, p_item_type, p_parent_id, trim(p_title), p_notes, p_due_date, p_request_id)
    returning * into v_item;
  return v_item.id;
end;
$$;

create function bloom_private.create_growth_project(p_title text, p_notes text, p_due_date date, p_request_id uuid)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to create a project'; end if;
  if not bloom_private.has_module_access(v_profile, 'tasks') then raise exception 'Tasks access is not assigned' using errcode = '42501'; end if;
  if p_request_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 120
    or p_notes is null or char_length(p_notes) > 2000 then raise exception 'Check the project details'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-project:' || v_profile::text || ':' || p_request_id::text, 0));
  select * into v_item from public.bloom_growth_items i where i.profile_id = v_profile and i.request_id = p_request_id;
  if found then
    if (v_item.module_id, v_item.item_type, v_item.parent_id, v_item.title, v_item.notes, v_item.due_date)
      is distinct from ('tasks', 'project', null::uuid, trim(p_title), p_notes, p_due_date) then raise exception 'Request was already used for a different item'; end if;
    return v_item.id;
  end if;
  insert into public.bloom_growth_items(profile_id, module_id, item_type, title, notes, due_date, request_id)
    values (v_profile, 'tasks', 'project', trim(p_title), p_notes, p_due_date, p_request_id) returning * into v_item;
  return v_item.id;
end;
$$;

create table public.bloom_study_plan_slots (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  item_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  target_minutes smallint not null check (target_minutes between 1 and 1440),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(profile_id, item_id, day_of_week)
);
create index bloom_study_plan_slots_profile_day_idx on public.bloom_study_plan_slots(profile_id, day_of_week, item_id);
create table public.bloom_study_plan_changes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  item_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  original_date date not null,
  action text not null check (action in ('skip', 'move')),
  moved_to_date date,
  created_at timestamptz not null default clock_timestamp(),
  unique(profile_id, item_id, original_date),
  check ((action = 'move') = (moved_to_date is not null)),
  check (moved_to_date is null or moved_to_date <> original_date)
);
alter table public.bloom_study_plan_slots enable row level security;
alter table public.bloom_study_plan_changes enable row level security;
revoke all on public.bloom_study_plan_slots, public.bloom_study_plan_changes from public, anon, authenticated;
grant select on public.bloom_study_plan_slots, public.bloom_study_plan_changes to authenticated;
create policy bloom_study_plan_slots_read on public.bloom_study_plan_slots for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and bloom_private.has_module_access(profile_id, 'study'));
create policy bloom_study_plan_changes_read on public.bloom_study_plan_changes for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and bloom_private.has_module_access(profile_id, 'study'));

create function bloom_private.save_study_plan(p_entries jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_entry jsonb;
  v_item uuid;
  v_day integer;
  v_minutes integer;
  v_total integer;
  v_root record;
  v_seen text[] := '{}';
begin
  if v_profile is null then raise exception 'Sign in to save a study plan'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  if jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) > 84 then raise exception 'Choose up to 84 study sessions'; end if;
  for v_entry in select value from jsonb_array_elements(p_entries) loop
    if jsonb_typeof(v_entry) <> 'object' or (v_entry->>'item_id') !~* '^[0-9a-f-]{36}$'
      or (v_entry->>'day_of_week') !~ '^[0-6]$' or (v_entry->>'target_minutes') !~ '^[0-9]{1,3}$' then
      raise exception 'Check the study schedule';
    end if;
    v_item := (v_entry->>'item_id')::uuid;
    v_day := (v_entry->>'day_of_week')::integer;
    v_minutes := (v_entry->>'target_minutes')::integer;
    if v_minutes not between 1 and 1440 or (v_item::text || ':' || v_day::text) = any(v_seen) then raise exception 'Check the study schedule'; end if;
    v_seen := array_append(v_seen, v_item::text || ':' || v_day::text);
    if not exists (select 1 from public.bloom_growth_items i where i.id = v_item and i.profile_id = v_profile
      and i.module_id = 'study' and i.state = 'active') then raise exception 'Choose an active subject, course, lesson, or assignment'; end if;
  end loop;
  for v_root in select i.id, i.target_minutes from public.bloom_growth_items i
    where i.profile_id = v_profile and i.module_id = 'study' and i.item_type = 'subject' and i.state = 'active'
  loop
    with recursive subtree(id) as (
      select v_root.id
      union all
      select child.id from public.bloom_growth_items child join subtree parent on child.parent_id = parent.id
        where child.profile_id = v_profile and child.module_id = 'study' and child.state = 'active'
    )
    select coalesce(sum((e->>'target_minutes')::integer), 0) into v_total
      from jsonb_array_elements(p_entries) e where (e->>'item_id')::uuid in (select id from subtree);
    if v_total <> v_root.target_minutes then raise exception 'Schedule each subject for exactly its weekly target'; end if;
  end loop;
  if exists (select 1 from public.bloom_growth_items i where i.profile_id = v_profile and i.module_id = 'study'
    and i.item_type = 'subject' and i.state = 'active' and not exists (
      with recursive subtree(id) as (
        select i.id union all select child.id from public.bloom_growth_items child join subtree parent on child.parent_id = parent.id
          where child.profile_id = v_profile and child.module_id = 'study' and child.state = 'active'
      ) select 1 from jsonb_array_elements(p_entries) e where (e->>'item_id')::uuid in (select id from subtree)
    )) then raise exception 'Schedule every active subject before saving'; end if;
  delete from public.bloom_study_plan_slots where profile_id = v_profile;
  insert into public.bloom_study_plan_slots(profile_id, item_id, day_of_week, target_minutes)
    select v_profile, (e->>'item_id')::uuid, (e->>'day_of_week')::smallint, (e->>'target_minutes')::smallint
    from jsonb_array_elements(p_entries) e;
end;
$$;

create function bloom_private.change_study_occurrence(p_item_id uuid, p_original_date date, p_action text, p_moved_to_date date default null)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_timezone text := 'UTC'; v_today date;
begin
  if v_profile is null then raise exception 'Sign in to update the study plan'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  select coalesce(nullif(s.credit_timezone, ''), 'UTC') into v_timezone from public.bloom_settings s where s.user_id = v_profile;
  v_today := (clock_timestamp() at time zone coalesce(v_timezone, 'UTC'))::date;
  if p_action not in ('skip', 'move') or p_original_date not between v_today - 7 and v_today + 21
    or not exists (select 1 from public.bloom_study_plan_slots x where x.profile_id = v_profile and x.item_id = p_item_id)
    or (p_action = 'move' and (p_moved_to_date is null or p_moved_to_date not between v_today and v_today + 28))
    or (p_action = 'skip' and p_moved_to_date is not null) then raise exception 'Choose a valid planned session'; end if;
  insert into public.bloom_study_plan_changes(profile_id, item_id, original_date, action, moved_to_date)
    values (v_profile, p_item_id, p_original_date, p_action, p_moved_to_date)
    on conflict (profile_id, item_id, original_date) do update set action = excluded.action, moved_to_date = excluded.moved_to_date, created_at = clock_timestamp();
end;
$$;

create table public.bloom_task_focus_sessions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  task_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  request_id uuid not null,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'cancelled')),
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds between 0 and 43200),
  unique(profile_id, request_id),
  check ((status = 'completed') = (completed_at is not null)),
  check ((status = 'completed') = (duration_seconds is not null))
);
create unique index bloom_task_focus_one_running_idx on public.bloom_task_focus_sessions(profile_id) where status = 'in_progress';
create index bloom_task_focus_history_idx on public.bloom_task_focus_sessions(profile_id, started_at desc);
alter table public.bloom_task_focus_sessions enable row level security;
revoke all on public.bloom_task_focus_sessions from public, anon, authenticated;
grant select on public.bloom_task_focus_sessions to authenticated;
create policy bloom_task_focus_sessions_read on public.bloom_task_focus_sessions for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and bloom_private.has_module_access(profile_id, 'tasks'));

create function bloom_private.start_task_focus(p_task_id uuid, p_request_id uuid)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_session public.bloom_task_focus_sessions%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to start Focus'; end if;
  if not bloom_private.has_module_access(v_profile, 'tasks') then raise exception 'Tasks access is not assigned' using errcode = '42501'; end if;
  if p_request_id is null or not exists (select 1 from public.bloom_growth_items i where i.id = p_task_id and i.profile_id = v_profile
    and i.module_id = 'tasks' and i.item_type = 'task' and i.state = 'active') then raise exception 'Choose an active task'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-task-focus:' || v_profile::text, 0));
  select * into v_session from public.bloom_task_focus_sessions s where s.profile_id = v_profile and s.request_id = p_request_id;
  if found then
    if v_session.task_id <> p_task_id then raise exception 'Request was already used for another task'; end if;
    return v_session.id;
  end if;
  if exists (select 1 from public.bloom_task_focus_sessions s where s.profile_id = v_profile and s.status = 'in_progress') then raise exception 'Finish or cancel the active Focus session first'; end if;
  insert into public.bloom_task_focus_sessions(profile_id, task_id, request_id) values (v_profile, p_task_id, p_request_id) returning id into v_session.id;
  return v_session.id;
end;
$$;
create function bloom_private.finish_task_focus(p_session_id uuid, p_cancel boolean default false)
returns table(duration_seconds integer, completed_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_session public.bloom_task_focus_sessions%rowtype; v_now timestamptz;
begin
  if v_profile is null then raise exception 'Sign in to finish Focus'; end if;
  select * into v_session from public.bloom_task_focus_sessions s where s.id = p_session_id and s.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, 'tasks') then raise exception 'Focus session not found' using errcode = '42501'; end if;
  if v_session.status = 'completed' then return query select v_session.duration_seconds, v_session.completed_at; return; end if;
  if v_session.status <> 'in_progress' then raise exception 'This Focus session was cancelled'; end if;
  if p_cancel then update public.bloom_task_focus_sessions set status = 'cancelled' where id = p_session_id; return; end if;
  v_now := clock_timestamp();
  if v_now - v_session.started_at > interval '12 hours' then raise exception 'This Focus session has expired; cancel it and start a new one'; end if;
  update public.bloom_task_focus_sessions s set status = 'completed', completed_at = v_now,
    duration_seconds = greatest(0, floor(extract(epoch from v_now - s.started_at))::integer)
    where s.id = p_session_id returning s.duration_seconds, s.completed_at into duration_seconds, completed_at;
  return next;
end;
$$;

create table public.bloom_growth_records (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  item_id uuid references public.bloom_growth_items(id) on delete cascade,
  kind text not null check (kind in (
    'verification', 'task_breakdown_draft', 'reading_note', 'reading_annotation', 'vocabulary',
    'practice_question', 'practice_answer', 'review_prompt', 'review_answer', 'exam', 'exam_attempt',
    'reflection', 'achievement'
  )),
  title text not null check (char_length(trim(title)) between 1 and 120),
  body text not null default '' check (char_length(body) <= 10000),
  metadata jsonb not null default '{}'::jsonb check (pg_column_size(metadata) <= 32768),
  scheduled_at timestamptz,
  score numeric(5,2) check (score is null or score between 0 and 100),
  request_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(profile_id, request_id),
  check (
    (kind in ('verification', 'practice_question', 'practice_answer', 'review_prompt', 'review_answer', 'exam', 'exam_attempt') and module_id = 'study')
    or (kind in ('reading_note', 'reading_annotation', 'vocabulary', 'reflection') and module_id = 'read')
    or (kind = 'task_breakdown_draft' and module_id = 'tasks')
    or (kind = 'achievement' and module_id in ('study', 'read', 'tasks'))
  )
);
create index bloom_growth_records_item_kind_idx on public.bloom_growth_records(profile_id, module_id, item_id, kind, created_at desc);
create index bloom_growth_records_due_idx on public.bloom_growth_records(profile_id, scheduled_at) where scheduled_at is not null;
alter table public.bloom_growth_records enable row level security;
revoke all on public.bloom_growth_records from public, anon, authenticated;
grant select on public.bloom_growth_records to authenticated;
create policy bloom_growth_records_read on public.bloom_growth_records for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) and bloom_private.has_module_access(profile_id, module_id));

create function bloom_private.save_growth_record(
  p_module_id text, p_item_id uuid, p_kind text, p_title text, p_body text,
  p_metadata jsonb, p_scheduled_at timestamptz, p_score numeric, p_request_id uuid
) returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_record public.bloom_growth_records%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to save this entry'; end if;
  if p_module_id not in ('study', 'read', 'tasks') or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'This module is not assigned to the active profile' using errcode = '42501';
  end if;
  if p_request_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 120
    or p_body is null or char_length(p_body) > 10000 or p_metadata is null or pg_column_size(p_metadata) > 32768
    or (p_score is not null and p_score not between 0 and 100) then raise exception 'Check the entry details'; end if;
  if p_item_id is not null and not exists (select 1 from public.bloom_growth_items i where i.id = p_item_id
    and i.profile_id = v_profile and i.module_id = p_module_id) then raise exception 'Choose an item in this module'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-record:' || v_profile::text || ':' || p_request_id::text, 0));
  select * into v_record from public.bloom_growth_records r where r.profile_id = v_profile and r.request_id = p_request_id;
  if found then
    if (v_record.module_id, v_record.item_id, v_record.kind, v_record.title, v_record.body, v_record.metadata, v_record.scheduled_at, v_record.score)
      is distinct from (p_module_id, p_item_id, p_kind, trim(p_title), p_body, p_metadata, p_scheduled_at, p_score) then
      raise exception 'Request was already used for another entry';
    end if;
    return v_record.id;
  end if;
  insert into public.bloom_growth_records(profile_id, module_id, item_id, kind, title, body, metadata, scheduled_at, score, request_id)
    values (v_profile, p_module_id, p_item_id, p_kind, trim(p_title), p_body, p_metadata, p_scheduled_at, p_score, p_request_id)
    returning * into v_record;
  return v_record.id;
end;
$$;
create function bloom_private.update_growth_record(p_record_id uuid, p_title text, p_body text, p_metadata jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_module text;
begin
  if v_profile is null then raise exception 'Sign in to update this entry'; end if;
  select r.module_id into v_module from public.bloom_growth_records r where r.id = p_record_id and r.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_module) then raise exception 'Entry not found' using errcode = '42501'; end if;
  if p_title is null or char_length(trim(p_title)) not between 1 and 120 or p_body is null or char_length(p_body) > 10000
    or p_metadata is null or pg_column_size(p_metadata) > 32768 then raise exception 'Check the entry details'; end if;
  update public.bloom_growth_records set title = trim(p_title), body = p_body, metadata = p_metadata, updated_at = clock_timestamp() where id = p_record_id;
end;
$$;
create function bloom_private.delete_growth_record(p_record_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_module text;
begin
  if v_profile is null then raise exception 'Sign in to delete this entry'; end if;
  select r.module_id into v_module from public.bloom_growth_records r where r.id = p_record_id and r.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_module) then raise exception 'Entry not found' using errcode = '42501'; end if;
  delete from public.bloom_growth_records where id = p_record_id;
end;
$$;

create function bloom_private.submit_study_review(p_prompt_id uuid, p_response text, p_rating text, p_next_days integer, p_request_id uuid)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_prompt public.bloom_growth_records%rowtype;
  v_answer public.bloom_growth_records%rowtype; v_answer_id uuid; v_next_id uuid; v_next_request uuid;
  v_metadata jsonb;
begin
  if v_profile is null then raise exception 'Sign in to save a review'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  if p_request_id is null or p_response is null or char_length(trim(p_response)) not between 1 and 5000
    or p_rating is null or p_rating not in ('hard', 'remembered', 'easy') or p_next_days is null or p_next_days not between 1 and 30 then
    raise exception 'Check the review response';
  end if;
  select * into v_prompt from public.bloom_growth_records r where r.id = p_prompt_id and r.profile_id = v_profile
    and r.module_id = 'study' and r.kind = 'review_prompt' for update;
  if not found then raise exception 'Review prompt not found' using errcode = '42501'; end if;
  if v_prompt.scheduled_at is null or v_prompt.scheduled_at > clock_timestamp() then raise exception 'This review is not due yet'; end if;
  select * into v_answer from public.bloom_growth_records r where r.profile_id = v_profile and r.module_id = 'study'
    and r.kind = 'review_answer' and r.metadata->>'prompt_id' = p_prompt_id::text for update;
  if found then
    if v_answer.request_id = p_request_id and v_answer.body = trim(p_response)
      and v_answer.metadata->>'rating' = p_rating and (v_answer.metadata->>'next_interval_days')::integer = p_next_days
      and v_answer.metadata->>'next_prompt_id' is not null then
      return (v_answer.metadata->>'next_prompt_id')::uuid;
    end if;
    raise exception 'This prompt was already reviewed';
  end if;
  v_metadata := jsonb_build_object('prompt_id', p_prompt_id, 'rating', p_rating, 'next_interval_days', p_next_days);
  v_answer_id := bloom_private.save_growth_record('study', v_prompt.item_id, 'review_answer', v_prompt.title,
    trim(p_response), v_metadata, null, null, p_request_id);
  v_next_request := md5(p_request_id::text || ':next-review')::uuid;
  v_next_id := bloom_private.save_growth_record('study', v_prompt.item_id, 'review_prompt', v_prompt.title,
    v_prompt.body, jsonb_build_object('previous_prompt_id', p_prompt_id), clock_timestamp() + make_interval(days => p_next_days),
    null, v_next_request);
  update public.bloom_growth_records set metadata = metadata || jsonb_build_object('next_prompt_id', v_next_id), updated_at = clock_timestamp()
    where id = v_answer_id;
  return v_next_id;
end;
$$;

create table public.bloom_growth_ai_settings (
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  sharing_consent boolean not null default false,
  adult_attested boolean not null default false,
  parent_enabled boolean not null default false,
  minor_eligible_attested boolean not null default false,
  parent_sharing_consent boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(profile_id, module_id),
  check (not adult_attested or sharing_consent),
  check (not parent_enabled or (minor_eligible_attested and parent_sharing_consent))
);
alter table public.bloom_growth_ai_settings enable row level security;
revoke all on public.bloom_growth_ai_settings from public, anon, authenticated;
grant select on public.bloom_growth_ai_settings to authenticated;
create policy bloom_growth_ai_settings_read on public.bloom_growth_ai_settings for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));

create table bloom_private.growth_ai_requests (
  id uuid primary key,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  module_id text not null check (module_id in ('study', 'read', 'tasks')),
  request_kind text not null check (request_kind in ('task_breakdown')),
  item_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  approval_steps jsonb,
  status text not null check (status in ('pending', 'completed', 'failed')),
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  unique(profile_id, id)
);
create index growth_ai_requests_limit_idx on bloom_private.growth_ai_requests(profile_id, created_at desc);
revoke all on bloom_private.growth_ai_requests from public, anon, authenticated;

create function bloom_private.set_growth_ai_preferences(p_module_id text, p_consent boolean, p_adult_attested boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_child boolean;
begin
  if v_profile is null then raise exception 'Sign in to manage AI preferences'; end if;
  if p_module_id not in ('study', 'read', 'tasks') or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'This module is not assigned to the active profile' using errcode = '42501';
  end if;
  if p_consent is null or p_adult_attested is null then raise exception 'Choose valid privacy preferences'; end if;
  v_child := bloom_private.is_child_profile(v_profile);
  if (v_child and p_adult_attested) or (not v_child and p_consent and not p_adult_attested) then
    raise exception 'Age eligibility and consent are required';
  end if;
  insert into public.bloom_growth_ai_settings(profile_id, module_id, sharing_consent, adult_attested)
    values (v_profile, p_module_id, p_consent, p_consent and p_adult_attested)
    on conflict (profile_id, module_id) do update set sharing_consent = excluded.sharing_consent,
      adult_attested = excluded.adult_attested, updated_at = clock_timestamp();
end;
$$;
create function bloom_private.set_child_growth_ai_preferences(p_child_id uuid, p_module_id text, p_enabled boolean, p_eligible boolean, p_consent boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id)
    or not bloom_private.is_child_profile(p_child_id) then raise exception 'Parent access required'; end if;
  if p_module_id not in ('study', 'read', 'tasks') or p_enabled is null or p_eligible is null or p_consent is null
    or (p_enabled and (not p_eligible or not p_consent)) then raise exception 'Parent consent and eligibility are required'; end if;
  insert into public.bloom_growth_ai_settings(profile_id, module_id, parent_enabled, minor_eligible_attested, parent_sharing_consent)
    values (p_child_id, p_module_id, p_enabled, p_enabled and p_eligible, p_enabled and p_consent)
    on conflict (profile_id, module_id) do update set parent_enabled = excluded.parent_enabled,
      minor_eligible_attested = excluded.minor_eligible_attested, parent_sharing_consent = excluded.parent_sharing_consent,
      updated_at = clock_timestamp();
end;
$$;

create function bloom_private.begin_growth_ai_request(p_request_id uuid, p_module_id text, p_kind text, p_item_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_child boolean; v_settings public.bloom_growth_ai_settings%rowtype;
  v_task public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to request a task breakdown'; end if;
  if p_request_id is null or p_module_id <> 'tasks' or p_kind <> 'task_breakdown'
    or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Check the AI request'; end if;
  if not bloom_private.has_module_access(v_profile, 'tasks') then raise exception 'Tasks access is not assigned' using errcode = '42501'; end if;
  select * into v_task from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = 'tasks' and i.item_type = 'task' and i.state = 'active';
  if not found then raise exception 'Choose an active task'; end if;
  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = 'tasks';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
      and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then raise exception 'Task AI consent and eligibility are required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  if exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.id = p_request_id) then
    raise exception 'This AI request has already been used';
  end if;
  if (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '1 minute') >= 2 then
    raise exception 'AI request limit reached';
  end if;
  if exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.status = 'pending'
    and r.created_at > clock_timestamp() - interval '2 minutes') then raise exception 'An AI request is already running'; end if;
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, status)
    values (p_request_id, v_profile, p_module_id, p_kind, p_item_id, 'pending');
  -- The user prompt is validated but deliberately not persisted or included in diagnostics.
  return jsonb_build_object('is_child', v_child, 'task', jsonb_build_object('title', left(v_task.title, 120), 'notes', left(v_task.notes, 1000)));
end;
$$;
create function bloom_private.finish_growth_ai_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp()
    where id = p_request_id and status = 'pending';
  if not found then raise exception 'AI request is unavailable'; end if;
end;
$$;
create function bloom_private.fail_growth_ai_request(p_request_id uuid)
returns void language sql security definer set search_path = pg_catalog, pg_temp as $$
  update bloom_private.growth_ai_requests set status = 'failed' where id = p_request_id and status = 'pending';
$$;

create function bloom_private.apply_task_breakdown(p_task_id uuid, p_steps jsonb, p_request_id uuid)
returns setof uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_task public.bloom_growth_items%rowtype; v_ai_request bloom_private.growth_ai_requests%rowtype;
  v_step jsonb; v_index integer := 0;
begin
  if v_profile is null then raise exception 'Sign in to save task steps'; end if;
  if not bloom_private.has_module_access(v_profile, 'tasks') then raise exception 'Tasks access is not assigned' using errcode = '42501'; end if;
  select * into v_task from public.bloom_growth_items i where i.id = p_task_id and i.profile_id = v_profile
    and i.module_id = 'tasks' and i.item_type = 'task' and i.state = 'active' for update;
  if not found then raise exception 'Choose an active task'; end if;
  select * into v_ai_request from bloom_private.growth_ai_requests r where r.id = p_request_id and r.profile_id = v_profile
    and r.item_id = p_task_id and r.request_kind = 'task_breakdown' and r.status = 'completed' for update;
  if not found then raise exception 'Review a completed AI draft before saving steps'; end if;
  if p_request_id is null or jsonb_typeof(p_steps) <> 'array' or jsonb_array_length(p_steps) not between 1 and 12 then raise exception 'Choose 1–12 task steps'; end if;
  if v_ai_request.approval_steps is not null and v_ai_request.approval_steps is distinct from p_steps then
    raise exception 'This draft was already approved with different steps';
  end if;
  if v_ai_request.approval_steps is null then
    update bloom_private.growth_ai_requests set approval_steps = p_steps where id = p_request_id;
  end if;
  for v_step in select value from jsonb_array_elements(p_steps) loop
    if jsonb_typeof(v_step) <> 'string' or char_length(trim(v_step #>> '{}')) not between 1 and 120 then raise exception 'Each step must have 1–120 characters'; end if;
    return next bloom_private.create_growth_child(v_task.id, 'checklist', trim(v_step #>> '{}'), '', null,
      md5(p_request_id::text || ':' || v_index::text)::uuid);
    v_index := v_index + 1;
  end loop;
end;
$$;

create function public.bloom_set_growth_ai_preferences(p_module_id text, p_consent boolean, p_adult_attested boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.set_growth_ai_preferences(p_module_id, p_consent, p_adult_attested); $$;
create function public.bloom_set_child_growth_ai_preferences(p_child_id uuid, p_module_id text, p_enabled boolean, p_eligible boolean, p_consent boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.set_child_growth_ai_preferences(p_child_id, p_module_id, p_enabled, p_eligible, p_consent); $$;
create function public.bloom_begin_growth_ai_request(p_request_id uuid, p_module_id text, p_kind text, p_item_id uuid, p_prompt text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.begin_growth_ai_request(p_request_id, p_module_id, p_kind, p_item_id, p_prompt); $$;
create function public.bloom_finish_growth_ai_request(p_request_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.finish_growth_ai_request(p_request_id); $$;
create function public.bloom_fail_growth_ai_request(p_request_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.fail_growth_ai_request(p_request_id); $$;
create function public.bloom_apply_task_breakdown(p_task_id uuid, p_steps jsonb, p_request_id uuid)
returns setof uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$ select * from bloom_private.apply_task_breakdown(p_task_id, p_steps, p_request_id); $$;

create function public.bloom_create_growth_child(p_parent_id uuid, p_item_type text, p_title text, p_notes text, p_due_date date, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.create_growth_child(p_parent_id, p_item_type, p_title, p_notes, p_due_date, p_request_id); $$;
create function public.bloom_create_growth_project(p_title text, p_notes text, p_due_date date, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.create_growth_project(p_title, p_notes, p_due_date, p_request_id); $$;
create function public.bloom_save_study_plan(p_entries jsonb)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.save_study_plan(p_entries); $$;
create function public.bloom_change_study_occurrence(p_item_id uuid, p_original_date date, p_action text, p_moved_to_date date default null)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.change_study_occurrence(p_item_id, p_original_date, p_action, p_moved_to_date); $$;
create function public.bloom_start_task_focus(p_task_id uuid, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.start_task_focus(p_task_id, p_request_id); $$;
create function public.bloom_finish_task_focus(p_session_id uuid, p_cancel boolean default false)
returns table(duration_seconds integer, completed_at timestamptz) language sql security invoker set search_path = pg_catalog, pg_temp as $$ select * from bloom_private.finish_task_focus(p_session_id, p_cancel); $$;
create function public.bloom_save_growth_record(p_module_id text, p_item_id uuid, p_kind text, p_title text, p_body text,
  p_metadata jsonb, p_scheduled_at timestamptz, p_score numeric, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.save_growth_record(p_module_id, p_item_id, p_kind, p_title, p_body, p_metadata, p_scheduled_at, p_score, p_request_id);
$$;
create function public.bloom_update_growth_record(p_record_id uuid, p_title text, p_body text, p_metadata jsonb)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.update_growth_record(p_record_id, p_title, p_body, p_metadata); $$;
create function public.bloom_delete_growth_record(p_record_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.delete_growth_record(p_record_id); $$;
create function public.bloom_submit_study_review(p_prompt_id uuid, p_response text, p_rating text, p_next_days integer, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.submit_study_review(p_prompt_id, p_response, p_rating, p_next_days, p_request_id);
$$;

revoke all on function bloom_private.create_growth_child(uuid, text, text, text, date, uuid), bloom_private.create_growth_project(text, text, date, uuid), bloom_private.save_study_plan(jsonb),
  bloom_private.change_study_occurrence(uuid, date, text, date), bloom_private.start_task_focus(uuid, uuid),
  bloom_private.finish_task_focus(uuid, boolean), bloom_private.save_growth_record(text, uuid, text, text, text, jsonb, timestamptz, numeric, uuid),
  bloom_private.update_growth_record(uuid, text, text, jsonb), bloom_private.delete_growth_record(uuid),
  bloom_private.submit_study_review(uuid, text, text, integer, uuid) from public, anon, authenticated;
revoke all on function bloom_private.set_growth_ai_preferences(text, boolean, boolean),
  bloom_private.set_child_growth_ai_preferences(uuid, text, boolean, boolean, boolean),
  bloom_private.begin_growth_ai_request(uuid, text, text, uuid, text), bloom_private.finish_growth_ai_request(uuid),
  bloom_private.fail_growth_ai_request(uuid), bloom_private.apply_task_breakdown(uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function bloom_private.create_growth_child(uuid, text, text, text, date, uuid), bloom_private.create_growth_project(text, text, date, uuid), bloom_private.save_study_plan(jsonb),
  bloom_private.change_study_occurrence(uuid, date, text, date), bloom_private.start_task_focus(uuid, uuid),
  bloom_private.finish_task_focus(uuid, boolean), bloom_private.save_growth_record(text, uuid, text, text, text, jsonb, timestamptz, numeric, uuid),
  bloom_private.update_growth_record(uuid, text, text, jsonb), bloom_private.delete_growth_record(uuid),
  bloom_private.submit_study_review(uuid, text, text, integer, uuid) to authenticated;
grant execute on function bloom_private.set_growth_ai_preferences(text, boolean, boolean),
  bloom_private.set_child_growth_ai_preferences(uuid, text, boolean, boolean, boolean),
  bloom_private.begin_growth_ai_request(uuid, text, text, uuid, text), bloom_private.apply_task_breakdown(uuid, jsonb, uuid) to authenticated;
grant execute on function bloom_private.finish_growth_ai_request(uuid), bloom_private.fail_growth_ai_request(uuid) to service_role;
revoke all on function public.bloom_create_growth_child(uuid, text, text, text, date, uuid), public.bloom_create_growth_project(text, text, date, uuid), public.bloom_save_study_plan(jsonb),
  public.bloom_change_study_occurrence(uuid, date, text, date), public.bloom_start_task_focus(uuid, uuid),
  public.bloom_finish_task_focus(uuid, boolean), public.bloom_save_growth_record(text, uuid, text, text, text, jsonb, timestamptz, numeric, uuid),
  public.bloom_update_growth_record(uuid, text, text, jsonb), public.bloom_delete_growth_record(uuid),
  public.bloom_submit_study_review(uuid, text, text, integer, uuid) from public, anon;
revoke all on function public.bloom_set_growth_ai_preferences(text, boolean, boolean),
  public.bloom_set_child_growth_ai_preferences(uuid, text, boolean, boolean, boolean),
  public.bloom_begin_growth_ai_request(uuid, text, text, uuid, text), public.bloom_finish_growth_ai_request(uuid),
  public.bloom_fail_growth_ai_request(uuid), public.bloom_apply_task_breakdown(uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function public.bloom_create_growth_child(uuid, text, text, text, date, uuid), public.bloom_create_growth_project(text, text, date, uuid), public.bloom_save_study_plan(jsonb),
  public.bloom_change_study_occurrence(uuid, date, text, date), public.bloom_start_task_focus(uuid, uuid),
  public.bloom_finish_task_focus(uuid, boolean), public.bloom_save_growth_record(text, uuid, text, text, text, jsonb, timestamptz, numeric, uuid),
  public.bloom_update_growth_record(uuid, text, text, jsonb), public.bloom_delete_growth_record(uuid),
  public.bloom_submit_study_review(uuid, text, text, integer, uuid) to authenticated;
grant execute on function public.bloom_set_growth_ai_preferences(text, boolean, boolean),
  public.bloom_set_child_growth_ai_preferences(uuid, text, boolean, boolean, boolean),
  public.bloom_begin_growth_ai_request(uuid, text, text, uuid, text), public.bloom_apply_task_breakdown(uuid, jsonb, uuid) to authenticated;
grant execute on function public.bloom_finish_growth_ai_request(uuid), public.bloom_fail_growth_ai_request(uuid) to service_role;

commit;
