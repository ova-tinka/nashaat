begin;

create table if not exists public.bloom_account_export_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  requested_by_user_id uuid not null,
  status text not null check (status in ('completed', 'failed')),
  file_count integer not null default 0,
  created_at timestamptz not null default clock_timestamp()
);

alter table public.bloom_account_export_requests enable row level security;
revoke all on public.bloom_account_export_requests from public, anon, authenticated;
grant select on public.bloom_account_export_requests to authenticated;
create policy bloom_account_export_requests_read on public.bloom_account_export_requests for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));

create table if not exists public.bloom_account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  requested_by_user_id uuid not null,
  account_scope text not null check (account_scope in ('personal', 'family_review')),
  status text not null check (status in ('queued', 'revoking_access', 'removing_files', 'clearing_records', 'completed', 'needs_family_review')),
  pending_storage_paths text[] not null default '{}',
  removed_storage_paths text[] not null default '{}',
  family_household_ids uuid[] not null default '{}',
  last_error text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz
);

create unique index if not exists bloom_account_deletion_active_job_idx
  on public.bloom_account_deletion_jobs(profile_id)
  where status <> 'completed';

alter table public.bloom_account_deletion_jobs enable row level security;
revoke all on public.bloom_account_deletion_jobs from public, anon, authenticated;
grant select on public.bloom_account_deletion_jobs to authenticated;
create policy bloom_account_deletion_jobs_read on public.bloom_account_deletion_jobs for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()));

create or replace function bloom_private.export_my_account_data(
  p_profile_id uuid,
  p_user_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_storage_paths text[];
  v_payload jsonb;
begin
  if p_profile_id is null or p_user_id is null or not exists (
    select 1 from public.bloom_profile_accounts a
    where a.user_id = p_user_id and a.profile_id = p_profile_id
  ) then
    raise exception 'Account ownership verification failed' using errcode = '42501';
  end if;

  select coalesce(array_agg(d.storage_path order by d.created_at desc), '{}'::text[])
  into v_storage_paths
  from public.bloom_growth_documents d
  where d.profile_id = p_profile_id;

  v_payload := jsonb_build_object(
    'profile_id', p_profile_id,
    'exported_at', clock_timestamp(),
    'storage_paths', to_jsonb(v_storage_paths),
    'data', jsonb_build_object(
      'profile', (select to_jsonb(p) from public.bloom_profiles p where p.id = p_profile_id),
      'settings', (select to_jsonb(s) from public.bloom_settings s where s.user_id = p_profile_id),
      'workout_plans', coalesce((select jsonb_agg(to_jsonb(wp) order by wp.created_at desc) from public.bloom_workout_plans wp where wp.user_id = p_profile_id), '[]'::jsonb),
      'workout_sessions', coalesce((select jsonb_agg(to_jsonb(ws) order by ws.started_at desc) from public.bloom_workout_sessions ws where ws.user_id = p_profile_id), '[]'::jsonb),
      'credit_ledger', coalesce((select jsonb_agg(to_jsonb(cl) order by cl.created_at desc) from public.bloom_credit_ledger cl where cl.user_id = p_profile_id), '[]'::jsonb),
      'devices', coalesce((select jsonb_agg(to_jsonb(dv) order by dv.last_seen_at desc) from public.bloom_devices dv where dv.profile_id = p_profile_id and dv.removed_at is null), '[]'::jsonb),
      'growth_items', coalesce((select jsonb_agg(to_jsonb(gi) order by gi.created_at desc) from public.bloom_growth_items gi where gi.profile_id = p_profile_id), '[]'::jsonb),
      'growth_sessions', coalesce((select jsonb_agg(to_jsonb(gs) order by gs.started_at desc) from public.bloom_growth_sessions gs where gs.profile_id = p_profile_id), '[]'::jsonb),
      'growth_records', coalesce((select jsonb_agg(to_jsonb(gr) order by gr.created_at desc) from public.bloom_growth_records gr where gr.profile_id = p_profile_id), '[]'::jsonb),
      'growth_documents', coalesce((select jsonb_agg(to_jsonb(gd) order by gd.created_at desc) from public.bloom_growth_documents gd where gd.profile_id = p_profile_id), '[]'::jsonb),
      'study_tutor_messages', coalesce((select jsonb_agg(to_jsonb(tm) order by tm.created_at desc) from public.bloom_study_tutor_messages tm where tm.profile_id = p_profile_id), '[]'::jsonb),
      'document_help_answers', coalesce((select jsonb_agg(to_jsonb(da) order by da.created_at desc) from public.bloom_document_help_answers da where da.profile_id = p_profile_id), '[]'::jsonb)
    )
  );

  insert into public.bloom_account_export_requests(profile_id, requested_by_user_id, status, file_count)
  values (p_profile_id, p_user_id, 'completed', coalesce(cardinality(v_storage_paths), 0));

  return v_payload;
end;
$$;

create or replace function bloom_private.request_account_deletion(
  p_profile_id uuid,
  p_user_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_existing public.bloom_account_deletion_jobs%rowtype;
  v_households uuid[];
  v_paths text[];
  v_job public.bloom_account_deletion_jobs%rowtype;
begin
  if p_profile_id is null or p_user_id is null or not exists (
    select 1 from public.bloom_profile_accounts a
    where a.user_id = p_user_id and a.profile_id = p_profile_id
  ) then
    raise exception 'Account ownership verification failed' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-account-delete:' || p_profile_id::text, 0));

  select * into v_existing
  from public.bloom_account_deletion_jobs j
  where j.profile_id = p_profile_id and j.status <> 'completed'
  limit 1;
  if found then
    return to_jsonb(v_existing);
  end if;

  select coalesce(array_agg(distinct h_id), '{}'::uuid[])
  into v_households
  from (
    select m.household_id as h_id from public.bloom_household_members m where m.user_id = p_profile_id
    union all
    select h.id as h_id from public.bloom_households h where h.owner_user_id = p_profile_id
  ) fam;

  if bloom_private.is_child_profile(p_profile_id) or coalesce(cardinality(v_households), 0) > 0 then
    insert into public.bloom_account_deletion_jobs(
      profile_id, requested_by_user_id, account_scope, status, family_household_ids
    ) values (
      p_profile_id, p_user_id, 'family_review', 'needs_family_review', coalesce(v_households, '{}'::uuid[])
    ) returning * into v_job;
    return to_jsonb(v_job);
  end if;

  select coalesce(array_agg(d.storage_path order by d.created_at desc), '{}'::text[])
  into v_paths
  from public.bloom_growth_documents d
  where d.profile_id = p_profile_id;

  insert into public.bloom_account_deletion_jobs(
    profile_id, requested_by_user_id, account_scope, status, pending_storage_paths
  ) values (
    p_profile_id, p_user_id, 'personal', 'queued', coalesce(v_paths, '{}'::text[])
  ) returning * into v_job;
  return to_jsonb(v_job);
end;
$$;

create or replace function bloom_private.advance_account_deletion_job(
  p_job_id uuid,
  p_step text,
  p_removed_paths text[] default '{}',
  p_session_id uuid default null
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_job public.bloom_account_deletion_jobs%rowtype;
  v_session_ids uuid[];
  v_remaining text[];
  v_removed text[];
begin
  select * into v_job from public.bloom_account_deletion_jobs j where j.id = p_job_id for update;
  if not found then
    raise exception 'Deletion job not found';
  end if;
  if v_job.status = 'needs_family_review' then
    raise exception 'Family accounts require reviewed deletion';
  end if;
  if v_job.status = 'completed' then
    return to_jsonb(v_job);
  end if;

  if p_step = 'revoke_access' then
    select coalesce(array_agg(distinct s_id), '{}'::uuid[])
    into v_session_ids
    from (
      select d.auth_session_id as s_id
      from public.bloom_devices d
      where d.profile_id = v_job.profile_id and d.auth_session_id is not null
      union all
      select p_session_id as s_id where p_session_id is not null
    ) sessions;

    if coalesce(cardinality(v_session_ids), 0) > 0 then
      insert into bloom_private.revoked_auth_sessions(session_id, profile_id, device_id)
      select sid, v_job.profile_id, null
      from unnest(v_session_ids) as sid
      on conflict (session_id) do nothing;
    end if;

    update public.bloom_account_deletion_jobs
    set status = case when cardinality(v_job.pending_storage_paths) > 0 then 'removing_files' else 'clearing_records' end,
        updated_at = clock_timestamp()
    where id = v_job.id
    returning * into v_job;

    return to_jsonb(v_job) || jsonb_build_object('revoked_session_ids', to_jsonb(coalesce(v_session_ids, '{}'::uuid[])));
  elsif p_step = 'mark_files_removed' then
    select coalesce(array_agg(p), '{}'::text[])
    into v_remaining
    from unnest(v_job.pending_storage_paths) as p
    where not (p = any(coalesce(p_removed_paths, '{}'::text[])));

    select coalesce(array_agg(distinct p), '{}'::text[])
    into v_removed
    from (
      select unnest(v_job.removed_storage_paths) as p
      union all
      select unnest(coalesce(p_removed_paths, '{}'::text[])) as p
    ) all_removed;

    update public.bloom_account_deletion_jobs
    set pending_storage_paths = v_remaining,
        removed_storage_paths = v_removed,
        status = case when cardinality(v_remaining) = 0 then 'clearing_records' else 'removing_files' end,
        updated_at = clock_timestamp()
    where id = v_job.id
    returning * into v_job;

    return to_jsonb(v_job);
  elsif p_step = 'clear_records' then
    if coalesce(cardinality(v_job.pending_storage_paths), 0) > 0 then
      raise exception 'Private files must be removed before clearing records';
    end if;

    delete from public.bloom_document_help_answers where profile_id = v_job.profile_id;
    delete from public.bloom_growth_documents where profile_id = v_job.profile_id;
    delete from public.bloom_growth_records where profile_id = v_job.profile_id;
    delete from public.bloom_growth_sessions where profile_id = v_job.profile_id;
    delete from public.bloom_growth_items where profile_id = v_job.profile_id;
    delete from public.bloom_growth_reward_events where profile_id = v_job.profile_id;
    delete from public.bloom_growth_reward_rules where profile_id = v_job.profile_id;
    delete from public.bloom_growth_ai_settings where profile_id = v_job.profile_id;
    delete from public.bloom_study_tutor_messages where profile_id = v_job.profile_id;
    delete from bloom_private.growth_ai_requests where profile_id = v_job.profile_id;
    delete from bloom_private.growth_ai_quota_events where profile_id = v_job.profile_id;
    delete from public.bloom_credit_ledger where user_id = v_job.profile_id;
    delete from public.bloom_credit_sessions where user_id = v_job.profile_id;
    delete from public.bloom_usage_sessions where user_id = v_job.profile_id;
    delete from public.bloom_workout_sessions where user_id = v_job.profile_id;
    delete from public.bloom_workout_plans where user_id = v_job.profile_id;
    delete from public.bloom_blocking_rules where user_id = v_job.profile_id;
    delete from public.bloom_devices where profile_id = v_job.profile_id;
    delete from public.bloom_settings where user_id = v_job.profile_id;
    delete from public.exercises where bloom_owner_user_id = v_job.profile_id;
    delete from public.bloom_account_export_requests where profile_id = v_job.profile_id;
    delete from public.bloom_profile_accounts where profile_id = v_job.profile_id;
    delete from public.bloom_profiles where id = v_job.profile_id;

    update public.bloom_account_deletion_jobs
    set status = 'completed',
        completed_at = clock_timestamp(),
        updated_at = clock_timestamp()
    where id = v_job.id
    returning * into v_job;

    return to_jsonb(v_job);
  end if;

  raise exception 'Invalid deletion step';
end;
$$;

create or replace function public.bloom_export_my_account_data(p_profile_id uuid, p_user_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.export_my_account_data(p_profile_id, p_user_id);
$$;

create or replace function public.bloom_request_account_deletion(p_profile_id uuid, p_user_id uuid)
returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.request_account_deletion(p_profile_id, p_user_id);
$$;

create or replace function public.bloom_advance_account_deletion_job(
  p_job_id uuid,
  p_step text,
  p_removed_paths text[] default '{}',
  p_session_id uuid default null
) returns jsonb language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.advance_account_deletion_job(p_job_id, p_step, p_removed_paths, p_session_id);
$$;

revoke all on function bloom_private.export_my_account_data(uuid, uuid),
  bloom_private.request_account_deletion(uuid, uuid),
  bloom_private.advance_account_deletion_job(uuid, text, text[], uuid),
  public.bloom_export_my_account_data(uuid, uuid),
  public.bloom_request_account_deletion(uuid, uuid),
  public.bloom_advance_account_deletion_job(uuid, text, text[], uuid)
  from public, anon, authenticated;

grant execute on function bloom_private.export_my_account_data(uuid, uuid),
  bloom_private.request_account_deletion(uuid, uuid),
  bloom_private.advance_account_deletion_job(uuid, text, text[], uuid),
  public.bloom_export_my_account_data(uuid, uuid),
  public.bloom_request_account_deletion(uuid, uuid),
  public.bloom_advance_account_deletion_job(uuid, text, text[], uuid)
  to service_role;

commit;
