begin;

alter table public.bloom_growth_items add column reading_kind text;
update public.bloom_growth_items set reading_kind = 'book' where module_id = 'read';
alter table public.bloom_growth_items add constraint bloom_reading_kind_scope_valid check (
  reading_kind is null or (module_id = 'read' and reading_kind in ('book', 'article'))
);

create function bloom_private.update_reading_details_v2(
  p_item_id uuid, p_author text, p_genre text, p_page_count integer, p_current_page integer,
  p_reading_status text, p_reading_kind text
) returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id(); v_kind text;
begin
  if v_profile is null then raise exception 'Sign in to update this reading item'; end if;
  if p_reading_kind is not null and p_reading_kind not in ('book', 'article') then
    raise exception 'Choose Book or Article';
  end if;
  perform bloom_private.update_reading_details(p_item_id, p_author, p_genre, p_page_count, p_current_page, p_reading_status);
  select reading_kind into v_kind from public.bloom_growth_items
    where id = p_item_id and profile_id = v_profile and module_id = 'read' for update;
  update public.bloom_growth_items set reading_kind = coalesce(p_reading_kind, v_kind, 'book')
    where id = p_item_id and profile_id = v_profile and module_id = 'read';
end;
$$;
revoke all on function bloom_private.update_reading_details_v2(uuid, text, text, integer, integer, text, text)
  from public, anon, authenticated;
grant execute on function bloom_private.update_reading_details_v2(uuid, text, text, integer, integer, text, text)
  to authenticated;

create function public.bloom_update_reading_details_v2(
  p_item_id uuid, p_author text, p_genre text, p_page_count integer, p_current_page integer,
  p_reading_status text, p_reading_kind text default null
) returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.update_reading_details_v2(p_item_id, p_author, p_genre, p_page_count, p_current_page,
    p_reading_status, p_reading_kind);
$$;
revoke all on function public.bloom_update_reading_details_v2(uuid, text, text, integer, integer, text, text)
  from public, anon;
grant execute on function public.bloom_update_reading_details_v2(uuid, text, text, integer, integer, text, text)
  to authenticated;

commit;
