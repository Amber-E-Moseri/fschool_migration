update public.applicants a
set group_id = fm.group_id
from public.fellowship_map fm
where fm.fellowship_code = a.fellowship_code
  and a.group_id is null;

create index if not exists idx_applicants_subgroup_id
  on public.applicants (subgroup_id);
