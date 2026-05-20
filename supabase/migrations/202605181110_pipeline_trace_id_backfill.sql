begin;

alter table public.scheduled_notifications
  add column if not exists trace_id uuid;
create index if not exists idx_scheduled_notifications_trace_id
  on public.scheduled_notifications(trace_id);

alter table public.email_queue
  add column if not exists trace_id uuid;
create index if not exists idx_email_queue_trace_id
  on public.email_queue(trace_id);

alter table public.moodle_enrollment_sync
  add column if not exists trace_id uuid;
create index if not exists idx_moodle_enrollment_sync_trace_id
  on public.moodle_enrollment_sync(trace_id);

commit;

