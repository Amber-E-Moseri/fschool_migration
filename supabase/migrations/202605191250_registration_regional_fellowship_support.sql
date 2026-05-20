-- Support REGIONAL fellowship rows without group/subgroup mapping.
alter table public.fellowship_map
  alter column group_id drop not null,
  alter column subgroup_id drop not null;

update public.applicants a
set group_id = fm.group_id
from public.fellowship_map fm
where fm.fellowship_code = a.fellowship_code
  and a.group_id is null
  and coalesce(a.fellowship_code, '') <> 'REGIONAL';

create index if not exists idx_applicants_subgroup_id
  on public.applicants (subgroup_id);

insert into public.fellowship_map (
  fellowship_code,
  campus_name,
  group_id,
  subgroup_id,
  timezone,
  active
)
values (
  'REGIONAL',
  'Canada-wide (Online)',
  null,
  null,
  'America/Toronto',
  true
)
on conflict (fellowship_code) do update
set campus_name = excluded.campus_name,
    timezone = excluded.timezone,
    active = excluded.active,
    updated_at = now();
