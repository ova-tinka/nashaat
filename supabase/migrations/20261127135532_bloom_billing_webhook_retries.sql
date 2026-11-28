begin;

-- Retain only the verified lookup reference needed for a fresh provider read.
-- Do not retain webhook bodies, authorization headers or payment credentials.
alter table public.bloom_billing_events
  add column webhook_reference text,
  add column webhook_attempts integer not null default 0 check (webhook_attempts >= 0),
  add column webhook_retry_at timestamptz;
create index bloom_billing_webhooks_due
  on public.bloom_billing_events (webhook_retry_at, received_at, id)
  where processed_at is null and webhook_reference is not null;

create function public.bloom_queue_billing_webhook(
  p_provider text, p_event_id text, p_event_type text, p_reference text)
returns void language plpgsql security definer set search_path = pg_catalog, pg_temp as $$
begin
  if p_provider is null or p_provider not in ('revenuecat','tap')
    or p_event_id is null or length(p_event_id) not between 1 and 220
    or p_event_type is null or p_event_type !~ '^[A-Za-z0-9_]{1,64}$'
    or p_reference is null then
    raise exception 'Invalid provider callback';
  end if;
  if p_provider = 'revenuecat' then
    if p_reference !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'Invalid customer reference';
    end if;
    if not exists (select 1 from public.bloom_profiles p where p.id=p_reference::uuid) then return; end if;
  elsif p_reference !~* '^(chg|re|auth)_[a-z0-9]{1,120}$' then
    raise exception 'Invalid payment reference';
  end if;
  insert into public.bloom_billing_events(provider,provider_event_id,event_type,webhook_reference,webhook_retry_at)
  values(p_provider,p_event_id,p_event_type,p_reference,clock_timestamp())
  on conflict (provider,provider_event_id) do nothing;
end
$$;

create function public.bloom_claim_billing_webhooks()
returns table(id uuid,provider text,provider_event_id text,event_type text,webhook_reference text)
language sql security definer set search_path = pg_catalog, pg_temp as $$
  with due as (
    select e.id
    from public.bloom_billing_events e
    where e.processed_at is null and e.webhook_reference is not null and e.webhook_retry_at<=clock_timestamp()
    order by e.webhook_retry_at,e.received_at,e.id
    limit 10
    for update skip locked
  )
  update public.bloom_billing_events e
  set webhook_attempts=e.webhook_attempts+1,
    webhook_retry_at=clock_timestamp()+make_interval(secs=>least(3600,60*(1 << least(e.webhook_attempts,6))))
  from due where e.id=due.id
  returning e.id,e.provider,e.provider_event_id,e.event_type,e.webhook_reference
$$;

create function public.bloom_finish_billing_webhook(p_id uuid)
returns void language sql security definer set search_path = pg_catalog, pg_temp as $$
  update public.bloom_billing_events e set processed_at=clock_timestamp()
  where e.id=p_id and e.webhook_reference is not null and e.processed_at is null
$$;

revoke all on function public.bloom_queue_billing_webhook(text,text,text,text),
  public.bloom_claim_billing_webhooks(), public.bloom_finish_billing_webhook(uuid) from public,anon,authenticated;
grant execute on function public.bloom_queue_billing_webhook(text,text,text,text),
  public.bloom_claim_billing_webhooks(), public.bloom_finish_billing_webhook(uuid) to service_role;

commit;
