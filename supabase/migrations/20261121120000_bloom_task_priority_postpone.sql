begin;

alter table public.bloom_growth_items
  add column priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high', 'urgent')),
  add column postponed_until date;

alter table public.bloom_growth_items
  add constraint bloom_task_metadata_scope_valid check (
    module_id = 'tasks' or (priority = 'medium' and postponed_until is null)
  );

create index bloom_growth_tasks_postponed_idx
  on public.bloom_growth_items(profile_id, postponed_until, due_date)
  where module_id = 'tasks' and state = 'active';

create function bloom_private.update_task_metadata(p_item_id uuid, p_priority text, p_postponed_until date)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype;
begin
  if v_profile is null then raise exception 'Sign in to update this task'; end if;
  select * into v_item from public.bloom_growth_items i
    where i.id = p_item_id and i.profile_id = v_profile for update;
  if not found or v_item.module_id <> 'tasks' or v_item.item_type not in ('task', 'checklist')
    or not bloom_private.has_module_access(v_profile, 'tasks') then
    raise exception 'Task not found or module access is not assigned' using errcode = '42501';
  end if;
  if p_priority not in ('low', 'medium', 'high', 'urgent') then raise exception 'Choose a valid priority'; end if;
  if v_item.state <> 'active' and p_postponed_until is not null then raise exception 'Only an open task can be postponed'; end if;
  if p_postponed_until is not null and p_postponed_until <= current_date then raise exception 'Choose a future date to postpone this task'; end if;
  update public.bloom_growth_items set priority = p_priority, postponed_until = p_postponed_until,
    updated_at = clock_timestamp() where id = p_item_id;
end;
$$;

revoke all on function bloom_private.update_task_metadata(uuid, text, date) from public, anon, authenticated;
grant execute on function bloom_private.update_task_metadata(uuid, text, date) to authenticated;

create function public.bloom_update_task_metadata(p_item_id uuid, p_priority text, p_postponed_until date)
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_task_metadata(p_item_id, p_priority, p_postponed_until);
$$;
revoke all on function public.bloom_update_task_metadata(uuid, text, date) from public, anon;
grant execute on function public.bloom_update_task_metadata(uuid, text, date) to authenticated;

commit;
