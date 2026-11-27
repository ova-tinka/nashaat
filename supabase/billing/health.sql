-- Aggregate counts for the project operator. The output has no payer or payment identifiers.
select
  (select count(*) from public.bloom_subscriptions where billing_provider='tap' and status='grace_period') as tap_renewals_needing_attention,
  (select count(*) from bloom_private.tap_attempts where state='review'
    or (state in ('ready','pending') and created_at<now()-interval '20 minutes')) as overdue_or_uncertain_charges,
  (select count(*) from bloom_private.tap_refunds where state='review'
    or (state in ('approved','pending') and next_check_at<now()-interval '10 minutes')) as overdue_or_uncertain_refunds,
  (select count(*) from public.bloom_billing_events where processed_at is null) as unprocessed_events,
  (select count(*) from bloom_private.billing_alerts where kind='overlapping_subscriptions') as overlapping_subscriptions,
  (select count(*) from bloom_private.billing_alerts where kind='unmapped_mobile_product') as unmapped_products;
