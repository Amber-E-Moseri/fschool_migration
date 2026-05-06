-- =============================================================
-- 002_seed_data.sql
-- Foundation School — safe, idempotent seed data
-- =============================================================
--
-- IMPORTANT — tables that require CSV import before go-live:
-- ┌──────────────────┬────────────────────────────────────────────────────┐
-- │ Table            │ Source                                             │
-- ├──────────────────┼────────────────────────────────────────────────────┤
-- │ fellowship_map   │ Export FELLOWSHIP_MAP sheet → CSV → import via     │
-- │                  │ Supabase dashboard or COPY command.                │
-- │                  │ Do NOT rely on this file for fellowship data.      │
-- ├──────────────────┼────────────────────────────────────────────────────┤
-- │ teachers         │ Export TEACHERS sheet → CSV. Preserve teacher_id   │
-- │                  │ text values exactly as used in Apps Script.        │
-- ├──────────────────┼────────────────────────────────────────────────────┤
-- │ class_options    │ Export CLASS_OPTIONS sheet → CSV. Preserve         │
-- │                  │ class_option_id and class_id text values exactly.  │
-- │                  │ Note: column "time" → renamed to "class_time".     │
-- └──────────────────┴────────────────────────────────────────────────────┘
--
-- All INSERT statements use ON CONFLICT DO NOTHING so this file
-- is safe to re-run at any time without duplicating rows.
-- =============================================================


-- =============================================================
-- 1. config
-- System-level key/value configuration.
-- =============================================================

INSERT INTO config (key, value) VALUES

  -- Core system identifiers
  -- FILL THESE IN before running in production:
  ('FORM_ID_OR_URL',            ''),                        -- TODO: set to Phase 1 registration form ID
  ('SYSTEM_SPREADSHEET_ID',     ''),                        -- TODO: set to Foundation School spreadsheet ID

  -- Timezone
  ('SYSTEM_TIMEZONE',           'America/Toronto'),

  -- Form / UI behaviour (from 00_Config.gs)
  ('INCLUDE_CLASS_ID_IN_LABEL', 'false'),
  ('WEEKDAY_NORMALIZE',         'true'),
  ('SORT_CHOICES',              'true'),
  ('EMPTY_CHOICE_LABEL',        '(No active classes yet)'),

  -- Email sender identity (from 00_Constants.js)
  ('SENDER_NAME',               'Foundation School Team'),
  ('REPLY_TO',                  'info@lwcanada.org'),
  ('SEND_AS',                   ''),
  ('FS_ADMIN_EMAIL',            'info@lwcanada.org'),

  -- Teacher roster cadence (from 00_Constants.js)
  ('ROSTER_SEND_MODE',          'DAILY'),
  ('ROSTER_SEND_HOUR',          '7'),
  ('ROSTER_SEND_WEEKDAY',       '1'),       -- 1 = Monday

  -- Email type constants
  ('EMAIL_TYPE_TEACHER_ROSTER', 'TEACHER_ROSTER'),
  ('ROSTER_SEND_TYPE_T_MINUS_3','T_MINUS_3'),
  ('ROSTER_SEND_TYPE_DAY_OF',   'DAY_OF'),

  -- Script property key (Apps Script parity reference)
  ('PROP_LAST_RESPONSE_ID',     'FS_LAST_PROCESSED_RESPONSE_ID'),

  -- Phase 1 form labels (from 00_Config.gs)
  ('PHASE1_NONE_OPTION',              'None of these times work for me'),
  ('PHASE1_SECTION_QUESTION_TITLE',   'Which class would you like to join?'),
  ('PHASE1_ENTRY_QUESTION_TITLE',     'Which fellowship are you from?'),
  ('CAMPUS_QUESTION_TITLE',           'Which campus are you from?'),
  ('FULLNAME_Q_TITLE',                'Full Name'),
  ('EMAIL_Q_TITLE',                   'Email'),
  ('PHONE_Q_TITLE',                   'Phone Number'),
  ('FIRSTNAME_Q_TITLE',               'First Name'),
  ('LASTNAME_Q_TITLE',                'Last Name'),

  -- Attendance form
  ('ATTENDANCE_FORM_TITLE_PREFIX',    'Foundation School Attendance')

ON CONFLICT (key) DO NOTHING;


-- =============================================================
-- 2. batches
-- =============================================================
--
-- IMPORTANT — column rename notice:
-- Migration 004_batch_management.sql renames the "name" column to
-- "batch_name". This INSERT uses "name" because 002 runs BEFORE 004
-- in the standard 001→002→003→004 sequence. Do NOT add new batch rows
-- using "name" after applying 004; use "batch_name" instead.
--
-- To add batches in production: use the Batch Management section in
-- the admin portal, or INSERT directly using batch_name.

INSERT INTO batches (
  batch_id,
  name,
  start_sunday,
  start_date,
  registration_open,
  active
) VALUES (
  '2025A',
  'Foundation School 2025 — Batch A',
  '2025-09-01',
  '2025-09-01',
  false,
  true
)
ON CONFLICT (batch_id) DO NOTHING;


-- =============================================================
-- 3. email_templates
-- Stub rows — body_html must be filled in before go-live.
-- =============================================================

INSERT INTO email_templates (template_key, subject, body_html, active) VALUES

  ('WELCOME',
   'Welcome to Foundation School',
   '', true),

  ('CLASS_ASSIGNED',
   'Your Foundation School class has been assigned',
   '', true),

  ('TEACHER_ROSTER_DAILY',
   '[Foundation School] Daily Teacher Roster',
   '', true),

  ('TEACHER_ROSTER_WEEKLY',
   '[Foundation School] Weekly Teacher Roster',
   '', true),

  ('WEEK3_FOLLOWUP',
   '[Foundation School] Week 3 Follow-Up',
   '', true),

  ('WEEK6_FOLLOWUP',
   '[Foundation School] Week 6 Follow-Up',
   '', true),

  ('ATTENDANCE_FLAG_CLASS1',
   '[Foundation School] Class 1 No-Show Alert',
   '', true),

  ('ATTENDANCE_FLAG_REPEAT',
   '[Foundation School] Repeat Absentee Alert',
   '', true),

  ('GRADUATION_READY',
   'Congratulations — You Are Ready to Graduate!',
   '', true),

  ('TRANSITION_OVERDUE',
   '[Foundation School] Cell Placement Overdue',
   '', true)

ON CONFLICT (template_key) DO NOTHING;
