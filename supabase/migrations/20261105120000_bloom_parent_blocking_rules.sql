begin;

drop policy if exists bloom_blocking_own on public.bloom_blocking_rules;

create policy bloom_blocking_child_read on public.bloom_blocking_rules for select to authenticated
  using (user_id = (select auth.uid()));

create function bloom_private.clear_unlinked_child_blocking_rules()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if old.role = 'child' and not exists (
    select 1 from public.bloom_household_members c
    join public.bloom_household_members p on p.household_id = c.household_id and p.role = 'parent'
    where c.user_id = old.user_id and c.role = 'child'
  ) then
    delete from public.bloom_blocking_rules where user_id = old.user_id;
  end if;
  return old;
end;
$$;
revoke all on function bloom_private.clear_unlinked_child_blocking_rules() from public, anon, authenticated;

create trigger bloom_clear_unlinked_child_rules
after delete on public.bloom_household_members
for each row execute function bloom_private.clear_unlinked_child_blocking_rules();

commit;
