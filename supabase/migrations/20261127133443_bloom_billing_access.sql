begin;

-- Keep history and finish/cancel paths available when coverage ends. Only
-- the creation of a new activity or plan crosses this billing boundary.
create function bloom_private.billing_guard_new_activity()
returns trigger language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_time timestamptz := clock_timestamp();
  v_profile uuid;
  v_allowed boolean;
begin
  if not exists (select 1 from bloom_private.billing_config c where c.notice_at <= v_time) then return new; end if;
  if tg_table_name in ('bloom_workout_plans', 'bloom_workout_sessions') then
    v_profile := new.user_id;
  else
    v_profile := new.profile_id;
  end if;
  select b.can_access into v_allowed from bloom_private.billing_usage_balance(v_profile, v_time) b;
  if not v_allowed then
    raise exception using errcode = '42501', message = 'A Bloom subscription is required to start this activity.';
  end if;
  return new;
end
$$;

create trigger bloom_subscription_workout_plan before insert on public.bloom_workout_plans
  for each row execute function bloom_private.billing_guard_new_activity();
create trigger bloom_subscription_workout_session before insert on public.bloom_workout_sessions
  for each row execute function bloom_private.billing_guard_new_activity();
create trigger bloom_subscription_growth_item before insert on public.bloom_growth_items
  for each row execute function bloom_private.billing_guard_new_activity();
create trigger bloom_subscription_growth_session before insert on public.bloom_growth_sessions
  for each row execute function bloom_private.billing_guard_new_activity();
create trigger bloom_subscription_task_focus before insert on public.bloom_task_focus_sessions
  for each row execute function bloom_private.billing_guard_new_activity();

-- Scope the cached draft to the authenticated author and exact task.
create function bloom_private.billing_task_draft(p_request uuid, p_item uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select r.result from bloom_private.growth_ai_requests r
  where r.id = p_request and r.item_id = p_item and r.profile_id = bloom_private.current_profile_id()
    and r.request_kind = 'task_breakdown' and r.status = 'completed'
    and bloom_private.has_module_access(r.profile_id, 'tasks')
$$;
create function public.bloom_load_task_ai_draft(p_request uuid, p_item uuid)
returns jsonb language sql stable security invoker set search_path = pg_catalog, pg_temp
as $$ select bloom_private.billing_task_draft(p_request, p_item) $$;

create function public.bloom_finish_task_ai_draft(p_request uuid, p_result jsonb)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if jsonb_typeof(p_result) <> 'object' or octet_length(p_result::text) > 16000 then
    raise exception 'Invalid task draft';
  end if;
  update bloom_private.growth_ai_requests set status = 'completed', completed_at = clock_timestamp(), result = p_result
    where id = p_request and request_kind = 'task_breakdown' and status = 'pending';
  if not found then raise exception 'AI request is unavailable'; end if;
end
$$;

create function bloom_private.usage_request_status(p_request uuid)
returns text language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select r.status from bloom_private.growth_ai_requests r
    where r.id=p_request and r.profile_id=bloom_private.current_profile_id()
$$;
create function public.bloom_usage_request_status(p_request uuid)
returns text language sql stable security invoker set search_path = pg_catalog, pg_temp
as $$ select bloom_private.usage_request_status(p_request) $$;

create function bloom_private.billing_tutor_answer(p_request uuid,p_item uuid)
returns jsonb language sql stable security definer set search_path = pg_catalog, pg_temp as $$
  select jsonb_build_object('answer',m.content,'answer_scope',m.answer_scope,'uncertainty',m.uncertainty)
  from public.bloom_study_tutor_messages m
  where m.request_id=p_request and m.item_id=p_item and m.profile_id=bloom_private.current_profile_id()
    and m.role='assistant' and bloom_private.has_module_access(m.profile_id,'study')
$$;
create function public.bloom_load_tutor_answer(p_request uuid,p_item uuid)
returns jsonb language sql stable security invoker set search_path = pg_catalog, pg_temp
as $$ select bloom_private.billing_tutor_answer(p_request,p_item) $$;
revoke all on function bloom_private.usage_request_status(uuid),public.bloom_usage_request_status(uuid),
  bloom_private.billing_tutor_answer(uuid,uuid),public.bloom_load_tutor_answer(uuid,uuid) from public,anon,authenticated;
grant execute on function bloom_private.usage_request_status(uuid),public.bloom_usage_request_status(uuid),
  bloom_private.billing_tutor_answer(uuid,uuid),public.bloom_load_tutor_answer(uuid,uuid) to authenticated;

revoke all on function bloom_private.billing_guard_new_activity(),
  bloom_private.billing_task_draft(uuid,uuid), public.bloom_load_task_ai_draft(uuid,uuid),
  public.bloom_finish_task_ai_draft(uuid,jsonb) from public, anon, authenticated;
grant execute on function bloom_private.billing_task_draft(uuid,uuid), public.bloom_load_task_ai_draft(uuid,uuid) to authenticated;
grant execute on function public.bloom_finish_task_ai_draft(uuid,jsonb) to service_role;

commit;
