-- Ensure fellowship_map supports Fellowship Management page requirements.

create table if not exists public.fellowship_map (
  fellowship_code text primary key
);

alter table public.fellowship_map
  add column if not exists campus_name text,
  add column if not exists group_id text,
  add column if not exists subgroup_id text,
  add column if not exists timezone text,
  add column if not exists active boolean,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz;

alter table public.fellowship_map
  alter column campus_name set not null,
  alter column timezone set default 'America/Toronto',
  alter column timezone set not null,
  alter column active set default true,
  alter column active set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fellowship_map_pkey'
      and conrelid = 'public.fellowship_map'::regclass
  ) then
    alter table public.fellowship_map add constraint fellowship_map_pkey primary key (fellowship_code);
  end if;
end
$$;

alter table public.fellowship_map enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fellowship_map'
      and policyname = 'fellowship_map_authenticated_active_read'
  ) then
    create policy fellowship_map_authenticated_active_read
      on public.fellowship_map
      for select
      to authenticated
      using (active = true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fellowship_map'
      and policyname = 'fellowship_map_admin_insert'
  ) then
    create policy fellowship_map_admin_insert
      on public.fellowship_map
      for insert
      to authenticated
      with check (public.is_admin());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fellowship_map'
      and policyname = 'fellowship_map_admin_update'
  ) then
    create policy fellowship_map_admin_update
      on public.fellowship_map
      for update
      to authenticated
      using (public.is_admin())
      with check (public.is_admin());
  end if;
end
$$;
