INSERT INTO public.moodle_enrollment_sync (
  id, applicant_id, email, full_name, batch_id, class_option_id, registration_status, sync_status, payload, created_at, updated_at
)
SELECT
  gen_random_uuid(),
  a.id,
  a.email,
  'E2E_TEST Applicant',
  a.batch_id,
  a.class_option_id,
  'ASSIGNED',
  'PENDING',
  jsonb_build_object('source','E2E_TEST','fellowship_code',a.fellowship_code),
  now(),
  now()
FROM public.applicants a
WHERE a.id = '21193568-773b-46f2-8be5-7366d50460ee'
AND a.registration_status = 'ASSIGNED'
LIMIT 1
RETURNING id, applicant_id, email, sync_status, batch_id, class_option_id, created_at;