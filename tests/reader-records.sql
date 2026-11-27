begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000601'),
  ('00000000-0000-0000-0000-000000000602');

insert into public.bloom_settings(user_id, credits_enabled)
values
  ('00000000-0000-0000-0000-000000000601', true),
  ('00000000-0000-0000-0000-000000000602', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000601', true);

do $$
declare
  v_item uuid;
  v_first_doc uuid;
  v_deleted_doc uuid;
  v_foreign_doc uuid;
  v_doc_id uuid;
  v_pos_id_1 uuid;
  v_pos_id_2 uuid;
  v_i integer;
begin
  v_item := public.bloom_create_growth_item('read', 'reading', 'Archive Shelf', '', null, null,
    '90000000-0000-0000-0000-000000000601');

  -- Insert 105 reading documents and 105 reading records so the first document falls outside any newest-100 window.
  for v_i in 1..105 loop
    v_doc_id := (public.bloom_create_growth_document(
      'read', v_item, 'Book #' || v_i::text, 'book-' || v_i::text || '.epub',
      'epub', 'application/epub+zip', 1024,
      ('90000000-0000-0000-0001-' || lpad(v_i::text, 12, '0'))::uuid
    ))->>'id';
    if v_i = 1 then
      v_first_doc := v_doc_id;
      perform public.bloom_save_growth_record(
        'read', v_item, 'reader_bookmark', 'Chapter 1 bookmark', '{"page":5,"percent":12}',
        jsonb_build_object('document_id', v_first_doc::text), null, null,
        '90000000-0000-0000-0002-000000000001'
      );
    end if;
    perform public.bloom_save_growth_record(
      'read', v_item, 'reading_note', 'Note #' || v_i::text, 'Reading note ' || v_i::text,
      '{}'::jsonb, null, null,
      ('90000000-0000-0000-0003-' || lpad(v_i::text, 12, '0'))::uuid
    );
  end loop;

  -- Direct lookup by ID finds document #1 and its bookmark despite >100 newer docs/records.
  if not exists (select 1 from public.bloom_growth_documents where id = v_first_doc and profile_id = bloom_private.current_profile_id()) then
    raise exception 'Oldest reading document was not directly queryable by ID';
  end if;
  if not exists (
    select 1 from public.bloom_growth_records
    where profile_id = bloom_private.current_profile_id()
      and module_id = 'read'
      and kind = 'reader_bookmark'
      and metadata @> jsonb_build_object('document_id', v_first_doc::text)
  ) then
    raise exception 'Bookmark for oldest reading document was not directly queryable';
  end if;

  -- Canonical position: repeated saves from two devices update one single canonical row.
  v_pos_id_1 := public.bloom_upsert_reader_position(v_first_doc, 'Reading position · Book #1', '{"page":10,"percent":25}');
  v_pos_id_2 := public.bloom_upsert_reader_position(v_first_doc, 'Reading position · Book #1', '{"page":22,"percent":55}');
  if v_pos_id_1 is distinct from v_pos_id_2 then
    raise exception 'Canonical reader position created multiple rows (% vs %)', v_pos_id_1, v_pos_id_2;
  end if;
  if (select count(*) from public.bloom_growth_records
      where profile_id = bloom_private.current_profile_id()
        and module_id = 'read' and kind = 'reader_position'
        and metadata->>'document_id' = v_first_doc::text) <> 1 then
    raise exception 'Expected exactly one canonical reader_position row';
  end if;

  -- Deleted document is rejected.
  v_deleted_doc := (public.bloom_create_growth_document(
    'read', v_item, 'Deleted Book', 'deleted.pdf', 'pdf', 'application/pdf', 1024,
    '90000000-0000-0000-0004-000000000001'
  ))->>'id';
  perform public.bloom_delete_growth_document(v_deleted_doc);
  begin
    perform public.bloom_upsert_reader_position(v_deleted_doc, 'Reading position · Deleted', '{"page":1,"percent":5}');
    raise exception using errcode = 'P0002', message = 'Deleted document accepted a reader position';
  exception when insufficient_privilege then null; end;

  perform set_config('bloom.test_first_doc', v_first_doc::text, true);
end $$;

-- Foreign profile cannot read or write position for another profile's document.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000602', true);
do $$
declare
  v_foreign uuid := current_setting('bloom.test_first_doc')::uuid;
begin
  if exists (select 1 from public.bloom_growth_documents where id = v_foreign) then
    raise exception 'Foreign profile read private reading document';
  end if;
  begin
    perform public.bloom_upsert_reader_position(v_foreign, 'Foreign', '{"page":1,"percent":5}');
    raise exception using errcode = 'P0002', message = 'Foreign profile saved position for another account document';
  exception when insufficient_privilege then null; end;
end $$;

rollback;
