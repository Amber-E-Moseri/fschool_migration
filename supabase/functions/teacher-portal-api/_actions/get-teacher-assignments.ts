import { ApiError } from "../_lib/errors.ts";
import { json, withTimeout } from "../_lib/http.ts";
import type { ActionContext } from "../_lib/types.ts";


export async function getTeacherAssignmentsAction(ctx: ActionContext): Promise<Response> {
  const { db, auth } = ctx;
  const teacherId = String(auth.teacher.teacherId || "").trim();
  const teacherEmail = String(auth.teacher.email || "").trim().toLowerCase();

  const baseSelect =
    "class_option_id,class_id,teacher_id,teacher_name,fellowship_codes,group_id,subgroup_id,day,class_time,active,max_capacity,deleted_at,class_slots(batch_id,current_enrolment,status)";

  const { data: byTeacherId, error: byTeacherIdError } = await withTimeout(
    db
      .from("class_options")
      .select(baseSelect)
      .eq("teacher_id", teacherId)
      .is("deleted_at", null)
      .order("day")
      .order("class_time"),
    "fetch teacher assignments",
  );
  if (byTeacherIdError) throw new ApiError("INTERNAL_ERROR", "Failed to load teacher assignments", 500);

  let rows = byTeacherId || [];

  if (!rows.length && teacherEmail) {
    const { data: teacherRows, error: teacherError } = await withTimeout(
      db
        .from("teachers")
        .select("teacher_id,email")
        .ilike("email", teacherEmail)
        .limit(1),
      "resolve teacher by email",
    );
    if (teacherError) throw new ApiError("INTERNAL_ERROR", "Failed to load teacher assignments", 500);

    const fallbackTeacherId = String(teacherRows?.[0]?.teacher_id || "").trim();
    if (fallbackTeacherId) {
      const { data: byTeacherEmail, error: byTeacherEmailError } = await withTimeout(
        db
          .from("class_options")
          .select(baseSelect)
          .eq("teacher_id", fallbackTeacherId)
          .is("deleted_at", null)
          .order("day")
          .order("class_time"),
        "fetch teacher assignments by email",
      );
      if (byTeacherEmailError) throw new ApiError("INTERNAL_ERROR", "Failed to load teacher assignments", 500);
      rows = byTeacherEmail || [];
    }
  }

  const normalized = rows.map((r: any) => {
    const slot = Array.isArray(r.class_slots) ? r.class_slots[0] : r.class_slots;
    return {
      class_option_id: r.class_option_id ?? null,
      class_id: r.class_id ?? null,
      teacher_id: r.teacher_id ?? null,
      teacher_name: r.teacher_name ?? null,
      fellowship_codes: Array.isArray(r.fellowship_codes) ? r.fellowship_codes : [],
      group_id: r.group_id ?? null,
      subgroup_id: r.subgroup_id ?? null,
      day: r.day ?? null,
      class_time: r.class_time ?? null,
      active: r.active ?? null,
      max_capacity: r.max_capacity ?? null,
      deleted_at: r.deleted_at ?? null,
      batch_id: slot?.batch_id ?? null,
      current_enrolment: slot?.current_enrolment ?? null,
      slot_status: slot?.status ?? null,
    };
  });

  return json({ ok: true, data: normalized });
}
