begin;

alter table public.bloom_growth_documents
  add column if not exists status text not null default 'ready'
    check (status in ('pending', 'ready', 'deleting')),
  add column if not exists updated_at timestamptz not null default clock_timestamp();

create or replace function bloom_private.create_growth_document(
  p_module_id text, p_item_id uuid, p_title text, p_file_name text, p_format text, p_mime_type text,
  p_byte_size integer, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype;
  v_doc public.bloom_growth_documents%rowtype; v_id uuid; v_path text; v_ext text;
begin
  if v_profile is null then raise exception 'Sign in to add a private document'; end if;
  if p_module_id not in ('study', 'read') or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'This module is not assigned to the active profile' using errcode = '42501';
  end if;
  if p_request_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 120
    or p_file_name is null or char_length(trim(p_file_name)) not between 1 and 180
    or p_file_name ~ '[[:cntrl:]/\\]' or p_mime_type is null or p_byte_size is null then raise exception 'Check the document details'; end if;
  if (p_module_id = 'study' and (p_format not in ('pdf', 'docx') or p_byte_size not between 1 and 10485760
      or (p_format = 'pdf' and p_mime_type <> 'application/pdf')
      or (p_format = 'docx' and p_mime_type <> 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')))
    or (p_module_id = 'read' and (p_format not in ('pdf', 'epub') or p_byte_size not between 1 and 26214400
      or (p_format = 'pdf' and p_mime_type <> 'application/pdf')
      or (p_format = 'epub' and p_mime_type <> 'application/epub+zip'))) then raise exception 'This format or size is not supported'; end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile
    and i.module_id = p_module_id and i.state <> 'archived';
  if not found or (p_module_id = 'read' and v_item.item_type <> 'reading') then raise exception 'Choose an active item in this module'; end if;
  select * into v_doc from public.bloom_growth_documents d where d.profile_id = v_profile and d.request_id = p_request_id for update;
  if found then
    if (v_doc.module_id, v_doc.item_id, v_doc.title, v_doc.file_name, v_doc.format, v_doc.byte_size)
      is distinct from (p_module_id, p_item_id, trim(p_title), trim(p_file_name), p_format, p_byte_size) then
      raise exception 'Request was already used for a different document'; end if;
    if v_doc.status = 'deleting' then
      raise exception 'This document is being deleted';
    end if;
    return jsonb_build_object('id', v_doc.id, 'storage_path', v_doc.storage_path, 'status', v_doc.status);
  end if;
  v_id := gen_random_uuid();
  v_ext := case p_format when 'pdf' then 'pdf' when 'docx' then 'docx' else 'epub' end;
  v_path := v_profile::text || '/' || p_module_id || '/' || v_id::text || '.' || v_ext;
  insert into public.bloom_growth_documents(id, profile_id, module_id, item_id, title, file_name, format, mime_type, byte_size, storage_path, request_id, status)
    values (v_id, v_profile, p_module_id, p_item_id, trim(p_title), trim(p_file_name), p_format, p_mime_type, p_byte_size, v_path, p_request_id, 'pending');
  return jsonb_build_object('id', v_id, 'storage_path', v_path, 'status', 'pending');
end;
$$;

create or replace function bloom_private.confirm_growth_document(p_document_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_doc public.bloom_growth_documents%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to confirm this document'; end if;
  select * into v_doc from public.bloom_growth_documents d
    where d.id = p_document_id and d.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_doc.module_id) then
    raise exception 'Document not found' using errcode = '42501';
  end if;
  if v_doc.status = 'ready' then
    return jsonb_build_object('id', v_doc.id, 'storage_path', v_doc.storage_path, 'status', 'ready');
  end if;
  if v_doc.status = 'deleting' then
    raise exception 'Document is being deleted';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'bloom-growth-content' and o.name = v_doc.storage_path
  ) then
    raise exception 'Uploaded file was not found in private storage';
  end if;
  update public.bloom_growth_documents
  set status = 'ready', updated_at = clock_timestamp()
  where id = p_document_id and profile_id = v_profile;
  return jsonb_build_object('id', v_doc.id, 'storage_path', v_doc.storage_path, 'status', 'ready');
end;
$$;

create or replace function bloom_private.begin_delete_growth_document(p_document_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_doc public.bloom_growth_documents%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to delete this document'; end if;
  select * into v_doc from public.bloom_growth_documents d
    where d.id = p_document_id and d.profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_doc.module_id) then
    raise exception 'Document not found' using errcode = '42501';
  end if;
  update public.bloom_growth_documents
  set status = 'deleting', updated_at = clock_timestamp()
  where id = p_document_id and profile_id = v_profile;
  return jsonb_build_object('id', v_doc.id, 'storage_path', v_doc.storage_path, 'status', 'deleting');
end;
$$;

create or replace function bloom_private.delete_growth_document(p_document_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_path text; v_module text;
begin
  if v_profile is null then raise exception 'Sign in to delete this document'; end if;
  select storage_path, module_id into v_path, v_module from public.bloom_growth_documents
    where id = p_document_id and profile_id = v_profile for update;
  if not found or not bloom_private.has_module_access(v_profile, v_module) then raise exception 'Document not found' using errcode = '42501'; end if;
  if exists (
    select 1 from storage.objects o
    where o.bucket_id = 'bloom-growth-content' and o.name = v_path
  ) then
    update public.bloom_growth_documents
    set status = 'deleting', updated_at = clock_timestamp()
    where id = p_document_id and profile_id = v_profile;
    raise exception 'Remove the private file from storage before finishing deletion';
  end if;
  delete from public.bloom_growth_documents where id = p_document_id and profile_id = v_profile;
  return v_path;
end;
$$;

create or replace function bloom_private.begin_document_help_request(p_request_id uuid, p_document_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_doc public.bloom_growth_documents%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype; v_child boolean; v_existing bloom_private.growth_ai_requests%rowtype;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_request_id is null or p_document_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Enter a question of up to 2,000 characters'; end if;
  select * into v_doc from public.bloom_growth_documents
    where id = p_document_id and profile_id = v_profile and module_id = 'study' and status = 'ready';
  if not found then raise exception 'Study document not found' using errcode = '42501'; end if;
  select * into v_settings from public.bloom_growth_ai_settings where profile_id = v_profile and module_id = 'study';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or not v_settings.document_sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested
      and v_settings.document_parent_enabled and v_settings.document_parent_sharing_consent and v_settings.document_minor_eligible_attested))
    or (not v_child and not (v_settings.adult_attested and v_settings.document_adult_attested)) then
    raise exception 'Study document AI consent and eligibility are required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  select * into v_existing from bloom_private.growth_ai_requests where profile_id = v_profile and id = p_request_id;
  if found then
    if v_existing.request_kind <> 'document_help' or v_existing.document_id <> p_document_id then raise exception 'AI request id was already used'; end if;
    if v_existing.status = 'completed' then return jsonb_build_object('status', 'completed', 'result', v_existing.result); end if;
    raise exception 'This document request is already in progress';
  end if;
  if (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '24 hours') >= 10
    or (select count(*) from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.created_at > clock_timestamp() - interval '1 minute') >= 2
    or exists (select 1 from bloom_private.growth_ai_requests r where r.profile_id = v_profile and r.status = 'pending'
      and r.created_at > clock_timestamp() - interval '2 minutes') then raise exception 'AI request limit reached'; end if;
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, document_id, status)
    values (p_request_id, v_profile, 'study', 'document_help', v_doc.item_id, v_doc.id, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child, 'document_id', v_doc.id, 'storage_path', v_doc.storage_path,
    'file_name', v_doc.file_name, 'format', v_doc.format, 'title', v_doc.title);
end;
$$;

create or replace function bloom_private.upsert_reader_position(
  p_document_id uuid,
  p_title text,
  p_body text
) returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_doc public.bloom_growth_documents%rowtype;
  v_id uuid;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'read') then
    raise exception 'Read access is required' using errcode = '42501';
  end if;
  if p_document_id is null or p_title is null or char_length(trim(p_title)) not between 1 and 160
    or p_body is null or char_length(p_body) > 16000 then
    raise exception 'Invalid reading position';
  end if;

  select * into v_doc
  from public.bloom_growth_documents d
  where d.id = p_document_id
    and d.profile_id = v_profile
    and d.module_id = 'read'
    and d.status = 'ready';
  if not found then
    raise exception 'Reading document not found' using errcode = '42501';
  end if;

  insert into public.bloom_growth_records (
    profile_id, module_id, item_id, kind, title, body, metadata, request_id
  ) values (
    v_profile,
    'read',
    v_doc.item_id,
    'reader_position',
    trim(p_title),
    p_body,
    jsonb_build_object('document_id', p_document_id::text),
    gen_random_uuid()
  )
  on conflict (profile_id, (metadata->>'document_id'))
    where module_id = 'read' and kind = 'reader_position' and metadata ? 'document_id'
  do update set
    title = excluded.title,
    body = excluded.body,
    updated_at = clock_timestamp()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.bloom_confirm_growth_document(p_document_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.confirm_growth_document(p_document_id);
$$;

create or replace function public.bloom_begin_delete_growth_document(p_document_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.begin_delete_growth_document(p_document_id);
$$;

revoke all on function bloom_private.confirm_growth_document(uuid), bloom_private.begin_delete_growth_document(uuid),
  public.bloom_confirm_growth_document(uuid), public.bloom_begin_delete_growth_document(uuid)
  from public, anon;
grant execute on function bloom_private.confirm_growth_document(uuid), bloom_private.begin_delete_growth_document(uuid),
  public.bloom_confirm_growth_document(uuid), public.bloom_begin_delete_growth_document(uuid)
  to authenticated;

commit;
