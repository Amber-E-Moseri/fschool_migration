begin;

create table if not exists public.clickup_admin_watchers (
  id uuid primary key default gen_random_uuid(),
  group_id text not null,
  subgroup_id text null,
  clickup_user_id text not null,
  watcher_name text null,
  watcher_email text null,
  active boolean not null default true,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_clickup_admin_watchers_group on public.clickup_admin_watchers(group_id);
create index if not exists idx_clickup_admin_watchers_subgroup on public.clickup_admin_watchers(subgroup_id) where subgroup_id is not null;
create index if not exists idx_clickup_admin_watchers_active on public.clickup_admin_watchers(active);

alter table public.clickup_admin_watchers enable row level security;

drop policy if exists clickup_admin_watchers_admin_select on public.clickup_admin_watchers;
create policy clickup_admin_watchers_admin_select
on public.clickup_admin_watchers
for select
to authenticated
using (public.is_admin());

drop policy if exists clickup_admin_watchers_admin_insert on public.clickup_admin_watchers;
create policy clickup_admin_watchers_admin_insert
on public.clickup_admin_watchers
for insert
to authenticated
with check (public.is_admin());

drop policy if exists clickup_admin_watchers_admin_update on public.clickup_admin_watchers;
create policy clickup_admin_watchers_admin_update
on public.clickup_admin_watchers
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into public.clickup_admin_watchers (
  group_id,
  subgroup_id,
  clickup_user_id,
  watcher_name,
  watcher_email,
  active,
  notes
)
values (
  'CS',
  'CSGA',
  '93663664',
  'Jason Chan',
  'jc032751@gmail.com',
  true,
  'CSGA watcher / secondary admin'
)
on conflict do nothing;

-- Keep updated_at synced when helper trigger exists.
do $$
begin
  if exists (select 1 from pg_proc where proname = 'trigger_set_updated_at') then
    if not exists (
      select 1 from pg_trigger where tgname = 'trg_clickup_admin_watchers_updated_at'
    ) then
      create trigger trg_clickup_admin_watchers_updated_at
      before update on public.clickup_admin_watchers
      for each row execute function trigger_set_updated_at();
    end if;
  end if;
end $$;

commit;
