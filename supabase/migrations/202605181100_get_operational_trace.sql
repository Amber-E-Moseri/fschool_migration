begin;

create or replace function public.get_operational_trace(lookup text)
returns table (
  event_time timestamptz,
  source text,
  event_type text,
  status text,
  details jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lookup text := nullif(trim(coalesce(lookup, '')), '');
  v_lookup_lower text := nullif(lower(trim(coalesce(lookup, ''))), '');
  v_lookup_uuid uuid := null;
  v_is_uuid boolean := false;
  v_admin boolean := false;
  v_applicant_id uuid := null;
  v_student_id text := null;
  v_email text := null;
  v_trace_id uuid := null;
begin
  -- RLS-equivalent authorization guard inside SECURITY DEFINER function
  select exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.is_active = true
      and lower(coalesce(p.role, '')) in ('admin', 'superadmin')
  )
  or exists (
    select 1
    from public.admin_users au
    where au.auth_user_id = auth.uid()
      and lower(coalesce(au.role, '')) in ('admin', 'superadmin')
      and coalesce(au.active, true) = true
  )
  into v_admin;

  if not v_admin then
    return;
  end if;

  if v_lookup is null then
    return;
  end if;

  v_is_uuid := v_lookup ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
  if v_is_uuid then
    v_lookup_uuid := v_lookup::uuid;
  end if;

  -- Resolve applicant/email/student/trace context from lookup
  if to_regclass('public.applicants') is not null then
    select a.id, lower(a.email), a.trace_id
    into v_applicant_id, v_email, v_trace_id
    from public.applicants a
    where (v_lookup_lower is not null and lower(a.email) = v_lookup_lower)
       or (v_is_uuid and a.id = v_lookup_uuid)
    order by a.created_at desc
    limit 1;
  end if;

  if v_student_id is null and to_regclass('public.students') is not null then
    select s.student_id, lower(s.email)
    into v_student_id, v_email
    from public.students s
    where (v_lookup_lower is not null and lower(s.email) = v_lookup_lower)
       or (v_lookup is not null and s.student_id = v_lookup)
    order by s.created_at desc
    limit 1;
  end if;

  if v_applicant_id is null and v_is_uuid and to_regclass('public.moodle_enrollment_sync') is not null then
    select coalesce(m.registration_id, m.applicant_id), lower(m.email), m.trace_id
    into v_applicant_id, v_email, v_trace_id
    from public.moodle_enrollment_sync m
    where m.registration_id = v_lookup_uuid
       or m.applicant_id = v_lookup_uuid
       or m.trace_id = v_lookup_uuid
    order by coalesce(m.updated_at, m.created_at) desc
    limit 1;
  end if;

  if v_trace_id is null and v_is_uuid then
    v_trace_id := v_lookup_uuid;
  end if;
  if v_email is null and v_lookup_lower like '%@%' then
    v_email := v_lookup_lower;
  end if;
  if v_student_id is null and v_lookup ilike 'FS-%' then
    v_student_id := v_lookup;
  end if;

  return query
  with trace as (
    -- applicants lifecycle
    select
      coalesce(a.assigned_at, a.created_at) as event_time,
      'applicant'::text as source,
      'REGISTRATION_STATE'::text as event_type,
      coalesce(a.registration_status, 'UNKNOWN')::text as status,
      jsonb_build_object(
        'applicant_id', a.id,
        'email', a.email,
        'registration_status', a.registration_status,
        'availability_status', a.availability_status,
        'assigned_at', a.assigned_at,
        'created_at', a.created_at,
        'trace_id', a.trace_id
      ) as details
    from public.applicants a
    where to_regclass('public.applicants') is not null
      and (
        (v_applicant_id is not null and a.id = v_applicant_id)
        or (v_email is not null and lower(a.email) = v_email)
      )

    union all

    -- student and roster enrollment events
    select
      coalesce(cr.created_at, s.created_at) as event_time,
      'applicant'::text as source,
      'ENROLLMENT'::text as event_type,
      coalesce(cr.status, s.status, 'UNKNOWN')::text as status,
      jsonb_build_object(
        'student_id', s.student_id,
        'email', s.email,
        'class_option_id', cr.class_option_id,
        'batch_id', cr.batch_id,
        'student_status', s.status,
        'roster_status', cr.status
      ) as details
    from public.students s
    left join public.class_roster cr
      on cr.student_id = s.student_id
    where to_regclass('public.students') is not null
      and (
        (v_student_id is not null and s.student_id = v_student_id)
        or (v_email is not null and lower(s.email) = v_email)
      )

    union all

    -- canonical audit trail for applicant/student/registration entities
    select
      coalesce(al.logged_at, al.created_at) as event_time,
      'audit'::text as source,
      coalesce(al.action, 'AUDIT_EVENT')::text as event_type,
      coalesce(al.status, 'UNKNOWN')::text as status,
      coalesce(al.details, '{}'::jsonb)
        || jsonb_build_object('entity_type', al.entity_type, 'entity_id', al.entity_id) as details
    from public.audit_logs al
    where to_regclass('public.audit_logs') is not null
      and lower(coalesce(al.entity_type, '')) in ('applicant', 'student', 'registration')
      and (
        (v_applicant_id is not null and al.entity_id = v_applicant_id::text)
        or (v_student_id is not null and al.entity_id = v_student_id)
      )

    union all

    -- scheduled notifications correlated by trace_id
    select
      coalesce(sn.updated_at, sn.created_at) as event_time,
      'notification'::text as source,
      coalesce(sn.event_type, sn.template_key, 'SCHEDULED_NOTIFICATION')::text as event_type,
      coalesce(sn.status, 'UNKNOWN')::text as status,
      coalesce(to_jsonb(sn), '{}'::jsonb) as details
    from public.scheduled_notifications sn
    where to_regclass('public.scheduled_notifications') is not null
      and (
        (v_trace_id is not null and sn.trace_id = v_trace_id)
        or (v_applicant_id is not null and sn.applicant_id = v_applicant_id)
      )

    union all

    -- email queue by trace_id or recipient email
    select
      coalesce(eq.sent_at, eq.updated_at, eq.created_at) as event_time,
      'email'::text as source,
      coalesce(eq.template_key, 'EMAIL_QUEUE')::text as event_type,
      coalesce(eq.status, 'UNKNOWN')::text as status,
      coalesce(to_jsonb(eq), '{}'::jsonb) as details
    from public.email_queue eq
    where to_regclass('public.email_queue') is not null
      and (
        (v_trace_id is not null and eq.trace_id = v_trace_id)
        or (v_email is not null and lower(eq.recipient_email) = v_email)
      )

    union all

    -- moodle sync by trace_id
    select
      coalesce(ms.synced_at, ms.updated_at, ms.created_at) as event_time,
      'moodle'::text as source,
      coalesce(ms.sync_status, ms.status, 'MOODLE_EVENT')::text as event_type,
      coalesce(ms.sync_status, ms.status, 'UNKNOWN')::text as status,
      coalesce(to_jsonb(ms), '{}'::jsonb) as details
    from public.moodle_enrollment_sync ms
    where to_regclass('public.moodle_enrollment_sync') is not null
      and (
        (v_trace_id is not null and ms.trace_id = v_trace_id)
        or (v_applicant_id is not null and (ms.registration_id = v_applicant_id or ms.applicant_id = v_applicant_id))
        or (v_email is not null and lower(ms.email) = v_email)
      )
  )
  select
    t.event_time,
    t.source,
    t.event_type,
    t.status,
    t.details
  from trace t
  where t.event_time is not null
  order by t.event_time asc;
end;
$$;

revoke all on function public.get_operational_trace(text) from public;
revoke all on function public.get_operational_trace(text) from anon;
grant execute on function public.get_operational_trace(text) to authenticated;

commit;
