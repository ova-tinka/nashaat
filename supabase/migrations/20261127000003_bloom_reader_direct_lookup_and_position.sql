begin;

-- Deduplicate any legacy duplicate reader_position rows per (profile_id, document_id), keeping the newest.
with ranked as (
  select id,
         row_number() over (
           partition by profile_id, (metadata->>'document_id')
           order by updated_at desc, created_at desc, id desc
         ) as row_num
  from public.bloom_growth_records
  where module_id = 'read'
    and kind = 'reader_position'
    and metadata ? 'document_id'
)
delete from public.bloom_growth_records r
using ranked
where r.id = ranked.id
  and ranked.row_num > 1;

create unique index bloom_reader_canonical_position_idx
  on public.bloom_growth_records (profile_id, (metadata->>'document_id'))
  where module_id = 'read'
    and kind = 'reader_position'
    and metadata ? 'document_id';

create function bloom_private.upsert_reader_position(
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
    and d.module_id = 'read';
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

create function public.bloom_upsert_reader_position(
  p_document_id uuid,
  p_title text,
  p_body text
) returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.upsert_reader_position(p_document_id, p_title, p_body);
$$;

revoke all on function bloom_private.upsert_reader_position(uuid, text, text) from public, anon, authenticated;
grant execute on function bloom_private.upsert_reader_position(uuid, text, text) to authenticated;
revoke all on function public.bloom_upsert_reader_position(uuid, text, text) from public, anon;
grant execute on function public.bloom_upsert_reader_position(uuid, text, text) to authenticated;

commit;
