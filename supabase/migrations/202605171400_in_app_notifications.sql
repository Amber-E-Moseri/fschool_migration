create table if not exists public.in_app_notifications (
  id                uuid        primary key default gen_random_uuid(),
  recipient_role    text,
  recipient_user_id uuid        references auth.users(id) on delete cascade,
  title             text        not null,
  body              text        not null,
  type              text        not null check (type in ('info','success','warning','error')),
  action_url        text,
  read              boolean     not null default false,
  created_at        timestamptz not null default now()
);

alter table public.in_app_notifications enable row level security;

create policy "users can read own notifications"
  on public.in_app_notifications for select
  to authenticated
  using (
    recipient_user_id = auth.uid()
    or (
      recipient_user_id is null
      and recipient_role = (
        select role from public.profiles where user_id = auth.uid() limit 1
      )
    )
  );

create policy "authenticated users can insert notifications"
  on public.in_app_notifications for insert
  to authenticated
  with check (true);

create policy "users can mark own notifications read"
  on public.in_app_notifications for update
  to authenticated
  using (
    recipient_user_id = auth.uid()
    or (
      recipient_user_id is null
      and recipient_role = (
        select role from public.profiles where user_id = auth.uid() limit 1
      )
    )
  )
  with check (read = true);

create index if not exists idx_in_app_notifs_user
  on public.in_app_notifications (recipient_user_id, read, created_at desc);

create index if not exists idx_in_app_notifs_role
  on public.in_app_notifications (recipient_role, read, created_at desc);
