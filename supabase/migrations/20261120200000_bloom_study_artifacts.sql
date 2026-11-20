begin;

alter table public.bloom_growth_records
  add constraint bloom_growth_records_profile_id_id_key unique (profile_id, id);
alter table public.bloom_growth_documents
  add constraint bloom_growth_documents_profile_id_id_key unique (profile_id, id);

create table public.bloom_growth_record_attachments (
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  record_id uuid primary key,
  document_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint bloom_growth_record_attachments_record_fk foreign key (profile_id, record_id)
    references public.bloom_growth_records(profile_id, id) on delete cascade,
  constraint bloom_growth_record_attachments_document_fk foreign key (profile_id, document_id)
    references public.bloom_growth_documents(profile_id, id) on delete cascade
);
create index bloom_growth_record_attachments_document_idx on public.bloom_growth_record_attachments(profile_id, document_id);
alter table public.bloom_growth_record_attachments enable row level security;
revoke all on public.bloom_growth_record_attachments from public, anon, authenticated;
grant select on public.bloom_growth_record_attachments to authenticated;
create policy bloom_growth_record_attachments_read on public.bloom_growth_record_attachments for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id())
    and bloom_private.has_module_access(profile_id, 'study')
    and exists (
      select 1 from public.bloom_growth_records r
      join public.bloom_growth_documents d on d.profile_id = r.profile_id and d.id = bloom_growth_record_attachments.document_id
      where r.profile_id = bloom_growth_record_attachments.profile_id and r.id = bloom_growth_record_attachments.record_id
        and r.module_id = 'study' and r.kind = 'verification' and r.item_id = d.item_id
    ));

create function bloom_private.set_study_record_artifact(p_record_id uuid, p_document_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_record public.bloom_growth_records%rowtype;
  v_document public.bloom_growth_documents%rowtype;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then
    raise exception 'Study access is required' using errcode = '42501';
  end if;
  select * into v_record from public.bloom_growth_records
    where id = p_record_id and profile_id = v_profile for update;
  if not found or v_record.module_id <> 'study' or v_record.kind <> 'verification' then
    raise exception 'Study reflection not found' using errcode = '42501';
  end if;
  if p_document_id is null then
    delete from public.bloom_growth_record_attachments where profile_id = v_profile and record_id = v_record.id;
    return;
  end if;
  select * into v_document from public.bloom_growth_documents
    where id = p_document_id and profile_id = v_profile and module_id = 'study' and item_id = v_record.item_id;
  if not found then raise exception 'Choose a private artifact for this Study item' using errcode = '42501'; end if;
  insert into public.bloom_growth_record_attachments(profile_id, record_id, document_id)
    values (v_profile, v_record.id, v_document.id)
    on conflict (record_id) do update set document_id = excluded.document_id, created_at = clock_timestamp();
end;
$$;

create function bloom_private.save_study_verification(
  p_item_id uuid, p_title text, p_body text, p_document_id uuid, p_request_id uuid
) returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_record_id uuid;
  v_body text;
  v_metadata jsonb;
begin
  if (p_body is null or char_length(trim(p_body)) = 0) and p_document_id is null then
    raise exception 'Add an answer or attach a private Study artifact';
  end if;
  if p_body is not null and char_length(p_body) > 3000 then raise exception 'Keep the Study reflection under 3,000 characters'; end if;
  v_body := coalesce(nullif(trim(p_body), ''), 'Learning artifact attached.');
  v_metadata := jsonb_build_object('section_reference', null, 'optional_learning_signal', true,
    'artifact_only', p_body is null or char_length(trim(p_body)) = 0);
  v_record_id := bloom_private.save_growth_record('study', p_item_id, 'verification', p_title, v_body,
    v_metadata, null, null, p_request_id);
  perform bloom_private.set_study_record_artifact(v_record_id, p_document_id);
  return v_record_id;
end;
$$;

create function bloom_private.update_study_verification(
  p_record_id uuid, p_title text, p_body text, p_document_id uuid
) returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_body text;
  v_metadata jsonb;
begin
  if (p_body is null or char_length(trim(p_body)) = 0) and p_document_id is null then
    raise exception 'Add an answer or attach a private Study artifact';
  end if;
  if p_body is not null and char_length(p_body) > 3000 then raise exception 'Keep the Study reflection under 3,000 characters'; end if;
  v_body := coalesce(nullif(trim(p_body), ''), 'Learning artifact attached.');
  v_metadata := jsonb_build_object('section_reference', null, 'optional_learning_signal', true,
    'artifact_only', p_body is null or char_length(trim(p_body)) = 0);
  perform bloom_private.update_growth_record(p_record_id, p_title, v_body, v_metadata);
  perform bloom_private.set_study_record_artifact(p_record_id, p_document_id);
end;
$$;

create function public.bloom_save_study_verification(p_item_id uuid, p_title text, p_body text, p_document_id uuid, p_request_id uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.save_study_verification(p_item_id, p_title, p_body, p_document_id, p_request_id);
$$;
create function public.bloom_update_study_verification(p_record_id uuid, p_title text, p_body text, p_document_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_study_verification(p_record_id, p_title, p_body, p_document_id);
$$;

revoke all on function bloom_private.set_study_record_artifact(uuid, uuid),
  bloom_private.save_study_verification(uuid, text, text, uuid, uuid),
  bloom_private.update_study_verification(uuid, text, text, uuid),
  public.bloom_save_study_verification(uuid, text, text, uuid, uuid),
  public.bloom_update_study_verification(uuid, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.bloom_save_study_verification(uuid, text, text, uuid, uuid),
  public.bloom_update_study_verification(uuid, text, text, uuid) to authenticated;
grant execute on function bloom_private.save_study_verification(uuid, text, text, uuid, uuid),
  bloom_private.update_study_verification(uuid, text, text, uuid) to authenticated;

commit;
