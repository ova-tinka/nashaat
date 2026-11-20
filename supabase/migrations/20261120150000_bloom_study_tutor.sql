begin;

alter table bloom_private.growth_ai_requests
  drop constraint growth_ai_requests_request_kind_check,
  add constraint growth_ai_requests_request_kind_check
    check (request_kind in ('task_breakdown', 'study_tutor'));

create table public.bloom_study_tutor_messages (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  item_id uuid not null references public.bloom_growth_items(id) on delete cascade,
  request_id uuid not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(trim(content)) between 1 and 4000),
  answer_scope text check (answer_scope is null or answer_scope in ('general')),
  uncertainty text check (uncertainty is null or char_length(uncertainty) <= 500),
  created_at timestamptz not null default clock_timestamp(),
  unique (request_id, role),
  check ((role = 'user' and answer_scope is null and uncertainty is null)
    or (role = 'assistant' and answer_scope = 'general'))
);
create index bloom_study_tutor_messages_profile_idx
  on public.bloom_study_tutor_messages(profile_id, created_at desc);
alter table public.bloom_study_tutor_messages enable row level security;
revoke all on public.bloom_study_tutor_messages from public, anon, authenticated;
grant select on public.bloom_study_tutor_messages to authenticated;
create policy bloom_study_tutor_messages_read on public.bloom_study_tutor_messages for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(profile_id, 'study'));

create function bloom_private.begin_study_tutor_request(p_request_id uuid, p_item_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_child boolean;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to use the Study tutor'; end if;
  if p_request_id is null or p_item_id is null or p_prompt is null
    or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Enter a question of up to 2,000 characters'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = 'study' and i.state <> 'archived';
  if not found then raise exception 'Choose a Study item'; end if;
  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = 'study';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
      and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then
    raise exception 'Study tutor consent and eligibility are required';
  end if;
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
    values (p_request_id, v_profile, 'study', 'study_tutor', p_item_id, 'pending');
  -- The question is not stored until the tutor response is ready and is never
  -- copied into the private request metadata or diagnostic logs.
  return jsonb_build_object('is_child', v_child,
    'item', jsonb_build_object('title', left(v_item.title, 120), 'notes', left(v_item.notes, 1000)));
end;
$$;

create function bloom_private.finish_study_tutor_request(
  p_request_id uuid, p_prompt text, p_answer text, p_uncertainty text
) returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_request bloom_private.growth_ai_requests%rowtype;
begin
  if p_request_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000
    or p_answer is null or char_length(trim(p_answer)) not between 1 and 4000
    or p_uncertainty is null or char_length(p_uncertainty) > 500 then raise exception 'Invalid tutor response'; end if;
  select * into v_request from bloom_private.growth_ai_requests r where r.id = p_request_id
    and r.request_kind = 'study_tutor' and r.status = 'pending' for update;
  if not found then raise exception 'Study tutor request is unavailable'; end if;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp()
    where id = p_request_id;
  insert into public.bloom_study_tutor_messages(profile_id, item_id, request_id, role, content)
    values (v_request.profile_id, v_request.item_id, p_request_id, 'user', trim(p_prompt));
  insert into public.bloom_study_tutor_messages(profile_id, item_id, request_id, role, content, answer_scope, uncertainty)
    values (v_request.profile_id, v_request.item_id, p_request_id, 'assistant', trim(p_answer), 'general', trim(p_uncertainty));
end;
$$;

create function bloom_private.clear_study_tutor_conversation()
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to clear this conversation'; end if;
  if not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is not assigned' using errcode = '42501'; end if;
  delete from public.bloom_study_tutor_messages where profile_id = v_profile;
  delete from bloom_private.growth_ai_requests where profile_id = v_profile and request_kind = 'study_tutor';
end;
$$;

create function bloom_private.get_child_growth_ai_status(p_child_id uuid, p_module_id text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_settings public.bloom_growth_ai_settings%rowtype;
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id)
    or not bloom_private.is_child_profile(p_child_id) then raise exception 'Parent access required' using errcode = '42501'; end if;
  if p_module_id not in ('study', 'read', 'tasks') then raise exception 'Invalid AI module'; end if;
  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = p_child_id and s.module_id = p_module_id;
  return jsonb_build_object('enabled', coalesce(v_settings.parent_enabled, false),
    'eligible', coalesce(v_settings.minor_eligible_attested, false),
    'parent_consent', coalesce(v_settings.parent_sharing_consent, false));
end;
$$;

create function public.bloom_begin_study_tutor_request(p_request_id uuid, p_item_id uuid, p_prompt text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.begin_study_tutor_request(p_request_id, p_item_id, p_prompt);
$$;
create function public.bloom_clear_study_tutor_conversation()
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.clear_study_tutor_conversation();
$$;
create function public.bloom_get_child_growth_ai_status(p_child_id uuid, p_module_id text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.get_child_growth_ai_status(p_child_id, p_module_id);
$$;

revoke all on function bloom_private.begin_study_tutor_request(uuid, uuid, text),
  bloom_private.finish_study_tutor_request(uuid, text, text, text), bloom_private.clear_study_tutor_conversation(),
  bloom_private.get_child_growth_ai_status(uuid, text) from public, anon, authenticated;
grant execute on function bloom_private.begin_study_tutor_request(uuid, uuid, text),
  bloom_private.clear_study_tutor_conversation(), bloom_private.get_child_growth_ai_status(uuid, text) to authenticated;
grant execute on function bloom_private.finish_study_tutor_request(uuid, text, text, text) to service_role;
revoke all on function public.bloom_begin_study_tutor_request(uuid, uuid, text),
  public.bloom_clear_study_tutor_conversation(), public.bloom_get_child_growth_ai_status(uuid, text) from public, anon, authenticated;
grant execute on function public.bloom_begin_study_tutor_request(uuid, uuid, text),
  public.bloom_clear_study_tutor_conversation(), public.bloom_get_child_growth_ai_status(uuid, text) to authenticated;

commit;
