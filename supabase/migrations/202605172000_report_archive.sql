create table if not exists public.report_archive (
  id             uuid        primary key default gen_random_uuid(),
  report_type    text        not null check (report_type in ('weekly','monthly','custom','pastor_digest')),
  scope          text        not null check (scope in ('regional','group','subgroup')),
  scope_value    text,
  date_from      date        not null,
  date_to        date        not null,
  batch_id       text        references public.batches(batch_id),
  generated_by   text,
  recipient_count int        not null default 0,
  body_html      text        not null,
  created_at     timestamptz not null default now()
);

alter table public.report_archive enable row level security;

create policy "admins can read report archive"
  on public.report_archive for select
  to authenticated
  using (
    (select role from public.profiles where user_id = auth.uid() limit 1)
      in ('superadmin','admin','pastor')
  );

create index if not exists idx_report_archive_type
  on public.report_archive (report_type, created_at desc);

create index if not exists idx_report_archive_scope
  on public.report_archive (scope_value, created_at desc);
