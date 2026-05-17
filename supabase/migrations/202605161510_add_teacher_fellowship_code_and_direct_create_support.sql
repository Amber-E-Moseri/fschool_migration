begin;

alter table public.teachers
  add column if not exists fellowship_code text references public.fellowship_map(fellowship_code);

create index if not exists idx_teachers_fellowship_code on public.teachers (fellowship_code);

create or replace function public.admin_create_teacher_direct(
  p_full_name text,
  p_email text,
  p_phone text default null,
  p_group_id text default null,
  p_subgroup_id text default null,
  p_fellowship_code text default null,
  p_notes text default null,
  p_actor_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_full_name text := trim(coalesce(p_full_name, ''));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_actor text := nullif(trim(coalesce(p_actor_email, '')), '');
  v_teacher_id text;
  v_existing_teacher_id text;
  v_fellowship_code text := nullif(upper(trim(coalesce(p_fellowship_code, ''))), '');
begin
  if v_email = '' then
    return jsonb_build_object('ok', false, 'error', 'Email is required');
  end if;

  if v_full_name = '' then
    return jsonb_build_object('ok', false, 'error', 'Full name is required');
  end if;

  if v_fellowship_code is not null then
    if not exists (
      select 1
      from public.fellowship_map fm
      where fm.fellowship_code = v_fellowship_code
    ) then
      return jsonb_build_object('ok', false, 'error', 'Invalid fellowship_code');
    end if;
  end if;

  select t.teacher_id
  into v_existing_teacher_id
  from public.teachers t
  where lower(trim(coalesce(t.email, ''))) = v_email
    and t.deleted_at is null
  limit 1;

  if v_existing_teacher_id is not null then
    return jsonb_build_object(
      'ok', false,
      'error', 'A teacher with this email already exists',
      'teacher_id', v_existing_teacher_id
    );
  end if;

  v_teacher_id :=
    'T-' ||
    upper(
      substring(
        regexp_replace(gen_random_uuid()::text, '[^a-zA-Z0-9]', '', 'g')
        from 1 for 8
      )
    );

  insert into public.teachers (
    teacher_id,
    full_name,
    email,
    phone,
    group_id,
    subgroup_id,
    fellowship_code,
    notes,
    status,
    active,
    created_by,
    updated_by
  )
  values (
    v_teacher_id,
    v_full_name,
    v_email,
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_group_id, '')), ''),
    nullif(trim(coalesce(p_subgroup_id, '')), ''),
    v_fellowship_code,
    nullif(trim(coalesce(p_notes, '')), ''),
    'PENDING',
    false,
    coalesce(v_actor, 'admin'),
    coalesce(v_actor, 'admin')
  );

  insert into public.audit_logs (
    action,
    actor_id,
    target_id,
    entity_type,
    metadata
  )
  values (
    'teacher_created_direct',
    coalesce(v_actor, 'admin'),
    v_teacher_id,
    'teacher',
    jsonb_build_object(
      'full_name', v_full_name,
      'email', v_email,
      'method', 'direct_no_email',
      'group_id', nullif(trim(coalesce(p_group_id, '')), ''),
      'subgroup_id', nullif(trim(coalesce(p_subgroup_id, '')), ''),
      'fellowship_code', v_fellowship_code
    )
  );

  return jsonb_build_object(
    'ok', true,
    'teacher_id', v_teacher_id,
    'email', v_email,
    'status', 'PENDING',
    'fellowship_code', v_fellowship_code,
    'note', 'Teacher created directly without email delivery'
  );
end;
$$;

grant execute on function public.admin_create_teacher_direct(text, text, text, text, text, text, text, text) to authenticated;
revoke execute on function public.admin_create_teacher_direct(text, text, text, text, text, text, text, text) from anon;

commit;
