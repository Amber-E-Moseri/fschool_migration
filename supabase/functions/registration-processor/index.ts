import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_SERVICE_ROLE_KEY =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const db = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY
    );

    const body = await req.json();

    const full_name = String(body.full_name || "").trim();

    const first_name =
      full_name.split(" ")[0] || full_name;

    const last_name =
      full_name.split(" ").slice(1).join(" ");

    const email =
      String(body.email || "")
        .trim()
        .toLowerCase();

    const phone =
  String(body.phone || "").trim();

const fellowship_code_raw =
  String(body.fellowship_code || "").trim();

const fellowship_code =
  fellowship_code_raw || null;

const class_option_id_raw =
  String(body.class_option_id || "").trim();

const class_option_id =
  class_option_id_raw || null;

const batch_id_raw =
  String(body.batch_id || "").trim();

const batch_id =
  batch_id_raw || null;

const availability =
  String(body.availability || "").trim() || null;

    if (!full_name || !email) {
      throw new Error(
        "full_name and email are required"
      );
    }

    // Duplicate detection is informational only; it must never block registration.
    const { count, error: countError } = await db
      .from("applicants")
      .select("*", { count: "exact", head: true })
      .eq("email", email);

    if (countError) {
      console.error("REGISTRATION_PROCESSOR_DUPLICATE_COUNT_ERROR", countError);
    }

    const existingCount = count || 0;
    const duplicateCount = existingCount + 1;
    const isDuplicate = existingCount > 0;
    console.log("DUPLICATE_CHECK", {
      email,
      existingCount,
      duplicateCount,
      isDuplicate,
    });

    const applicantInsertBase = {
      full_name,
      first_name,
      last_name,
      email,
      phone,
      fellowship_code: fellowship_code || null,
      class_option_id: class_option_id || null,
      batch_id: batch_id || null,
      availability,
      status: "Pending",
      source: "registration_processor",
      raw_payload: body,
    };

    const applicantInsertWithDuplicateFlags = {
      ...applicantInsertBase,
      duplicate_count: duplicateCount,
      needs_admin_review: isDuplicate,
      admin_note: isDuplicate
        ? `Duplicate registration detected. This email has submitted ${duplicateCount} times.`
        : null,
    };

    let applicant: Record<string, unknown> | null = null;
    let applicantError: unknown = null;

    ({
      data: applicant,
      error: applicantError,
    } = await db
      .from("applicants")
      .insert(applicantInsertWithDuplicateFlags)
      .select("*")
      .single());

    if (applicantError) {
      const msg = JSON.stringify(applicantError);
      const duplicateFlagColumnsMissing =
        msg.includes("duplicate_count") ||
        msg.includes("needs_admin_review") ||
        msg.includes("admin_note");

      if (duplicateFlagColumnsMissing) {
        console.error(
          "REGISTRATION_PROCESSOR_SCHEMA_MIGRATION_NEEDED",
          "Add duplicate_count, needs_admin_review, admin_note columns to applicants.",
        );

        ({
          data: applicant,
          error: applicantError,
        } = await db
          .from("applicants")
          .insert(applicantInsertBase)
          .select("*")
          .single());
      }
    }

    if (applicantError) {
      throw new Error(
        (applicantError as { message?: string })?.message ||
        (applicantError as { details?: string })?.details ||
        (applicantError as { hint?: string })?.hint ||
        JSON.stringify(applicantError)
      );
    }

    const insertedApplicant = applicant as { id?: string } | null;
    console.log("APPLICANT_CREATED", {
      applicantId: insertedApplicant?.id,
      email,
      duplicateCount,
    });

    let classDetails: {
      class_option_id?: string;
      class_id?: string;
      teacher_name?: string;
      day?: string;
      class_time?: string;
    } | null = null;

    if (class_option_id) {
      const { data, error } = await db
        .from("class_options")
        .select("class_option_id,class_id,teacher_name,day,class_time")
        .eq("class_option_id", class_option_id)
        .maybeSingle();

      if (error) {
        console.error("REGISTRATION_PROCESSOR_CLASS_LOOKUP_ERROR", error);
      } else {
        classDetails = data;
      }
    }

    let fellowshipDetails: {
      fellowship_code?: string;
      campus_name?: string;
      timezone?: string;
    } | null = null;

    if (fellowship_code) {
      const { data, error } = await db
        .from("fellowship_map")
        .select("fellowship_code,campus_name,timezone")
        .eq("fellowship_code", fellowship_code)
        .maybeSingle();

      if (error) {
        console.error("REGISTRATION_PROCESSOR_FELLOWSHIP_LOOKUP_ERROR", error);
      } else {
        fellowshipDetails = data;
      }
    }

    const templateKey = isDuplicate
      ? "duplicate_registration"
      : "foundation_welcome";
    console.log("EMAIL_TEMPLATE_SELECTED", {
      email,
      isDuplicate,
      templateKey,
    });

    await db
      .from("email_queue")
      .insert({
        recipient_email: email,
        recipient_name: full_name,
        template_key: templateKey,
        subject:
          isDuplicate
            ? "We received your additional registration"
            : "Welcome to Foundation School",
        status: "Pending",
        payload: {
          first_name,
          last_name,
          full_name,
          email,
          phone,
          duplicate_count: duplicateCount,
          fellowship_code,
          class_option_id,
          batch_id,
          campus:
            body.fellowship_name ||
            body.fellowship_code ||
            "",
          class_label:
            body.class_label ||
            "",
          class_time:
            body.class_time ||
            "",
          class_day:
            body.class_day ||
            "",
          class_date:
            body.class_date ||
            body.class_start_date ||
            "",
          teacher_name:
            body.teacher_name ||
            "",
          timezone:
            body.timezone ||
            "",
          availability:
            body.availability || "",
          template_key: templateKey,
        },
      });

    await db
      .from("audit_logs")
      .insert({
        actor_email:
          "registration-processor@system",

        action:
          "REGISTRATION_RECEIVED",

        entity_type:
          "applicant",

        entity_id:
          applicant.id,

        status:
          "SUCCESS",

        details: {
          full_name,
          email,
          fellowship_code,
          class_option_id,
          batch_id,
          availability,
          template_key: templateKey,
        },
      });

    return new Response(
      JSON.stringify({
        ok: true,
        applicant_id: applicant.id,
        message:
          "Registration processed",
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type":
            "application/json",
        },
      }
    );

  } catch (error) {

    console.error(
      "REGISTRATION_PROCESSOR_ERROR",
      error
    );

    const message =
      error instanceof Error
        ? error.message
        : JSON.stringify(error);

    return new Response(
      JSON.stringify({
        ok: false,
        error: message,
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type":
            "application/json",
        },
      }
    );
  }
});
