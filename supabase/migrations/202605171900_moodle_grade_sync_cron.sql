-- Moodle grade sync — runs every 6 hours to check course completion and upsert HOLY_SPIRIT milestone.
-- BEFORE RUNNING: replace <SERVICE_ROLE_KEY> with your actual service role key from
-- Project Settings → API → service_role. Apply this migration manually via the Supabase SQL
-- editor. Do NOT commit the key to version control.

select cron.schedule(
  'moodle-grade-sync',
  '0 */6 * * *',
  $$
    select net.http_post(
      url     := 'https://xelpsttqhrcqmttmjory.supabase.co/functions/v1/moodle-grade-sync',
      headers := '{"Content-Type":"application/json","Authorization":"Bearer <SERVICE_ROLE_KEY>"}'::jsonb,
      body    := '{}'::jsonb
    )
  $$
);
