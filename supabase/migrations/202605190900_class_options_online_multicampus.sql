-- Add online/multi-campus metadata to class options.
-- Additive only: does not alter existing keys or attendance/moodle logic.

ALTER TABLE public.class_options
  ADD COLUMN IF NOT EXISTS is_online BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS confirmed_start_date DATE NULL;

