begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000401');
insert into public.bloom_settings(user_id, credits_enabled)
values ('00000000-0000-0000-0000-000000000401', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
do $$
declare
  v_item uuid;
  v_request uuid := '90000000-0000-0000-0000-000000000401';
  v_context jsonb;
begin
  v_item := public.bloom_create_growth_item('read', 'reading', 'The Secret Garden', 'A note about returning to the garden scene.', null, null,
    '90000000-0000-0000-0000-000000000401');
  perform set_config('bloom.reading_item', v_item::text, true);

  begin
    perform public.bloom_begin_read_reflection_request(v_request, v_item);
    raise exception using errcode = 'P0002', message = 'Reading reflection started without consent';
  exception when raise_exception then
    if sqlerrm <> 'Reading reflection consent and eligibility are required' then raise; end if;
  end;

  perform public.bloom_set_growth_ai_preferences('read', true, true);
  if public.bloom_growth_ai_memory_context('read') <> '[]'::jsonb then
    raise exception 'Read received shared memory before any domain was enabled';
  end if;
  begin
    perform public.bloom_growth_ai_memory_context('exercise');
    raise exception using errcode = 'P0002', message = 'Exercise memory was read without Exercise AI consent';
  exception when raise_exception then if sqlerrm <> 'AI consent and eligibility are required' then raise; end if; end;
  perform public.bloom_set_coach_preferences(true, true, 'Move regularly', 'beginner', array[]::text[]);
  perform public.bloom_save_growth_memory(true, array['read', 'exercise']::text[],
    '{"read":"Prefers short reflection questions.","exercise":"Enjoys walking outdoors."}'::jsonb);
  if not (public.bloom_growth_ai_memory_context('read') @> '[{"domain":"read","summary":"Prefers short reflection questions."}]'::jsonb)
    or not (public.bloom_growth_ai_memory_context('exercise') @> '[{"domain":"exercise","summary":"Enjoys walking outdoors."}]'::jsonb) then
    raise exception 'Read or Exercise did not receive only its consented shared memory';
  end if;
  if not (public.bloom_growth_ai_memory_context('read') @> '[{"domain":"exercise","summary":"Enjoys walking outdoors."}]'::jsonb) then
    raise exception 'Read could not use a separately opted-in Exercise memory domain';
  end if;

  v_context := public.bloom_begin_read_reflection_request(v_request, v_item);
  if v_context->>'status' <> 'pending' or v_context->'reading'->>'title' <> 'The Secret Garden'
    or v_context->'reading'->>'notes' <> 'A note about returning to the garden scene.'
    or exists (select 1 from information_schema.columns where table_schema = 'bloom_private'
      and table_name = 'growth_ai_requests' and column_name in ('reading_title', 'reading_notes', 'prompt_text')) then
    raise exception 'Read reflection context or private request minimization failed';
  end if;
  perform set_config('bloom.read_reflection_request', v_request::text, true);
  if has_function_privilege('authenticated', 'public.bloom_finish_read_reflection_request(uuid,text,text)', 'EXECUTE') then
    raise exception 'Authenticated clients can complete unverified AI prompts';
  end if;
end $$;

reset role;
do $$
begin
  if (select read_reflection_prompt from bloom_private.growth_ai_requests where id = current_setting('bloom.read_reflection_request')::uuid) is not null then
    raise exception 'Reading notes or prompt text were persisted before provider completion';
  end if;
end $$;
set local role service_role;
do $$
begin
  perform public.bloom_finish_read_reflection_request(current_setting('bloom.read_reflection_request')::uuid,
    'What would you like to revisit?', 'This prompt uses your reading title and notes; it is not a reading assessment.');
end $$;

reset role;
set local role authenticated;
do $$
declare
  v_item uuid := current_setting('bloom.reading_item')::uuid;
  v_withdrawn_request uuid := '90000000-0000-0000-0000-000000000402';
  v_replay jsonb;
begin
  v_replay := public.bloom_begin_read_reflection_request(current_setting('bloom.read_reflection_request')::uuid,
    v_item);
  if v_replay->>'status' <> 'completed' or v_replay->'response'->>'prompt' <> 'What would you like to revisit?'
    then raise exception 'Completed Read reflection request did not replay its saved response';
  end if;
  perform public.bloom_begin_read_reflection_request(v_withdrawn_request, v_item);
  perform set_config('bloom.read_reflection_withdrawn_request', v_withdrawn_request::text, true);
end $$;

select public.bloom_set_growth_ai_preferences('read', false, false);
reset role;
set local role service_role;
do $$
begin
  begin
    perform public.bloom_finish_read_reflection_request(current_setting('bloom.read_reflection_withdrawn_request')::uuid,
      'What would you like to revisit?', 'This prompt uses your reading title and notes; it is not a reading assessment.');
    raise exception using errcode = 'P0002', message = 'Prompt was saved after consent was withdrawn';
  exception when raise_exception then if sqlerrm <> 'Reading reflection consent was withdrawn' then raise; end if; end;
  perform public.bloom_fail_growth_ai_request(current_setting('bloom.read_reflection_withdrawn_request')::uuid);
end $$;

reset role;
do $$
begin
  if (select read_reflection_prompt from bloom_private.growth_ai_requests where id = current_setting('bloom.read_reflection_withdrawn_request')::uuid) is not null then
    raise exception 'A prompt was saved after consent was withdrawn';
  end if;
end $$;
rollback;
