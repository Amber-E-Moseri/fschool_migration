-- Cron: daily attendance reminder sweep (09:00 UTC)
-- BEFORE RUNNING: replace <SERVICE_ROLE_KEY> with your project service role key.

select cron.unschedule('attendance-reminder-daily')
where exists (
  select 1
  from cron.job
  where jobname = 'attendance-reminder-daily'
);

select cron.schedule(
  'attendance-reminder-daily',
  '0 9 * * *',
  $$
    select net.http_post(
      url     := 'https://xelpsttqhrcqmttmjory.supabase.co/functions/v1/attendance-reminder',
      headers := '{"Content-Type":"application/json","Authorization":"Bearer <SERVICE_ROLE_KEY>"}'::jsonb,
      body    := '{}'::jsonb
    )
  $$
);

