begin;

insert into auth.users(id) values
  ('ac000000-0000-4000-8000-000000000005'),
  ('ac000000-0000-4000-8000-000000000006');
update public.bloom_profiles set created_at=now()-interval '60 days'
  where id='ac000000-0000-4000-8000-000000000005';

-- Exercise the shortest permitted notice, including profiles created either
-- side of the notice boundary.
update bloom_private.billing_config set
  notice_at=now()-interval '7 days',
  enforcement_at=now()+interval '23 days',
  transition_weekly_credits=2;
do $$
begin
  begin
    update bloom_private.billing_config set enforcement_at=notice_at+interval '719 hours';
    raise exception 'A rollout without a full 30 days of notice was accepted';
  exception when check_violation then null;
  end;
end
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','ac000000-0000-4000-8000-000000000006',true);
do $$
declare summary jsonb := public.bloom_billing_summary();
begin
  if summary->>'can_access' is distinct from 'false' or summary->>'allowance' is distinct from '0' then
    raise exception 'A new account received transition access';
  end if;
  begin
    perform public.bloom_create_growth_item('study','subject','New profile subject','',null,30,gen_random_uuid());
    raise exception 'A new account started a paid activity before purchase';
  exception when insufficient_privilege then
    if sqlerrm <> 'A Bloom subscription is required to start this activity.' then raise; end if;
  end;
end
$$;

select set_config('request.jwt.claim.sub','ac000000-0000-4000-8000-000000000005',true);
do $$
declare
  summary jsonb := public.bloom_billing_summary();
  subject_id uuid;
  session_id uuid;
begin
  if summary->>'can_access' is distinct from 'true' or summary->>'remaining' is distinct from '2'
    or (summary->>'enforcement_at')::timestamptz is distinct from now()+interval '23 days' then
    raise exception 'Existing profile did not get the advertised transition access';
  end if;
  subject_id := public.bloom_create_growth_item('study','subject','Transition subject','',null,30,gen_random_uuid());
  insert into public.bloom_settings(user_id,credit_timezone)
    values (bloom_private.current_profile_id(),'UTC');
  perform public.bloom_save_growth_reward_rules(bloom_private.current_profile_id(),'study',true,5,10,20,0,false);
  session_id := public.bloom_start_growth_session('study',subject_id,gen_random_uuid(),'Fixture device',gen_random_uuid());
  perform set_config('bloom.rollout_subject',subject_id::text,true);
  perform set_config('bloom.rollout_session',session_id::text,true);
end
$$;

reset role;
update bloom_private.billing_config set notice_at=now()-interval '720 hours',enforcement_at=now();

set local role authenticated;
do $$
declare
  subject_id uuid := current_setting('bloom.rollout_subject')::uuid;
  session_id uuid := current_setting('bloom.rollout_session')::uuid;
  summary jsonb := public.bloom_billing_summary();
begin
  if summary->>'can_access' is distinct from 'false' or summary->>'remaining' is distinct from '0' then
    raise exception 'Transition credits survived the enforcement boundary';
  end if;
  if not exists(select 1 from public.bloom_growth_items where id=subject_id and title='Transition subject') then
    raise exception 'An expired profile lost access to its activity record';
  end if;
  perform public.bloom_finish_growth_session(session_id);
  perform public.bloom_finish_growth_session(session_id);
  if not exists(select 1 from public.bloom_growth_sessions where id=session_id and status='completed')
    or public.bloom_credit_balance() is distinct from 5::numeric then
    raise exception 'Expiry stopped an in-progress session from completing or earning screen-time minutes';
  end if;
  begin
    perform public.bloom_start_growth_session('study',subject_id,gen_random_uuid(),'Fixture device',gen_random_uuid());
    raise exception 'An expired profile started a new activity';
  exception when insufficient_privilege then
    if sqlerrm <> 'A Bloom subscription is required to start this activity.' then raise; end if;
  end;
  insert into public.bloom_website_rules(user_id,domain,scope)
    values (bloom_private.current_profile_id(),'rollout-safety.example','always');
  if not exists(select 1 from public.bloom_website_rules where domain='rollout-safety.example') then
    raise exception 'Expiry blocked safety settings';
  end if;
end
$$;

rollback;
