begin;

-- M1-03: Prevent invited (non-managed) child profiles from directly mutating bloom_settings.
create or replace function bloom_private.current_is_child()
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select bloom_private.current_profile_id() is not null
    and bloom_private.is_child_profile(bloom_private.current_profile_id());
$$;
revoke all on function bloom_private.current_is_child() from public, anon;
grant execute on function bloom_private.current_is_child() to authenticated;

drop policy if exists bloom_settings_update on public.bloom_settings;
create policy bloom_settings_update on public.bloom_settings for update to authenticated
  using (user_id = (select bloom_private.current_profile_id()) and not bloom_private.current_is_child())
  with check (user_id = (select bloom_private.current_profile_id()) and not bloom_private.current_is_child());

drop policy if exists bloom_settings_insert on public.bloom_settings;
create policy bloom_settings_insert on public.bloom_settings for insert to authenticated
  with check (user_id = (select bloom_private.current_profile_id()));

-- M1-04: Settle expired Easy usage sessions before computing balance in parent_adjust_credit.
create or replace function bloom_private.parent_adjust_credit(p_child_id uuid, p_request_id uuid, p_minutes numeric, p_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_parent uuid := bloom_private.current_profile_id();
  v_settings public.bloom_settings%rowtype;
  v_existing bloom_private.parent_credit_adjustments%rowtype;
  v_session public.bloom_credit_sessions%rowtype;
  v_usage public.bloom_usage_sessions%rowtype;
  v_now timestamptz;
  v_balance numeric;
  v_remaining numeric;
  v_amount numeric;
  v_bucket record;
  v_part integer := 0;
  v_rows integer;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if v_parent is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  perform 1 from public.bloom_household_members p
    join public.bloom_household_members c on c.household_id = p.household_id
    where p.user_id = v_parent and p.role = 'parent' and c.user_id = p_child_id and c.role = 'child'
    for share of p, c;
  if not found then raise exception 'Parent access required'; end if;
  if p_request_id is null or p_minutes is null or p_minutes = 0 or abs(p_minutes) > 10080
    or round(p_minutes, 4) <> p_minutes or char_length(v_reason) > 200 then
    raise exception 'Enter a valid credit adjustment';
  end if;
  select * into v_settings from public.bloom_settings where user_id = p_child_id for update;
  if not found then raise exception 'Child screen-time settings not found'; end if;
  v_now := clock_timestamp();
  insert into bloom_private.parent_credit_adjustments(parent_id, request_id, child_id, amount_minutes, reason)
    values (v_parent, p_request_id, p_child_id, p_minutes, v_reason) on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    select * into v_existing from bloom_private.parent_credit_adjustments where parent_id = v_parent and request_id = p_request_id;
    if v_existing.child_id <> p_child_id or v_existing.amount_minutes <> p_minutes or v_existing.reason <> v_reason then
      raise exception 'Adjustment request was already used';
    end if;
    return;
  end if;

  select * into v_session from public.bloom_credit_sessions where user_id = p_child_id and settled_at is null for update;
  if found then
    if v_session.ends_at > v_now then raise exception 'Stop the child’s active screen-time session first'; end if;
    perform bloom_private.settle_credit_session(p_child_id, v_session.id, v_now);
  end if;

  select * into v_usage from public.bloom_usage_sessions where user_id = p_child_id and settled_at is null for update;
  if found then
    if v_usage.expires_at > v_now then raise exception 'Stop the child’s active screen-time session first'; end if;
    perform bloom_private.settle_usage_session(p_child_id, v_usage.id, v_now);
  end if;

  if p_minutes > 0 then
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
      values (p_child_id, p_minutes, 'adjustment', 'parent:' || p_request_id::text || ':0',
        bloom_private.credit_week_end(v_now, v_settings.credit_timezone));
    return;
  end if;

  select coalesce(sum(amount_minutes), 0) into v_balance from public.bloom_credit_ledger
    where user_id = p_child_id and expires_at > v_now;
  if v_balance < -p_minutes then raise exception 'Adjustment exceeds the child’s balance'; end if;
  v_remaining := -p_minutes;
  for v_bucket in select l.expires_at, sum(l.amount_minutes) as available
    from public.bloom_credit_ledger l where l.user_id = p_child_id and l.expires_at > v_now
    group by l.expires_at having sum(l.amount_minutes) > 0 order by l.expires_at loop
    exit when v_remaining <= 0;
    v_amount := least(v_bucket.available, v_remaining);
    v_part := v_part + 1;
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
      values (p_child_id, -v_amount, 'adjustment', 'parent:' || p_request_id::text || ':' || v_part, v_bucket.expires_at);
    v_remaining := v_remaining - v_amount;
  end loop;
  if v_remaining > 0 then raise exception 'Could not allocate the credit adjustment'; end if;
end;
$$;

-- M1-05: Bound claimed workout duration and rep volume against server elapsed time.
create or replace function bloom_private.complete_workout(p_session_id uuid, p_results jsonb)
returns table(session_id uuid, credits_enabled boolean)
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_user_id uuid := bloom_private.current_profile_id();
  v_session public.bloom_workout_sessions%rowtype;
  v_item jsonb;
  v_planned jsonb;
  v_sanitized jsonb := '[]'::jsonb;
  v_exercise_id uuid;
  v_seen uuid[] := '{}';
  v_sets integer;
  v_value integer;
  v_extra numeric;
  v_enabled boolean;
  v_now timestamptz := clock_timestamp();
  v_elapsed_seconds integer;
  v_total_timed_seconds bigint := 0;
  v_total_reps bigint := 0;
begin
  if v_user_id is null then raise exception 'Sign in to complete a workout'; end if;
  select * into v_session from public.bloom_workout_sessions s
    where s.id = p_session_id and s.user_id = v_user_id for update;
  if not found then raise exception 'Workout session not found'; end if;
  if v_session.status = 'completed' then
    return query select v_session.id, v_session.credits_enabled_at_completion;
    return;
  end if;
  if v_session.status <> 'in_progress' then raise exception 'Workout was cancelled'; end if;
  if jsonb_typeof(p_results) is distinct from 'array' then
    raise exception 'Workout results must be an array';
  end if;
  if jsonb_array_length(p_results) not between 1 and 50 then
    raise exception 'Log at least one exercise';
  end if;

  v_elapsed_seconds := greatest(0, floor(extract(epoch from (v_now - v_session.started_at)))::integer);

  for v_item in select value from jsonb_array_elements(p_results) loop
    v_exercise_id := (v_item->>'exercise_id')::uuid;
    if v_exercise_id is null or v_exercise_id = any(v_seen) then
      raise exception 'Each exercise can only be logged once';
    end if;
    v_seen := array_append(v_seen, v_exercise_id);
    select value into v_planned from jsonb_array_elements(v_session.plan_snapshot)
      where value->>'exercise_id' = v_exercise_id::text limit 1;
    if v_planned is null then raise exception 'Exercise is not in this workout'; end if;
    v_sets := (v_item->>'sets_completed')::integer;
    if v_sets is null or v_sets not between 1 and 20 then raise exception 'Enter completed sets'; end if;
    if v_planned->>'measurement_type' in ('reps_only', 'reps_weight') then
      v_value := (v_item->>'reps_completed')::integer;
      if v_value is null or v_value not between 1 and 1000 then raise exception 'Enter completed repetitions'; end if;
      v_total_reps := v_total_reps + (v_sets::bigint * v_value::bigint);
      v_extra := nullif(v_item->>'weight_kg', '')::numeric;
      if v_extra is not null and (v_planned->>'measurement_type' <> 'reps_weight' or v_extra < 0 or v_extra > 1000) then
        raise exception 'Invalid completed weight';
      end if;
      v_sanitized := v_sanitized || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'exercise_id', v_exercise_id, 'sets_completed', v_sets, 'reps_completed', v_value, 'weight_kg', v_extra
      )));
    else
      v_value := (v_item->>'duration_seconds')::integer;
      if v_value is null or v_value not between 1 and 86400 then raise exception 'Enter completed seconds'; end if;
      v_total_timed_seconds := v_total_timed_seconds + (v_sets::bigint * v_value::bigint);
      v_extra := nullif(v_item->>'distance_km', '')::numeric;
      if v_extra is not null and (v_planned->>'measurement_type' <> 'time_distance' or v_extra <= 0 or v_extra > 1000) then
        raise exception 'Invalid completed distance';
      end if;
      v_sanitized := v_sanitized || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'exercise_id', v_exercise_id, 'sets_completed', v_sets, 'duration_seconds', v_value, 'distance_km', v_extra
      )));
    end if;
  end loop;

  if v_total_timed_seconds > (v_elapsed_seconds::bigint + 120) then
    raise exception 'Completed exercise duration exceeds elapsed workout time';
  end if;
  if v_total_reps > greatest(200::bigint, (v_elapsed_seconds::bigint + 60) * 5) then
    raise exception 'Completed repetitions exceed plausible workout pace';
  end if;

  select coalesce((select s.credits_enabled from public.bloom_settings s where s.user_id = v_user_id), true)
    into v_enabled;
  update public.bloom_workout_sessions s set status = 'completed', completed_at = v_now,
    exercise_results = v_sanitized, credits_enabled_at_completion = v_enabled
    where s.id = v_session.id;
  return query select v_session.id, v_enabled;
end;
$$;

-- M1-07 + M1-12: Make billing FKs safe for account deletion, guard active Tap billing before revocation/file removal, and keep deletion resumable.
do $$
declare
  v_fk record;
  v_chk record;
begin
  for v_fk in
    select n.nspname, c.relname, con.conname
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum = con.conkey[1]
    where con.contype = 'f'
      and cardinality(con.conkey) = 1
      and (
        (n.nspname = 'public' and c.relname = 'bloom_subscriptions' and a.attname in ('payer_user_id', 'household_id'))
        or (n.nspname = 'bloom_private' and c.relname = 'tap_attempts' and a.attname = 'payer')
        or (n.nspname = 'bloom_private' and c.relname = 'tap_refunds' and a.attname = 'payer')
        or (n.nspname = 'bloom_private' and c.relname = 'billing_offer_uses' and a.attname = 'profile_id')
      )
  loop
    execute format('alter table %I.%I drop constraint %I', v_fk.nspname, v_fk.relname, v_fk.conname);
  end loop;

  for v_chk in
    select con.conname
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'bloom_account_deletion_jobs' and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%needs_family_review%'
  loop
    execute format('alter table public.bloom_account_deletion_jobs drop constraint %I', v_chk.conname);
  end loop;
end;
$$;

alter table public.bloom_subscriptions
  alter column payer_user_id drop not null,
  add constraint bloom_subscriptions_payer_user_id_fkey foreign key (payer_user_id) references public.bloom_profiles(id) on delete set null,
  add constraint bloom_subscriptions_household_id_fkey foreign key (household_id) references public.bloom_households(id) on delete set null;

alter table bloom_private.tap_attempts
  alter column payer drop not null,
  add constraint tap_attempts_payer_fkey foreign key (payer) references public.bloom_profiles(id) on delete set null;

alter table bloom_private.tap_refunds
  alter column payer drop not null,
  add constraint tap_refunds_payer_fkey foreign key (payer) references public.bloom_profiles(id) on delete set null;

alter table bloom_private.billing_offer_uses
  add constraint billing_offer_uses_profile_id_fkey foreign key (profile_id) references public.bloom_profiles(id) on delete cascade;

alter table bloom_private.tap_agreements
  alter column customer_ref drop not null,
  alter column card_ref drop not null,
  alter column agreement_ref drop not null;

alter table public.bloom_account_deletion_jobs
  add constraint bloom_account_deletion_jobs_status_check
  check (status in ('queued', 'revoking_access', 'removing_files', 'clearing_records', 'deleting_auth_user', 'completed', 'needs_family_review', 'needs_billing_cancellation'));

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
  where d.profile_id = p_profile_id and d.status = 'ready';

  v_payload := jsonb_build_object(
    'profile_id', p_profile_id,
    'exported_at', clock_timestamp(),
    'storage_paths', to_jsonb(v_storage_paths),
    'data', jsonb_build_object(
      'profile', (select to_jsonb(p) from public.bloom_profiles p where p.id = p_profile_id),
      'settings', (select to_jsonb(s) from public.bloom_settings s where s.user_id = p_profile_id),
      'subscriptions', coalesce((select jsonb_agg(jsonb_build_object(
        'id', bs.id, 'status', bs.status, 'billing_provider', bs.billing_provider,
        'current_period_start', bs.current_period_start, 'current_period_end', bs.current_period_end,
        'cancel_at_period_end', bs.cancel_at_period_end
      ) order by bs.created_at desc) from public.bloom_subscriptions bs where bs.payer_user_id = p_profile_id), '[]'::jsonb),
      'workout_plans', coalesce((select jsonb_agg(to_jsonb(wp) order by wp.created_at desc) from public.bloom_workout_plans wp where wp.user_id = p_profile_id), '[]'::jsonb),
      'workout_sessions', coalesce((select jsonb_agg(to_jsonb(ws) order by ws.started_at desc) from public.bloom_workout_sessions ws where ws.user_id = p_profile_id), '[]'::jsonb),
      'credit_ledger', coalesce((select jsonb_agg(to_jsonb(cl) order by cl.created_at desc) from public.bloom_credit_ledger cl where cl.user_id = p_profile_id or cl.usage_profile_id = p_profile_id), '[]'::jsonb),
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
  v_now timestamptz := clock_timestamp();
begin
  if p_user_id is null then
    raise exception 'Account ownership verification failed' using errcode = '42501';
  end if;

  select * into v_existing
  from public.bloom_account_deletion_jobs j
  where j.requested_by_user_id = p_user_id and j.status = 'deleting_auth_user'
  limit 1;
  if found then
    return to_jsonb(v_existing);
  end if;

  if p_profile_id is null or not exists (
    select 1 from public.bloom_profile_accounts a
    where a.user_id = p_user_id and a.profile_id = p_profile_id
  ) then
    raise exception 'Account ownership verification failed' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-account-delete:' || p_profile_id::text, 0));

  select * into v_existing
  from public.bloom_account_deletion_jobs j
  where j.profile_id = p_profile_id and j.status not in ('completed', 'needs_billing_cancellation')
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

  if exists (
    select 1 from public.bloom_subscriptions s
    where s.payer_user_id = p_profile_id
      and s.billing_provider = 'tap'
      and s.status in ('active', 'grace_period')
      and not s.cancel_at_period_end
      and greatest(s.current_period_end, coalesce(s.grace_until, s.current_period_end)) > v_now
  ) or exists (
    select 1 from bloom_private.tap_attempts a
    where a.payer = p_profile_id and a.state in ('ready', 'pending', 'review')
  ) or exists (
    select 1 from bloom_private.tap_refunds r
    where r.payer = p_profile_id and r.state in ('requested', 'approved', 'pending', 'review')
  ) then
    return jsonb_build_object(
      'id', gen_random_uuid(),
      'profile_id', p_profile_id,
      'account_scope', 'personal',
      'status', 'needs_billing_cancellation',
      'pending_storage_paths', '[]'::jsonb
    );
  end if;

  select coalesce(array_agg(distinct path), '{}'::text[])
  into v_paths
  from (
    select d.storage_path as path from public.bloom_growth_documents d where d.profile_id = p_profile_id
    union all
    select o.name as path from storage.objects o
      where o.bucket_id = 'bloom-growth-content' and o.name like p_profile_id::text || '/%'
  ) all_paths;

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
    select coalesce(array_agg(distinct d.auth_session_id), '{}'::uuid[])
    into v_session_ids
    from public.bloom_devices d
    where d.profile_id = v_job.profile_id
      and d.auth_session_id is not null
      and (p_session_id is null or d.auth_session_id <> p_session_id);

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

    update bloom_private.tap_agreements ta
    set customer_ref = null, card_ref = null, agreement_ref = null
    from public.bloom_subscriptions s
    where ta.subscription_id = s.id and s.payer_user_id = v_job.profile_id;

    delete from bloom_private.billing_offer_uses where profile_id = v_job.profile_id;
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
    set status = 'deleting_auth_user',
        updated_at = clock_timestamp()
    where id = v_job.id
    returning * into v_job;

    return to_jsonb(v_job);
  elsif p_step = 'finalize' then
    update public.bloom_account_deletion_jobs
    set status = 'completed',
        completed_at = clock_timestamp(),
        pending_storage_paths = '{}',
        removed_storage_paths = '{}',
        updated_at = clock_timestamp()
    where id = v_job.id
    returning * into v_job;

    return to_jsonb(v_job);
  end if;

  raise exception 'Invalid deletion step';
end;
$$;

-- M1-08: Fix bloom-read-reflection service_role check (auth.uid() is NULL under service_role).
create or replace function bloom_private.finish_read_reflection_request(p_request_id uuid, p_prompt text, p_uncertainty text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_request bloom_private.growth_ai_requests%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype;
  v_child boolean;
  v_response jsonb;
begin
  if p_request_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 120
    or p_uncertainty is null or char_length(trim(p_uncertainty)) not between 1 and 500 then
    raise exception 'Invalid reading reflection response';
  end if;
  select * into v_request from bloom_private.growth_ai_requests r where r.id = p_request_id
    and r.request_kind = 'read_reflection' for update;
  if not found then raise exception 'Reading reflection request is unavailable'; end if;
  v_child := bloom_private.is_child_profile(v_request.profile_id);
  select * into v_settings from public.bloom_growth_ai_settings s
    where s.profile_id = v_request.profile_id and s.module_id = 'read';
  if not found or not v_settings.sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested))
    or (not v_child and not v_settings.adult_attested)
    or not bloom_private.module_is_available('read')
    or (v_child and not exists (
      select 1 from public.bloom_child_module_assignments a
      where a.profile_id = v_request.profile_id and a.module_id = 'read' and a.assigned
    )) then
    raise exception 'Reading reflection consent was withdrawn';
  end if;
  v_response := jsonb_build_object('prompt', trim(p_prompt), 'uncertainty', trim(p_uncertainty));
  if v_request.status = 'completed' then
    if v_request.read_reflection_prompt is distinct from v_response then raise exception 'Reading reflection request was already completed'; end if;
    return v_request.read_reflection_prompt;
  end if;
  if v_request.status <> 'pending' then raise exception 'Reading reflection request is unavailable'; end if;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), read_reflection_prompt = v_response
    where id = p_request_id;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
  return v_response;
end;
$$;

-- M1-09: Restore growth_ai_quota_events enforcement in begin_document_help_request while preserving status = 'ready'.
create or replace function bloom_private.begin_document_help_request(p_request_id uuid, p_document_id uuid, p_prompt text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_doc public.bloom_growth_documents%rowtype;
  v_settings public.bloom_growth_ai_settings%rowtype; v_child boolean; v_existing bloom_private.growth_ai_requests%rowtype;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_request_id is null or p_document_id is null or p_prompt is null or char_length(trim(p_prompt)) not between 1 and 2000 then raise exception 'Enter a question of up to 2,000 characters'; end if;
  select * into v_doc from public.bloom_growth_documents
    where id = p_document_id and profile_id = v_profile and module_id = 'study' and status = 'ready';
  if not found then raise exception 'Study document not found' using errcode = '42501'; end if;
  select * into v_settings from public.bloom_growth_ai_settings where profile_id = v_profile and module_id = 'study';
  v_child := bloom_private.is_child_profile(v_profile);
  if not found or not v_settings.sharing_consent or not v_settings.document_sharing_consent
    or (v_child and not (v_settings.parent_enabled and v_settings.parent_sharing_consent and v_settings.minor_eligible_attested
      and v_settings.document_parent_enabled and v_settings.document_parent_sharing_consent and v_settings.document_minor_eligible_attested))
    or (not v_child and not (v_settings.adult_attested and v_settings.document_adult_attested)) then
    raise exception 'Study document AI consent and eligibility are required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-ai:' || v_profile::text, 0));
  select * into v_existing from bloom_private.growth_ai_requests where profile_id = v_profile and id = p_request_id;
  if found then
    if v_existing.request_kind <> 'document_help' or v_existing.document_id <> p_document_id then raise exception 'AI request id was already used'; end if;
    if v_existing.status = 'completed' then return jsonb_build_object('status', 'completed', 'result', v_existing.result); end if;
    raise exception 'This document request is already in progress';
  end if;
  if exists (select 1 from bloom_private.growth_ai_quota_events q where q.request_id = p_request_id) then
    raise exception 'AI request id was already used';
  end if;
  perform bloom_private.assert_growth_ai_quota(v_profile);
  insert into bloom_private.growth_ai_quota_events(request_id, profile_id, module_id, request_kind, status)
    values (p_request_id, v_profile, 'study', 'document_help', 'pending');
  insert into bloom_private.growth_ai_requests(id, profile_id, module_id, request_kind, item_id, document_id, status)
    values (p_request_id, v_profile, 'study', 'document_help', v_doc.item_id, v_doc.id, 'pending');
  return jsonb_build_object('status', 'pending', 'is_child', v_child, 'document_id', v_doc.id, 'storage_path', v_doc.storage_path,
    'file_name', v_doc.file_name, 'format', v_doc.format, 'title', v_doc.title);
end;
$$;

-- M1-20: Close growth_ai_quota_events when finishing task AI breakdown draft.
create or replace function public.bloom_finish_task_ai_draft(p_request uuid, p_result jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if jsonb_typeof(p_result) <> 'object' or octet_length(p_result::text) > 16000 then
    raise exception 'Invalid task draft';
  end if;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), result = p_result
    where id = p_request and request_kind = 'task_breakdown' and status = 'pending';
  if not found then raise exception 'AI request is unavailable'; end if;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request and status = 'pending';
end;
$$;

-- M1-21: Dead-letter permanently failing billing webhooks after 12 attempts so they do not starve the worker.
alter table public.bloom_billing_events
  add column if not exists webhook_failed_at timestamptz;

create or replace function public.bloom_claim_billing_webhooks()
returns table(id uuid, provider text, provider_event_id text, event_type text, webhook_reference text)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  update public.bloom_billing_events e
  set webhook_failed_at = clock_timestamp()
  where e.processed_at is null
    and e.webhook_reference is not null
    and e.webhook_failed_at is null
    and e.webhook_attempts >= 12;

  return query
  with due as (
    select e.id
    from public.bloom_billing_events e
    where e.processed_at is null
      and e.webhook_reference is not null
      and e.webhook_failed_at is null
      and e.webhook_attempts < 12
      and e.webhook_retry_at <= clock_timestamp()
    order by e.webhook_retry_at, e.received_at, e.id
    limit 10
    for update skip locked
  )
  update public.bloom_billing_events e
  set webhook_attempts = e.webhook_attempts + 1,
      webhook_retry_at = clock_timestamp() + make_interval(secs => least(3600, 60 * (1 << least(e.webhook_attempts, 6))))
  from due
  where e.id = due.id
  returning e.id, e.provider, e.provider_event_id, e.event_type, e.webhook_reference;
end;
$$;

-- M1-11: Enforce session revocation on competition admin, child link, and identity RLS policies.
create or replace function bloom_private.is_competition_admin()
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select auth.uid() is not null
    and not bloom_private.is_session_revoked(bloom_private.current_session_id())
    and exists (select 1 from bloom_private.competition_admins a where a.user_id = auth.uid());
$$;

drop policy if exists bloom_profile_accounts_self on public.bloom_profile_accounts;
create policy bloom_profile_accounts_self on public.bloom_profile_accounts for select to authenticated
  using (user_id = (select auth.uid()) and not bloom_private.is_session_revoked(bloom_private.current_session_id()));

drop policy if exists bloom_profiles_self on public.bloom_profiles;
create policy bloom_profiles_self on public.bloom_profiles for select to authenticated
  using (
    not bloom_private.is_session_revoked(bloom_private.current_session_id())
    and exists (
      select 1 from public.bloom_profile_accounts a
      where a.profile_id = bloom_profiles.id and a.user_id = (select auth.uid())
    )
  );

create or replace function bloom_private.accept_child_account_link(p_token text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_user uuid := auth.uid(); v_request bloom_private.child_account_link_requests%rowtype;
  v_own_profile uuid; v_fk record; v_has_data boolean;
begin
  if v_user is null or bloom_private.is_session_revoked(bloom_private.current_session_id())
    or p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid or expired link code';
  end if;
  select * into v_request from bloom_private.child_account_link_requests r
    where r.token_hash = sha256(convert_to(p_token, 'UTF8')) for update;
  if not found then raise exception 'Invalid or expired link code'; end if;
  if v_request.accepted_by = v_user and exists (select 1 from public.bloom_profile_accounts a where a.user_id = v_user and a.profile_id = v_request.profile_id) then
    return v_request.profile_id;
  end if;
  if v_request.accepted_at is not null or v_request.expires_at <= clock_timestamp()
    or v_user = v_request.profile_id or not exists (select 1 from public.bloom_household_members m
      where m.household_id = v_request.household_id and m.user_id = v_request.created_by and m.role = 'parent') then
    raise exception 'Invalid or expired link code';
  end if;
  perform 1 from auth.users u where u.id = v_user and u.email is not null and u.email_confirmed_at is not null
    and not coalesce(u.is_anonymous, false) and coalesce(u.raw_app_meta_data->>'bloom_managed_child', '') <> 'true' for update;
  if not found then raise exception 'A verified email account is required'; end if;
  select a.profile_id into v_own_profile from public.bloom_profile_accounts a where a.user_id = v_user for update;
  if v_own_profile is distinct from v_user then raise exception 'Use a new, unlinked account'; end if;
  perform 1 from public.profiles p where p.id = v_user for update;
  perform 1 from public.bloom_profiles p where p.id = v_own_profile for update;
  if (select count(*) from public.bloom_profile_accounts a where a.profile_id = v_own_profile) <> 1 then
    raise exception 'Use a new, unlinked account';
  end if;
  for v_fk in select distinct n.nspname, c.relname, a.attname
    from pg_constraint f join pg_class c on c.oid = f.conrelid join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum = f.conkey[1]
    where f.contype = 'f' and cardinality(f.conkey) = 1
      and f.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass, 'public.bloom_profiles'::regclass)
      and n.nspname in ('public', 'bloom_private')
      and not (n.nspname = 'public' and c.relname in ('profiles', 'bloom_profile_accounts'))
  loop
    if v_fk.nspname = 'public' and v_fk.relname = 'bloom_growth_memory' and v_fk.attname = 'profile_id' then
      select exists (select 1 from public.bloom_growth_memory m where m.profile_id = v_user and not m.automatic_default)
        into v_has_data;
    else
      execute format('select exists (select 1 from %I.%I where %I = $1)', v_fk.nspname, v_fk.relname, v_fk.attname)
        into v_has_data using v_user;
    end if;
    if v_has_data then raise exception 'Use a new account with no existing activity'; end if;
  end loop;
  update public.bloom_profile_accounts set profile_id = v_request.profile_id where user_id = v_user;
  delete from public.bloom_profiles where id = v_own_profile;
  update bloom_private.child_account_link_requests set accepted_by = v_user, accepted_at = clock_timestamp()
    where token_hash = v_request.token_hash;
  return v_request.profile_id;
end;
$$;

-- M1-15: Exclude offline self-reported workouts from competition scores, sanitize offline workout p_results, and close stale in-progress sessions on offline sync.
create or replace function bloom_private.competition_scores(p_id uuid)
returns table(profile_id uuid, display_name text, score numeric)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p.profile_id, coalesce(social.display_name, 'Bloom member'),
    case when c.metric = 'workouts' then count(w.id)::numeric
      else round(coalesce(sum(w.active_duration_seconds) filter (where w.started_at >= greatest(c.starts_at, p.approved_at)), 0) / 60, 2) end
  from public.bloom_competitions c join public.bloom_competition_participants p on p.competition_id = c.id and p.status = 'approved'
  left join public.bloom_social_profiles social on social.profile_id = p.profile_id
  left join public.bloom_workout_sessions w on w.user_id = p.profile_id and w.status = 'completed'
    and w.offline_self_reported = false
    and w.completed_at >= greatest(c.starts_at, p.approved_at) and w.completed_at < c.ends_at
  where c.id = p_id group by p.profile_id, social.display_name, c.metric;
$$;

create or replace function bloom_private.sync_offline_workout(
  p_activity_id uuid,
  p_plan_id uuid,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_seconds integer,
  p_results jsonb
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_existing public.bloom_workout_sessions%rowtype;
  v_plan public.bloom_workout_plans%rowtype;
  v_snapshot jsonb;
  v_session_id uuid;
  v_item jsonb;
  v_sanitized jsonb := '[]'::jsonb;
  v_exercise_id uuid;
  v_sets integer;
  v_reps integer;
  v_duration integer;
  v_weight numeric;
  v_distance numeric;
  v_now timestamptz := clock_timestamp();
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'exercise') then
    raise exception 'Exercise access is required' using errcode = '42501';
  end if;
  if p_activity_id is null or p_started_at is null or p_completed_at is null
    or p_completed_at < p_started_at
    or p_completed_at > v_now + interval '5 minutes'
    or p_duration_seconds is null or p_duration_seconds not between 1 and 43200
    or p_results is null or jsonb_typeof(p_results) <> 'array'
    or pg_column_size(p_results) > 32768
    or jsonb_array_length(p_results) not between 1 and 100 then
    raise exception 'Invalid offline workout activity';
  end if;

  for v_item in select value from jsonb_array_elements(p_results) loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'Invalid offline workout activity';
    end if;
    begin
      v_exercise_id := nullif(v_item->>'exercise_id', '')::uuid;
      v_sets := nullif(v_item->>'sets_completed', '')::integer;
      v_reps := nullif(v_item->>'reps_completed', '')::integer;
      v_duration := nullif(v_item->>'duration_seconds', '')::integer;
      v_weight := nullif(v_item->>'weight_kg', '')::numeric;
      v_distance := nullif(v_item->>'distance_km', '')::numeric;
    exception when others then
      raise exception 'Invalid offline workout activity';
    end;
    if v_exercise_id is null or v_sets is null or v_sets not between 1 and 20 then
      raise exception 'Invalid offline workout activity';
    end if;
    if v_reps is not null and v_reps not between 1 and 1000 then
      raise exception 'Invalid offline workout activity';
    end if;
    if v_duration is not null and v_duration not between 1 and 86400 then
      raise exception 'Invalid offline workout activity';
    end if;
    if v_weight is not null and (v_weight < 0 or v_weight > 1000) then
      raise exception 'Invalid offline workout activity';
    end if;
    if v_distance is not null and (v_distance < 0 or v_distance > 1000) then
      raise exception 'Invalid offline workout activity';
    end if;
    v_sanitized := v_sanitized || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'exercise_id', v_exercise_id,
      'sets_completed', v_sets,
      'reps_completed', v_reps,
      'duration_seconds', v_duration,
      'weight_kg', v_weight,
      'distance_km', v_distance
    )));
  end loop;

  perform pg_advisory_xact_lock(hashtextextended('bloom-offline-workout:' || v_profile::text || ':' || p_activity_id::text, 0));

  select * into v_existing
  from public.bloom_workout_sessions s
  where s.user_id = v_profile and s.client_activity_id = p_activity_id;
  if found then
    return jsonb_build_object(
      'session_id', v_existing.id,
      'status', 'accepted',
      'duplicate', true,
      'credits_earned_minutes', 0,
      'duration_seconds', v_existing.active_duration_seconds
    );
  end if;

  update public.bloom_workout_sessions s
  set status = 'cancelled', completed_at = coalesce(s.completed_at, v_now)
  where s.user_id = v_profile and s.status = 'in_progress' and s.started_at <= p_completed_at;

  select * into v_plan
  from public.bloom_workout_plans p
  where p.id = p_plan_id and p.user_id = v_profile;

  if found then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'exercise_id', pe.exercise_id,
          'name', e.name,
          'measurement_type', e.measurement_type,
          'sets', pe.sets,
          'target_reps', pe.target_reps,
          'target_seconds', pe.target_seconds,
          'target_weight_kg', pe.target_weight_kg,
          'target_distance_km', pe.target_distance_km
        )
        order by pe.position
      ),
      '[]'::jsonb
    ) into v_snapshot
    from public.bloom_plan_exercises pe
    join public.exercises e on e.id = pe.exercise_id
    where pe.plan_id = v_plan.id;
  else
    v_snapshot := '[]'::jsonb;
  end if;

  insert into public.bloom_workout_sessions(
    user_id, plan_id, plan_snapshot, status, started_at, completed_at,
    active_duration_seconds, credits_enabled_at_completion, credits_earned_minutes,
    exercise_results, offline_self_reported, client_activity_id
  ) values (
    v_profile, case when v_plan.id is not null then v_plan.id else null end,
    coalesce(v_snapshot, '[]'::jsonb), 'completed', p_started_at, p_completed_at,
    p_duration_seconds, false, 0, v_sanitized, true, p_activity_id
  )
  returning id into v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'status', 'accepted',
    'duplicate', false,
    'credits_earned_minutes', 0,
    'duration_seconds', p_duration_seconds
  );
end;
$$;

create or replace function bloom_private.sync_offline_growth_session(
  p_activity_id uuid,
  p_module_id text,
  p_item_id uuid,
  p_source_device_id uuid,
  p_source_device_name text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_seconds integer
) returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_existing public.bloom_growth_sessions%rowtype;
  v_item public.bloom_growth_items%rowtype;
  v_session_id uuid;
  v_now timestamptz := clock_timestamp();
begin
  if v_profile is null or p_module_id not in ('study', 'read')
    or not bloom_private.has_module_access(v_profile, p_module_id) then
    raise exception 'Module access is required' using errcode = '42501';
  end if;
  if p_activity_id is null or p_item_id is null or p_source_device_id is null
    or p_source_device_name is null or char_length(trim(p_source_device_name)) not between 1 and 80
    or p_started_at is null or p_completed_at is null or p_completed_at < p_started_at
    or p_completed_at > v_now + interval '5 minutes'
    or p_duration_seconds is null or p_duration_seconds not between 1 and 43200 then
    raise exception 'Invalid offline session activity';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('bloom-growth-session:' || v_profile::text || ':' || p_activity_id::text, 0));

  select * into v_existing
  from public.bloom_growth_sessions s
  where s.profile_id = v_profile and s.request_id = p_activity_id;
  if found then
    return jsonb_build_object(
      'session_id', v_existing.id,
      'status', 'accepted',
      'duplicate', true,
      'credits_earned_minutes', 0,
      'duration_seconds', v_existing.duration_seconds
    );
  end if;

  select * into v_item
  from public.bloom_growth_items i
  where i.id = p_item_id and i.profile_id = v_profile and i.module_id = p_module_id;
  if not found then
    raise exception 'Item not found' using errcode = '42501';
  end if;

  update public.bloom_growth_sessions s
  set status = 'cancelled', completed_at = coalesce(s.completed_at, v_now)
  where s.profile_id = v_profile and s.module_id = p_module_id and s.item_id = p_item_id
    and s.status in ('active', 'paused') and s.started_at <= p_completed_at;

  insert into public.bloom_growth_sessions(
    profile_id, module_id, item_id, source_device_id, source_device_name,
    request_id, status, started_at, completed_at, duration_seconds, offline_self_reported
  ) values (
    v_profile, p_module_id, p_item_id, p_source_device_id, trim(p_source_device_name),
    p_activity_id, 'completed', p_started_at, p_completed_at, p_duration_seconds, true
  )
  returning id into v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'status', 'accepted',
    'duplicate', false,
    'credits_earned_minutes', 0,
    'duration_seconds', p_duration_seconds
  );
end;
$$;

-- P2 SQL wins: clean stale billing_seats when child leaves household, truncate mock exam attempt title to 120 chars, harden search_path & legacy RPCs, add hot indexes.
create or replace function bloom_private.cleanup_removed_household_billing_seat()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  delete from bloom_private.billing_seats bs
  using public.bloom_subscriptions s
  where bs.subscription_id = s.id
    and s.household_id = old.household_id
    and bs.profile_id = old.user_id;
  return old;
end;
$$;

drop trigger if exists bloom_cleanup_removed_household_billing_seat on public.bloom_household_members;
create trigger bloom_cleanup_removed_household_billing_seat
  after delete on public.bloom_household_members
  for each row execute function bloom_private.cleanup_removed_household_billing_seat();

create or replace function bloom_private.save_mock_exam_objective(p_exam_id uuid, p_answers jsonb, p_duration_seconds integer, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id(); v_exam public.bloom_growth_records%rowtype;
  v_question jsonb; v_answer text; v_correct boolean; v_count integer := 0; v_score_sum numeric := 0;
  v_results jsonb := '[]'::jsonb; v_record_id uuid; v_body text; v_score numeric;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then raise exception 'Study access is required' using errcode = '42501'; end if;
  if p_request_id is null or jsonb_typeof(p_answers) <> 'object' or pg_column_size(p_answers) > 16384
    or p_duration_seconds is null or p_duration_seconds not between 0 and 43200 then raise exception 'Check the exam attempt'; end if;
  select * into v_exam from public.bloom_growth_records r where r.id = p_exam_id and r.profile_id = v_profile and r.module_id = 'study' and r.kind = 'exam';
  if not found then raise exception 'Mock exam not found' using errcode = '42501'; end if;
  for v_question in select value from jsonb_array_elements((v_exam.body::jsonb)->'questions') loop
    if v_question->>'type' not in ('multiple_choice', 'true_false') then raise exception 'Use AI assessment for short-answer questions'; end if;
    v_count := v_count + 1; v_answer := coalesce(p_answers->>(v_question->>'id'), '');
    v_correct := lower(trim(v_answer)) = lower(trim(v_question->>'expected_answer'));
    v_score_sum := v_score_sum + case when v_correct then 100 else 0 end;
    v_results := v_results || jsonb_build_array(jsonb_build_object('question_id', v_question->>'id', 'answer', v_answer,
      'correct', v_correct, 'expected_answer', v_question->>'expected_answer', 'explanation', v_question->>'explanation'));
  end loop;
  if v_count = 0 or v_count > 50 then raise exception 'Mock exam content is invalid'; end if;
  v_score := round(v_score_sum / v_count, 2);
  v_body := jsonb_build_object('results', v_results, 'duration_seconds', p_duration_seconds, 'assessment_scope', 'objective')::text;
  v_record_id := md5(p_request_id::text || ':exam-attempt')::uuid;
  insert into public.bloom_growth_records(id, profile_id, module_id, item_id, kind, title, body, metadata, score, request_id)
    values (v_record_id, v_profile, 'study', v_exam.item_id, 'exam_attempt', left('Mock exam · ' || v_exam.title, 120),
      v_body, jsonb_build_object('exam_id', p_exam_id, 'source_reference', v_exam.metadata->>'source_reference'), v_score, v_record_id)
    on conflict (profile_id, request_id) do nothing;
  return jsonb_build_object('record_id', v_record_id, 'score', v_score, 'results', v_results,
    'duration_seconds', p_duration_seconds, 'assessment_scope', 'objective');
end;
$$;

create or replace function bloom_private.finish_mock_exam_assessment(p_request_id uuid, p_assessments jsonb, p_duration_seconds integer)
returns jsonb language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_req bloom_private.growth_ai_requests%rowtype; v_exam public.bloom_growth_records%rowtype;
  v_question jsonb; v_assessment jsonb; v_answer text; v_correct boolean; v_score numeric;
  v_count integer := 0; v_score_sum numeric := 0; v_short_ids text[] := '{}'; v_result jsonb := '[]'::jsonb;
  v_attempt jsonb; v_attempt_id uuid;
begin
  if p_request_id is null or jsonb_typeof(p_assessments) <> 'array' or p_duration_seconds is null or p_duration_seconds not between 0 and 43200 then
    raise exception 'Invalid mock exam assessment'; end if;
  select * into v_req from bloom_private.growth_ai_requests where id = p_request_id and request_kind = 'mock_exam_assess' for update;
  if not found then raise exception 'Assessment is unavailable'; end if;
  if v_req.status = 'completed' and v_req.result is not null then return v_req.result; end if;
  if v_req.status <> 'pending' then raise exception 'Assessment is unavailable'; end if;
  select * into v_exam from public.bloom_growth_records where id = v_req.source_record_id and profile_id = v_req.profile_id and kind = 'exam';
  if not found then raise exception 'Mock exam was deleted'; end if;
  for v_question in select value from jsonb_array_elements((v_exam.body::jsonb)->'questions') loop
    v_count := v_count + 1; v_answer := coalesce(v_req.response->>(v_question->>'id'), '');
    if v_question->>'type' = 'short_answer' then
      v_short_ids := array_append(v_short_ids, v_question->>'id');
      select value into v_assessment from jsonb_array_elements(p_assessments) where value->>'question_id' = v_question->>'id';
      if v_assessment is null then raise exception 'An answer assessment is missing'; end if;
      v_score := (v_assessment->>'score')::numeric;
      if v_score not between 0 and 100 or char_length(coalesce(v_assessment->>'explanation', '')) not between 1 and 1000
        or char_length(coalesce(v_assessment->>'uncertainty', '')) not between 1 and 500 then raise exception 'Invalid answer assessment'; end if;
      v_score_sum := v_score_sum + v_score;
      v_result := v_result || jsonb_build_array(jsonb_build_object('question_id', v_question->>'id', 'answer', v_answer,
        'score', v_score, 'explanation', v_assessment->>'explanation', 'uncertainty', v_assessment->>'uncertainty'));
    else
      v_correct := lower(trim(v_answer)) = lower(trim(v_question->>'expected_answer'));
      v_score_sum := v_score_sum + case when v_correct then 100 else 0 end;
      v_result := v_result || jsonb_build_array(jsonb_build_object('question_id', v_question->>'id', 'answer', v_answer,
        'correct', v_correct, 'expected_answer', v_question->>'expected_answer', 'explanation', v_question->>'explanation'));
    end if;
  end loop;
  if v_count = 0 or jsonb_array_length(p_assessments) <> cardinality(v_short_ids)
    or exists (select 1 from jsonb_array_elements(p_assessments) a where not ((a->>'question_id') = any(v_short_ids))) then
    raise exception 'Mock exam assessment does not match its questions'; end if;
  v_score := round(v_score_sum / v_count, 2);
  v_attempt := jsonb_build_object('score', v_score, 'results', v_result, 'duration_seconds', p_duration_seconds,
    'assessment_scope', 'mixed', 'uncertainty', 'Short-answer scores are AI suggestions. Review each explanation and adjust your rubric if needed.');
  v_attempt_id := md5(p_request_id::text || ':exam-attempt')::uuid;
  insert into public.bloom_growth_records(id, profile_id, module_id, item_id, kind, title, body, metadata, score, request_id)
    values (v_attempt_id, v_req.profile_id, 'study', v_exam.item_id, 'exam_attempt', left('Mock exam · ' || v_exam.title, 120),
      v_attempt::text, jsonb_build_object('exam_id', v_exam.id, 'source_reference', v_exam.metadata->>'source_reference'), v_score, v_attempt_id)
    on conflict (profile_id, request_id) do nothing;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), result = v_attempt where id = p_request_id;
  update bloom_private.growth_ai_quota_events set status = 'completed', finished_at = clock_timestamp()
    where request_id = p_request_id and status = 'pending';
  return v_attempt || jsonb_build_object('record_id', v_attempt_id);
end;
$$;

create or replace function public.search_public_profiles(p_query text, p_limit integer default 20)
returns table(id uuid, username text, first_name text, last_name text, streak_count integer)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p.id, p.username, p.first_name, p.last_name, p.streak_count from public.profiles p
  where auth.uid() is not null
    and not bloom_private.is_session_revoked(bloom_private.current_session_id())
    and p.id <> auth.uid()
    and char_length(trim(coalesce(p_query, ''))) >= 2
    and not exists (select 1 from public.bloom_profile_accounts a where a.user_id = p.id and bloom_private.is_child_profile(a.profile_id))
    and exists (
      select 1 from public.bloom_profile_accounts a
      join public.bloom_social_profiles sp on sp.profile_id = a.profile_id
      where a.user_id = p.id and sp.searchable = true
    )
    and (position(lower(trim(p_query)) in lower(coalesce(p.username, ''))) > 0
      or position(lower(trim(p_query)) in lower(coalesce(p.first_name, ''))) > 0
      or position(lower(trim(p_query)) in lower(coalesce(p.last_name, ''))) > 0)
  order by coalesce(p.username, p.first_name, p.last_name), p.id limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

create or replace function public.get_public_profile(p_user_id uuid)
returns table(id uuid, username text, first_name text, last_name text, streak_count integer)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p.id, p.username, p.first_name, p.last_name,
    case when p.last_workout_date is null or p.last_workout_date <
      (clock_timestamp() at time zone coalesce(nullif(p.timezone, ''), 'UTC'))::date - 1 then 0 else coalesce(p.streak_count, 0) end
  from public.profiles p
  where auth.uid() is not null
    and not bloom_private.is_session_revoked(bloom_private.current_session_id())
    and p.id = p_user_id
    and (
      exists (
        select 1 from public.bloom_profile_accounts a
        join public.bloom_social_profiles sp on sp.profile_id = a.profile_id
        where a.user_id = p.id and sp.searchable = true and not bloom_private.is_child_profile(a.profile_id)
      )
      or exists (select 1 from public.bloom_profile_accounts a where a.user_id = p.id
        and (a.profile_id = bloom_private.current_profile_id() or bloom_private.is_parent_of(a.profile_id)))
    );
$$;

do $$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'handle_new_user'
  ) then
    execute 'alter function public.handle_new_user() set search_path = pg_catalog, pg_temp';
  end if;
end;
$$;

create index if not exists bloom_credit_ledger_user_expires_idx
  on public.bloom_credit_ledger(user_id, expires_at);
create index if not exists bloom_workout_sessions_completed_idx
  on public.bloom_workout_sessions(user_id, completed_at desc)
  where status = 'completed';
create index if not exists bloom_friendships_requester_idx
  on public.bloom_friendships(requester_id);
create index if not exists bloom_friendships_addressee_idx
  on public.bloom_friendships(addressee_id);
create index if not exists bloom_subscriptions_payer_idx
  on public.bloom_subscriptions(payer_user_id);
create index if not exists bloom_tap_refunds_due_idx
  on bloom_private.tap_refunds(next_check_at)
  where state in ('approved', 'pending');
create index if not exists bloom_revoked_auth_sessions_profile_idx
  on bloom_private.revoked_auth_sessions(profile_id);

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.bloom_billing_tap(uuid, text, jsonb)'::regprocedure) into v_def;
  if v_def is null then
    raise exception 'public.bloom_billing_tap not found';
  end if;
  if position('if not found then raise exception ''Request already reviewed''; end if;' in v_def) = 0 then
    raise exception 'Expected refund_decision guard not found in bloom_billing_tap';
  end if;
  v_def := replace(
    v_def,
    'if not found then raise exception ''Request already reviewed''; end if;',
    'if not found then raise exception ''Request already reviewed''; end if; if v_refund.payer = p_profile then raise exception ''Another reviewer must decide this refund''; end if;'
  );
  if position('next_product_id=null where id=v_subscription;' in v_def) = 0 then
    raise exception 'Expected subscription update not found in bloom_billing_tap';
  end if;
  v_def := replace(
    v_def,
    'next_product_id=null where id=v_subscription;',
    'next_product_id=null, cancel_at_period_end=case when v_attempt.kind=''recovery'' then false else cancel_at_period_end end where id=v_subscription;'
  );
  execute v_def;
end;
$$;

commit;
