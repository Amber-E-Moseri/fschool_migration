import { assignApplicant } from "../../_shared/lib/assign-applicant.ts";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

function applicantName(app: any) {
  return app?.full_name || [app?.first_name, app?.last_name].filter(Boolean).join(" ") || "Unnamed Applicant";
}

function buildStudentId(app: any) {
  const base = (app?.email || app?.id || "student").toString().replace(/[^a-zA-Z0-9]/g, "").slice(0, 16).toUpperCase();
  return `STU-${base}-${Date.now().toString().slice(-6)}`;
}

function firstDefined(...vals: unknown[]) {
  return vals.find((v) => v !== undefined && v !== null && String(v).trim() !== "");
}

export async function assignApplicantAdminAction(ctx: { db: any; auth: any; params: any }) {
  const { db, auth, params } = ctx;
  const applicantId = String(params?.applicant_id || "").trim();
  const classOptionId = String(params?.class_option_id || "").trim();
  const batchId = String(params?.batch_id || "").trim();
  const actorEmail = String(params?.actor_email || auth?.profile?.email || auth?.user?.email || "").trim() || null;
  const now = new Date().toISOString();

  if (!applicantId || !classOptionId || !batchId) {
    return json({ ok: false, error: "applicant_id, class_option_id, and batch_id are required" }, 400);
  }

  const { data: applicant, error: appErr } = await db
    .from("applicants")
    .select("*")
    .eq("id", applicantId)
    .maybeSingle();
  if (appErr || !applicant) return json({ ok: false, error: "Applicant not found" }, 404);

  const { data: cls } = await db
    .from("class_options")
    .select("*")
    .eq("class_option_id", classOptionId)
    .maybeSingle();

  const result = await assignApplicant(applicantId, db, {
    mode: "registration",
    nowIso: now,
    batch_id: batchId,
    class_option_id: classOptionId,
    availability: applicant?.availability || applicant?.availability_status || null,
    canAutoAssign: true,
    isDuplicate: false,
    duplicateCount: Number(applicant?.duplicate_count || 0),
  });

  if (String(result?.status || "").toUpperCase() !== "ASSIGNED") {
    return json({
      ok: false,
      error: "Assignment did not resolve to ASSIGNED",
      result: {
        status: result?.status || null,
        availabilityStatus: result?.availabilityStatus || null,
        classId: result?.classId || null,
      },
    }, 400);
  }

  let student = null;
  if (applicant?.email) {
    const existing = await db.from("students").select("*").eq("email", applicant.email).maybeSingle();
    if (existing.error && existing.error.code !== "PGRST116") throw existing.error;
    student = existing.data || null;
  }

  const studentId = student?.student_id || buildStudentId(applicant);
  const studentPayload = {
    student_id: studentId,
    full_name: applicantName(applicant),
    email: applicant.email,
    phone: applicant.phone || null,
    group_id: firstDefined(applicant.group_id, cls?.group_id, "UNSET"),
    subgroup_id: firstDefined(applicant.subgroup_id, cls?.subgroup_id, "UNSET"),
    fellowship_code: firstDefined(applicant.fellowship_code, cls?.subgroup_id, null),
    batch_id: batchId,
    class_option_id: classOptionId,
    teacher_id: cls?.teacher_id || null,
    teacher_name: cls?.teacher_name || null,
    status: "Active",
    created_by: actorEmail,
    updated_by: actorEmail,
    deleted_at: null,
    updated_at: now,
  };

  if (student) {
    const { error: updateStudentError } = await db.from("students").update(studentPayload).eq("student_id", student.student_id);
    if (updateStudentError) throw updateStudentError;
  } else {
    const { error: insertStudentError } = await db.from("students").insert({ ...studentPayload, created_at: now });
    if (insertStudentError) throw insertStudentError;
  }

  const rosterPayload = {
    student_id: studentId,
    class_option_id: classOptionId,
    batch_id: batchId,
    group_id: firstDefined(applicant.group_id, cls?.group_id, "UNSET"),
    subgroup_id: firstDefined(applicant.subgroup_id, cls?.subgroup_id, "UNSET"),
    status: "Active",
    enrolled_at: now,
    created_by: actorEmail,
    updated_by: actorEmail,
    updated_at: now,
  };
  const { error: rosterError } = await db.from("class_roster").upsert(rosterPayload, { onConflict: "student_id,class_option_id,batch_id" });
  if (rosterError) throw rosterError;

  const dedupeKey = `applicant:${applicant.id}:class:${classOptionId}:batch:${batchId}`;
  const moodlePayload = {
    applicant_id: applicant.id,
    student_id: studentId,
    email: applicant.email,
    full_name: applicantName(applicant),
    batch_id: batchId,
    class_option_id: classOptionId,
    registration_status: "ASSIGNED",
    sync_status: "PENDING",
    dedupe_key: dedupeKey,
    retry_requested_at: now,
    updated_at: now,
    payload: { source: "admin_review_assignment", duplicate_attempt: false },
  };
  const moodleRes = await db.from("moodle_enrollment_sync").upsert(moodlePayload, { onConflict: "applicant_id" });
  if (moodleRes.error) throw moodleRes.error;

  const { error: auditError } = await db.from("audit_logs").insert({
    actor_email: actorEmail,
    action: "APPLICANT_ASSIGNED",
    entity_type: "applicant",
    entity_id: applicantId,
    status: "SUCCESS",
    details: {
      applicant_id: applicantId,
      student_id: studentId,
      batch_id: batchId,
      class_option_id: classOptionId,
      source: "admin_review_assignment",
    },
    logged_at: now,
  });
  if (auditError) throw auditError;

  return json({
    ok: true,
    studentId,
    registrationStatus: "ASSIGNED",
    availabilityStatus: result.availabilityStatus || "CLASS_ASSIGNED",
  });
}

