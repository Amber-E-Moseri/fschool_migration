-- =============================================================
-- 001_initial_schema.sql
-- Supabase / PostgreSQL initial schema for Foundation School
-- Migrated from: Google Apps Script + Google Sheets system
-- Groups: CE (Central East), CS (Central South), WS (West)
-- =============================================================


-- =============================================================
-- UTILITY: auto-update updated_at on every row change
-- =============================================================

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


-- =============================================================
-- LEVEL 0: Foundation tables — no foreign key dependencies
-- =============================================================

-- ── config ───────────────────────────────────────────────────
-- Replaces: CONFIG sheet
CREATE TABLE config (
  key        TEXT        PRIMARY KEY,
  value      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE config IS
  'Replaces: CONFIG sheet. Key/value system configuration (form IDs, feature flags, timezone settings).';

CREATE TRIGGER trg_config_updated_at
  BEFORE UPDATE ON config
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── fellowship_map ───────────────────────────────────────────
-- Replaces: FELLOWSHIP_MAP sheet
CREATE TABLE fellowship_map (
  fellowship_code TEXT        PRIMARY KEY,
  campus_name     TEXT        NOT NULL,
  group_id        TEXT        NOT NULL,   -- CE | CS | WS
  subgroup_id     TEXT        NOT NULL,   -- e.g. CESGA, CESGB, CSGA, WSGA
  active          BOOLEAN     NOT NULL DEFAULT true,
  timezone        TEXT        NOT NULL DEFAULT 'America/Toronto',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_fellowship_map_group_id CHECK (group_id IN ('CE', 'CS', 'WS'))
);
COMMENT ON TABLE fellowship_map IS
  'Replaces: FELLOWSHIP_MAP sheet. Maps campus codes (e.g. CMU, YORK) to group (CE/CS/WS) and subgroup.';

CREATE INDEX idx_fellowship_map_group_id    ON fellowship_map (group_id);
CREATE INDEX idx_fellowship_map_subgroup_id ON fellowship_map (subgroup_id);

CREATE TRIGGER trg_fellowship_map_updated_at
  BEFORE UPDATE ON fellowship_map
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── teachers ─────────────────────────────────────────────────
-- Replaces: TEACHERS sheet
CREATE TABLE teachers (
  teacher_id  TEXT        PRIMARY KEY,   -- preserved text ID from Apps Script
  full_name   TEXT        NOT NULL,
  email       TEXT,
  phone       TEXT,
  group_id    TEXT,
  subgroup_id TEXT,
  active      BOOLEAN     NOT NULL DEFAULT true,
  notes       TEXT,
  deleted_at  TIMESTAMPTZ,               -- soft delete: non-null means removed
  created_by  TEXT,
  updated_by  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE teachers IS
  'Replaces: TEACHERS sheet. Teacher records; soft-deleted via deleted_at.';

CREATE INDEX idx_teachers_email       ON teachers (email);
CREATE INDEX idx_teachers_group_id    ON teachers (group_id);
CREATE INDEX idx_teachers_not_deleted ON teachers (teacher_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_teachers_updated_at
  BEFORE UPDATE ON teachers
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── email_templates ──────────────────────────────────────────
-- Replaces: EMAIL_TEMPLATES sheet
CREATE TABLE email_templates (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key TEXT        NOT NULL UNIQUE,
  subject      TEXT        NOT NULL,
  body_html    TEXT,
  body_text    TEXT,
  active       BOOLEAN     NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE email_templates IS
  'Replaces: EMAIL_TEMPLATES sheet. Reusable email templates keyed by template_key.';

CREATE TRIGGER trg_email_templates_updated_at
  BEFORE UPDATE ON email_templates
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── sync_log ─────────────────────────────────────────────────
-- Replaces: SYNC_LOG sheet
CREATE TABLE sync_log (
  id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  logged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  phase     TEXT,
  message   TEXT,
  details   JSONB,
  run_by    TEXT
);
COMMENT ON TABLE sync_log IS
  'Replaces: SYNC_LOG sheet. Operational log of automated sync/trigger runs.';

CREATE INDEX idx_sync_log_phase     ON sync_log (phase);
CREATE INDEX idx_sync_log_logged_at ON sync_log (logged_at DESC);


-- ── audit_log ────────────────────────────────────────────────
-- Replaces: AUDIT_LOG sheet
CREATE TABLE audit_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  action      TEXT        NOT NULL,
  entity_type TEXT,
  entity_id   TEXT,
  before_data JSONB,
  after_data  JSONB,
  notes       TEXT,
  changed_by  TEXT
);
COMMENT ON TABLE audit_log IS
  'Replaces: AUDIT_LOG sheet. Tracks before/after state for entity changes (auditing).';

CREATE INDEX idx_audit_log_entity_type ON audit_log (entity_type);
CREATE INDEX idx_audit_log_entity_id   ON audit_log (entity_id);


-- ── elvanto_import ───────────────────────────────────────────
-- Replaces: ELVANTO_IMPORT sheet
-- Staging table for members imported from Elvanto CRM before promotion to ft_pipeline.
CREATE TABLE elvanto_import (
  id                         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email                      TEXT        NOT NULL,
  full_name                  TEXT,
  date_added                 DATE,
  processed_to_eligible_pool BOOLEAN     NOT NULL DEFAULT false,
  imported_date              TIMESTAMPTZ,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE elvanto_import IS
  'Replaces: ELVANTO_IMPORT sheet. Staging for Elvanto CRM member imports before ft_pipeline promotion.';

CREATE INDEX idx_elvanto_import_email     ON elvanto_import (email);
CREATE INDEX idx_elvanto_import_processed ON elvanto_import (processed_to_eligible_pool);

CREATE TRIGGER trg_elvanto_import_updated_at
  BEFORE UPDATE ON elvanto_import
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── batches ──────────────────────────────────────────────────
-- NEW: Foundation School cohort/batch table.
-- Must be created before all tables that carry batch_id so FK constraints resolve.
CREATE TABLE batches (
  batch_id          TEXT        PRIMARY KEY,   -- preserved text ID (e.g. '2025A', 'B3')
  name              TEXT,
  start_sunday      DATE,
  start_date        DATE,
  end_date          DATE,
  registration_open BOOLEAN     NOT NULL DEFAULT false,
  active            BOOLEAN     NOT NULL DEFAULT true,
  created_by        TEXT,
  updated_by        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_batches_dates
    CHECK (start_date IS NULL OR start_sunday IS NULL OR start_date >= start_sunday)
);
COMMENT ON TABLE batches IS
  'NEW: Foundation School cohort/batch records. batch_id is the preserved text ID used throughout the Apps Script system.';

CREATE INDEX idx_batches_active ON batches (active);

CREATE TRIGGER trg_batches_updated_at
  BEFORE UPDATE ON batches
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================
-- LEVEL 1: Depends on teachers / batches
-- =============================================================

-- ── class_options ────────────────────────────────────────────
-- Replaces: CLASS_OPTIONS sheet
-- class_option_id = preserved text PK for this scheduled offering row
-- class_id        = curriculum/class label (e.g. the ClassID in Apps Script forms)
--                   Multiple class_options rows can share the same class_id
--                   (different time slots for the same curriculum unit).
CREATE TABLE class_options (
  class_option_id  TEXT        PRIMARY KEY,   -- preserved text ID from Apps Script
  class_id         TEXT        NOT NULL,       -- curriculum label (ClassID in Apps Script)
  teacher_id       TEXT        REFERENCES teachers(teacher_id)
                               ON DELETE SET NULL,
  teacher_name     TEXT,
  fellowship_codes TEXT[]      NOT NULL DEFAULT '{}',  -- e.g. '{CMU,YORK}'
  group_id         TEXT        NOT NULL,
  subgroup_id      TEXT        NOT NULL,
  day              TEXT,                -- e.g. 'Monday'
  class_time       TIME,
  active           BOOLEAN     NOT NULL DEFAULT false,
  enrollment_open  BOOLEAN     NOT NULL DEFAULT false,
  max_capacity     INTEGER,
  label_suffix     TEXT,                -- appended to teacher/time label in registration forms
  deleted_at       TIMESTAMPTZ,         -- soft delete
  created_by       TEXT,
  updated_by       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE class_options IS
  'Replaces: CLASS_OPTIONS sheet. Scheduled class offerings; class_option_id is the row PK, class_id is the curriculum label.';

CREATE INDEX idx_class_options_class_id         ON class_options (class_id);
CREATE INDEX idx_class_options_teacher_id       ON class_options (teacher_id);
CREATE INDEX idx_class_options_group_id         ON class_options (group_id);
CREATE INDEX idx_class_options_subgroup_id      ON class_options (subgroup_id);
CREATE INDEX idx_class_options_active           ON class_options (active);
CREATE INDEX idx_class_options_enrollment_open  ON class_options (enrollment_open);
CREATE INDEX idx_class_options_fellowship_codes ON class_options USING gin (fellowship_codes);
CREATE INDEX idx_class_options_not_deleted      ON class_options (class_option_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_class_options_updated_at
  BEFORE UPDATE ON class_options
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── form_sections ────────────────────────────────────────────
-- Replaces: FORM_SECTIONS sheet
CREATE TABLE form_sections (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  section_title    TEXT        NOT NULL,
  question_title   TEXT,
  fellowship_codes TEXT[]      NOT NULL DEFAULT '{}',
  group_id         TEXT        NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE form_sections IS
  'Replaces: FORM_SECTIONS sheet. Campus-based sections within group registration forms, rebuilt automatically.';

CREATE INDEX idx_form_sections_group_id ON form_sections (group_id);

CREATE TRIGGER trg_form_sections_updated_at
  BEFORE UPDATE ON form_sections
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================
-- LEVEL 2: Depends on class_options / fellowship_map / batches
-- =============================================================

-- ── class_slots ──────────────────────────────────────────────
-- Replaces: CLASS_SLOTS sheet
-- Running batch instances of class_options; tracks enrolment and status per batch.
CREATE TABLE class_slots (
  class_slot_id   TEXT        PRIMARY KEY,
  class_option_id TEXT        REFERENCES class_options(class_option_id)
                              ON DELETE RESTRICT,
  teacher_id      TEXT        REFERENCES teachers(teacher_id)
                              ON DELETE SET NULL,
  teacher_name    TEXT,
  group_id        TEXT        NOT NULL,
  subgroup_id     TEXT        NOT NULL,
  batch_id        TEXT        NOT NULL
                  REFERENCES batches(batch_id)
                  ON DELETE RESTRICT,
  status          TEXT        NOT NULL DEFAULT 'Active'
                  CHECK (status IN ('Active', 'Closed', 'Cancelled')),
  current_enrolment INTEGER   NOT NULL DEFAULT 0,
  max_capacity    INTEGER,
  created_by      TEXT,
  updated_by      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE class_slots IS
  'Replaces: CLASS_SLOTS sheet. Running class instances per batch; tracks enrolment count and status.';

CREATE INDEX idx_class_slots_class_option_id ON class_slots (class_option_id);
CREATE INDEX idx_class_slots_teacher_id      ON class_slots (teacher_id);
CREATE INDEX idx_class_slots_group_id        ON class_slots (group_id);
CREATE INDEX idx_class_slots_batch_id        ON class_slots (batch_id);
CREATE INDEX idx_class_slots_status          ON class_slots (status);

CREATE TRIGGER trg_class_slots_updated_at
  BEFORE UPDATE ON class_slots
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── applicants ───────────────────────────────────────────────
-- Replaces: APPLICANTS sheet
-- Phase 1 registration form submissions.
CREATE TABLE applicants (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name        TEXT        NOT NULL,
  last_name         TEXT        NOT NULL,
  email             TEXT        NOT NULL,
  phone             TEXT,
  fellowship_code   TEXT        REFERENCES fellowship_map(fellowship_code)
                                ON DELETE RESTRICT,
  group_id          TEXT,
  class_option_id   TEXT        REFERENCES class_options(class_option_id)
                                ON DELETE SET NULL,
  born_again        TEXT,         -- 'Yes' | 'No' | "I'm don't know"
  speaks_in_tongues TEXT,         -- 'Yes' | 'No' | "I'm not sure"
  water_baptized    TEXT,         -- 'Yes' | 'No'
  status            TEXT        NOT NULL DEFAULT 'Pending'
                    CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Enrolled')),
  submitted_at      TIMESTAMPTZ,
  created_by        TEXT,
  updated_by        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE applicants IS
  'Replaces: APPLICANTS sheet. Phase 1 intake form submissions; source of truth for registered applicants.';

CREATE INDEX idx_applicants_email             ON applicants (email);
CREATE INDEX idx_applicants_fellowship_code   ON applicants (fellowship_code);
CREATE INDEX idx_applicants_group_id          ON applicants (group_id);
CREATE INDEX idx_applicants_class_option_id   ON applicants (class_option_id);
CREATE INDEX idx_applicants_status            ON applicants (status);
CREATE UNIQUE INDEX uq_applicants_email_pending ON applicants (email) WHERE status = 'Pending';

CREATE TRIGGER trg_applicants_updated_at
  BEFORE UPDATE ON applicants
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── teacher_availability ─────────────────────────────────────
-- NEW: teacher scheduling availability per batch/offering.
-- Drives the teacher-availability scheduling UI (ui/teacher-availability/).
CREATE TABLE teacher_availability (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id      TEXT        NOT NULL
                  REFERENCES teachers(teacher_id)
                  ON DELETE RESTRICT,
  class_option_id TEXT        REFERENCES class_options(class_option_id)
                              ON DELETE SET NULL,
  batch_id        TEXT        REFERENCES batches(batch_id)
                              ON DELETE SET NULL,
  day             TEXT,
  time_slot       TIME,
  status          TEXT        NOT NULL DEFAULT 'Available'
                  CHECK (status IN ('Available', 'Unavailable', 'Tentative')),
  notes           TEXT,
  created_by      TEXT,
  updated_by      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE teacher_availability IS
  'NEW: Teacher scheduling availability per batch/offering; drives the teacher-availability scheduling UI.';

CREATE INDEX idx_teacher_availability_teacher_id      ON teacher_availability (teacher_id);
CREATE INDEX idx_teacher_availability_class_option_id ON teacher_availability (class_option_id);
CREATE INDEX idx_teacher_availability_batch_id        ON teacher_availability (batch_id);
CREATE INDEX idx_teacher_availability_status          ON teacher_availability (status);

CREATE TRIGGER trg_teacher_availability_updated_at
  BEFORE UPDATE ON teacher_availability
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================
-- LEVEL 3: Depends on class_options / fellowship_map / batches
-- =============================================================

-- ── students ─────────────────────────────────────────────────
-- Replaces: STUDENTS sheet
-- Core enrolled-student table; class assignment, status, flags, and pool state.
CREATE TABLE students (
  student_id             TEXT        PRIMARY KEY,   -- preserved text ID from Apps Script
  full_name              TEXT        NOT NULL,
  email                  TEXT        NOT NULL,
  phone                  TEXT,
  group_id               TEXT        NOT NULL,
  subgroup_id            TEXT        NOT NULL,
  fellowship_code        TEXT        REFERENCES fellowship_map(fellowship_code)
                                     ON DELETE RESTRICT,
  batch_id               TEXT        REFERENCES batches(batch_id)
                                     ON DELETE SET NULL,
  class_option_id        TEXT        REFERENCES class_options(class_option_id)
                                     ON DELETE RESTRICT,
  teacher_id             TEXT        REFERENCES teachers(teacher_id)
                                     ON DELETE SET NULL,
  teacher_name           TEXT,
  status                 TEXT        NOT NULL DEFAULT 'Active'
                         CHECK (status IN ('Active', 'At Risk', 'Withdrawn', 'Graduated')),
  eligible_for_fs        BOOLEAN     NOT NULL DEFAULT false,
  date_added_elvanto     DATE,
  needs_attention_flag   BOOLEAN     NOT NULL DEFAULT false,
  needs_attention_reason TEXT,
  reason_not_started     TEXT,
  owner                  TEXT,         -- admin point-of-contact
  deleted_at             TIMESTAMPTZ,  -- soft delete
  created_by             TEXT,
  updated_by             TEXT,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_students_email UNIQUE (email)
);
COMMENT ON TABLE students IS
  'Replaces: STUDENTS sheet. Enrolled student records; soft-deleted via deleted_at.';

CREATE INDEX idx_students_email                ON students (email);
CREATE INDEX idx_students_group_id             ON students (group_id);
CREATE INDEX idx_students_subgroup_id          ON students (subgroup_id);
CREATE INDEX idx_students_class_option_id      ON students (class_option_id);
CREATE INDEX idx_students_teacher_id           ON students (teacher_id);
CREATE INDEX idx_students_batch_id             ON students (batch_id);
CREATE INDEX idx_students_status               ON students (status);
CREATE INDEX idx_students_fellowship_code      ON students (fellowship_code);
CREATE INDEX idx_students_not_deleted          ON students (student_id)       WHERE deleted_at IS NULL;

CREATE TRIGGER trg_students_updated_at
  BEFORE UPDATE ON students
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── attendance_forms ─────────────────────────────────────────
-- Replaces: ATTENDANCE_FORMS sheet
-- Registry of attendance form instances (one per group/subgroup/class).
CREATE TABLE attendance_forms (
  attendance_form_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id           TEXT        NOT NULL,
  subgroup_id        TEXT        NOT NULL,
  class_option_id    TEXT        REFERENCES class_options(class_option_id)
                                 ON DELETE RESTRICT,
  teacher_id         TEXT        REFERENCES teachers(teacher_id)
                                 ON DELETE SET NULL,
  teacher_name       TEXT,
  form_id            TEXT,         -- legacy Google Form ID; null for Supabase-native forms
  form_edit_url      TEXT,
  form_published_url TEXT,
  active             BOOLEAN     NOT NULL DEFAULT true,
  last_synced        TIMESTAMPTZ,
  created_by         TEXT,
  updated_by         TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE attendance_forms IS
  'Replaces: ATTENDANCE_FORMS sheet. Registry of attendance form instances per class.';

CREATE INDEX idx_attendance_forms_group_id        ON attendance_forms (group_id);
CREATE INDEX idx_attendance_forms_class_option_id ON attendance_forms (class_option_id);
CREATE INDEX idx_attendance_forms_teacher_id      ON attendance_forms (teacher_id);
CREATE INDEX idx_attendance_forms_active          ON attendance_forms (active);

CREATE TRIGGER trg_attendance_forms_updated_at
  BEFORE UPDATE ON attendance_forms
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── error_submissions ────────────────────────────────────────
-- Replaces: ERROR_SUBMISSIONS sheet
-- Captures form submissions that failed processing for manual triage.
CREATE TABLE error_submissions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  source_form   TEXT,
  raw_data      JSONB,
  error_message TEXT,
  resolved      BOOLEAN     NOT NULL DEFAULT false,
  resolved_by   TEXT,
  resolved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE error_submissions IS
  'Replaces: ERROR_SUBMISSIONS sheet. Failed form submissions for manual triage.';

CREATE INDEX idx_error_submissions_resolved ON error_submissions (resolved);

CREATE TRIGGER trg_error_submissions_updated_at
  BEFORE UPDATE ON error_submissions
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── email_queue ──────────────────────────────────────────────
-- Replaces: EMAIL_QUEUE sheet
CREATE TABLE email_queue (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key    TEXT        REFERENCES email_templates(template_key)
                              ON DELETE SET NULL,
  recipient_email TEXT        NOT NULL,
  recipient_name  TEXT,
  student_id      TEXT        REFERENCES students(student_id)
                              ON DELETE SET NULL,
  subject         TEXT,
  body_html       TEXT,
  status          TEXT        NOT NULL DEFAULT 'Pending'
                  CHECK (status IN ('Pending', 'Sent', 'Failed')),
  sent_at         TIMESTAMPTZ,
  error_message   TEXT,
  metadata        JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE email_queue IS
  'Replaces: EMAIL_QUEUE sheet. Outbound email queue; status tracks Pending → Sent or Failed.';

CREATE INDEX idx_email_queue_recipient_email ON email_queue (recipient_email);
CREATE INDEX idx_email_queue_student_id      ON email_queue (student_id);
CREATE INDEX idx_email_queue_status          ON email_queue (status);

CREATE TRIGGER trg_email_queue_updated_at
  BEFORE UPDATE ON email_queue
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── class_roster ─────────────────────────────────────────────
-- Replaces: CLASS_ROSTER sheet
-- Enrolment roster linking students to class offerings per batch.
CREATE TABLE class_roster (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      TEXT        NOT NULL
                  REFERENCES students(student_id)
                  ON DELETE RESTRICT,
  class_option_id TEXT        NOT NULL
                  REFERENCES class_options(class_option_id)
                  ON DELETE RESTRICT,
  batch_id        TEXT        REFERENCES batches(batch_id)
                              ON DELETE SET NULL,
  group_id        TEXT        NOT NULL,
  subgroup_id     TEXT        NOT NULL,
  enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  status          TEXT        NOT NULL DEFAULT 'Active'
                  CHECK (status IN ('Active', 'Withdrawn', 'Graduated')),
  created_by      TEXT,
  updated_by      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (student_id, class_option_id, batch_id)
);
COMMENT ON TABLE class_roster IS
  'Replaces: CLASS_ROSTER sheet. Enrolment roster; links students to class offerings per batch.';

CREATE INDEX idx_class_roster_student_id      ON class_roster (student_id);
CREATE INDEX idx_class_roster_class_option_id ON class_roster (class_option_id);
CREATE INDEX idx_class_roster_batch_id        ON class_roster (batch_id);
CREATE INDEX idx_class_roster_group_id        ON class_roster (group_id);
CREATE INDEX idx_class_roster_status          ON class_roster (status);

CREATE TRIGGER trg_class_roster_updated_at
  BEFORE UPDATE ON class_roster
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================
-- LEVEL 4: Depends on students
-- =============================================================

-- ── attendance_log ───────────────────────────────────────────
-- Replaces: ATTENDANCE_LOG sheet
-- Per-student per-class-week attendance records with risk detection flags.
-- Requires PostgreSQL 15+ for UNIQUE NULLS NOT DISTINCT.
CREATE TABLE attendance_log (
  attendance_id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id              TEXT        NOT NULL
                          REFERENCES students(student_id)
                          ON DELETE RESTRICT,
  group_id                TEXT        NOT NULL,
  subgroup_id             TEXT        NOT NULL,
  batch_id                TEXT        REFERENCES batches(batch_id)
                                      ON DELETE RESTRICT,
  class_option_id         TEXT        REFERENCES class_options(class_option_id)
                                      ON DELETE RESTRICT,
  teacher_name            TEXT,
  class_number            TEXT,         -- '1'–'7', or '4A'/'4B'
  class_date              DATE,
  present                 BOOLEAN     NOT NULL DEFAULT false,
  made_up                 BOOLEAN     NOT NULL DEFAULT false,
  makeup_date             DATE,
  submitted_by_teacher    BOOLEAN     NOT NULL DEFAULT false,
  submission_date         TIMESTAMPTZ,
  missing_submission_flag BOOLEAN     NOT NULL DEFAULT false,
  class1_no_show_flag     BOOLEAN     NOT NULL DEFAULT false,
  consecutive_miss_count  INTEGER     NOT NULL DEFAULT 0,
  repeat_absentee_flag    BOOLEAN     NOT NULL DEFAULT false,
  response_id             TEXT,         -- legacy Google Form response ID
  logged_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Prevents duplicate submissions for the same student/class/week/date.
  -- NULLS NOT DISTINCT: two NULLs in the same column are treated as equal,
  -- so a missing class_option_id or class_date still blocks duplicates.
  CONSTRAINT uq_attendance_no_dup
    UNIQUE NULLS NOT DISTINCT (student_id, class_option_id, class_number, class_date),
  -- A row cannot be simultaneously present and counted as a makeup.
  CONSTRAINT chk_attendance_present_makeup CHECK (NOT (present AND made_up))
);
COMMENT ON TABLE attendance_log IS
  'Replaces: ATTENDANCE_LOG sheet. Per-student per-week attendance with risk flags (no-show, repeat absentee, missing submission).';

CREATE INDEX idx_attendance_log_student_id      ON attendance_log (student_id);
CREATE INDEX idx_attendance_log_class_option_id ON attendance_log (class_option_id);
CREATE INDEX idx_attendance_log_batch_id        ON attendance_log (batch_id);
CREATE INDEX idx_attendance_log_group_id        ON attendance_log (group_id);
CREATE INDEX idx_attendance_log_class_number    ON attendance_log (class_number);
CREATE INDEX idx_attendance_log_class_date      ON attendance_log (class_date);
CREATE INDEX idx_attendance_log_student_batch   ON attendance_log (student_id, batch_id);


-- ── ft_pipeline ──────────────────────────────────────────────
-- Replaces: FT_PIPELINE sheet
-- Follow-Through pipeline: Elvanto members not yet enrolled in Foundation School.
-- Populated from elvanto_import; tracks week-3 and week-6 follow-up flags.
CREATE TABLE ft_pipeline (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email            TEXT        NOT NULL UNIQUE,
  full_name        TEXT,
  phone            TEXT,
  date_added       DATE,
  week3_flag_date  DATE,
  week3_flag_fired BOOLEAN     NOT NULL DEFAULT false,
  week6_flag_date  DATE,
  week6_flag_fired BOOLEAN     NOT NULL DEFAULT false,
  contact_notes    TEXT,
  contacted_by     TEXT,
  contact_date     DATE,
  follow_up_status TEXT,
  converted_to_fs  BOOLEAN     NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE ft_pipeline IS
  'Replaces: FT_PIPELINE sheet. Follow-Through tracking for Elvanto members eligible but not yet enrolled.';

CREATE INDEX idx_ft_pipeline_email           ON ft_pipeline (email);
CREATE INDEX idx_ft_pipeline_converted_to_fs ON ft_pipeline (converted_to_fs);
CREATE INDEX idx_ft_pipeline_week3_flag_date ON ft_pipeline (week3_flag_date);
CREATE INDEX idx_ft_pipeline_week6_flag_date ON ft_pipeline (week6_flag_date);

CREATE TRIGGER trg_ft_pipeline_updated_at
  BEFORE UPDATE ON ft_pipeline
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── eligible_pool ────────────────────────────────────────────
-- Replaces: ELIGIBLE_POOL sheet
-- Eligible members not yet graduated; drives the escalation logic
-- (>42 days Not Started → escalation_flag = true).
CREATE TABLE eligible_pool (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id           TEXT        NOT NULL UNIQUE
                       REFERENCES students(student_id)
                       ON DELETE CASCADE,
  full_name            TEXT,
  email                TEXT,
  group_id             TEXT        NOT NULL,
  subgroup_id          TEXT        NOT NULL,
  eligible_pool_status TEXT        NOT NULL DEFAULT 'Not Started'
                       CHECK (eligible_pool_status IN
                         ('Not Started', 'Registered', 'In Progress', 'Graduated')),
  next_action_deadline DATE,
  contact_outcome      TEXT,
  contacted_by         TEXT,
  contact_date         DATE,
  escalation_notes     TEXT,
  reason_not_started   TEXT,
  days_in_pool         INTEGER     NOT NULL DEFAULT 0,
  escalation_flag      BOOLEAN     NOT NULL DEFAULT false,
  created_by           TEXT,
  updated_by           TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE eligible_pool IS
  'Replaces: ELIGIBLE_POOL sheet. Eligible members tracking; escalation_flag fires after 42 days Not Started or overdue deadline.';

CREATE INDEX idx_eligible_pool_email               ON eligible_pool (email);
CREATE INDEX idx_eligible_pool_group_id            ON eligible_pool (group_id);
CREATE INDEX idx_eligible_pool_eligible_pool_status ON eligible_pool (eligible_pool_status);
CREATE INDEX idx_eligible_pool_escalation_flag     ON eligible_pool (escalation_flag);

CREATE TRIGGER trg_eligible_pool_updated_at
  BEFORE UPDATE ON eligible_pool
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── moodle_sync ──────────────────────────────────────────────
-- Replaces: MOODLE_SYNC sheet
-- Per-student Moodle LMS progress synced from the external Moodle instance.
CREATE TABLE moodle_sync (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id            TEXT         NOT NULL
                        REFERENCES students(student_id)
                        ON DELETE RESTRICT,
  batch_id              TEXT         REFERENCES batches(batch_id)
                                     ON DELETE SET NULL,
  subgroup_id           TEXT,
  assignments_completed INTEGER      NOT NULL DEFAULT 0,
  assignments_total     INTEGER      NOT NULL DEFAULT 0,
  exam_passed           BOOLEAN      NOT NULL DEFAULT false,
  moodle_progress       NUMERIC(5,2) NOT NULL DEFAULT 0.00,  -- 0.00–100.00
  synced_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_moodle_sync_student_batch UNIQUE NULLS NOT DISTINCT (student_id, batch_id)
);
COMMENT ON TABLE moodle_sync IS
  'Replaces: MOODLE_SYNC sheet. Moodle LMS data per student: feeds graduation Gate 2 (assignments) and Gate 3 (exam).';

CREATE INDEX idx_moodle_sync_student_id  ON moodle_sync (student_id);
CREATE INDEX idx_moodle_sync_batch_id    ON moodle_sync (batch_id);
CREATE INDEX idx_moodle_sync_subgroup_id ON moodle_sync (subgroup_id);

CREATE TRIGGER trg_moodle_sync_updated_at
  BEFORE UPDATE ON moodle_sync
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── graduation_review ────────────────────────────────────────
-- Replaces: GRADUATION_REVIEW sheet
-- Four-gate graduation readiness tracker per student per batch.
-- Gate 1: all 7 weeks attended or made up (source: attendance_log)
-- Gate 2: all Moodle assignments complete   (source: moodle_sync)
-- Gate 3: Moodle exam passed                (source: moodle_sync)
-- Gate 4: cell group integrated             (manual flag or eligible_pool_status = 'Graduated')
CREATE TABLE graduation_review (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id            TEXT        NOT NULL
                        REFERENCES students(student_id)
                        ON DELETE RESTRICT,
  batch_id              TEXT        NOT NULL
                        REFERENCES batches(batch_id)
                        ON DELETE RESTRICT,
  subgroup_id           TEXT,
  gate1_attendance      BOOLEAN     NOT NULL DEFAULT false,
  gate2_assignments     BOOLEAN     NOT NULL DEFAULT false,
  gate3_exam_passed     BOOLEAN     NOT NULL DEFAULT false,
  gate4_cell_integrated BOOLEAN     NOT NULL DEFAULT false,
  all_gates_met         BOOLEAN     NOT NULL DEFAULT false,
  graduation_status     TEXT        NOT NULL DEFAULT 'Not Ready'
                        CHECK (graduation_status IN ('Not Ready', 'Close', 'Ready')),
  notes                 TEXT,
  last_checked_at       TIMESTAMPTZ,
  reviewed_by           TEXT,
  created_by            TEXT,
  updated_by            TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, batch_id),
  -- all_gates_met must equal the conjunction of all four gate booleans
  CONSTRAINT chk_graduation_all_gates_met
    CHECK (all_gates_met = (gate1_attendance AND gate2_assignments AND gate3_exam_passed AND gate4_cell_integrated)),
  -- graduation_status must be derived from the gate count (mirrors Apps Script logic)
  CONSTRAINT chk_graduation_status
    CHECK (graduation_status = CASE
      WHEN gate1_attendance AND gate2_assignments AND gate3_exam_passed AND gate4_cell_integrated THEN 'Ready'
      WHEN (gate1_attendance::int + gate2_assignments::int + gate3_exam_passed::int + gate4_cell_integrated::int) = 3 THEN 'Close'
      ELSE 'Not Ready'
    END)
);
COMMENT ON TABLE graduation_review IS
  'Replaces: GRADUATION_REVIEW sheet. Four-gate graduation readiness per student per batch.';

CREATE INDEX idx_graduation_review_student_id        ON graduation_review (student_id);
CREATE INDEX idx_graduation_review_batch_id          ON graduation_review (batch_id);
CREATE INDEX idx_graduation_review_graduation_status ON graduation_review (graduation_status);
CREATE INDEX idx_graduation_review_all_gates_met     ON graduation_review (all_gates_met);

CREATE TRIGGER trg_graduation_review_updated_at
  BEFORE UPDATE ON graduation_review
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── teacher_roster_log ───────────────────────────────────────
-- Replaces: TEACHER_ROSTER_LOG sheet
-- Append-only audit trail of teacher-to-class assignment changes.
CREATE TABLE teacher_roster_log (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id          TEXT        NOT NULL
                      REFERENCES teachers(teacher_id)
                      ON DELETE RESTRICT,
  class_option_id     TEXT        REFERENCES class_options(class_option_id)
                                  ON DELETE SET NULL,
  batch_id            TEXT        REFERENCES batches(batch_id)
                                  ON DELETE SET NULL,
  action              TEXT        NOT NULL,   -- Assigned | Removed | Replaced
  previous_teacher_id TEXT,
  notes               TEXT,
  changed_by          TEXT,
  changed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE teacher_roster_log IS
  'Replaces: TEACHER_ROSTER_LOG sheet. Append-only audit trail of teacher assignment events per class.';

CREATE INDEX idx_teacher_roster_log_teacher_id      ON teacher_roster_log (teacher_id);
CREATE INDEX idx_teacher_roster_log_class_option_id ON teacher_roster_log (class_option_id);
CREATE INDEX idx_teacher_roster_log_batch_id        ON teacher_roster_log (batch_id);


-- =============================================================
-- LEVEL 5: Depends on students + graduation_review
-- =============================================================

-- ── makeup_queue ─────────────────────────────────────────────
-- Replaces: MAKEUP_QUEUE (referenced in 70_GRADUATION.js)
-- Tracks missed classes requiring a makeup session before graduation Gate 1 can pass.
CREATE TABLE makeup_queue (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id       TEXT        NOT NULL
                   REFERENCES students(student_id)
                   ON DELETE RESTRICT,
  subgroup_id      TEXT,
  batch_id         TEXT        NOT NULL
                   REFERENCES batches(batch_id)
                   ON DELETE RESTRICT,
  class_number     TEXT        NOT NULL,   -- '1'–'7'
  makeup_type      TEXT        NOT NULL DEFAULT 'Standard',  -- Standard | Escalated
  deadline         DATE,
  makeup_completed BOOLEAN     NOT NULL DEFAULT false,
  completed_date   DATE,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE makeup_queue IS
  'Replaces: MAKEUP_QUEUE sheet. Missed-class makeup queue; unresolved entries block graduation Gate 1.';

CREATE INDEX idx_makeup_queue_student_id       ON makeup_queue (student_id);
CREATE INDEX idx_makeup_queue_batch_id         ON makeup_queue (batch_id);
CREATE INDEX idx_makeup_queue_makeup_completed ON makeup_queue (makeup_completed);

CREATE TRIGGER trg_makeup_queue_updated_at
  BEFORE UPDATE ON makeup_queue
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── transition_log ───────────────────────────────────────────
-- Replaces: TRANSITION_LOG sheet
-- Post-graduation cell placement tracking; overdue_flag fires after 21 days unplaced.
CREATE TABLE transition_log (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id       TEXT        NOT NULL
                   REFERENCES students(student_id)
                   ON DELETE RESTRICT,
  graduation_date  DATE        NOT NULL,
  batch_id         TEXT        REFERENCES batches(batch_id)
                               ON DELETE SET NULL,
  placement_deadline DATE,
  target_group     TEXT,
  placed_by        TEXT,
  placement_date   DATE,
  placement_status TEXT        NOT NULL DEFAULT 'Pending'
                   CHECK (placement_status IN ('Pending', 'Placed', 'Stalled')),
  overdue_flag     BOOLEAN     NOT NULL DEFAULT false,
  notes            TEXT,
  created_by       TEXT,
  updated_by       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE transition_log IS
  'Replaces: TRANSITION_LOG sheet. Post-graduation cell placement; overdue_flag fires at 21 days without placement.';

CREATE INDEX idx_transition_log_student_id       ON transition_log (student_id);
CREATE INDEX idx_transition_log_batch_id         ON transition_log (batch_id);
CREATE INDEX idx_transition_log_placement_status ON transition_log (placement_status);
CREATE INDEX idx_transition_log_overdue_flag     ON transition_log (overdue_flag);

CREATE TRIGGER trg_transition_log_updated_at
  BEFORE UPDATE ON transition_log
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- ── feedback_log ─────────────────────────────────────────────
-- Replaces: FEEDBACK_LOG sheet
-- Student feedback per class/subgroup; overall_score feeds group_summary averages.
CREATE TABLE feedback_log (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      TEXT         REFERENCES students(student_id)
                               ON DELETE SET NULL,
  subgroup_id     TEXT         NOT NULL,
  batch_id        TEXT         REFERENCES batches(batch_id)
                               ON DELETE SET NULL,
  class_option_id TEXT         REFERENCES class_options(class_option_id)
                               ON DELETE SET NULL,
  overall_score   NUMERIC(3,1),  -- e.g. 4.5 out of 5
  comments        TEXT,
  submitted_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON TABLE feedback_log IS
  'Replaces: FEEDBACK_LOG sheet. Student feedback; overall_score aggregated into group_summary.avg_feedback_score.';

CREATE INDEX idx_feedback_log_student_id      ON feedback_log (student_id);
CREATE INDEX idx_feedback_log_subgroup_id     ON feedback_log (subgroup_id);
CREATE INDEX idx_feedback_log_batch_id        ON feedback_log (batch_id);
CREATE INDEX idx_feedback_log_class_option_id ON feedback_log (class_option_id);

CREATE TRIGGER trg_feedback_log_updated_at
  BEFORE UPDATE ON feedback_log
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();


-- =============================================================
-- LEVEL 6: Aggregate / computed tables
-- =============================================================

-- ── group_summary ────────────────────────────────────────────
-- Replaces: GROUP_SUMMARY sheet
-- Denormalized group-level metrics refreshed by the buildGroupSummary job.
CREATE TABLE group_summary (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id              TEXT         NOT NULL,
  subgroup_id           TEXT         NOT NULL,
  total_students        INTEGER      NOT NULL DEFAULT 0,
  active_count          INTEGER      NOT NULL DEFAULT 0,
  at_risk_count         INTEGER      NOT NULL DEFAULT 0,
  eligible_pool_count   INTEGER      NOT NULL DEFAULT 0,
  classes_running       INTEGER      NOT NULL DEFAULT 0,
  avg_moodle_progress   NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  graduated_gates_count INTEGER      NOT NULL DEFAULT 0,
  graduated_count       INTEGER      NOT NULL DEFAULT 0,
  cell_integrated_count INTEGER      NOT NULL DEFAULT 0,
  placed_count          INTEGER      NOT NULL DEFAULT 0,
  ft_conversion_rate    NUMERIC(5,4) NOT NULL DEFAULT 0.0000,  -- 0.0000–1.0000
  avg_feedback_score    NUMERIC(3,1) NOT NULL DEFAULT 0.0,
  last_updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (group_id, subgroup_id)
);
COMMENT ON TABLE group_summary IS
  'Replaces: GROUP_SUMMARY sheet. Denormalized aggregate metrics per group/subgroup; refreshed on demand by buildGroupSummary.';

-- group_id and subgroup_id are covered by UNIQUE (group_id, subgroup_id); no separate indexes needed.

CREATE TRIGGER trg_group_summary_updated_at
  BEFORE UPDATE ON group_summary
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
