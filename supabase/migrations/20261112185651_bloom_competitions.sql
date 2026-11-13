begin;

-- A child cannot remove the family relationship to bypass parent approval or
-- search privacy. A parent can still remove separately signed-in children.
create or replace function bloom_private.leave_or_remove_child(p_household_id uuid, p_child_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null or not exists (select 1 from public.bloom_household_members m where m.household_id = p_household_id
    and m.user_id = v_profile and m.role = 'parent') then raise exception 'Parent access required'; end if;
  if exists (select 1 from public.bloom_child_profiles c where c.profile_id = p_child_id and c.household_id = p_household_id) then
    raise exception 'Managed child profiles cannot leave the family here';
  end if;
  delete from public.bloom_household_members m where m.household_id = p_household_id and m.user_id = p_child_id and m.role = 'child';
  if not found then raise exception 'Child membership not found'; end if;
end;
$$;

create table public.bloom_social_profiles (
  profile_id uuid primary key references public.bloom_profiles(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 60),
  searchable boolean not null default false,
  child_search_opt_in boolean not null default false,
  updated_at timestamptz not null default now()
);
create table public.bloom_friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.bloom_profiles(id) on delete cascade,
  addressee_id uuid not null references public.bloom_profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id)
);
create unique index bloom_friendships_pair_idx on public.bloom_friendships(least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create table bloom_private.competition_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
revoke all on bloom_private.competition_admins from public, anon, authenticated;
create table public.bloom_competitions (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 100),
  description text not null default '' check (char_length(description) <= 1000),
  metric text not null check (metric in ('workouts', 'minutes')),
  visibility text not null check (visibility in ('private', 'public')),
  status text not null check (status in ('draft', 'published', 'cancelled')),
  max_participants integer not null check (max_participants between 2 and 100),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at and ends_at <= starts_at + interval '90 days'),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  finalized_at timestamptz
);
create table public.bloom_competition_participants (
  competition_id uuid not null references public.bloom_competitions(id) on delete cascade,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  status text not null check (status in ('pending_parent', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  check ((status = 'approved') = (approved_at is not null)),
  primary key (competition_id, profile_id)
);
create index bloom_competition_participants_profile_idx on public.bloom_competition_participants(profile_id, requested_at desc);
create table public.bloom_competition_friend_invites (
  competition_id uuid not null references public.bloom_competitions(id) on delete cascade,
  invitee_id uuid not null references public.bloom_profiles(id) on delete cascade,
  invited_by uuid not null references public.bloom_profiles(id) on delete cascade,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (competition_id, invitee_id)
);
create table public.bloom_competition_badges (
  competition_id uuid not null references public.bloom_competitions(id) on delete cascade,
  profile_id uuid not null references public.bloom_profiles(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  primary key (competition_id, profile_id)
);
create table bloom_private.competition_link_invites (
  token_hash bytea primary key,
  competition_id uuid not null references public.bloom_competitions(id) on delete cascade,
  created_by uuid not null references public.bloom_profiles(id) on delete cascade,
  expires_at timestamptz not null,
  uses integer not null default 0 check (uses between 0 and 100)
);
revoke all on bloom_private.competition_link_invites from public, anon, authenticated;

alter table public.bloom_social_profiles enable row level security;
alter table public.bloom_friendships enable row level security;
alter table public.bloom_competitions enable row level security;
alter table public.bloom_competition_participants enable row level security;
alter table public.bloom_competition_friend_invites enable row level security;
alter table public.bloom_competition_badges enable row level security;
revoke all on public.bloom_social_profiles, public.bloom_friendships, public.bloom_competitions,
  public.bloom_competition_participants, public.bloom_competition_friend_invites, public.bloom_competition_badges from public, anon, authenticated;
grant select on public.bloom_social_profiles, public.bloom_friendships, public.bloom_competitions,
  public.bloom_competition_participants, public.bloom_competition_friend_invites, public.bloom_competition_badges to authenticated;

create function bloom_private.is_competition_admin()
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select auth.uid() is not null and exists (select 1 from bloom_private.competition_admins a where a.user_id = auth.uid());
$$;
revoke all on function bloom_private.is_competition_admin() from public, anon;
grant execute on function bloom_private.is_competition_admin() to authenticated;
create function public.bloom_is_competition_admin()
returns boolean language sql stable security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.is_competition_admin(); $$;

create function bloom_private.can_view_competition(p_competition_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select bloom_private.current_profile_id() is not null and exists (
    select 1 from public.bloom_competitions c where c.id = p_competition_id and (
      (c.visibility = 'public' and c.status = 'published') or c.owner_profile_id = bloom_private.current_profile_id()
      or (c.visibility = 'public' and bloom_private.is_competition_admin())
      or exists (select 1 from public.bloom_competition_participants p where p.competition_id = c.id
        and (p.profile_id = bloom_private.current_profile_id() or bloom_private.is_parent_of(p.profile_id)))
      or exists (select 1 from public.bloom_competition_friend_invites i where i.competition_id = c.id and i.invitee_id = bloom_private.current_profile_id())
    )
  );
$$;
revoke all on function bloom_private.can_view_competition(uuid) from public, anon;
grant execute on function bloom_private.can_view_competition(uuid) to authenticated;
create policy bloom_social_profiles_owner_parent on public.bloom_social_profiles for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(profile_id));
create policy bloom_friendships_participants on public.bloom_friendships for select to authenticated
  using (requester_id = (select bloom_private.current_profile_id()) or addressee_id = (select bloom_private.current_profile_id()));
create policy bloom_competitions_visible on public.bloom_competitions for select to authenticated using (bloom_private.can_view_competition(id));
create policy bloom_competition_participants_self_parent on public.bloom_competition_participants for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(profile_id));
create policy bloom_competition_invites_visible on public.bloom_competition_friend_invites for select to authenticated
  using (invitee_id = (select bloom_private.current_profile_id()) or invited_by = (select bloom_private.current_profile_id()));
create policy bloom_competition_badges_self_parent on public.bloom_competition_badges for select to authenticated
  using (profile_id = (select bloom_private.current_profile_id()) or bloom_private.is_parent_of(profile_id));

create function bloom_private.set_social_profile(p_name text, p_searchable boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to manage your display name'; end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 60 or p_searchable is null then raise exception 'Enter a display name of up to 60 characters'; end if;
  insert into public.bloom_social_profiles(profile_id, display_name, searchable) values (v_profile, trim(p_name), p_searchable)
    on conflict (profile_id) do update set display_name = excluded.display_name, searchable = excluded.searchable, updated_at = clock_timestamp();
end;
$$;
create function public.bloom_set_social_profile(p_name text, p_searchable boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.set_social_profile(p_name, p_searchable); $$;

create function bloom_private.set_child_search(p_child_id uuid, p_enabled boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null or not bloom_private.is_parent_of(p_child_id)
    or not bloom_private.is_child_profile(p_child_id) then raise exception 'Parent access required'; end if;
  if p_enabled is null then raise exception 'Choose a search setting'; end if;
  insert into public.bloom_social_profiles(profile_id, display_name, child_search_opt_in)
    values (p_child_id, 'Bloom member', p_enabled)
    on conflict (profile_id) do update set child_search_opt_in = excluded.child_search_opt_in, updated_at = clock_timestamp();
end;
$$;
create function public.bloom_set_child_search(p_child_id uuid, p_enabled boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.set_child_search(p_child_id, p_enabled); $$;

create function bloom_private.search_people(p_query text)
returns table(profile_id uuid, display_name text) language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null then raise exception 'Sign in to search'; end if;
  if p_query is null or char_length(trim(p_query)) not between 2 and 60 then raise exception 'Enter at least two characters'; end if;
  return query select s.profile_id, s.display_name from public.bloom_social_profiles s
    where s.profile_id <> bloom_private.current_profile_id() and s.searchable
      and (not bloom_private.is_child_profile(s.profile_id) or s.child_search_opt_in)
      and position(lower(trim(p_query)) in lower(s.display_name)) > 0 order by s.display_name, s.profile_id limit 30;
end;
$$;
create function public.bloom_search_people(p_query text)
returns table(profile_id uuid, display_name text) language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.search_people(p_query);
$$;

-- The older Nashaat search returns real-name fields. Keep child profiles out
-- of that search even when a parent enables Bloom's display-name discovery.
create or replace function public.search_public_profiles(p_query text, p_limit integer default 20)
returns table(id uuid, username text, first_name text, last_name text, streak_count integer)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p.id, p.username, p.first_name, p.last_name, p.streak_count from public.profiles p
  where auth.uid() is not null and p.id <> auth.uid() and char_length(trim(coalesce(p_query, ''))) >= 2
    and not exists (select 1 from public.bloom_profile_accounts a where a.user_id = p.id and bloom_private.is_child_profile(a.profile_id))
    and (position(lower(trim(p_query)) in lower(coalesce(p.username, ''))) > 0
      or position(lower(trim(p_query)) in lower(coalesce(p.first_name, ''))) > 0
      or position(lower(trim(p_query)) in lower(coalesce(p.last_name, ''))) > 0)
  order by coalesce(p.username, p.first_name, p.last_name), p.id limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.search_public_profiles(text, integer) from public, anon;
grant execute on function public.search_public_profiles(text, integer) to authenticated;

create or replace function public.get_public_profile(p_user_id uuid)
returns table(id uuid, username text, first_name text, last_name text, streak_count integer)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p.id, p.username, p.first_name, p.last_name,
    case when p.last_workout_date is null or p.last_workout_date <
      (clock_timestamp() at time zone coalesce(nullif(p.timezone, ''), 'UTC'))::date - 1 then 0 else coalesce(p.streak_count, 0) end
  from public.profiles p where auth.uid() is not null and p.id = p_user_id and (
    not exists (select 1 from public.bloom_profile_accounts a where a.user_id = p.id and bloom_private.is_child_profile(a.profile_id))
    or exists (select 1 from public.bloom_profile_accounts a where a.user_id = p.id
      and (a.profile_id = bloom_private.current_profile_id() or bloom_private.is_parent_of(a.profile_id)))
  );
$$;
revoke all on function public.get_public_profile(uuid) from public, anon;
grant execute on function public.get_public_profile(uuid) to authenticated;

create function bloom_private.send_friend_request(p_other uuid)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_friend public.bloom_friendships%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to add friends'; end if;
  if p_other is null or p_other = v_profile then raise exception 'Choose another person'; end if;
  if not exists (select 1 from public.bloom_social_profiles s where s.profile_id = v_profile) then raise exception 'Choose a display name first'; end if;
  if not exists (select 1 from public.bloom_social_profiles s where s.profile_id = p_other and s.searchable
    and (not bloom_private.is_child_profile(p_other) or s.child_search_opt_in)) then raise exception 'Person not found'; end if;
  select * into v_friend from public.bloom_friendships f where least(f.requester_id, f.addressee_id) = least(v_profile, p_other)
    and greatest(f.requester_id, f.addressee_id) = greatest(v_profile, p_other) for update;
  if not found then
    insert into public.bloom_friendships(requester_id, addressee_id) values (v_profile, p_other) on conflict do nothing returning * into v_friend;
    if not found then
      select * into v_friend from public.bloom_friendships f where least(f.requester_id, f.addressee_id) = least(v_profile, p_other)
        and greatest(f.requester_id, f.addressee_id) = greatest(v_profile, p_other) for update;
    end if;
  end if;
  if v_friend.status = 'rejected' and v_friend.requester_id = v_profile then
    update public.bloom_friendships set status = 'pending', updated_at = clock_timestamp() where id = v_friend.id;
  end if;
  return v_friend.id;
end;
$$;
create function public.bloom_send_friend_request(p_other uuid)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.send_friend_request(p_other); $$;

create function bloom_private.respond_friend_request(p_friendship_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null or p_accept is null then raise exception 'Sign in to respond'; end if;
  update public.bloom_friendships set status = case when p_accept then 'accepted' else 'rejected' end, updated_at = clock_timestamp()
    where id = p_friendship_id and addressee_id = bloom_private.current_profile_id() and status = 'pending';
  if not found then raise exception 'Friend request not found'; end if;
end;
$$;
create function public.bloom_respond_friend_request(p_friendship_id uuid, p_accept boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.respond_friend_request(p_friendship_id, p_accept); $$;
create function bloom_private.remove_friend(p_friendship_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null then raise exception 'Sign in to manage friends'; end if;
  delete from public.bloom_friendships where id = p_friendship_id
    and bloom_private.current_profile_id() in (requester_id, addressee_id);
  if not found then raise exception 'Friendship not found'; end if;
end;
$$;
create function public.bloom_remove_friend(p_friendship_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.remove_friend(p_friendship_id); $$;

create function bloom_private.list_friends()
returns table(id uuid, profile_id uuid, display_name text, status text, incoming boolean)
language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to view friends'; end if;
  return query select f.id, s.profile_id, s.display_name, f.status, f.addressee_id = v_profile
    from public.bloom_friendships f join public.bloom_social_profiles s on s.profile_id = case when f.requester_id = v_profile then f.addressee_id else f.requester_id end
    where f.requester_id = v_profile or f.addressee_id = v_profile order by f.updated_at desc;
end;
$$;
create function public.bloom_list_friends()
returns table(id uuid, profile_id uuid, display_name text, status text, incoming boolean)
language sql security invoker set search_path = pg_catalog, pg_temp as $$ select * from bloom_private.list_friends(); $$;

create function bloom_private.validate_competition(p_title text, p_description text, p_metric text, p_max integer, p_starts timestamptz, p_ends timestamptz)
returns void language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
begin
  if p_title is null or char_length(trim(p_title)) not between 1 and 100 or p_description is null or char_length(p_description) > 1000
    or p_metric is null or p_metric not in ('workouts', 'minutes') or p_max is null or p_max not between 2 and 100
    or p_starts is null or p_ends is null or p_starts <= clock_timestamp() or p_starts > clock_timestamp() + interval '1 year'
    or p_ends <= p_starts or p_ends > p_starts + interval '90 days' then raise exception 'Invalid competition details'; end if;
end;
$$;
revoke all on function bloom_private.validate_competition(text, text, text, integer, timestamptz, timestamptz) from public, anon, authenticated;

create function bloom_private.create_competition(p_title text, p_description text, p_metric text, p_visibility text, p_max integer, p_starts timestamptz, p_ends timestamptz)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_id uuid; v_child boolean;
begin
  if v_profile is null then raise exception 'Sign in to create a competition'; end if;
  perform bloom_private.validate_competition(p_title, p_description, p_metric, p_max, p_starts, p_ends);
  if p_visibility is null or p_visibility not in ('private', 'public') then raise exception 'Invalid competition visibility'; end if;
  if p_visibility = 'public' and not bloom_private.is_competition_admin() then raise exception 'Administrator access required'; end if;
  if p_visibility = 'private' and not exists (select 1 from public.bloom_social_profiles s where s.profile_id = v_profile) then
    raise exception 'Choose a display name first';
  end if;
  insert into public.bloom_competitions(owner_profile_id, title, description, metric, visibility, status, max_participants, starts_at, ends_at, published_at)
    values (v_profile, trim(p_title), trim(p_description), p_metric, p_visibility,
      case when p_visibility = 'public' then 'draft' else 'published' end, p_max, p_starts, p_ends,
      case when p_visibility = 'private' then clock_timestamp() else null end) returning id into v_id;
  if p_visibility = 'private' then
    v_child := bloom_private.is_child_profile(v_profile);
    insert into public.bloom_competition_participants(competition_id, profile_id, status, approved_at)
      values (v_id, v_profile, case when v_child then 'pending_parent' else 'approved' end,
        case when v_child then null else clock_timestamp() end);
  end if;
  return v_id;
end;
$$;
create function public.bloom_create_competition(p_title text, p_description text, p_metric text, p_visibility text, p_max integer, p_starts timestamptz, p_ends timestamptz)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.create_competition(p_title, p_description, p_metric, p_visibility, p_max, p_starts, p_ends);
$$;

create function bloom_private.update_public_competition_draft(p_id uuid, p_title text, p_description text, p_metric text, p_max integer, p_starts timestamptz, p_ends timestamptz)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if not bloom_private.is_competition_admin() then raise exception 'Administrator access required'; end if;
  perform bloom_private.validate_competition(p_title, p_description, p_metric, p_max, p_starts, p_ends);
  update public.bloom_competitions set title = trim(p_title), description = trim(p_description), metric = p_metric,
    max_participants = p_max, starts_at = p_starts, ends_at = p_ends
    where id = p_id and visibility = 'public' and status = 'draft';
  if not found then raise exception 'Draft not found'; end if;
end;
$$;
create function public.bloom_update_public_competition_draft(p_id uuid, p_title text, p_description text, p_metric text, p_max integer, p_starts timestamptz, p_ends timestamptz)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_public_competition_draft(p_id, p_title, p_description, p_metric, p_max, p_starts, p_ends);
$$;
create function bloom_private.publish_competition(p_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if not bloom_private.is_competition_admin() then raise exception 'Administrator access required'; end if;
  update public.bloom_competitions set status = 'published', published_at = clock_timestamp()
    where id = p_id and visibility = 'public' and status = 'draft' and starts_at > clock_timestamp();
  if not found then raise exception 'Draft not found or start time has passed'; end if;
end;
$$;
create function public.bloom_publish_competition(p_id uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.publish_competition(p_id); $$;

create function bloom_private.join_competition(p_id uuid, p_profile uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_event public.bloom_competitions%rowtype; v_status text; v_child boolean;
begin
  select * into v_event from public.bloom_competitions c where c.id = p_id for update;
  if not found or v_event.status <> 'published' or v_event.ends_at <= clock_timestamp() then raise exception 'Competition is unavailable'; end if;
  if p_profile is null or p_profile <> bloom_private.current_profile_id() then raise exception 'Sign in to join'; end if;
  if not exists (select 1 from public.bloom_social_profiles s where s.profile_id = p_profile) then raise exception 'Choose a display name first'; end if;
  select p.status into v_status from public.bloom_competition_participants p where p.competition_id = p_id and p.profile_id = p_profile for update;
  if found and v_status in ('approved', 'pending_parent') then return v_status; end if;
  if (select count(*) from public.bloom_competition_participants p where p.competition_id = p_id and p.status in ('approved', 'pending_parent')) >= v_event.max_participants then
    raise exception 'Competition is full';
  end if;
  v_child := bloom_private.is_child_profile(p_profile);
  v_status := case when v_child then 'pending_parent' else 'approved' end;
  insert into public.bloom_competition_participants(competition_id, profile_id, status, requested_at, approved_at)
    values (p_id, p_profile, v_status, clock_timestamp(), case when v_child then null else clock_timestamp() end)
    on conflict (competition_id, profile_id) do update set status = excluded.status, requested_at = excluded.requested_at, approved_at = excluded.approved_at;
  return v_status;
end;
$$;
revoke all on function bloom_private.join_competition(uuid, uuid) from public, anon, authenticated;

create function bloom_private.join_public_competition(p_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null then raise exception 'Sign in to join'; end if;
  if not exists (select 1 from public.bloom_competitions c where c.id = p_id and c.visibility = 'public' and c.status = 'published') then
    raise exception 'Competition is unavailable';
  end if;
  return bloom_private.join_competition(p_id, bloom_private.current_profile_id());
end;
$$;
create function public.bloom_join_public_competition(p_id uuid)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.join_public_competition(p_id); $$;

create function bloom_private.approve_competition_child(p_id uuid, p_child_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_event public.bloom_competitions%rowtype;
begin
  if bloom_private.current_profile_id() is null or p_approve is null or not bloom_private.is_parent_of(p_child_id)
    or not bloom_private.is_child_profile(p_child_id) then raise exception 'Parent access required'; end if;
  select * into v_event from public.bloom_competitions c where c.id = p_id for update;
  if not found or v_event.status <> 'published' or v_event.ends_at <= clock_timestamp() then raise exception 'Competition is unavailable'; end if;
  update public.bloom_competition_participants set status = case when p_approve then 'approved' else 'rejected' end,
    approved_at = case when p_approve then clock_timestamp() else null end
    where competition_id = p_id and profile_id = p_child_id and status = 'pending_parent';
  if not found then raise exception 'Pending request not found'; end if;
end;
$$;
create function public.bloom_approve_competition_child(p_id uuid, p_child_id uuid, p_approve boolean)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.approve_competition_child(p_id, p_child_id, p_approve); $$;

create function bloom_private.invite_competition_friend(p_id uuid, p_friend uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to invite friends'; end if;
  perform 1 from public.bloom_competitions c where c.id = p_id and c.owner_profile_id = v_profile and c.visibility = 'private'
    and c.status = 'published' and c.ends_at > clock_timestamp() for share;
  if not found then raise exception 'Competition not found'; end if;
  if not exists (select 1 from public.bloom_friendships f where f.status = 'accepted'
    and ((f.requester_id = v_profile and f.addressee_id = p_friend) or (f.addressee_id = v_profile and f.requester_id = p_friend))) then
    raise exception 'Choose an accepted friend';
  end if;
  insert into public.bloom_competition_friend_invites(competition_id, invitee_id, invited_by)
    values (p_id, p_friend, v_profile) on conflict (competition_id, invitee_id) do nothing;
end;
$$;
create function public.bloom_invite_competition_friend(p_id uuid, p_friend uuid)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.invite_competition_friend(p_id, p_friend); $$;

create function bloom_private.accept_competition_friend_invite(p_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_status text;
begin
  if v_profile is null then raise exception 'Sign in to join'; end if;
  if not exists (select 1 from public.bloom_competition_friend_invites i where i.competition_id = p_id and i.invitee_id = v_profile) then
    raise exception 'Invitation not found';
  end if;
  v_status := bloom_private.join_competition(p_id, v_profile);
  update public.bloom_competition_friend_invites set accepted_at = coalesce(accepted_at, clock_timestamp())
    where competition_id = p_id and invitee_id = v_profile;
  return v_status;
end;
$$;
create function public.bloom_accept_competition_friend_invite(p_id uuid)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.accept_competition_friend_invite(p_id); $$;

create function bloom_private.create_competition_link(p_id uuid)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_ends timestamptz; v_token text;
begin
  if v_profile is null then raise exception 'Sign in to invite people'; end if;
  select c.ends_at into v_ends from public.bloom_competitions c where c.id = p_id and c.owner_profile_id = v_profile
    and c.visibility = 'private' and c.status = 'published' and c.ends_at > clock_timestamp() for share;
  if not found then raise exception 'Competition not found'; end if;
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into bloom_private.competition_link_invites(token_hash, competition_id, created_by, expires_at)
    values (sha256(convert_to(v_token, 'UTF8')), p_id, v_profile, least(v_ends, clock_timestamp() + interval '7 days'));
  return v_token;
end;
$$;
create function public.bloom_create_competition_link(p_id uuid)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.create_competition_link(p_id); $$;

create function bloom_private.accept_competition_link(p_token text)
returns uuid language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_invite bloom_private.competition_link_invites%rowtype; v_profile uuid := bloom_private.current_profile_id(); v_existing boolean;
begin
  if v_profile is null or p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'Invalid or expired invitation'; end if;
  select * into v_invite from bloom_private.competition_link_invites i where i.token_hash = sha256(convert_to(p_token, 'UTF8')) for update;
  if not found or v_invite.expires_at <= clock_timestamp() or v_invite.uses >= 100 or not exists (
    select 1 from public.bloom_competitions c where c.id = v_invite.competition_id and c.owner_profile_id = v_invite.created_by
      and c.visibility = 'private' and c.status = 'published' and c.ends_at > clock_timestamp()) then raise exception 'Invalid or expired invitation'; end if;
  select exists (select 1 from public.bloom_competition_participants p where p.competition_id = v_invite.competition_id
    and p.profile_id = v_profile and p.status in ('approved', 'pending_parent')) into v_existing;
  perform bloom_private.join_competition(v_invite.competition_id, v_profile);
  if not v_existing then update bloom_private.competition_link_invites set uses = uses + 1 where token_hash = v_invite.token_hash; end if;
  return v_invite.competition_id;
end;
$$;
create function public.bloom_accept_competition_link(p_token text)
returns uuid language sql security invoker set search_path = pg_catalog, pg_temp as $$ select bloom_private.accept_competition_link(p_token); $$;

-- Results are derived from saved sessions, so submitting the same workout
-- twice cannot create a second score. Timed sessions that began before the
-- event or approval are excluded because their interval cannot be split.
create function bloom_private.competition_scores(p_id uuid)
returns table(profile_id uuid, display_name text, score numeric)
language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select p.profile_id, coalesce(social.display_name, 'Bloom member'),
    case when c.metric = 'workouts' then count(w.id)::numeric
      else round(coalesce(sum(w.active_duration_seconds) filter (where w.started_at >= greatest(c.starts_at, p.approved_at)), 0) / 60, 2) end
  from public.bloom_competitions c join public.bloom_competition_participants p on p.competition_id = c.id and p.status = 'approved'
  left join public.bloom_social_profiles social on social.profile_id = p.profile_id
  left join public.bloom_workout_sessions w on w.user_id = p.profile_id and w.status = 'completed'
    and w.completed_at >= greatest(c.starts_at, p.approved_at) and w.completed_at < c.ends_at
  where c.id = p_id group by p.profile_id, social.display_name, c.metric;
$$;
revoke all on function bloom_private.competition_scores(uuid) from public, anon, authenticated;

create function bloom_private.finalize_competition(p_id uuid)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_event public.bloom_competitions%rowtype; v_best numeric;
begin
  select * into v_event from public.bloom_competitions c where c.id = p_id for update;
  if not found or v_event.status <> 'published' or v_event.ends_at > clock_timestamp() or v_event.finalized_at is not null then return; end if;
  select max(s.score) into v_best from bloom_private.competition_scores(p_id) s;
  if v_best > 0 then
    insert into public.bloom_competition_badges(competition_id, profile_id)
      select p_id, s.profile_id from bloom_private.competition_scores(p_id) s where s.score = v_best on conflict do nothing;
  end if;
  update public.bloom_competitions set finalized_at = clock_timestamp() where id = p_id;
end;
$$;
revoke all on function bloom_private.finalize_competition(uuid) from public, anon, authenticated;

create function bloom_private.competition_results(p_id uuid)
returns table(display_name text, score numeric, placement bigint, is_self boolean, winner boolean)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if not bloom_private.can_view_competition(p_id) then raise exception 'Competition not found'; end if;
  perform bloom_private.finalize_competition(p_id);
  return query select s.display_name, s.score, rank() over (order by s.score desc),
    s.profile_id = bloom_private.current_profile_id(),
    exists (select 1 from public.bloom_competition_badges b where b.competition_id = p_id and b.profile_id = s.profile_id)
    from bloom_private.competition_scores(p_id) s order by s.score desc, s.display_name, s.profile_id;
end;
$$;
create function public.bloom_competition_results(p_id uuid)
returns table(display_name text, score numeric, placement bigint, is_self boolean, winner boolean)
language sql security invoker set search_path = pg_catalog, pg_temp as $$ select * from bloom_private.competition_results(p_id); $$;

create function bloom_private.my_competition_badges()
returns table(competition_id uuid, title text, awarded_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_id uuid;
begin
  if v_profile is null then raise exception 'Sign in to view badges'; end if;
  for v_id in select c.id from public.bloom_competitions c join public.bloom_competition_participants p on p.competition_id = c.id
    where p.profile_id = v_profile and p.status = 'approved' and c.status = 'published'
      and c.ends_at <= clock_timestamp() and c.finalized_at is null order by c.id limit 100
  loop perform bloom_private.finalize_competition(v_id); end loop;
  return query select c.id, c.title, b.awarded_at from public.bloom_competition_badges b
    join public.bloom_competitions c on c.id = b.competition_id where b.profile_id = v_profile order by b.awarded_at desc;
end;
$$;
create function public.bloom_my_competition_badges()
returns table(competition_id uuid, title text, awarded_at timestamptz)
language sql security invoker set search_path = pg_catalog, pg_temp as $$ select * from bloom_private.my_competition_badges(); $$;
revoke all on function bloom_private.my_competition_badges(), public.bloom_my_competition_badges() from public, anon;
grant execute on function bloom_private.my_competition_badges(), public.bloom_my_competition_badges() to authenticated;

revoke all on function bloom_private.set_social_profile(text, boolean), bloom_private.set_child_search(uuid, boolean),
  bloom_private.search_people(text), bloom_private.send_friend_request(uuid), bloom_private.respond_friend_request(uuid, boolean),
  bloom_private.remove_friend(uuid), bloom_private.list_friends(), bloom_private.create_competition(text, text, text, text, integer, timestamptz, timestamptz),
  bloom_private.update_public_competition_draft(uuid, text, text, text, integer, timestamptz, timestamptz), bloom_private.publish_competition(uuid),
  bloom_private.join_public_competition(uuid), bloom_private.approve_competition_child(uuid, uuid, boolean), bloom_private.invite_competition_friend(uuid, uuid),
  bloom_private.accept_competition_friend_invite(uuid), bloom_private.create_competition_link(uuid), bloom_private.accept_competition_link(text), bloom_private.competition_results(uuid),
  public.bloom_is_competition_admin(), public.bloom_set_social_profile(text, boolean), public.bloom_set_child_search(uuid, boolean),
  public.bloom_search_people(text), public.bloom_send_friend_request(uuid), public.bloom_respond_friend_request(uuid, boolean), public.bloom_remove_friend(uuid), public.bloom_list_friends(),
  public.bloom_create_competition(text, text, text, text, integer, timestamptz, timestamptz), public.bloom_update_public_competition_draft(uuid, text, text, text, integer, timestamptz, timestamptz),
  public.bloom_publish_competition(uuid), public.bloom_join_public_competition(uuid), public.bloom_approve_competition_child(uuid, uuid, boolean),
  public.bloom_invite_competition_friend(uuid, uuid), public.bloom_accept_competition_friend_invite(uuid), public.bloom_create_competition_link(uuid),
  public.bloom_accept_competition_link(text), public.bloom_competition_results(uuid) from public, anon;
grant execute on function bloom_private.set_social_profile(text, boolean), bloom_private.set_child_search(uuid, boolean),
  bloom_private.search_people(text), bloom_private.send_friend_request(uuid), bloom_private.respond_friend_request(uuid, boolean),
  bloom_private.remove_friend(uuid), bloom_private.list_friends(), bloom_private.create_competition(text, text, text, text, integer, timestamptz, timestamptz),
  bloom_private.update_public_competition_draft(uuid, text, text, text, integer, timestamptz, timestamptz), bloom_private.publish_competition(uuid),
  bloom_private.join_public_competition(uuid), bloom_private.approve_competition_child(uuid, uuid, boolean), bloom_private.invite_competition_friend(uuid, uuid),
  bloom_private.accept_competition_friend_invite(uuid), bloom_private.create_competition_link(uuid), bloom_private.accept_competition_link(text), bloom_private.competition_results(uuid),
  public.bloom_is_competition_admin(), public.bloom_set_social_profile(text, boolean), public.bloom_set_child_search(uuid, boolean),
  public.bloom_search_people(text), public.bloom_send_friend_request(uuid), public.bloom_respond_friend_request(uuid, boolean), public.bloom_remove_friend(uuid), public.bloom_list_friends(),
  public.bloom_create_competition(text, text, text, text, integer, timestamptz, timestamptz), public.bloom_update_public_competition_draft(uuid, text, text, text, integer, timestamptz, timestamptz),
  public.bloom_publish_competition(uuid), public.bloom_join_public_competition(uuid), public.bloom_approve_competition_child(uuid, uuid, boolean),
  public.bloom_invite_competition_friend(uuid, uuid), public.bloom_accept_competition_friend_invite(uuid), public.bloom_create_competition_link(uuid),
  public.bloom_accept_competition_link(text), public.bloom_competition_results(uuid) to authenticated;

commit;
