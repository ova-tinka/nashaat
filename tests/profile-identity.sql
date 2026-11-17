begin;
do $$ begin
  if (select count(*) from public.bloom_profile_accounts where user_id in
      ('00000000-0000-0000-0000-000000000111', '00000000-0000-0000-0000-000000000112') and profile_id = user_id) <> 2 then
    raise exception 'Existing accounts were not backfilled';
  end if;
  if not exists (select 1 from public.bloom_workout_plans where id = '11000000-0000-0000-0000-000000000111' and user_id = '00000000-0000-0000-0000-000000000112')
    or not exists (select 1 from public.bloom_workout_sessions where id = '11000000-0000-0000-0000-000000000112' and status = 'completed')
    or not exists (select 1 from public.bloom_credit_ledger where idempotency_key = 'identity-fixture' and amount_minutes = 10)
    or (select count(*) from public.bloom_household_members where household_id = '11000000-0000-0000-0000-000000000113') <> 2 then
    raise exception 'Existing records changed during backfill';
  end if;
end $$;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000113');
do $$ begin
  if not exists (select 1 from public.bloom_profile_accounts where user_id = '00000000-0000-0000-0000-000000000113' and profile_id = user_id) then
    raise exception 'New account did not receive a profile';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000113', true);
do $$ begin
  if (select count(*) from public.bloom_profiles) <> 1 or (select count(*) from public.bloom_profile_accounts) <> 1 then
    raise exception 'Account can see another account profile or link';
  end if;
  if has_table_privilege('authenticated', 'public.bloom_profiles', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_profile_accounts', 'INSERT')
    or has_table_privilege('authenticated', 'public.bloom_profile_accounts', 'UPDATE') then
    raise exception 'Account can forge a profile link';
  end if;
end $$;
rollback;
