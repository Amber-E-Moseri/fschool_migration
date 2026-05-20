alter table public.applicants
  add column if not exists subgroup_id text;

update public.applicants a
set subgroup_id = fm.subgroup_id
from public.fellowship_map fm
where fm.fellowship_code = a.fellowship_code
  and a.subgroup_id is null;

create index if not exists idx_applicants_subgroup_id
  on public.applicants (subgroup_id);
