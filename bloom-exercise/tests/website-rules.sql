begin;

insert into auth.users(id) values
  ('00000000-0000-0000-0000-000000000201'),
  ('00000000-0000-0000-0000-000000000202'),
  ('00000000-0000-0000-0000-000000000203');
insert into public.bloom_profiles(id) values ('00000000-0000-0000-0000-000000000204');
insert into public.bloom_households(id, owner_user_id, name)
  values ('20000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000201', 'Website rules');
insert into public.bloom_household_members(household_id, user_id, role) values
  ('20000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000201', 'parent'),
  ('20000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000202', 'child');
insert into public.bloom_child_profiles(profile_id, household_id, display_name, created_by, request_id)
  values ('00000000-0000-0000-0000-000000000204', '20000000-0000-0000-0000-000000000201', 'Unpaired child',
    '00000000-0000-0000-0000-000000000201', '30000000-0000-0000-0000-000000000204');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
insert into public.bloom_website_rules(user_id, domain, scope)
  values ('00000000-0000-0000-0000-000000000202', 'example.com', 'always') returning id \gset parent_rule_
select set_config('bloom.test_parent_rule', :'parent_rule_id', true);
insert into public.bloom_website_rules(user_id, domain, scope)
  values ('00000000-0000-0000-0000-000000000204', 'unpaired.example', 'always') returning id \gset unpaired_rule_
select set_config('bloom.test_unpaired_rule', :'unpaired_rule_id', true);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000202', true);
insert into public.bloom_website_rules(user_id, domain, scope)
  values ((select bloom_private.current_profile_id()), 'study.example.com', 'focus') returning id \gset child_rule_
select set_config('bloom.test_child_rule', :'child_rule_id', true);
do $$
declare v_count integer;
begin
  if (select count(*) from public.bloom_website_rules where user_id = bloom_private.current_profile_id()) <> 2 then
    raise exception 'Child could not read own and parent-set website rules';
  end if;
  delete from public.bloom_website_rules where id = current_setting('bloom.test_parent_rule')::uuid;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'Child deleted a parent-managed website rule'; end if;
  begin
    insert into public.bloom_website_rules(user_id, domain, scope)
      values ('00000000-0000-0000-0000-000000000203', 'other.example', 'always');
    raise exception using errcode = 'P0002', message = 'Child inserted a rule for another profile';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.bloom_website_rules(user_id, domain, scope)
      values (auth.uid(), 'https://bad.example/path', 'always');
    raise exception using errcode = 'P0002', message = 'URL text bypassed canonical domain validation';
  exception when check_violation then null;
  end;
end;
$$;

insert into public.bloom_website_rules(user_id, domain, scope)
  values ((select bloom_private.current_profile_id()), 'example.com', 'always');
insert into public.bloom_website_rules(user_id, domain, scope)
  select (select bloom_private.current_profile_id()), 'site-' || n::text || '.example', 'always'
  from generate_series(1, 49) as n;
do $$
begin
  if (select count(distinct domain) from public.bloom_website_rules
      where user_id = bloom_private.current_profile_id() and scope = 'always') <> 50 then
    raise exception 'Website rule fixture did not reach the 50-domain iOS limit';
  end if;
  begin
    insert into public.bloom_website_rules(user_id, domain, scope)
      values (bloom_private.current_profile_id(), 'extra.example', 'always');
    raise exception using errcode = 'P0002', message = 'Profile exceeded the iOS always-domain limit';
  exception when check_violation then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
delete from public.bloom_website_rules where id = current_setting('bloom.test_child_rule')::uuid;
delete from public.bloom_website_rules where id = current_setting('bloom.test_unpaired_rule')::uuid;
do $$
begin
  if exists (select 1 from public.bloom_website_rules where id = current_setting('bloom.test_child_rule')::uuid) then
    raise exception 'Parent could not remove a child website rule';
  end if;
  if exists (select 1 from public.bloom_website_rules where id = current_setting('bloom.test_unpaired_rule')::uuid) then
    raise exception 'Parent could not manage website rules for an unpaired managed profile';
  end if;
  if has_table_privilege('authenticated', 'public.bloom_website_rules', 'UPDATE') then
    raise exception 'Website rules unexpectedly grant direct update privileges';
  end if;
end;
$$;

rollback;
