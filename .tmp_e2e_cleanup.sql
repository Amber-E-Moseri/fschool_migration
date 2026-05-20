WITH del_moodle AS (
  DELETE FROM public.moodle_enrollment_sync
  WHERE email = 'moseriamber@gmail.com'
    AND full_name LIKE 'E2E_TEST%'
  RETURNING id
), del_email AS (
  DELETE FROM public.email_queue
  WHERE recipient_email = 'moseriamber@gmail.com'
    AND subject LIKE 'E2E TEST%'
  RETURNING id
), del_students AS (
  DELETE FROM public.students
  WHERE email = 'moseriamber@gmail.com'
    AND student_id LIKE 'STU-E2E-%'
  RETURNING student_id
), del_applicants AS (
  DELETE FROM public.applicants
  WHERE email = 'moseriamber@gmail.com'
    AND first_name LIKE 'E2E_TEST%'
  RETURNING id
), del_teachers AS (
  DELETE FROM public.teachers
  WHERE teacher_id = 'T-E2ETEST1'
  RETURNING teacher_id
), del_audit AS (
  DELETE FROM public.audit_logs
  WHERE details::text LIKE '%E2E_TEST%'
  RETURNING id
)
SELECT
  (SELECT count(*) FROM del_moodle) AS moodle_deleted,
  (SELECT count(*) FROM del_email) AS email_deleted,
  (SELECT count(*) FROM del_students) AS students_deleted,
  (SELECT count(*) FROM del_applicants) AS applicants_deleted,
  (SELECT count(*) FROM del_teachers) AS teachers_deleted,
  (SELECT count(*) FROM del_audit) AS audit_deleted;