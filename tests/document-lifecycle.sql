begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000701'),
  ('00000000-0000-0000-0000-000000000702');

insert into public.bloom_settings(user_id, credits_enabled)
values
  ('00000000-0000-0000-0000-000000000701', true),
  ('00000000-0000-0000-0000-000000000702', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000701', true);

do $$
declare
  v_item uuid;
  v_doc jsonb;
  v_retry jsonb;
  v_doc_id uuid;
  v_path text;
  v_confirmed jsonb;
  v_deleting jsonb;
begin
  v_item := public.bloom_create_growth_item('read', 'reading', 'Lifecycle Book', '', null, null,
    '90000000-0000-0000-0000-000000000701');
  v_doc := public.bloom_create_growth_document('read', v_item, 'Guide', 'guide.pdf',
    'pdf', 'application/pdf', 2048, '90000000-0000-0000-0000-000000000702');
  if v_doc->>'status' <> 'pending' then
    raise exception 'New document must start in pending state, got %', v_doc->>'status';
  end if;
  v_doc_id := (v_doc->>'id')::uuid;
  v_path := v_doc->>'storage_path';

  -- Retry reuses the same request_id and document row.
  v_retry := public.bloom_create_growth_document('read', v_item, 'Guide', 'guide.pdf',
    'pdf', 'application/pdf', 2048, '90000000-0000-0000-0000-000000000702');
  if v_retry->>'id' <> v_doc->>'id' then
    raise exception 'Upload retry did not reuse original document ID';
  end if;

  -- Confirm fails if the object does not exist in private storage yet.
  begin
    perform public.bloom_confirm_growth_document(v_doc_id);
    raise exception using errcode = 'P0002', message = 'Confirmed document without storage object';
  exception when raise_exception then
    if sqlerrm <> 'Uploaded file was not found in private storage' then raise; end if;
  end;

  -- Pending document cannot be used for reader position.
  begin
    perform public.bloom_upsert_reader_position(v_doc_id, 'Pos', '{"page":1}');
    raise exception using errcode = 'P0002', message = 'Pending document accepted reader position';
  exception when insufficient_privilege then null; end;

  -- Once object exists in storage, confirm transitions it to ready.
  insert into storage.objects(bucket_id, name) values ('bloom-growth-content', v_path);
  v_confirmed := public.bloom_confirm_growth_document(v_doc_id);
  if v_confirmed->>'status' <> 'ready' then
    raise exception 'Document did not transition to ready';
  end if;
  perform public.bloom_upsert_reader_position(v_doc_id, 'Pos', '{"page":1}');

  -- Begin delete marks status = deleting and blocks confirm/position.
  v_deleting := public.bloom_begin_delete_growth_document(v_doc_id);
  if v_deleting->>'status' <> 'deleting' then
    raise exception 'Begin delete did not transition to deleting';
  end if;

  -- Finalize delete refuses while storage object still exists.
  begin
    perform public.bloom_delete_growth_document(v_doc_id);
    raise exception using errcode = 'P0002', message = 'Deleted document metadata while storage object remained';
  exception when raise_exception then
    if sqlerrm <> 'Remove the private file from storage before finishing deletion' then raise; end if;
  end;

  perform set_config('bloom.doc_lifecycle_id', v_doc_id::text, true);
  perform set_config('bloom.doc_lifecycle_path', v_path, true);
end $$;

-- Foreign profile cannot confirm or delete owner document.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000702', true);
do $$
declare
  v_doc_id uuid := current_setting('bloom.doc_lifecycle_id')::uuid;
begin
  begin
    perform public.bloom_confirm_growth_document(v_doc_id);
    raise exception using errcode = 'P0002', message = 'Foreign profile confirmed document';
  exception when insufficient_privilege then null; end;
  begin
    perform public.bloom_begin_delete_growth_document(v_doc_id);
    raise exception using errcode = 'P0002', message = 'Foreign profile began deleting document';
  exception when insufficient_privilege then null; end;
end $$;

-- Owner removes storage object, then finalizes delete cleanly.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000701', true);
do $$
declare
  v_doc_id uuid := current_setting('bloom.doc_lifecycle_id')::uuid;
  v_path text := current_setting('bloom.doc_lifecycle_path');
begin
  delete from storage.objects where bucket_id = 'bloom-growth-content' and name = v_path;
  if public.bloom_delete_growth_document(v_doc_id) <> v_path then
    raise exception 'Finalize delete returned wrong storage path';
  end if;
  if exists (select 1 from public.bloom_growth_documents where id = v_doc_id) then
    raise exception 'Document metadata remained after finalized delete';
  end if;
end $$;

rollback;
