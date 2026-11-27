begin;

do $$
declare
  v_system_count integer;
  v_custom_count integer;
begin
  select count(*) into v_system_count
  from public.exercises
  where is_system = true and bloom_owner_user_id is null;

  if v_system_count <> 62 then
    raise exception 'Reseed changed system exercise count to % (expected 62)', v_system_count;
  end if;

  select count(*) into v_custom_count
  from public.exercises
  where name = 'Plank'
    and is_system = false
    and bloom_owner_user_id = '00000000-0000-0000-0000-000000009001'
    and description = 'My custom plank variant'
    and media_link is null;

  if v_custom_count <> 1 then
    raise exception 'Reseed modified or deleted the same-name custom exercise';
  end if;
end $$;

commit;
