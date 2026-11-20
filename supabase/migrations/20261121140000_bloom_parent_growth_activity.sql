begin;

create function bloom_private.parent_child_growth_activity(p_child_id uuid)
returns table (
  id uuid,
  module_id text,
  activity_type text,
  title text,
  occurred_at timestamptz,
  duration_seconds integer,
  progress_percent numeric,
  current_page integer,
  page_count integer
) language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
begin
  if bloom_private.current_profile_id() is null
    or not bloom_private.is_parent_of(p_child_id)
    or not bloom_private.is_child_profile(p_child_id) then
    raise exception 'Parent access required' using errcode = '42501';
  end if;

  return query
    select activity.id, activity.module_id, activity.activity_type, activity.title, activity.occurred_at,
      activity.duration_seconds, activity.progress_percent, activity.current_page, activity.page_count
    from (
      select s.id, s.module_id, 'study_session'::text as activity_type, i.title, s.completed_at as occurred_at,
        s.duration_seconds, null::numeric as progress_percent, null::integer as current_page, null::integer as page_count
      from public.bloom_growth_sessions s
      join public.bloom_growth_items i on i.id = s.item_id and i.profile_id = s.profile_id
      where s.profile_id = p_child_id and s.module_id = 'study' and s.status = 'completed'
        and bloom_private.has_module_access(p_child_id, 'study')
      union all
      select i.id, i.module_id, 'reading_progress'::text as activity_type, i.title, i.updated_at as occurred_at,
        null::integer as duration_seconds, i.progress_percent, i.current_page, i.page_count
      from public.bloom_growth_items i
      where i.profile_id = p_child_id and i.module_id = 'read' and i.item_type = 'reading'
        and i.state <> 'archived' and bloom_private.has_module_access(p_child_id, 'read')
    ) as activity
    order by activity.occurred_at desc
    limit 50;
end;
$$;

revoke all on function bloom_private.parent_child_growth_activity(uuid) from public, anon, authenticated;
grant execute on function bloom_private.parent_child_growth_activity(uuid) to authenticated;

create function public.bloom_parent_child_growth_activity(p_child_id uuid)
returns table (
  id uuid,
  module_id text,
  activity_type text,
  title text,
  occurred_at timestamptz,
  duration_seconds integer,
  progress_percent numeric,
  current_page integer,
  page_count integer
) language sql stable security invoker set search_path = pg_catalog, pg_temp as $$
  select * from bloom_private.parent_child_growth_activity(p_child_id);
$$;

revoke all on function public.bloom_parent_child_growth_activity(uuid) from public, anon;
grant execute on function public.bloom_parent_child_growth_activity(uuid) to authenticated;

commit;
