begin;

insert into auth.users(id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000551', 'rev-a@example.invalid', now()),
  ('00000000-0000-0000-0000-000000000552', 'rev-b@example.invalid', now());
insert into public.profiles(id) values
  ('00000000-0000-0000-0000-000000000551'),
  ('00000000-0000-0000-0000-000000000552');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000551', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000551","session_id":"55000000-0000-0000-0000-000000000001"}', true);

do $$
declare
  v_item uuid;
  v_doc jsonb;
begin
  if not public.bloom_register_device('55100000-0000-0000-0000-000000000001', 'Lost Phone', 'ios', true, 'allowed', 'on', 2) then
    raise exception 'Device 1 registration failed';
  end if;
  v_item := public.bloom_create_growth_item('read', 'reading', 'Private Book', '', null, null, '55200000-0000-0000-0000-000000000001');
  v_doc := public.bloom_create_growth_document('read', v_item, 'Book PDF', 'book.pdf', 'pdf', 'application/pdf', 1024, '55200000-0000-0000-0000-000000000002');
  perform set_config('bloom.rev_doc_path', v_doc->>'storage_path', true);
end $$;

reset role;
insert into storage.objects(bucket_id, name)
values ('bloom-growth-content', current_setting('bloom.rev_doc_path'));

-- Register second authorized device on a different Auth session for Profile A.
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000551', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000551","session_id":"55000000-0000-0000-0000-000000000002"}', true);
do $$ begin
  if not public.bloom_register_device('55100000-0000-0000-0000-000000000002', 'Trusted Mac', 'macos', true, 'allowed', 'on', 1) then
    raise exception 'Device 2 registration failed';
  end if;
end $$;

-- Profile B cannot revoke Profile A's device.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000552', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000552","session_id":"55000000-0000-0000-0000-000000000099"}', true);
do $$ begin
  begin
    perform public.bloom_revoke_device('55100000-0000-0000-0000-000000000001');
    raise exception using errcode = 'P0002', message = 'Foreign profile revoked another profile device';
  exception when raise_exception then
    if sqlerrm <> 'Device was not found' then raise; end if;
  end;
end $$;

-- Profile A revokes Device 1 from Device 2's session.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000551', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000551","session_id":"55000000-0000-0000-0000-000000000002"}', true);
do $$
declare
  v_revoked jsonb;
begin
  v_revoked := public.bloom_revoke_device('55100000-0000-0000-0000-000000000001');
  if (v_revoked->>'revoked')::boolean is not true
    or v_revoked->>'session_id' <> '55000000-0000-0000-0000-000000000001' then
    raise exception 'Revoke device did not return bound session ID: %', v_revoked;
  end if;
  -- Device 2 continues working for Data API and private Storage.
  if (select count(*) from public.bloom_devices) <> 1
    or (select count(*) from public.bloom_growth_items) <> 1
    or (select count(*) from storage.objects where bucket_id = 'bloom-growth-content'
      and name = current_setting('bloom.rev_doc_path')) <> 1 then
    raise exception 'Trusted session 2 lost access after revoking device 1';
  end if;
end $$;

-- Revoked session 1 is blocked from Data API, RPCs, and private Storage.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000551","session_id":"55000000-0000-0000-0000-000000000001"}', true);
do $$ begin
  if bloom_private.current_profile_id() is not null then
    raise exception 'Revoked session still resolved profile_id';
  end if;
  if (select count(*) from public.bloom_devices) <> 0
    or (select count(*) from public.bloom_growth_items) <> 0
    or (select count(*) from storage.objects where bucket_id = 'bloom-growth-content'
      and name = current_setting('bloom.rev_doc_path')) <> 0 then
    raise exception 'Revoked session still accessed Data API or private Storage';
  end if;
end $$;

set local role service_role;
do $$ begin
  if not public.bloom_is_session_revoked('55000000-0000-0000-0000-000000000001')
    or public.bloom_is_session_revoked('55000000-0000-0000-0000-000000000002') then
    raise exception 'Service role session revocation check mismatch';
  end if;
end $$;

rollback;
