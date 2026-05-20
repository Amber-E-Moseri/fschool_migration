-- Dashboard KPI RPCs: active/certified teachers + currently teaching.

create or replace function public.get_active_teacher_count()
returns table (active_certified bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select count(*)::bigint
  from public.teachers t
  where upper(coalesce(t.status, '')) = 'ACTIVE'
    and coalesce(t.active, false) = true
    and t.deleted_at is null
    and t.suspended_at is null;
end;
$$;

grant execute on function public.get_active_teacher_count() to authenticated;

create or replace function public.get_currently_teaching_count(p_batch_id text default null)
returns table (currently_teaching bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select count(distinct t.teacher_id)::bigint
  from public.class_options co
  join public.class_slots cs
    on cs.class_option_id = co.class_option_id
  join public.teachers t
    on t.teacher_id::text = co.teacher_id::text
  where co.active = true
    and upper(coalesce(t.status, '')) = 'ACTIVE'
    and coalesce(t.active, false) = true
    and t.deleted_at is null
    and t.suspended_at is null
    and co.deleted_at is null
    and cs.status = 'Active'
    and (p_batch_id is null or cs.batch_id = p_batch_id);
end;
$$;

grant execute on function public.get_currently_teaching_count(text) to authenticated;
