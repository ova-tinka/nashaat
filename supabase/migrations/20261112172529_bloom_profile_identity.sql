begin;

-- Keep legacy profile identifiers equal to their existing account identifiers.
-- Existing workout, family and credit records therefore remain untouched.
create table public.bloom_profiles (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);
create table public.bloom_profile_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profile_id uuid not null references public.bloom_profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index bloom_profile_accounts_profile_idx on public.bloom_profile_accounts(profile_id);

alter table public.bloom_profiles enable row level security;
alter table public.bloom_profile_accounts enable row level security;
revoke all on public.bloom_profiles, public.bloom_profile_accounts from public, anon, authenticated;
grant select on public.bloom_profiles, public.bloom_profile_accounts to authenticated;
create policy bloom_profile_accounts_self on public.bloom_profile_accounts for select to authenticated
  using (user_id = (select auth.uid()));
create policy bloom_profiles_self on public.bloom_profiles for select to authenticated
  using (exists (select 1 from public.bloom_profile_accounts a
    where a.profile_id = bloom_profiles.id and a.user_id = (select auth.uid())));

-- Block concurrent signups until both the backfill and the insert trigger exist.
lock table auth.users in share row exclusive mode;
insert into public.bloom_profiles(id)
  select id from auth.users;
insert into public.bloom_profile_accounts(user_id, profile_id)
  select id, id from auth.users;

create function bloom_private.create_profile_for_new_account()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  insert into public.bloom_profiles(id) values (new.id);
  insert into public.bloom_profile_accounts(user_id, profile_id) values (new.id, new.id);
  return new;
end;
$$;
revoke all on function bloom_private.create_profile_for_new_account() from public, anon, authenticated;
create trigger bloom_create_profile_for_new_account after insert on auth.users
  for each row execute function bloom_private.create_profile_for_new_account();

commit;
