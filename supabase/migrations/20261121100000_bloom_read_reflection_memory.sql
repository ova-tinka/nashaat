begin;

alter table bloom_private.growth_ai_requests
  drop constraint growth_ai_requests_request_kind_check,
  add constraint growth_ai_requests_request_kind_check
    check (request_kind in ('task_breakdown', 'study_tutor', 'mock_exam_assess', 'document_help', 'read_reflection')),
  add column read_reflection_prompt jsonb,
  add constraint growth_ai_requests_read_reflection_prompt_check check (
    read_reflection_prompt is null or (
      request_kind = 'read_reflection'
      and jsonb_typeof(read_reflection_prompt) = 'object'
      and jsonb_typeof(read_reflection_prompt->'prompt') = 'string'
      and char_length(read_reflection_prompt->>'prompt') between 1 and 120
      and jsonb_typeof(read_reflection_prompt->'uncertainty') = 'string'
      and char_length(read_reflection_prompt->>'uncertainty') between 1 and 500
    )
  );

create function bloom_private.begin_read_reflection_request(p_request_id uuid, p_item_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_child boolean;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_item public.bloom_growth_items%rowtype;
  v_request bloom_private.growth_ai_requests%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to request a reading reflection'; end if;
  if p_request_id is null or p_item_id is null then raise exception 'Choose a reading item'; end if;
  if not bloom_private.has_module_access(v_profile, 'read') then
    raise exception 'Read access is not assigned' using errcode = '42501';
  end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id
    and i.profile_id = v_profile and i.module_id = 'read' and i.item_type = 'reading' and i.state = 'active';
  if not found then raise exception 'Choose an active reading item'; end if;

  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = 'read';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then
    raise exception 'Reading reflection consent and eligibility are required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  select * into v_request from bloom_private.growth_ai_requests r where r.id = p_request_id and r.profile_id = v_profile;
  if found then
    if v_request.module_id <> 'read' or v_request.request_kind <> 'read_reflection' or v_request.item_id <> p_item_id then
      raise exception 'This AI request was already used';
    end if;
    if v_request.status = 'completed' and v_request.read_reflection_prompt is not null then
      return jsonb_build_object('status', 'completed', 'response', v_request.read_reflection_prompt);
    end if;
    raise exception 'This AI request has already been processed';
  end if;
  if (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile
      and r.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile
      and r.created_at > clock_timestamp() - interval '1 minute') >= 2 then
    raise exception 'AI request limit reached';
  end if;
  if exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.status = 'pending'
      and r.created_at > clock_timestamp() - interval '2 minutes') then
    raise exception 'An AI request is already running';
  end if;
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, status)
    values (p_request_id, v_profile, 'read', 'read_reflection', p_item_id, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child,
    'reading', jsonb_build_object('title', left(v_item.title, 120), 'notes', left(v_item.notes, 1000)));
end;
$$;

create function bloom_private.finish_read_reflection_request(p_request_id uuid, p_prompt text, p_uncertainty text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_request bloom_private.growth_ai_requests%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_child boolean;
  v_response jsonb;
begin
  if p_request_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 120
    or p_uncertainty is null or char_length(trim(p_uncertainty)) not between 1 and 500 then
    raise exception 'Invalid reading reflection response';
  end if;
  select * into v_request from bloom_private.growth_ai_requests r where r.id = p_request_id
    and r.request_kind = 'read_reflection' for update;
  if not found then raise exception 'Reading reflection request is unavailable'; end if;
  v_child := bloom_private.is_child_profile(v_request.profile_id);
  select * into v_settings from public.bloom_growth_ai_settings s
    where s.profile_id = v_request.profile_id and s.module_id = 'read';
  if not found or not v_settings.sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested)
    or not bloom_private.has_module_access(v_request.profile_id, 'read') then
    raise exception 'Reading reflection consent was withdrawn';
  end if;
  v_response := jsonb_build_object('prompt', trim(p_prompt), 'uncertainty', trim(p_uncertainty));
  if v_request.status = 'completed' then
    if v_request.read_reflection_prompt is distinct from v_response then raise exception 'Reading reflection request was already completed'; end if;
    return v_request.read_reflection_prompt;
  end if;
  if v_request.status <> 'pending' then raise exception 'Reading reflection request is unavailable'; end if;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), read_reflection_prompt = v_response
    where id = p_request_id;
  return v_response;
end;
$$;

create or replace function bloom_private.growth_ai_memory_context(p_module_id text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_coach_settings public.bloom_coach_settings%rowtype;
  v_child boolean;
  v_memory public.bloom_growth_memory%rowtype;
  v_context jsonb;
begin
  if v_profile is null or p_module_id not in ('exercise', 'study', 'read', 'tasks')
    or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'AI module access is not assigned' using errcode = '42501';
  end if;
  v_child := bloom_private.is_child_profile(v_profile);
  if p_module_id = 'exercise' then
    select * into v_coach_settings from public.bloom_coach_settings s where s.profile_id = v_profile;
    if not found or not v_coach_settings.sharing_consent
      or (v_child and not (v_coach_settings.parent_enabled and v_coach_settings.parent_sharing_consent and v_coach_settings.minor_eligible_attested))
      or (not v_child and not v_coach_settings.adult_attested) then
      raise exception 'AI consent and eligibility are required';
    end if;
  else
    select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = p_module_id;
    if not found or not v_settings.sharing_consent
      or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
      or (not v_child and not v_settings.adult_attested) then
      raise exception 'AI consent and eligibility are required';
    end if;
  end if;
  select * into v_memory from public.bloom_growth_memory m where m.profile_id = v_profile;
  if not found or not v_memory.enabled then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(jsonb_build_object('domain', d.domain, 'summary', left(v_memory.summaries->>d.domain, 1200)) order by d.domain), '[]'::jsonb)
    into v_context from unnest(v_memory.shared_domains) as d(domain)
    where nullif(trim(v_memory.summaries->>d.domain), '') is not null;
  return v_context;
end;
$$;

create function public.bloom_begin_read_reflection_request(p_request_id uuid, p_item_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.begin_read_reflection_request(p_request_id, p_item_id);
$$;
create function public.bloom_finish_read_reflection_request(p_request_id uuid, p_prompt text, p_uncertainty text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.finish_read_reflection_request(p_request_id, p_prompt, p_uncertainty);
$$;

revoke all on function bloom_private.begin_read_reflection_request(uuid, uuid),
  bloom_private.finish_read_reflection_request(uuid, text, text) from public, anon, authenticated;
grant execute on function bloom_private.begin_read_reflection_request(uuid, uuid) to authenticated;
grant execute on function bloom_private.finish_read_reflection_request(uuid, text, text) to service_role;
revoke all on function public.bloom_begin_read_reflection_request(uuid, uuid),
  public.bloom_finish_read_reflection_request(uuid, text, text) from public, anon, authenticated;
grant execute on function public.bloom_begin_read_reflection_request(uuid, uuid) to authenticated;
grant execute on function public.bloom_finish_read_reflection_request(uuid, text, text) to service_role;

commit;
