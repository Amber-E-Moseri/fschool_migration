-- =============================================================
-- 003_rls_policies.sql
-- Foundation School — Row Level Security policies
-- =============================================================
--
-- Role model:
-- ┌──────────────────┬─────────────────────────────────────────────────────┐
-- │ Role             │ Who                                                 │
-- ├──────────────────┼─────────────────────────────────────────────────────┤
-- │ anon             │ Public users (unauthenticated); uses Supabase        │
-- │                  │ anon key. Limited to registration lookup + submit.  │
-- ├──────────────────┼─────────────────────────────────────────────────────┤
-- │ authenticated    │ Staff / admins who have signed in via Supabase Auth.│
-- │                  │ Full read access; scoped write access per table.    │
-- ├──────────────────┼─────────────────────────────────────────────────────┤
-- │ service_role     │ Edge Functions and server-side jobs running with    │
-- │                  │ the service role key. Bypasses RLS entirely —       │
-- │                  │ no explicit policies needed.                        │
-- └──────────────────┴─────────────────────────────────────────────────────┘
--
-- Notes:
-- • service_role bypasses RLS — audit_log, teacher_roster_log, and
--   elvanto_import are fully accessible to service_role even though
--   no anon/authenticated policies are defined for them.
-- • No student-facing auth exists yet; all public flows go through anon.
-- • Policy names follow the pattern: <table>_<role>_<operation>.
-- =============================================================


-- =============================================================
-- Enable RLS on every table
-- =============================================================

ALTER TABLE config                ENABLE ROW LEVEL SECURITY;
ALTER TABLE fellowship_map        ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers              ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log              ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log             ENABLE ROW LEVEL SECURITY;
ALTER TABLE elvanto_import        ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches               ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_options         ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_sections         ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_slots           ENABLE ROW LEVEL SECURITY;
ALTER TABLE applicants            ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_availability  ENABLE ROW LEVEL SECURITY;
ALTER TABLE students              ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_forms      ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_submissions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_queue           ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_roster          ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_log        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ft_pipeline           ENABLE ROW LEVEL SECURITY;
ALTER TABLE eligible_pool         ENABLE ROW LEVEL SECURITY;
ALTER TABLE moodle_sync           ENABLE ROW LEVEL SECURITY;
ALTER TABLE graduation_review     ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_roster_log    ENABLE ROW LEVEL SECURITY;
ALTER TABLE makeup_queue          ENABLE ROW LEVEL SECURITY;
ALTER TABLE transition_log        ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_log          ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_summary         ENABLE ROW LEVEL SECURITY;


-- =============================================================
-- PUBLIC (anon) — SELECT only, filtered rows
-- =============================================================

-- Active fellowships for the registration form campus dropdown
CREATE POLICY fellowship_map_anon_select ON fellowship_map
  FOR SELECT TO anon
  USING (active = true);

-- Active, non-deleted class options for the class selection step
CREATE POLICY class_options_anon_select ON class_options
  FOR SELECT TO anon
  USING (active = true AND deleted_at IS NULL);

-- Active, non-deleted teachers (needed for class display labels)
CREATE POLICY teachers_anon_select ON teachers
  FOR SELECT TO anon
  USING (active = true AND deleted_at IS NULL);

-- Batches that are currently open for registration
CREATE POLICY batches_anon_select ON batches
  FOR SELECT TO anon
  USING (registration_open = true);

-- Full config read (no secrets stored here; form labels, flags only)
CREATE POLICY config_anon_select ON config
  FOR SELECT TO anon
  USING (true);


-- =============================================================
-- PUBLIC (anon) — INSERT only
-- =============================================================

-- Phase 1 registration form submissions
CREATE POLICY applicants_anon_insert ON applicants
  FOR INSERT TO anon
  WITH CHECK (true);

-- Failed-submission capture from the public registration flow
CREATE POLICY error_submissions_anon_insert ON error_submissions
  FOR INSERT TO anon
  WITH CHECK (true);


-- =============================================================
-- AUTHENTICATED STAFF — full SELECT on all tables
-- =============================================================

CREATE POLICY config_staff_select             ON config             FOR SELECT TO authenticated USING (true);
CREATE POLICY fellowship_map_staff_select     ON fellowship_map     FOR SELECT TO authenticated USING (true);
CREATE POLICY teachers_staff_select           ON teachers           FOR SELECT TO authenticated USING (true);
CREATE POLICY email_templates_staff_select    ON email_templates    FOR SELECT TO authenticated USING (true);
CREATE POLICY sync_log_staff_select           ON sync_log           FOR SELECT TO authenticated USING (true);
CREATE POLICY audit_log_staff_select          ON audit_log          FOR SELECT TO authenticated USING (true);
CREATE POLICY elvanto_import_staff_select     ON elvanto_import     FOR SELECT TO authenticated USING (true);
CREATE POLICY batches_staff_select            ON batches            FOR SELECT TO authenticated USING (true);
CREATE POLICY class_options_staff_select      ON class_options      FOR SELECT TO authenticated USING (true);
CREATE POLICY form_sections_staff_select      ON form_sections      FOR SELECT TO authenticated USING (true);
CREATE POLICY class_slots_staff_select        ON class_slots        FOR SELECT TO authenticated USING (true);
CREATE POLICY applicants_staff_select         ON applicants         FOR SELECT TO authenticated USING (true);
CREATE POLICY teacher_availability_staff_select ON teacher_availability FOR SELECT TO authenticated USING (true);
CREATE POLICY students_staff_select           ON students           FOR SELECT TO authenticated USING (true);
CREATE POLICY attendance_forms_staff_select   ON attendance_forms   FOR SELECT TO authenticated USING (true);
CREATE POLICY error_submissions_staff_select  ON error_submissions  FOR SELECT TO authenticated USING (true);
CREATE POLICY email_queue_staff_select        ON email_queue        FOR SELECT TO authenticated USING (true);
CREATE POLICY class_roster_staff_select       ON class_roster       FOR SELECT TO authenticated USING (true);
CREATE POLICY attendance_log_staff_select     ON attendance_log     FOR SELECT TO authenticated USING (true);
CREATE POLICY ft_pipeline_staff_select        ON ft_pipeline        FOR SELECT TO authenticated USING (true);
CREATE POLICY eligible_pool_staff_select      ON eligible_pool      FOR SELECT TO authenticated USING (true);
CREATE POLICY moodle_sync_staff_select        ON moodle_sync        FOR SELECT TO authenticated USING (true);
CREATE POLICY graduation_review_staff_select  ON graduation_review  FOR SELECT TO authenticated USING (true);
CREATE POLICY teacher_roster_log_staff_select ON teacher_roster_log FOR SELECT TO authenticated USING (true);
CREATE POLICY makeup_queue_staff_select       ON makeup_queue       FOR SELECT TO authenticated USING (true);
CREATE POLICY transition_log_staff_select     ON transition_log     FOR SELECT TO authenticated USING (true);
CREATE POLICY feedback_log_staff_select       ON feedback_log       FOR SELECT TO authenticated USING (true);
CREATE POLICY group_summary_staff_select      ON group_summary      FOR SELECT TO authenticated USING (true);


-- =============================================================
-- AUTHENTICATED STAFF — INSERT / UPDATE (operational tables)
-- These tables grow through normal program operation.
-- =============================================================

CREATE POLICY students_staff_insert ON students
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY students_staff_update ON students
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY attendance_log_staff_insert ON attendance_log
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY attendance_log_staff_update ON attendance_log
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY eligible_pool_staff_insert ON eligible_pool
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY eligible_pool_staff_update ON eligible_pool
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY moodle_sync_staff_insert ON moodle_sync
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY moodle_sync_staff_update ON moodle_sync
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY graduation_review_staff_insert ON graduation_review
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY graduation_review_staff_update ON graduation_review
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY ft_pipeline_staff_insert ON ft_pipeline
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY ft_pipeline_staff_update ON ft_pipeline
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY class_roster_staff_insert ON class_roster
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY class_roster_staff_update ON class_roster
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY makeup_queue_staff_insert ON makeup_queue
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY makeup_queue_staff_update ON makeup_queue
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY transition_log_staff_insert ON transition_log
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY transition_log_staff_update ON transition_log
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY teacher_availability_staff_insert ON teacher_availability
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY teacher_availability_staff_update ON teacher_availability
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY email_queue_staff_insert ON email_queue
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY email_queue_staff_update ON email_queue
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY sync_log_staff_insert ON sync_log
  FOR INSERT TO authenticated WITH CHECK (true);


-- =============================================================
-- AUTHENTICATED STAFF — full INSERT / UPDATE / DELETE
-- Configuration and reference tables managed by admins.
-- =============================================================

CREATE POLICY class_options_staff_insert ON class_options
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY class_options_staff_update ON class_options
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY class_options_staff_delete ON class_options
  FOR DELETE TO authenticated USING (true);

CREATE POLICY class_slots_staff_insert ON class_slots
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY class_slots_staff_update ON class_slots
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY class_slots_staff_delete ON class_slots
  FOR DELETE TO authenticated USING (true);

CREATE POLICY teachers_staff_insert ON teachers
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY teachers_staff_update ON teachers
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY teachers_staff_delete ON teachers
  FOR DELETE TO authenticated USING (true);

CREATE POLICY fellowship_map_staff_insert ON fellowship_map
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY fellowship_map_staff_update ON fellowship_map
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY fellowship_map_staff_delete ON fellowship_map
  FOR DELETE TO authenticated USING (true);

CREATE POLICY batches_staff_insert ON batches
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY batches_staff_update ON batches
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY batches_staff_delete ON batches
  FOR DELETE TO authenticated USING (true);

CREATE POLICY email_templates_staff_insert ON email_templates
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY email_templates_staff_update ON email_templates
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY email_templates_staff_delete ON email_templates
  FOR DELETE TO authenticated USING (true);

CREATE POLICY form_sections_staff_insert ON form_sections
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY form_sections_staff_update ON form_sections
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY form_sections_staff_delete ON form_sections
  FOR DELETE TO authenticated USING (true);

CREATE POLICY group_summary_staff_insert ON group_summary
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY group_summary_staff_update ON group_summary
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY group_summary_staff_delete ON group_summary
  FOR DELETE TO authenticated USING (true);

-- Applicants: staff can update (approve/reject) and delete (spam/error cleanup)
CREATE POLICY applicants_staff_update ON applicants
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY applicants_staff_delete ON applicants
  FOR DELETE TO authenticated USING (true);

-- error_submissions: staff can update (mark resolved) and delete
CREATE POLICY error_submissions_staff_update ON error_submissions
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY error_submissions_staff_delete ON error_submissions
  FOR DELETE TO authenticated USING (true);

-- feedback_log: staff can insert (manual entry) and update
CREATE POLICY feedback_log_staff_insert ON feedback_log
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY feedback_log_staff_update ON feedback_log
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- =============================================================
-- SERVICE ROLE ONLY — no anon or authenticated policies
-- audit_log, teacher_roster_log, elvanto_import have no policies
-- defined here. service_role bypasses RLS and can access them
-- freely. Authenticated staff have SELECT only (defined above).
-- These tables should never be writable from the client.
-- =============================================================

-- (no additional policies needed — service_role bypass covers writes)
