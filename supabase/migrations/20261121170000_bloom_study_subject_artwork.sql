begin;

alter table public.bloom_growth_items
  add column artwork_id text,
  add constraint bloom_growth_items_study_artwork_valid check (
    (module_id = 'study' and item_type = 'subject' and (artwork_id is null or artwork_id = any(array[
      'biology', 'geology', 'chemistry', 'physics', 'mathematics', 'computer-science', 'history',
      'geography', 'literature', 'psychology', 'medicine', 'astronomy', 'economics', 'art', 'music',
      'engineering', 'environmental-science', 'political-science', 'linguistics', 'sociology',
      'philosophy', 'statistics', 'anatomy', 'design', 'agriculture'
    ]::text[])))
    or ((module_id <> 'study' or item_type <> 'subject') and artwork_id is null)
  );

comment on column public.bloom_growth_items.artwork_id is
  'Shared Study subject artwork identifier, synchronized with the profile across devices.';

create function bloom_private.set_study_subject_artwork(p_item_id uuid, p_artwork_id text, p_only_if_unset boolean)
returns text language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_profile uuid := bloom_private.current_profile_id();
  v_artwork text;
begin
  if v_profile is null or not bloom_private.has_module_access(v_profile, 'study') then
    raise exception 'Study access is required' using errcode = '42501';
  end if;
  if p_artwork_id is null or p_artwork_id <> all(array[
    'biology', 'geology', 'chemistry', 'physics', 'mathematics', 'computer-science', 'history',
    'geography', 'literature', 'psychology', 'medicine', 'astronomy', 'economics', 'art', 'music',
    'engineering', 'environmental-science', 'political-science', 'linguistics', 'sociology',
    'philosophy', 'statistics', 'anatomy', 'design', 'agriculture'
  ]::text[]) then
    raise exception 'Choose a valid Study subject artwork' using errcode = '22023';
  end if;
  if p_only_if_unset is null then raise exception 'Artwork update mode is required' using errcode = '22023'; end if;

  if p_only_if_unset then
    select artwork_id into v_artwork from public.bloom_growth_items
      where id = p_item_id and profile_id = v_profile and module_id = 'study' and item_type = 'subject'
      for update;
    if not found then raise exception 'Study subject not found' using errcode = '42501'; end if;
    if v_artwork is not null then return v_artwork; end if;
  end if;

  update public.bloom_growth_items
    set artwork_id = p_artwork_id, updated_at = clock_timestamp()
    where id = p_item_id and profile_id = v_profile and module_id = 'study' and item_type = 'subject'
    returning artwork_id into v_artwork;
  if not found then raise exception 'Study subject not found' using errcode = '42501'; end if;
  return v_artwork;
end;
$$;

create function public.bloom_set_study_subject_artwork(p_item_id uuid, p_artwork_id text, p_only_if_unset boolean default false)
returns text language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.set_study_subject_artwork(p_item_id, p_artwork_id, p_only_if_unset);
$$;

revoke all on function bloom_private.set_study_subject_artwork(uuid, text, boolean) from public, anon, authenticated;
grant execute on function bloom_private.set_study_subject_artwork(uuid, text, boolean) to authenticated;
revoke all on function public.bloom_set_study_subject_artwork(uuid, text, boolean) from public, anon;
grant execute on function public.bloom_set_study_subject_artwork(uuid, text, boolean) to authenticated;

commit;
