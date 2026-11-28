-- Bloom public-site iPhone waitlist. No public or authenticated read path exists.
create table if not exists public.bloom_website_waitlist (
  id uuid primary key default gen_random_uuid(),
  email_normalized text not null unique check (
    length(email_normalized) between 3 and 254
    and email_normalized = lower(btrim(email_normalized))
    and email_normalized ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  status text not null default 'pending_confirmation'
    check (status in ('pending_confirmation', 'confirmed', 'unsubscribed')),
  adult_or_guardian boolean not null check (adult_or_guardian),
  consent_policy_version text not null,
  consented_at timestamptz not null default clock_timestamp(),
  confirmed_at timestamptz,
  beta_interest boolean not null default false,
  beta_interest_recorded_at timestamptz,
  marketing_consent boolean not null default false,
  marketing_consented_at timestamptz,
  confirmation_generation uuid,
  confirmation_expires_at timestamptz,
  confirmation_sent_at timestamptz,
  management_generation uuid,
  management_expires_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (beta_interest_recorded_at is null or beta_interest),
  check (marketing_consented_at is null or marketing_consent)
);

create index if not exists bloom_website_waitlist_review_idx
  on public.bloom_website_waitlist (created_at desc)
  where status = 'confirmed';

create table if not exists public.bloom_website_waitlist_events (
  id uuid primary key default gen_random_uuid(),
  waitlist_id uuid references public.bloom_website_waitlist(id) on delete set null,
  event_type text not null check (event_type in (
    'launch_updates_requested', 'email_confirmed', 'preferences_updated',
    'unsubscribed', 'deletion_requested'
  )),
  policy_version text,
  adult_or_guardian boolean,
  beta_interest boolean not null default false,
  marketing_consent boolean not null default false,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.bloom_website_rate_limits (
  fingerprint text primary key check (fingerprint ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0),
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.bloom_website_waitlist enable row level security;
alter table public.bloom_website_waitlist_events enable row level security;
alter table public.bloom_website_rate_limits enable row level security;
revoke all on public.bloom_website_waitlist, public.bloom_website_waitlist_events,
  public.bloom_website_rate_limits from public, anon, authenticated;
grant all on public.bloom_website_waitlist, public.bloom_website_waitlist_events,
  public.bloom_website_rate_limits to service_role;

create or replace function public.bloom_website_consume_rate_limit(
  p_fingerprint text,
  p_limit integer,
  p_window_seconds integer
) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare
  v_now timestamptz := clock_timestamp();
  v_window timestamptz;
  v_count integer;
begin
  if p_fingerprint !~ '^[0-9a-f]{64}$' or p_limit < 1 or p_limit > 100
    or p_window_seconds < 1 or p_window_seconds > 86400 then
    raise exception 'Invalid rate-limit request';
  end if;
  v_window := to_timestamp(floor(extract(epoch from v_now) / p_window_seconds) * p_window_seconds);
  insert into public.bloom_website_rate_limits(fingerprint, window_started_at, request_count, updated_at)
  values (p_fingerprint, v_window, 1, v_now)
  on conflict (fingerprint) do update
    set window_started_at = case
          when public.bloom_website_rate_limits.window_started_at < excluded.window_started_at
            then excluded.window_started_at
          else public.bloom_website_rate_limits.window_started_at end,
        request_count = case
          when public.bloom_website_rate_limits.window_started_at < excluded.window_started_at
            then 1
          else public.bloom_website_rate_limits.request_count + 1 end,
        updated_at = excluded.updated_at
  returning request_count into v_count;
  delete from public.bloom_website_rate_limits where updated_at < v_now - interval '7 days';
  return v_count <= p_limit;
end;
$$;

create or replace function public.bloom_website_start_waitlist(
  p_email text,
  p_email_fingerprint text,
  p_generation uuid,
  p_beta_interest boolean,
  p_marketing_consent boolean,
  p_adult_or_guardian boolean,
  p_policy_version text
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare
  v_email text := lower(btrim(p_email));
  v_row public.bloom_website_waitlist%rowtype;
  v_should_send boolean := false;
begin
  if length(v_email) < 3 or length(v_email) > 254
    or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    or p_email_fingerprint !~ '^[0-9a-f]{64}$'
    or p_generation is null
    or p_policy_version is null or length(p_policy_version) not between 1 and 40
    or p_adult_or_guardian is not true then
    raise exception 'Invalid waitlist request';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_email_fingerprint, 9321));
  select * into v_row from public.bloom_website_waitlist
    where email_normalized = v_email for update;
  if found then
    if v_row.status = 'confirmed' then
      return jsonb_build_object('id', v_row.id, 'should_send', false);
    end if;
    if v_row.status = 'pending_confirmation'
      and v_row.confirmation_sent_at > clock_timestamp() - interval '15 minutes'
      and v_row.confirmation_expires_at > clock_timestamp() then
      return jsonb_build_object('id', v_row.id, 'should_send', false);
    end if;

    update public.bloom_website_waitlist set
      status = 'pending_confirmation', adult_or_guardian = true,
      consent_policy_version = p_policy_version, consented_at = clock_timestamp(),
      beta_interest = p_beta_interest,
      beta_interest_recorded_at = case when p_beta_interest then clock_timestamp() else null end,
      marketing_consent = p_marketing_consent,
      marketing_consented_at = case when p_marketing_consent then clock_timestamp() else null end,
      confirmed_at = null, confirmation_generation = p_generation,
      confirmation_expires_at = clock_timestamp() + interval '48 hours',
      confirmation_sent_at = null, management_generation = null,
      management_expires_at = null, updated_at = clock_timestamp()
    where id = v_row.id returning * into v_row;
  else
    insert into public.bloom_website_waitlist (
      email_normalized, adult_or_guardian, consent_policy_version, consented_at,
      beta_interest, beta_interest_recorded_at, marketing_consent,
      marketing_consented_at, confirmation_generation,
      confirmation_expires_at, confirmation_sent_at
    ) values (
      v_email, true, p_policy_version, clock_timestamp(),
      p_beta_interest, case when p_beta_interest then clock_timestamp() else null end,
      p_marketing_consent, case when p_marketing_consent then clock_timestamp() else null end,
      p_generation, clock_timestamp() + interval '48 hours', null
    ) returning * into v_row;
  end if;
  v_should_send := true;
  insert into public.bloom_website_waitlist_events (
    waitlist_id, event_type, policy_version, adult_or_guardian, beta_interest, marketing_consent
  ) values (v_row.id, 'launch_updates_requested', p_policy_version, true, p_beta_interest, p_marketing_consent);
  return jsonb_build_object('id', v_row.id, 'generation', p_generation, 'should_send', v_should_send);
end;
$$;

create or replace function public.bloom_website_confirm_waitlist(
  p_id uuid,
  p_generation uuid
) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare
  v_row public.bloom_website_waitlist%rowtype;
begin
  update public.bloom_website_waitlist set
    status = 'confirmed', confirmed_at = clock_timestamp(),
    confirmation_generation = null, confirmation_expires_at = null,
    updated_at = clock_timestamp()
  where id = p_id and status = 'pending_confirmation'
    and confirmation_generation = p_generation
    and confirmation_expires_at > clock_timestamp()
  returning * into v_row;
  if not found then return false; end if;
  insert into public.bloom_website_waitlist_events (
    waitlist_id, event_type, policy_version, adult_or_guardian, beta_interest, marketing_consent
  ) values (v_row.id, 'email_confirmed', v_row.consent_policy_version, true, v_row.beta_interest, v_row.marketing_consent);
  return true;
end;
$$;

create or replace function public.bloom_website_mark_waitlist_email_sent(
  p_id uuid,
  p_generation uuid
) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
begin
  update public.bloom_website_waitlist set
    confirmation_sent_at = clock_timestamp(), updated_at = clock_timestamp()
  where id = p_id and status = 'pending_confirmation'
    and confirmation_generation = p_generation
    and confirmation_expires_at > clock_timestamp();
  return found;
end;
$$;

create or replace function public.bloom_website_start_management(
  p_email text,
  p_generation uuid
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare
  v_row public.bloom_website_waitlist%rowtype;
begin
  update public.bloom_website_waitlist set
    management_generation = p_generation,
    management_expires_at = clock_timestamp() + interval '30 minutes',
    updated_at = clock_timestamp()
  where email_normalized = lower(btrim(p_email)) and status = 'confirmed'
  returning * into v_row;
  if not found then return jsonb_build_object('found', false); end if;
  return jsonb_build_object('found', true, 'id', v_row.id,
    'generation', p_generation, 'email', v_row.email_normalized);
end;
$$;

create or replace function public.bloom_website_manage(
  p_id uuid,
  p_generation uuid,
  p_action text,
  p_beta_interest boolean default false,
  p_marketing_consent boolean default false,
  p_policy_version text default '2026-11-28-v1'
) returns boolean
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare
  v_row public.bloom_website_waitlist%rowtype;
begin
  if p_action not in ('update', 'unsubscribe', 'delete') then raise exception 'Invalid action'; end if;
  select * into v_row from public.bloom_website_waitlist
    where id = p_id and status = 'confirmed'
      and management_generation = p_generation
      and management_expires_at > clock_timestamp()
    for update;
  if not found then return false; end if;

  if p_action = 'delete' then
    insert into public.bloom_website_waitlist_events (waitlist_id, event_type, policy_version, adult_or_guardian, beta_interest, marketing_consent)
      values (v_row.id, 'deletion_requested', v_row.consent_policy_version, true, v_row.beta_interest, v_row.marketing_consent);
    delete from public.bloom_website_waitlist where id = v_row.id;
    return true;
  end if;

  insert into public.bloom_website_waitlist_events (
    waitlist_id, event_type, policy_version, adult_or_guardian, beta_interest, marketing_consent
  ) values (v_row.id, case when p_action = 'unsubscribe' then 'unsubscribed' else 'preferences_updated' end,
    p_policy_version, true, case when p_action = 'unsubscribe' then false else p_beta_interest end,
    case when p_action = 'unsubscribe' then false else p_marketing_consent end);
  update public.bloom_website_waitlist set
    status = case when p_action = 'unsubscribe' then 'unsubscribed' else status end,
    beta_interest = case when p_action = 'unsubscribe' then false else p_beta_interest end,
    beta_interest_recorded_at = case when p_action = 'unsubscribe' or not p_beta_interest then null
      when not v_row.beta_interest then clock_timestamp() else v_row.beta_interest_recorded_at end,
    marketing_consent = case when p_action = 'unsubscribe' then false else p_marketing_consent end,
    marketing_consented_at = case when p_action = 'unsubscribe' or not p_marketing_consent then null
      when not v_row.marketing_consent then clock_timestamp() else v_row.marketing_consented_at end,
    management_generation = null, management_expires_at = null, updated_at = clock_timestamp()
  where id = v_row.id;
  return true;
end;
$$;

create or replace function public.bloom_website_get_preferences(
  p_id uuid,
  p_generation uuid
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $$
declare
  v_row public.bloom_website_waitlist%rowtype;
begin
  select * into v_row from public.bloom_website_waitlist
    where id = p_id and status = 'confirmed'
      and management_generation = p_generation
      and management_expires_at > clock_timestamp();
  if not found then return null; end if;
  return jsonb_build_object('beta_interest', v_row.beta_interest, 'marketing_consent', v_row.marketing_consent);
end;
$$;

revoke all on function public.bloom_website_consume_rate_limit(text, integer, integer) from public, anon, authenticated;
revoke all on function public.bloom_website_start_waitlist(text, text, uuid, boolean, boolean, boolean, text) from public, anon, authenticated;
revoke all on function public.bloom_website_confirm_waitlist(uuid, uuid) from public, anon, authenticated;
revoke all on function public.bloom_website_mark_waitlist_email_sent(uuid, uuid) from public, anon, authenticated;
revoke all on function public.bloom_website_start_management(text, uuid) from public, anon, authenticated;
revoke all on function public.bloom_website_manage(uuid, uuid, text, boolean, boolean, text) from public, anon, authenticated;
revoke all on function public.bloom_website_get_preferences(uuid, uuid) from public, anon, authenticated;
grant execute on function public.bloom_website_consume_rate_limit(text, integer, integer) to service_role;
grant execute on function public.bloom_website_start_waitlist(text, text, uuid, boolean, boolean, boolean, text) to service_role;
grant execute on function public.bloom_website_confirm_waitlist(uuid, uuid) to service_role;
grant execute on function public.bloom_website_mark_waitlist_email_sent(uuid, uuid) to service_role;
grant execute on function public.bloom_website_start_management(text, uuid) to service_role;
grant execute on function public.bloom_website_manage(uuid, uuid, text, boolean, boolean, text) to service_role;
grant execute on function public.bloom_website_get_preferences(uuid, uuid) to service_role;

comment on table public.bloom_website_waitlist is 'Adult-submitted Bloom iPhone launch list. Access is restricted to the server-side service role.';
comment on table public.bloom_website_waitlist_events is 'Minimal waitlist consent and lifecycle audit. Never contains addresses.';
