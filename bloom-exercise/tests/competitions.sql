begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000181'), ('00000000-0000-0000-0000-000000000182'),
 ('00000000-0000-0000-0000-000000000183'), ('00000000-0000-0000-0000-000000000184');
insert into bloom_private.competition_admins(user_id) values ('00000000-0000-0000-0000-000000000184');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_set_social_profile('Parent', true);
select set_config('bloom.comp_house', public.bloom_create_household('Competition family')::text, true);
select set_config('bloom.comp_child', public.bloom_create_child_profile(current_setting('bloom.comp_house')::uuid, 'Child',
  '18000000-0000-0000-0000-000000000181')::text, true);
select public.bloom_authorize_child_provisioning(current_setting('bloom.comp_child')::uuid);
reset role;
insert into auth.users(id, raw_app_meta_data) values (current_setting('bloom.comp_child')::uuid,
  jsonb_build_object('bloom_managed_child', true, 'bloom_profile_id', current_setting('bloom.comp_child')));
insert into public.profiles(id, first_name) values (current_setting('bloom.comp_child')::uuid, 'PrivateChildName');
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('bloom.comp_child'), true);
select public.bloom_set_social_profile('Tiny Moves', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
select public.bloom_set_social_profile('Friend', true);
do $$ begin
  if exists (select 1 from public.bloom_search_people('Tiny')) then raise exception 'Child searchable without parent opt-in'; end if;
  begin
    perform public.bloom_create_competition('Unauthorized', '', 'workouts', 'public', 2, clock_timestamp() + interval '1 hour', clock_timestamp() + interval '2 hours');
    raise exception using errcode = 'P0002', message = 'Non-admin created public event';
  exception when raise_exception then if sqlerrm <> 'Administrator access required' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_set_child_search(current_setting('bloom.comp_child')::uuid, true);
select set_config('bloom.comp_friendship', public.bloom_send_friend_request('00000000-0000-0000-0000-000000000182')::text, true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
do $$ begin
  if not exists (select 1 from public.bloom_search_people('Tiny') where profile_id = current_setting('bloom.comp_child')::uuid) then raise exception 'Parent opt-in did not enable search'; end if;
  if exists (select 1 from public.search_public_profiles('PrivateChildName', 20))
    or exists (select 1 from public.get_public_profile(current_setting('bloom.comp_child')::uuid)) then
    raise exception 'Legacy profile endpoints exposed child real-name fields';
  end if;
  perform public.bloom_respond_friend_request(current_setting('bloom.comp_friendship')::uuid, true);
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_set_child_search(current_setting('bloom.comp_child')::uuid, false);
select set_config('bloom.comp_private', public.bloom_create_competition('Friends event', 'Self-reported', 'workouts', 'private', 3,
  clock_timestamp() + interval '1 hour', clock_timestamp() + interval '2 hours')::text, true);
select public.bloom_invite_competition_friend(current_setting('bloom.comp_private')::uuid, '00000000-0000-0000-0000-000000000182');
select set_config('bloom.comp_link', public.bloom_create_competition_link(current_setting('bloom.comp_private')::uuid), true);
select set_config('bloom.comp_expired_link', public.bloom_create_competition_link(current_setting('bloom.comp_private')::uuid), true);
do $$ begin
  begin
    perform public.bloom_create_competition('Invalid dates', '', 'workouts', 'private', 2,
      clock_timestamp() + interval '2 hours', clock_timestamp() + interval '1 hour');
    raise exception using errcode = 'P0002', message = 'Invalid event dates were accepted';
  exception when raise_exception then if sqlerrm <> 'Invalid competition details' then raise; end if; end;
end $$;
reset role;
update bloom_private.competition_link_invites set expires_at = clock_timestamp() - interval '1 second'
  where token_hash = sha256(convert_to(current_setting('bloom.comp_expired_link'), 'UTF8'));
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
select public.bloom_set_social_profile('Outsider', true);
do $$ begin
  if exists (select 1 from public.bloom_search_people('Tiny')) or exists (select 1 from public.bloom_competitions where id = current_setting('bloom.comp_private')::uuid) then
    raise exception 'Search privacy or private event visibility failed';
  end if;
  begin
    perform public.bloom_competition_results(current_setting('bloom.comp_private')::uuid);
    raise exception using errcode = 'P0002', message = 'Outsider read private results';
  exception when raise_exception then if sqlerrm <> 'Competition not found' then raise; end if; end;
  begin
    perform public.bloom_accept_competition_link(current_setting('bloom.comp_expired_link'));
    raise exception using errcode = 'P0002', message = 'Expired invitation was accepted';
  exception when raise_exception then if sqlerrm <> 'Invalid or expired invitation' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', current_setting('bloom.comp_child'), true);
select public.bloom_accept_competition_link(current_setting('bloom.comp_link'));
do $$ begin
  if not exists (select 1 from public.bloom_competition_participants where competition_id = current_setting('bloom.comp_private')::uuid
    and profile_id = current_setting('bloom.comp_child')::uuid and status = 'pending_parent') then raise exception 'Child joined without parent approval'; end if;
  begin
    perform public.bloom_approve_competition_child(current_setting('bloom.comp_private')::uuid, current_setting('bloom.comp_child')::uuid, true);
    raise exception using errcode = 'P0002', message = 'Child approved own participation';
  exception when raise_exception then if sqlerrm <> 'Parent access required' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_approve_competition_child(current_setting('bloom.comp_private')::uuid, current_setting('bloom.comp_child')::uuid, false);
select set_config('request.jwt.claim.sub', current_setting('bloom.comp_child'), true);
select public.bloom_accept_competition_link(current_setting('bloom.comp_link'));
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_approve_competition_child(current_setting('bloom.comp_private')::uuid, current_setting('bloom.comp_child')::uuid, true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
select public.bloom_accept_competition_friend_invite(current_setting('bloom.comp_private')::uuid);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
do $$ begin
  begin
    perform public.bloom_accept_competition_link(current_setting('bloom.comp_link'));
    raise exception using errcode = 'P0002', message = 'Competition exceeded capacity';
  exception when raise_exception then if sqlerrm <> 'Competition is full' then raise; end if; end;
end $$;

-- Only explicitly authorized administrators can draft and publish public events.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000184', true);
select set_config('bloom.comp_public', public.bloom_create_competition('Public event', 'Self-reported', 'minutes', 'public', 2,
  clock_timestamp() + interval '1 hour', clock_timestamp() + interval '2 hours')::text, true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
do $$ begin
  if exists (select 1 from public.bloom_competitions where id = current_setting('bloom.comp_public')::uuid) then raise exception 'Draft visible to non-admin'; end if;
  begin
    perform public.bloom_publish_competition(current_setting('bloom.comp_public')::uuid);
    raise exception using errcode = 'P0002', message = 'Non-admin published event';
  exception when raise_exception then if sqlerrm <> 'Administrator access required' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000184', true);
select public.bloom_publish_competition(current_setting('bloom.comp_public')::uuid);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select public.bloom_join_public_competition(current_setting('bloom.comp_public')::uuid);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000182', true);
select public.bloom_join_public_competition(current_setting('bloom.comp_public')::uuid);
select set_config('request.jwt.claim.sub', current_setting('bloom.comp_child'), true);
do $$ begin
  begin
    perform public.bloom_join_public_competition(current_setting('bloom.comp_public')::uuid);
    raise exception using errcode = 'P0002', message = 'One-to-one event exceeded capacity';
  exception when raise_exception then if sqlerrm <> 'Competition is full' then raise; end if; end;
end $$;

-- Synthetic timestamps model events that ended without waiting in real time.
reset role;
update public.bloom_competitions set starts_at = clock_timestamp() - interval '3 hours', ends_at = clock_timestamp() - interval '1 hour'
  where id in (current_setting('bloom.comp_private')::uuid, current_setting('bloom.comp_public')::uuid);
update public.bloom_competition_participants set approved_at = clock_timestamp() - interval '4 hours'
  where competition_id in (current_setting('bloom.comp_private')::uuid, current_setting('bloom.comp_public')::uuid) and status = 'approved';
insert into public.bloom_workout_sessions(id, user_id, plan_snapshot, status, started_at, completed_at, credits_enabled_at_completion, active_duration_seconds) values
 ('18000000-0000-0000-0000-000000000181', '00000000-0000-0000-0000-000000000181', '[]', 'completed', clock_timestamp() - interval '2 hours 30 minutes', clock_timestamp() - interval '2 hours', false, 300),
 ('18000000-0000-0000-0000-000000000182', '00000000-0000-0000-0000-000000000181', '[]', 'completed', clock_timestamp() - interval '4 hours', clock_timestamp() - interval '2 hours', false, 600),
 ('18000000-0000-0000-0000-000000000183', '00000000-0000-0000-0000-000000000182', '[]', 'completed', clock_timestamp() - interval '2 hours 30 minutes', clock_timestamp() - interval '2 hours', false, 150),
 ('18000000-0000-0000-0000-000000000184', '00000000-0000-0000-0000-000000000182', '[]', 'completed', clock_timestamp() - interval '2 hours 20 minutes', clock_timestamp() - interval '2 hours', false, 150);
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000181', true);
select * from public.bloom_complete_workout('18000000-0000-0000-0000-000000000181', '[]');
do $$ begin
  if (select count(*) from public.bloom_competition_results(current_setting('bloom.comp_private')::uuid) where score = 2 and placement = 1 and winner) <> 2 then
    raise exception 'Workout scoring, ties, or duplicate completion failed';
  end if;
  if (select count(*) from public.bloom_competition_results(current_setting('bloom.comp_private')::uuid) where score = 0 and winner) <> 0 then
    raise exception 'Zero-score participant received a badge';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000183', true);
do $$ begin
  if (select count(*) from public.bloom_competition_results(current_setting('bloom.comp_public')::uuid) where score = 5 and placement = 1 and winner) <> 2 then
    raise exception 'Active-minute scoring or ties failed';
  end if;
  perform public.bloom_competition_results(current_setting('bloom.comp_public')::uuid);
end $$;
reset role;
do $$ begin
  if (select count(*) from public.bloom_competition_badges where competition_id in
    (current_setting('bloom.comp_private')::uuid, current_setting('bloom.comp_public')::uuid)) <> 4 then
    raise exception 'Badges were duplicated or missing';
  end if;
end $$;
rollback;
