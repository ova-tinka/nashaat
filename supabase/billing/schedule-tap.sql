-- Provision both named Vault entries before running this operational script.
-- The URL ends in /functions/v1/bloom-tap/worker.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule('bloom-tap-billing','* * * * *', $worker$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='bloom_billing_worker_url'),
    headers := jsonb_build_object(
      'Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='bloom_billing_worker_token'),
      'Content-Type','application/json'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 45000
  );
$worker$);
