begin;

-- Keep request rows for rate limits and replay protection, but remove their
-- original prompts along with the visible messages.
create function bloom_private.clear_coach_conversation()
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare v_profile uuid := bloom_private.current_profile_id();
begin
  if v_profile is null then raise exception 'Sign in to manage coaching'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bloom-coach:' || v_profile::text, 0));
  update bloom_private.coach_requests set status = 'failed'
    where profile_id = v_profile and status = 'pending' and created_at <= clock_timestamp() - interval '2 minutes';
  if exists (select 1 from bloom_private.coach_requests where profile_id = v_profile and status = 'pending') then
    raise exception 'Wait for the coaching request to finish';
  end if;
  delete from public.bloom_coach_messages where profile_id = v_profile;
  update bloom_private.coach_requests set prompt = '[deleted]' where profile_id = v_profile;
end;
$$;
create function public.bloom_clear_coach_conversation()
returns void language sql security invoker set search_path = pg_catalog, pg_temp as $$
  select bloom_private.clear_coach_conversation();
$$;
revoke all on function bloom_private.clear_coach_conversation(), public.bloom_clear_coach_conversation() from public, anon;
grant execute on function bloom_private.clear_coach_conversation(), public.bloom_clear_coach_conversation() to authenticated;

commit;
