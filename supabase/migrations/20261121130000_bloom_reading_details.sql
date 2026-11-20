begin;

alter table public.bloom_growth_items
  add column reading_status text check (reading_status is null or reading_status in ('want_to_read', 'currently_reading', 'finished')),
  add column author text not null default '' check (char_length(author) <= 160),
  add column genre text not null default '' check (char_length(genre) <= 80),
  add column page_count integer check (page_count is null or page_count between 1 and 100000),
  add column current_page integer check (current_page is null or current_page between 0 and 100000),
  add constraint bloom_reading_details_scope_valid check (
    module_id = 'read' or (reading_status is null and author = '' and genre = '' and page_count is null and current_page is null)
  ),
  add constraint bloom_reading_page_count_valid check (
    page_count is null or (current_page is not null and current_page <= page_count)
  );

create function bloom_private.update_reading_details(
  p_item_id uuid, p_author text, p_genre text, p_page_count integer, p_current_page integer, p_reading_status text
) returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_item public.bloom_growth_items%rowtype; v_progress numeric(5,2);
begin
  if v_profile is null then raise exception 'Sign in to update this reading item'; end if;
  select * into v_item from public.bloom_growth_items i where i.id = p_item_id and i.profile_id = v_profile for update;
  if not found or v_item.module_id <> 'read' or v_item.item_type <> 'reading'
    or not bloom_private.has_module_access(v_profile, 'read') then
    raise exception 'Reading item not found or module access is not assigned' using errcode = '42501';
  end if;
  if p_author is null or char_length(p_author) > 160 or p_genre is null or char_length(p_genre) > 80
    or p_reading_status not in ('want_to_read', 'currently_reading', 'finished') then
    raise exception 'Check the reading details';
  end if;
  if p_page_count is not null and p_page_count not between 1 and 100000 then raise exception 'Choose a valid page count'; end if;
  if p_current_page is not null and p_current_page not between 0 and 100000 then raise exception 'Choose a valid current page'; end if;
  if p_page_count is null and p_current_page is not null or p_page_count is not null and (p_current_page is null or p_current_page > p_page_count) then
    raise exception 'Current page must be within the total page count';
  end if;
  v_progress := case when p_reading_status = 'finished' then 100
    when p_page_count is not null then round((p_current_page::numeric / p_page_count) * 100, 2)
    else v_item.progress_percent end;
  update public.bloom_growth_items set author = trim(p_author), genre = trim(p_genre), page_count = p_page_count,
    current_page = p_current_page, reading_status = p_reading_status,
    progress_percent = v_progress,
    state = case when p_reading_status = 'finished' then 'completed' else 'active' end,
    completed_at = case when p_reading_status = 'finished' then coalesce(v_item.completed_at, clock_timestamp()) else null end,
    updated_at = clock_timestamp()
    where id = p_item_id;
end;
$$;

revoke all on function bloom_private.update_reading_details(uuid, text, text, integer, integer, text) from public, anon, authenticated;
grant execute on function bloom_private.update_reading_details(uuid, text, text, integer, integer, text) to authenticated;

create function public.bloom_update_reading_details(
  p_item_id uuid, p_author text, p_genre text, p_page_count integer, p_current_page integer, p_reading_status text
) returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_reading_details(p_item_id, p_author, p_genre, p_page_count, p_current_page, p_reading_status);
$$;
revoke all on function public.bloom_update_reading_details(uuid, text, text, integer, integer, text) from public, anon;
grant execute on function public.bloom_update_reading_details(uuid, text, text, integer, integer, text) to authenticated;

commit;
