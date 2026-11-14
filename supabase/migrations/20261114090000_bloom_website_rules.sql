begin;

create table public.bloom_website_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.bloom_profiles(id) on delete cascade,
  domain text not null check (
    char_length(domain) <= 253
    and domain = lower(domain)
    and domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
  ),
  scope text not null check (scope in ('always', 'focus')),
  created_by uuid not null default bloom_private.current_profile_id() references public.bloom_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, scope, domain, created_by)
);

create index bloom_website_rules_user_scope_idx on public.bloom_website_rules(user_id, scope, created_at);

create function bloom_private.enforce_bloom_website_rule_limit()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_always_domains integer;
begin
  if new.scope <> 'always' then return new; end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-website-rules:' || new.user_id::text, 0));
  select count(distinct domain)::integer into v_always_domains
  from public.bloom_website_rules
  where user_id = new.user_id and scope = 'always';

  if v_always_domains >= 50 and not exists (
    select 1 from public.bloom_website_rules
    where user_id = new.user_id and scope = 'always' and domain = new.domain
  ) then
    raise exception using errcode = '23514', message = 'A profile can have at most 50 always-blocked website domains.';
  end if;
  return new;
end;
$$;
revoke all on function bloom_private.enforce_bloom_website_rule_limit() from public, anon, authenticated;

create trigger bloom_website_rule_limit_before_insert
  before insert on public.bloom_website_rules
  for each row execute function bloom_private.enforce_bloom_website_rule_limit();

alter table public.bloom_website_rules enable row level security;
revoke all on public.bloom_website_rules from public, anon, authenticated;
grant select, insert, delete on public.bloom_website_rules to authenticated;

create function bloom_private.can_manage_website_rules(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select bloom_private.is_parent_of(p_profile_id) or exists (
    select 1 from public.bloom_child_profiles c
    where c.profile_id = p_profile_id and bloom_private.is_household_parent(c.household_id)
  );
$$;
revoke all on function bloom_private.can_manage_website_rules(uuid) from public, anon;
grant execute on function bloom_private.can_manage_website_rules(uuid) to authenticated;

create policy bloom_website_rules_read on public.bloom_website_rules for select to authenticated
  using (user_id = (select bloom_private.current_profile_id()) or bloom_private.can_manage_website_rules(user_id));
create policy bloom_website_rules_insert_own on public.bloom_website_rules for insert to authenticated
  with check (user_id = (select bloom_private.current_profile_id()) and created_by = (select bloom_private.current_profile_id()));
create policy bloom_website_rules_insert_parent on public.bloom_website_rules for insert to authenticated
  with check (bloom_private.can_manage_website_rules(user_id) and created_by = (select bloom_private.current_profile_id()));
create policy bloom_website_rules_delete_own on public.bloom_website_rules for delete to authenticated
  using (user_id = (select bloom_private.current_profile_id()) and created_by = (select bloom_private.current_profile_id()));
create policy bloom_website_rules_delete_parent on public.bloom_website_rules for delete to authenticated
  using (bloom_private.can_manage_website_rules(user_id));

commit;
