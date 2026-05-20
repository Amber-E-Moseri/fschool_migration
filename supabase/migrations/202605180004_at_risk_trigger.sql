-- Auto-flag at-risk students from attendance streaks

CREATE OR REPLACE FUNCTION public.count_consecutive_misses(
  p_student_id TEXT,
  p_class_option_id TEXT
) RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  v_streak INTEGER := 0;
  r RECORD;
BEGIN
  FOR r IN
    SELECT attended FROM attendance_log
    WHERE student_id = p_student_id
      AND class_option_id = p_class_option_id
    ORDER BY session_date DESC
    LIMIT 10
  LOOP
    IF r.attended = false OR r.attended IS NULL THEN
      v_streak := v_streak + 1;
    ELSE
      EXIT;
    END IF;
  END LOOP;
  RETURN v_streak;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_at_risk_on_attendance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_misses INTEGER;
BEGIN
  v_misses := public.count_consecutive_misses(
    NEW.student_id, NEW.class_option_id
  );
  IF v_misses >= 3 THEN
    UPDATE public.students
    SET needs_attention_flag = true,
        status = 'At Risk',
        needs_attention_reason = '3 or more consecutive missed sessions',
        updated_at = NOW()
    WHERE student_id = NEW.student_id
      AND (status = 'Active' OR status IS NULL);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_at_risk_attendance ON public.attendance_log;
CREATE TRIGGER trg_at_risk_attendance
  AFTER INSERT OR UPDATE ON public.attendance_log
  FOR EACH ROW EXECUTE FUNCTION public.check_at_risk_on_attendance();
