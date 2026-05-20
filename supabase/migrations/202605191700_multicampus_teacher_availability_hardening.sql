-- Multi-campus availability hardening: store selected fellowships structurally,
-- validate non-empty campus selection, and keep class option creation single-row per slot.

alter table if exists public.teacher_availability
  add column if not exists selected_fellowship_codes text[];

alter table if exists public.teacher_availability
  add column if not exists campus_selection_review_needed boolean not null default false;

create unique index if not exists uq_teacher_availability_slot
  on public.teacher_availability (teacher_id, batch_id, day, time_slot);

-- Safe backfill only when the legacy notes format is confidently parseable: "Campus: CODE ..."
with parsed as (
  select
    ta.id,
    upper(trim(substring(ta.notes from 'Campus:\s*([A-Za-z0-9_\-]+)'))) as parsed_code
  from public.teacher_availability ta
  where (ta.selected_fellowship_codes is null or cardinality(ta.selected_fellowship_codes) = 0)
    and ta.notes is not null
)
update public.teacher_availability ta
set selected_fellowship_codes = array[p.parsed_code]::text[],
    campus_selection_review_needed = false,
    updated_at = now()
from parsed p
join public.fellowship_map fm
  on fm.fellowship_code = p.parsed_code
 and coalesce(fm.active, true) = true
where ta.id = p.id;

-- Flag rows that still have no structural campus list for manual review.
update public.teacher_availability ta
set campus_selection_review_needed = true,
    updated_at = now()
where (ta.selected_fellowship_codes is null or cardinality(ta.selected_fellowship_codes) = 0)
  and coalesce(ta.campus_selection_review_needed, false) = false;

create or replace function public.validate_teacher_availability_campuses()
returns trigger
language plpgsql
as $$
begin
  if new.selected_fellowship_codes is null or cardinality(new.selected_fellowship_codes) = 0 then
    raise exception 'selected_fellowship_codes must contain at least one campus/fellowship code';
  end if;

  new.selected_fellowship_codes := (
    select array_agg(distinct upper(trim(v)))
    from unnest(new.selected_fellowship_codes) as v
    where trim(coalesce(v, '')) <> ''
  );

  if new.selected_fellowship_codes is null or cardinality(new.selected_fellowship_codes) = 0 then
    raise exception 'selected_fellowship_codes cannot be blank';
  end if;

  new.campus_selection_review_needed := false;
  return new;
end;
$$;

drop trigger if exists trg_validate_teacher_availability_campuses on public.teacher_availability;
create trigger trg_validate_teacher_availability_campuses
before insert or update on public.teacher_availability
for each row
execute function public.validate_teacher_availability_campuses();

create or replace function public.validate_class_option_fellowship_codes()
returns trigger
language plpgsql
as $$
begin
  if new.fellowship_codes is null or cardinality(new.fellowship_codes) = 0 then
    raise exception 'class_options.fellowship_codes must contain at least one code';
  end if;

  new.fellowship_codes := (
    select array_agg(distinct upper(trim(v)))
    from unnest(new.fellowship_codes) as v
    where trim(coalesce(v, '')) <> ''
  );

  if new.fellowship_codes is null or cardinality(new.fellowship_codes) = 0 then
    raise exception 'class_options.fellowship_codes cannot be blank';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_class_option_fellowship_codes on public.class_options;
create trigger trg_validate_class_option_fellowship_codes
before insert or update on public.class_options
for each row
execute function public.validate_class_option_fellowship_codes();

create or replace function public.approve_teacher_availability_atomic(
  p_availability_id uuid,
  p_actor_email text default null,
  p_actor_id text default null
)
returns table (
  ok boolean,
  class_option_id text,
  class_slot_id text,
  error text
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_avail public.teacher_availability%rowtype;
  v_teacher public.teachers%rowtype;
  v_batch_id text;
  v_day text;
  v_time time;
  v_time_key text;
  v_tid_key text;
  v_sg_key text;
  v_co_id text;
  v_cs_id text;
  v_fellowship_codes text[];
begin
  if not (public.is_superadmin() or public.is_admin()) then
    return query select false, null::text, null::text, 'Only admin or superadmin can approve availability.';
    return;
  end if;

  begin
    select ta.*
      into v_avail
    from public.teacher_availability ta
    where ta.id = p_availability_id
    for update;

    if not found then
      return query select false, null::text, null::text, 'Availability row not found.';
      return;
    end if;

    select t.*
      into v_teacher
    from public.teachers t
    where t.teacher_id = v_avail.teacher_id;

    if not found then
      return query select false, null::text, null::text, 'Teacher not found for availability row.';
      return;
    end if;

    v_batch_id := coalesce(v_avail.batch_id, '2025A');
    v_day := coalesce(v_avail.day, '');
    v_time := v_avail.time_slot;

    if v_day = '' or v_time is null then
      return query select false, null::text, null::text, 'Availability day/time is required.';
      return;
    end if;

    v_fellowship_codes := (
      select array_agg(distinct upper(trim(v)))
      from unnest(coalesce(v_avail.selected_fellowship_codes, array[]::text[])) as v
      where trim(coalesce(v, '')) <> ''
    );

    -- Single-campus compatibility path only.
    if (v_fellowship_codes is null or cardinality(v_fellowship_codes) = 0)
       and coalesce(v_teacher.fellowship_code, '') <> '' then
      v_fellowship_codes := array[upper(trim(v_teacher.fellowship_code))]::text[];
    end if;

    if v_fellowship_codes is null or cardinality(v_fellowship_codes) = 0 then
      return query select false, null::text, null::text, 'No campuses selected for availability. Cannot approve.';
      return;
    end if;

    v_time_key := to_char(v_time, 'HH24MI');
    v_tid_key := upper(left(regexp_replace(coalesce(v_avail.teacher_id, ''), '[^A-Za-z0-9]', '', 'g'), 8));
    v_sg_key := upper(regexp_replace(coalesce(v_teacher.subgroup_id, ''), '[^A-Za-z0-9]', '', 'g'));

    v_co_id := 'CO-' || v_sg_key || '-' || upper(left(v_day, 3)) || '-' || v_time_key || '-' || v_tid_key;
    v_cs_id := 'CS-' || v_co_id || '-' || v_batch_id;

    insert into public.class_options (
      class_option_id,
      class_id,
      teacher_id,
      teacher_name,
      fellowship_codes,
      group_id,
      subgroup_id,
      day,
      class_time,
      active,
      enrollment_open,
      deleted_at,
      updated_by
    )
    values (
      v_co_id,
      v_co_id,
      v_avail.teacher_id,
      coalesce(v_teacher.full_name, ''),
      v_fellowship_codes,
      coalesce(v_teacher.group_id, ''),
      coalesce(v_teacher.subgroup_id, ''),
      v_day,
      v_time,
      true,
      true,
      null,
      p_actor_id
    )
    on conflict on constraint class_options_pkey
    do update
      set teacher_id = excluded.teacher_id,
          teacher_name = excluded.teacher_name,
          fellowship_codes = excluded.fellowship_codes,
          group_id = excluded.group_id,
          subgroup_id = excluded.subgroup_id,
          day = excluded.day,
          class_time = excluded.class_time,
          active = true,
          enrollment_open = true,
          deleted_at = null,
          updated_by = excluded.updated_by,
          updated_at = now();

    insert into public.class_slots (
      class_slot_id,
      class_option_id,
      teacher_id,
      teacher_name,
      group_id,
      subgroup_id,
      batch_id,
      status,
      current_enrolment,
      updated_by
    )
    values (
      v_cs_id,
      v_co_id,
      v_avail.teacher_id,
      coalesce(v_teacher.full_name, ''),
      coalesce(v_teacher.group_id, ''),
      coalesce(v_teacher.subgroup_id, ''),
      v_batch_id,
      'Active',
      0,
      p_actor_id
    )
    on conflict on constraint class_slots_pkey
    do update
      set class_option_id = excluded.class_option_id,
          teacher_id = excluded.teacher_id,
          teacher_name = excluded.teacher_name,
          group_id = excluded.group_id,
          subgroup_id = excluded.subgroup_id,
          batch_id = excluded.batch_id,
          status = 'Active',
          updated_by = excluded.updated_by,
          updated_at = now();

    update public.teacher_availability ta
    set
      status = 'Available',
      class_option_id = v_co_id,
      class_option_sync_status = 'SUCCESS',
      class_option_sync_error = null,
      class_option_sync_attempts = coalesce(ta.class_option_sync_attempts, 0) + 1,
      class_option_sync_last_at = now(),
      updated_by = p_actor_id,
      selected_fellowship_codes = v_fellowship_codes,
      campus_selection_review_needed = false
    where ta.id = p_availability_id;

    return query select true, v_co_id, v_cs_id, null::text;
  exception when others then
    update public.teacher_availability ta
    set
      class_option_sync_status = 'FAILED',
      class_option_sync_error = left(sqlerrm, 500),
      class_option_sync_attempts = coalesce(ta.class_option_sync_attempts, 0) + 1,
      class_option_sync_last_at = now(),
      updated_by = p_actor_id
    where ta.id = p_availability_id;

    return query select false, null::text, null::text, sqlerrm;
  end;
end;
$$;

grant execute on function public.approve_teacher_availability_atomic(uuid, text, text) to authenticated;
