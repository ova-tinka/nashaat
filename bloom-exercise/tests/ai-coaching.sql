begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000171'),
 ('00000000-0000-0000-0000-000000000172'),
 ('00000000-0000-0000-0000-000000000173');
insert into public.exercises(id, name, measurement_type, is_system)
values ('17000000-0000-0000-0000-000000000171', 'Catalog move', 'reps_only', true);
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000171', true);
select set_config('bloom.coach_house', public.bloom_create_household('Coach family')::text, true);
select set_config('bloom.coach_child', public.bloom_create_child_profile(current_setting('bloom.coach_house')::uuid, 'Child',
  '17000000-0000-0000-0000-000000000172')::text, true);
select public.bloom_authorize_child_provisioning(current_setting('bloom.coach_child')::uuid);
reset role;
insert into auth.users(id, raw_app_meta_data) values (current_setting('bloom.coach_child')::uuid,
  jsonb_build_object('bloom_managed_child', true, 'bloom_profile_id', current_setting('bloom.coach_child')));
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('bloom.coach_child'), true);
do $$ begin
  begin
    perform public.bloom_begin_coach_request('17000000-0000-0000-0000-000000000173', 'chat', 'Help');
    raise exception using errcode = 'P0002', message = 'Coaching started without consent';
  exception when raise_exception then if sqlerrm <> 'Coaching consent and eligibility are required' then raise; end if; end;
  begin
    perform public.bloom_set_coach_preferences(true, true, 'Goal', 'beginner', '{}'::text[]);
    raise exception using errcode = 'P0002', message = 'Child claimed adult eligibility';
  exception when raise_exception then if sqlerrm <> 'A parent must manage child eligibility' then raise; end if; end;
  perform public.bloom_set_coach_preferences(true, false, 'Enjoy movement', 'beginner', array['mat']);
  begin
    perform public.bloom_begin_coach_request('17000000-0000-0000-0000-000000000173', 'chat', 'Help');
    raise exception using errcode = 'P0002', message = 'Child used coaching without parent';
  exception when raise_exception then if sqlerrm <> 'Coaching consent and eligibility are required' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000171', true);
do $$ begin
  begin
    perform public.bloom_set_child_coaching(current_setting('bloom.coach_child')::uuid, true, false, true);
    raise exception using errcode = 'P0002', message = 'Ineligible child was enabled';
  exception when raise_exception then if sqlerrm <> 'Parent consent and eligibility are required' then raise; end if; end;
  perform public.bloom_set_child_coaching(current_setting('bloom.coach_child')::uuid, true, true, true);
end $$;
select set_config('request.jwt.claim.sub', current_setting('bloom.coach_child'), true);
select public.bloom_begin_coach_request('17000000-0000-0000-0000-000000000173', 'chat', 'Suggest a workout');
do $$ begin
  begin
    perform public.bloom_clear_coach_conversation();
    raise exception using errcode = 'P0002', message = 'Cleared a running request';
  exception when raise_exception then if sqlerrm <> 'Wait for the coaching request to finish' then raise; end if; end;
end $$;
set local role service_role;
do $$ begin
  begin
    perform public.bloom_finish_coach_request('17000000-0000-0000-0000-000000000173', 'Try this.',
      '{"title":"Unsafe","explanation":"A suggestion","scheduled_days":[1],"exercises":[{"exercise_id":"17000000-0000-0000-0000-000000000171","sets":1,"target":200}]}');
    raise exception using errcode = 'P0002', message = 'Unsafe target was accepted';
  exception when raise_exception then if sqlerrm <> 'Exercise target is outside coaching limits' then raise; end if; end;
  perform public.bloom_finish_coach_request('17000000-0000-0000-0000-000000000173', 'Here is a gentle option.',
    '{"title":"Gentle plan","explanation":"A short routine.","scheduled_days":[1,3],"exercises":[{"exercise_id":"17000000-0000-0000-0000-000000000171","sets":2,"target":10},{"custom":{"name":"Custom move","description":"Easy motion","measurement_type":"time_only"},"sets":1,"target":30}]}');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('bloom.coach_child'), true);
select set_config('bloom.coach_proposal', (select id::text from public.bloom_coach_proposals where request_id = '17000000-0000-0000-0000-000000000173'), true);
do $$ begin
  if exists (select 1 from public.exercises where name = 'Custom move') then raise exception 'Proposed exercise was saved before approval'; end if;
  begin
    perform public.bloom_decide_coach_proposal(current_setting('bloom.coach_proposal')::uuid, true);
    raise exception using errcode = 'P0002', message = 'Child approved own proposal';
  exception when raise_exception then if sqlerrm <> 'Approval is not authorized' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000171', true);
select public.bloom_clear_coach_conversation();
do $$ declare v_plan uuid; begin
  if exists (select 1 from public.bloom_coach_messages where profile_id = current_setting('bloom.coach_child')::uuid)
    or exists (select 1 from public.bloom_coach_settings where profile_id = current_setting('bloom.coach_child')::uuid)
    or exists (select 1 from public.bloom_coach_proposals where profile_id = current_setting('bloom.coach_child')::uuid) then
    raise exception 'Parent can read private coaching conversation or preferences';
  end if;
  if not exists (select 1 from public.bloom_child_coach_proposals(current_setting('bloom.coach_child')::uuid) p
      where p.id = current_setting('bloom.coach_proposal')::uuid and p.proposal->>'explanation' <> 'A short routine.'
        and p.proposal->'exercises'->1->'custom'->>'description' = '') then
    raise exception 'Parent proposal preview exposed private model text or omitted the plan';
  end if;
  v_plan := public.bloom_decide_coach_proposal(current_setting('bloom.coach_proposal')::uuid, true);
  if v_plan is null or v_plan <> public.bloom_decide_coach_proposal(current_setting('bloom.coach_proposal')::uuid, true)
    or not exists (select 1 from public.bloom_workout_plans where id = v_plan and user_id = current_setting('bloom.coach_child')::uuid and source = 'ai_generated')
    or not exists (select 1 from public.exercises where name = 'Custom move' and bloom_owner_user_id = current_setting('bloom.coach_child')::uuid) then
    raise exception 'Parent approval did not save the plan and exercise atomically';
  end if;
  perform set_config('bloom.coach_plan', v_plan::text, true);
end $$;

-- Changes to a plan after a proposal must prevent stale approval.
select set_config('request.jwt.claim.sub', current_setting('bloom.coach_child'), true);
do $$ begin
  if (select count(*) from public.bloom_coach_messages where profile_id = current_setting('bloom.coach_child')::uuid) <> 2 then
    raise exception 'Clearing the parent conversation removed the child conversation';
  end if;
end $$;
select public.bloom_begin_coach_request('17000000-0000-0000-0000-000000000174', 'weekly', 'Review this week');
set local role service_role;
select public.bloom_finish_coach_request('17000000-0000-0000-0000-000000000174', 'Consider a change.',
  jsonb_build_object('title', 'Updated plan', 'explanation', 'A review.', 'plan_id', current_setting('bloom.coach_plan'),
    'scheduled_days', '[2]'::jsonb, 'exercises', '[{"exercise_id":"17000000-0000-0000-0000-000000000171","sets":1,"target":10}]'::jsonb));
set local role authenticated;
update public.bloom_workout_plans set scheduled_days = array[5]::smallint[] where id = current_setting('bloom.coach_plan')::uuid;
select set_config('bloom.coach_stale', (select id::text from public.bloom_coach_proposals where request_id = '17000000-0000-0000-0000-000000000174'), true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000171', true);
do $$ begin
  begin
    perform public.bloom_decide_coach_proposal(current_setting('bloom.coach_stale')::uuid, true);
    raise exception using errcode = 'P0002', message = 'Stale proposal applied';
  exception when raise_exception then if sqlerrm <> 'The plan changed since this proposal was created' then raise; end if; end;
  perform public.bloom_set_child_coaching(current_setting('bloom.coach_child')::uuid, false, false, false);
end $$;
select set_config('request.jwt.claim.sub', current_setting('bloom.coach_child'), true);
do $$ begin
  begin
    perform public.bloom_begin_coach_request('17000000-0000-0000-0000-000000000175', 'chat', 'Help again');
    raise exception using errcode = 'P0002', message = 'Coaching continued after withdrawal';
  exception when raise_exception then if sqlerrm <> 'Coaching consent and eligibility are required' then raise; end if; end;
  if has_function_privilege('authenticated', 'public.bloom_finish_coach_request(uuid,text,jsonb)', 'EXECUTE') then
    raise exception 'Client can forge a coach response';
  end if;
end $$;
select public.bloom_clear_coach_conversation();
do $$ begin
  if exists (select 1 from public.bloom_coach_messages where profile_id = current_setting('bloom.coach_child')::uuid)
    or not exists (select 1 from public.bloom_coach_proposals where id = current_setting('bloom.coach_proposal')::uuid) then
    raise exception 'Clearing the conversation did not preserve proposals or remove messages';
  end if;
end $$;
reset role;
do $$ begin
  if exists (select 1 from bloom_private.coach_requests where profile_id = current_setting('bloom.coach_child')::uuid and prompt <> '[deleted]') then
    raise exception 'Cleared prompts remain in request records';
  end if;
end $$;
rollback;
