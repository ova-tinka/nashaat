begin;

insert into auth.users(id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000901', 'personal-del@example.invalid', now()),
  ('00000000-0000-0000-0000-000000000902', 'unrelated@example.invalid', now()),
  ('00000000-0000-0000-0000-000000000903', 'family-parent@example.invalid', now()),
  ('00000000-0000-0000-0000-000000000904', 'family-child@example.invalid', now());

insert into public.bloom_settings(user_id, credits_enabled) values
  ('00000000-0000-0000-0000-000000000901', true),
  ('00000000-0000-0000-0000-000000000902', true),
  ('00000000-0000-0000-0000-000000000903', true);

-- Seed personal account data + 2 documents for 901, and separate data for 902.
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000901', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000901","session_id":"90000000-0000-0000-0000-000000000901"}', true);
do $$
declare
  v_item uuid;
  v_doc1 jsonb;
  v_doc2 jsonb;
begin
  perform public.bloom_register_device('91000000-0000-0000-0000-000000000901', 'Personal Mac', 'macos', true, 'allowed', 'on', 1);
  v_item := public.bloom_create_growth_item('read', 'reading', 'Personal Book', '', null, null, '92000000-0000-0000-0000-000000000001');
  v_doc1 := public.bloom_create_growth_document('read', v_item, 'Doc 1', 'doc1.pdf', 'pdf', 'application/pdf', 1000, '92000000-0000-0000-0000-000000000002');
  v_doc2 := public.bloom_create_growth_document('read', v_item, 'Doc 2', 'doc2.pdf', 'pdf', 'application/pdf', 1000, '92000000-0000-0000-0000-000000000003');
  perform set_config('bloom.del_path_1', v_doc1->>'storage_path', true);
  perform set_config('bloom.del_path_2', v_doc2->>'storage_path', true);
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000902', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000902","session_id":"90000000-0000-0000-0000-000000000902"}', true);
do $$ begin
  perform public.bloom_create_growth_item('study', 'subject', 'Unrelated Subject', '', null, 30, '92000000-0000-0000-0000-000000000004');
end $$;

-- Seed Family household with wallet balance for child.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000903', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000903"}', true);
select set_config('bloom.del_house', public.bloom_create_household('Protected Family')::text, true);
select set_config('bloom.del_invite', public.bloom_create_child_invite(current_setting('bloom.del_house')::uuid), true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000904', true);
select public.bloom_accept_child_invite(current_setting('bloom.del_invite'));
reset role;
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key)
values ('00000000-0000-0000-0000-000000000904', 25, 'adjustment', 'family-wallet-keep');

-- Verify client cannot invoke service-only export/delete functions.
set local role authenticated;
do $$ begin
  if has_function_privilege('authenticated', 'public.bloom_export_my_account_data(uuid,uuid)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.bloom_request_account_deletion(uuid,uuid)', 'EXECUTE') then
    raise exception 'Client can invoke privileged export/deletion RPCs directly';
  end if;
end $$;

-- Service role tests export ownership, Family review routing, and resumable personal deletion.
reset role;
set local role service_role;
do $$
declare
  v_export jsonb;
  v_fam_job jsonb;
  v_job jsonb;
  v_job_retry jsonb;
  v_step jsonb;
begin
  -- Export includes only 901's data and 2 storage paths.
  v_export := public.bloom_export_my_account_data('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000901');
  if jsonb_array_length(v_export->'storage_paths') <> 2
    or jsonb_array_length(v_export->'data'->'growth_items') <> 1
    or (v_export->'data'->'growth_items'->0->>'title') <> 'Personal Book' then
    raise exception 'Export payload mismatch: %', v_export;
  end if;

  -- Active Family parent routes to needs_family_review and preserves wallets.
  v_fam_job := public.bloom_request_account_deletion('00000000-0000-0000-0000-000000000903', '00000000-0000-0000-0000-000000000903');
  if v_fam_job->>'status' <> 'needs_family_review' or v_fam_job->>'account_scope' <> 'family_review' then
    raise exception 'Family account did not route to needs_family_review: %', v_fam_job;
  end if;

  -- Personal account deletion: request -> revoke_access -> partial file delete -> retry -> clear_records.
  v_job := public.bloom_request_account_deletion('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000901');
  if v_job->>'status' <> 'queued' or jsonb_array_length(v_job->'pending_storage_paths') <> 2 then
    raise exception 'Personal deletion job did not queue storage paths: %', v_job;
  end if;
  v_step := public.bloom_advance_account_deletion_job((v_job->>'id')::uuid, 'revoke_access', '{}', '90000000-0000-0000-0000-000000000901');
  if v_step->>'status' <> 'removing_files'
    or not public.bloom_is_session_revoked('90000000-0000-0000-0000-000000000901') then
    raise exception 'Revoke access step failed: %', v_step;
  end if;

  -- Partial file removal (1 of 2 removed).
  v_step := public.bloom_advance_account_deletion_job((v_job->>'id')::uuid, 'mark_files_removed', array[current_setting('bloom.del_path_1')], null);
  if v_step->>'status' <> 'removing_files' or jsonb_array_length(v_step->'pending_storage_paths') <> 1 then
    raise exception 'Partial file removal did not track remaining file: %', v_step;
  end if;

  -- Re-request returns existing active job cleanly (resumable).
  v_job_retry := public.bloom_request_account_deletion('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000901');
  if v_job_retry->>'id' <> v_job->>'id' then
    raise exception 'Retry created a duplicate deletion job';
  end if;

  -- Remove second file, then clear records.
  v_step := public.bloom_advance_account_deletion_job((v_job->>'id')::uuid, 'mark_files_removed', array[current_setting('bloom.del_path_2')], null);
  if v_step->>'status' <> 'clearing_records' then
    raise exception 'Final file removal did not advance to clearing_records: %', v_step;
  end if;
  v_step := public.bloom_advance_account_deletion_job((v_job->>'id')::uuid, 'clear_records', '{}', null);
  if v_step->>'status' <> 'completed' then
    raise exception 'Clear records did not complete job: %', v_step;
  end if;
end $$;

reset role;
do $$ begin
  if exists (select 1 from public.bloom_profiles where id = '00000000-0000-0000-0000-000000000901')
    or exists (select 1 from public.bloom_growth_items where profile_id = '00000000-0000-0000-0000-000000000901')
    or exists (select 1 from public.bloom_growth_documents where profile_id = '00000000-0000-0000-0000-000000000901') then
    raise exception 'Deleted account left owned profile, items, or documents behind';
  end if;
  if not exists (select 1 from public.bloom_growth_items where profile_id = '00000000-0000-0000-0000-000000000902')
    or not exists (select 1 from public.bloom_credit_ledger where user_id = '00000000-0000-0000-0000-000000000904' and amount_minutes = 25) then
    raise exception 'Unrelated account or family wallet was affected by personal account deletion';
  end if;
end $$;

rollback;
