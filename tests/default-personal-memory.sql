begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000491');
do $$ begin
  if not exists (select 1 from public.bloom_growth_memory where profile_id = '00000000-0000-0000-0000-000000000491'
    and enabled and automatic_default and shared_domains = '{}'::text[] and summaries = '{}'::jsonb) then
    raise exception 'New personal account should have enabled memory with no shared domains';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000491', true);
do $$ begin
  begin
    perform public.bloom_growth_ai_memory_context('study');
    raise exception using errcode = 'P0002', message = 'Memory bypassed AI consent';
  exception when raise_exception then
    if sqlerrm <> 'AI consent and eligibility are required' then raise; end if;
  end;
  perform public.bloom_save_growth_memory(false, '{}'::text[], '{}'::jsonb);
  if (select enabled or automatic_default from public.bloom_growth_memory where profile_id = bloom_private.current_profile_id()) then
    raise exception 'Explicit disabled preference was not preserved';
  end if;
end $$;
rollback;
