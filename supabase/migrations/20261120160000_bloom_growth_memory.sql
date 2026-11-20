begin;

create table public.bloom_growth_memory (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  enabled boolean not null default false,
  shared_domains text[] not null default '{}',
  summaries jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default clock_timestamp(),
  check (cardinality(shared_domains) <= 4),
  check (shared_domains <@ array['exercise', 'study', 'read', 'tasks']::text[]),
  check (jsonb_typeof(summaries) = 'object' and pg_column_size(summaries) <= 16384)
);
alter table public.bloom_growth_memory enable row level security;
revoke all on public.bloom_growth_memory from public, anon, authenticated;
grant select on public.bloom_growth_memory to authenticated;
create policy bloom_growth_memory_read on public.bloom_growth_memory for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));

create function bloom_private.save_growth_memory(p_enabled boolean, p_shared_domains text[], p_summaries jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_domains text[] := coalesce(p_shared_domains, '{}'::text[]); v_total integer;
begin
  if v_profile is null then raise exception 'Sign in to manage your memory'; end if;
  if p_enabled is null or p_summaries is null or jsonb_typeof(p_summaries) <> 'object'
    or pg_column_size(p_summaries) > 16384 or cardinality(v_domains) > 4
    or cardinality(v_domains) <> (select count(distinct d) from unnest(v_domains) as d)
    or exists (select 1 from unnest(v_domains) as d where d not in ('exercise', 'study', 'read', 'tasks'))
    or exists (select 1 from jsonb_each(p_summaries) e where e.key not in ('exercise', 'study', 'read', 'tasks')
      or jsonb_typeof(e.value) <> 'string' or char_length(e.value #>> '{}') > 1200) then
    raise exception 'Check your memory summary and sharing settings';
  end if;
  select coalesce(sum(char_length(e.value #>> '{}')), 0) into v_total from jsonb_each(p_summaries) e;
  if v_total > 4000 then raise exception 'Memory summaries can contain up to 4,000 characters total'; end if;
  insert into public.bloom_growth_memory(profile_id, enabled, shared_domains, summaries)
    values (v_profile, p_enabled, v_domains, p_summaries)
  on conflict (profile_id) do update set enabled = excluded.enabled,
    shared_domains = excluded.shared_domains, summaries = excluded.summaries, updated_at = clock_timestamp();
end;
$$;

create function bloom_private.delete_growth_memory()
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to delete your memory'; end if;
  delete from public.bloom_growth_memory where profile_id = v_profile;
end;
$$;

create function bloom_private.growth_ai_memory_context(p_module_id text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_child boolean;
  v_memory public.bloom_growth_memory%rowtype;
  v_context jsonb;
begin
  if v_profile is null or p_module_id not in ('study', 'tasks')
    or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'AI module access is not assigned' using errcode = '42501';
  end if;
  select * into v_settings from public.bloom_growth_ai_settings s where s.profile_id = v_profile and s.module_id = p_module_id;
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or (v_child and not (v_settings.parent_enabled
      and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested) then
    raise exception 'AI consent and eligibility are required';
  end if;
  select * into v_memory from public.bloom_growth_memory m where m.profile_id = v_profile;
  if not found or not v_memory.enabled then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(jsonb_build_object('domain', d.domain, 'summary', left(v_memory.summaries->>d.domain, 1200)) order by d.domain), '[]'::jsonb)
    into v_context from unnest(v_memory.shared_domains) as d(domain)
    where nullif(trim(v_memory.summaries->>d.domain), '') is not null;
  return v_context;
end;
$$;

create function public.bloom_save_growth_memory(p_enabled boolean, p_shared_domains text[], p_summaries jsonb)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.save_growth_memory(p_enabled, p_shared_domains, p_summaries);
$$;
create function public.bloom_delete_growth_memory()
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.delete_growth_memory();
$$;
create function public.bloom_growth_ai_memory_context(p_module_id text)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.growth_ai_memory_context(p_module_id);
$$;

revoke all on function bloom_private.save_growth_memory(boolean, text[], jsonb), bloom_private.delete_growth_memory(),
  bloom_private.growth_ai_memory_context(text) from public, anon, authenticated;
grant execute on function bloom_private.save_growth_memory(boolean, text[], jsonb),
  bloom_private.delete_growth_memory(), bloom_private.growth_ai_memory_context(text) to authenticated;
revoke all on function public.bloom_save_growth_memory(boolean, text[], jsonb),
  public.bloom_delete_growth_memory(), public.bloom_growth_ai_memory_context(text) from public, anon, authenticated;
grant execute on function public.bloom_save_growth_memory(boolean, text[], jsonb),
  public.bloom_delete_growth_memory(), public.bloom_growth_ai_memory_context(text) to authenticated;

commit;
