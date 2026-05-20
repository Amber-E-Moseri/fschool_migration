-- Safe teacher/auth linking hardening.
-- Enforces exact teacher_id + exact auth user id pairing and blocks email-only linking.

create unique index if not exists uq_teachers_teacher_user_id_not_null
  on public.teachers (teacher_user_id)
  where teacher_user_id is not null;

create or replace function public.link_teacher_to_auth_user(
  p_teacher_id text,
  p_auth_user_id uuid,
  p_actor_email text default null,
  p_allow_relink boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_teacher public.teachers%rowtype;
  v_other_teacher_id text;
  v_auth_email text;
  v_teacher_email text;
  v_actor text := nullif(trim(coalesce(p_actor_email, '')), '');
  v_previous uuid;
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN: admin role required';
  end if;

  if nullif(trim(coalesce(p_teacher_id, '')), '') is null then
    raise exception 'MISSING_TEACHER_ID';
  end if;
  if p_auth_user_id is null then
    raise exception 'MISSING_AUTH_USER_ID';
  end if;

  select *
  into v_teacher
  from public.teachers t
  where t.teacher_id = p_teacher_id
  for update;

  if not found then
    raise exception 'TEACHER_NOT_FOUND: %', p_teacher_id;
  end if;

  select lower(trim(coalesce(u.email, '')))
  into v_auth_email
  from auth.users u
  where u.id = p_auth_user_id;

  if nullif(v_auth_email, '') is null then
    raise exception 'AUTH_USER_NOT_FOUND: %', p_auth_user_id;
  end if;

  v_teacher_email := lower(trim(coalesce(v_teacher.email, '')));
  if nullif(v_teacher_email, '') is null then
    raise exception 'TEACHER_EMAIL_MISSING: %', v_teacher.teacher_id;
  end if;
  if v_teacher_email <> v_auth_email then
    raise exception 'EMAIL_MISMATCH: teacher(%) != auth_user(%)', v_teacher_email, v_auth_email;
  end if;

  if v_teacher.teacher_user_id is not null then
    if v_teacher.teacher_user_id = p_auth_user_id then
      raise exception 'TEACHER_ALREADY_LINKED: teacher is already linked to this auth user';
    end if;
    if not p_allow_relink then
      raise exception 'TEACHER_ALREADY_LINKED: teacher is linked to another auth user';
    end if;
  end if;

  select t.teacher_id
  into v_other_teacher_id
  from public.teachers t
  where t.teacher_user_id = p_auth_user_id
    and t.teacher_id <> v_teacher.teacher_id
  limit 1;

  if v_other_teacher_id is not null then
    raise exception 'AUTH_USER_ALREADY_LINKED: auth user is linked to teacher %', v_other_teacher_id;
  end if;

  v_previous := v_teacher.teacher_user_id;
  update public.teachers
  set teacher_user_id = p_auth_user_id,
      updated_at = now()
  where teacher_id = v_teacher.teacher_id;

  insert into public.audit_logs (
    logged_at,
    actor_email,
    action,
    entity_type,
    entity_id,
    status,
    details
  ) values (
    now(),
    v_actor,
    case when v_previous is null then 'TEACHER_AUTH_LINKED' else 'TEACHER_AUTH_RELINKED' end,
    'teacher',
    v_teacher.teacher_id,
    'SUCCESS',
    jsonb_build_object(
      'teacher_id', v_teacher.teacher_id,
      'previous_teacher_user_id', v_previous,
      'new_teacher_user_id', p_auth_user_id,
      'teacher_email', v_teacher_email,
      'auth_user_email', v_auth_email,
      'changed_at', now()
    )
  );

  return jsonb_build_object(
    'ok', true,
    'teacher_id', v_teacher.teacher_id,
    'previous_teacher_user_id', v_previous,
    'new_teacher_user_id', p_auth_user_id
  );
end;
$$;

-- Legacy email-only function retained but blocked intentionally.
create or replace function public.link_teacher_to_auth_user(teacher_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'EMAIL_ONLY_LINKING_DISABLED: use link_teacher_to_auth_user(p_teacher_id, p_auth_user_id, ...)';
end;
$$;

create or replace function public.unlink_teacher_from_auth_user(
  p_teacher_id text,
  p_actor_email text default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_teacher public.teachers%rowtype;
  v_actor text := nullif(trim(coalesce(p_actor_email, '')), '');
  v_previous uuid;
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN: admin role required';
  end if;
  if nullif(trim(coalesce(p_teacher_id, '')), '') is null then
    raise exception 'MISSING_TEACHER_ID';
  end if;

  select *
  into v_teacher
  from public.teachers t
  where t.teacher_id = p_teacher_id
  for update;

  if not found then
    raise exception 'TEACHER_NOT_FOUND: %', p_teacher_id;
  end if;
  if v_teacher.teacher_user_id is null then
    raise exception 'TEACHER_NOT_LINKED: no auth user attached';
  end if;

  v_previous := v_teacher.teacher_user_id;
  update public.teachers
  set teacher_user_id = null,
      updated_at = now()
  where teacher_id = v_teacher.teacher_id;

  insert into public.audit_logs (
    logged_at,
    actor_email,
    action,
    entity_type,
    entity_id,
    status,
    details
  ) values (
    now(),
    v_actor,
    'TEACHER_AUTH_UNLINKED',
    'teacher',
    v_teacher.teacher_id,
    'SUCCESS',
    jsonb_build_object(
      'teacher_id', v_teacher.teacher_id,
      'previous_teacher_user_id', v_previous,
      'new_teacher_user_id', null,
      'reason', nullif(trim(coalesce(p_reason, '')), ''),
      'changed_at', now()
    )
  );

  return jsonb_build_object(
    'ok', true,
    'teacher_id', v_teacher.teacher_id,
    'previous_teacher_user_id', v_previous,
    'new_teacher_user_id', null
  );
end;
$$;

grant execute on function public.link_teacher_to_auth_user(text, uuid, text, boolean) to authenticated;
grant execute on function public.link_teacher_to_auth_user(text) to authenticated;
grant execute on function public.unlink_teacher_from_auth_user(text, text, text) to authenticated;
