begin;

create table bloom_private.parent_credit_adjustments (
  parent_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  child_id uuid not null references auth.users(id) on delete cascade,
  amount_minutes numeric(16, 4) not null,
  reason text not null,
  created_at timestamptz not null default now(),
  primary key (parent_id, request_id)
);
revoke all on bloom_private.parent_credit_adjustments from public, anon, authenticated;

create function bloom_private.parent_child_balance(p_child_id uuid)
returns numeric language plpgsql stable security definer set search_path = pg_catalog, pg_temp as $$
declare v_balance numeric;
begin
  if auth.uid() is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  select coalesce((select sum(l.amount_minutes) from public.bloom_credit_ledger l
      where l.user_id = p_child_id and l.expires_at > now()), 0)
    - coalesce((select sum(round(greatest(0, extract(epoch from (least(now(), s.ends_at) - s.started_at))) / 60, 4))
      from public.bloom_credit_sessions s where s.user_id = p_child_id and s.settled_at is null and s.expires_at > now()), 0)
    into v_balance;
  return v_balance;
end;
$$;

create function bloom_private.parent_adjust_credit(p_child_id uuid, p_request_id uuid, p_minutes numeric, p_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
declare
  v_parent uuid := auth.uid();
  v_settings public.bloom_settings%rowtype;
  v_existing bloom_private.parent_credit_adjustments%rowtype;
  v_session public.bloom_credit_sessions%rowtype;
  v_now timestamptz;
  v_balance numeric;
  v_remaining numeric;
  v_amount numeric;
  v_bucket record;
  v_part integer := 0;
  v_rows integer;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if v_parent is null or not bloom_private.is_parent_of(p_child_id) then raise exception 'Parent access required'; end if;
  perform 1 from public.bloom_household_members p
    join public.bloom_household_members c on c.household_id = p.household_id
    where p.user_id = v_parent and p.role = 'parent' and c.user_id = p_child_id and c.role = 'child'
    for share of p, c;
  if not found then raise exception 'Parent access required'; end if;
  if p_request_id is null or p_minutes is null or p_minutes = 0 or abs(p_minutes) > 10080
    or round(p_minutes, 4) <> p_minutes or char_length(v_reason) > 200 then
    raise exception 'Enter a valid credit adjustment';
  end if;
  select * into v_settings from public.bloom_settings where user_id = p_child_id for update;
  if not found then raise exception 'Child screen-time settings not found'; end if;
  v_now := clock_timestamp();
  insert into bloom_private.parent_credit_adjustments(parent_id, request_id, child_id, amount_minutes, reason)
    values (v_parent, p_request_id, p_child_id, p_minutes, v_reason) on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    select * into v_existing from bloom_private.parent_credit_adjustments where parent_id = v_parent and request_id = p_request_id;
    if v_existing.child_id <> p_child_id or v_existing.amount_minutes <> p_minutes or v_existing.reason <> v_reason then
      raise exception 'Adjustment request was already used';
    end if;
    return;
  end if;

  select * into v_session from public.bloom_credit_sessions where user_id = p_child_id and settled_at is null for update;
  if found then
    if v_session.ends_at > v_now then raise exception 'Stop the child’s active screen-time session first'; end if;
    perform bloom_private.settle_credit_session(p_child_id, v_session.id, v_now);
  end if;

  if p_minutes > 0 then
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
      values (p_child_id, p_minutes, 'adjustment', 'parent:' || p_request_id::text || ':0',
        bloom_private.credit_week_end(v_now, v_settings.credit_timezone));
    return;
  end if;

  select coalesce(sum(amount_minutes), 0) into v_balance from public.bloom_credit_ledger
    where user_id = p_child_id and expires_at > v_now;
  if v_balance < -p_minutes then raise exception 'Adjustment exceeds the child’s balance'; end if;
  v_remaining := -p_minutes;
  for v_bucket in select l.expires_at, sum(l.amount_minutes) as available
    from public.bloom_credit_ledger l where l.user_id = p_child_id and l.expires_at > v_now
    group by l.expires_at having sum(l.amount_minutes) > 0 order by l.expires_at loop
    exit when v_remaining <= 0;
    v_amount := least(v_bucket.available, v_remaining);
    v_part := v_part + 1;
    insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at)
      values (p_child_id, -v_amount, 'adjustment', 'parent:' || p_request_id::text || ':' || v_part, v_bucket.expires_at);
    v_remaining := v_remaining - v_amount;
  end loop;
  if v_remaining > 0 then raise exception 'Could not allocate the credit adjustment'; end if;
end;
$$;

revoke all on function bloom_private.parent_child_balance(uuid), bloom_private.parent_adjust_credit(uuid, uuid, numeric, text) from public, anon;
grant execute on function bloom_private.parent_child_balance(uuid), bloom_private.parent_adjust_credit(uuid, uuid, numeric, text) to authenticated;
create function public.bloom_parent_child_balance(p_child_id uuid) returns numeric language sql stable security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.parent_child_balance(p_child_id); $$;
create function public.bloom_parent_adjust_credit(p_child_id uuid, p_request_id uuid, p_minutes numeric, p_reason text)
returns void language sql security invoker set search_path = pg_catalog, pg_temp
  as $$ select bloom_private.parent_adjust_credit(p_child_id, p_request_id, p_minutes, p_reason); $$;
revoke all on function public.bloom_parent_child_balance(uuid), public.bloom_parent_adjust_credit(uuid, uuid, numeric, text) from public, anon;
grant execute on function public.bloom_parent_child_balance(uuid), public.bloom_parent_adjust_credit(uuid, uuid, numeric, text) to authenticated;

commit;
