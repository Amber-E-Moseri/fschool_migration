-- Late-start attendance support.
-- Additive migration only.

ALTER TABLE public.attendance_log
  ADD COLUMN IF NOT EXISTS session_status TEXT NOT NULL DEFAULT 'SUBMITTED';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_attendance_log_session_status'
      AND conrelid = 'public.attendance_log'::regclass
  ) THEN
    ALTER TABLE public.attendance_log
      ADD CONSTRAINT chk_attendance_log_session_status
      CHECK (session_status IN ('SUBMITTED', 'LATE_START', 'MISSING'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_log_session_status
  ON public.attendance_log (session_status);

ALTER TABLE public.class_options
  ADD COLUMN IF NOT EXISTS confirmed_start_date DATE NULL;

