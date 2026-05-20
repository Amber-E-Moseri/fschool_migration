INSERT INTO public.email_queue (
  id, recipient_email, recipient_name, template_key, subject, payload, status, created_at
) VALUES (
  gen_random_uuid(),
  'moseriamber@gmail.com',
  'E2E_TEST Applicant',
  'foundation_welcome',
  'E2E TEST Welcome to Rock Solid',
  '{"first_name":"E2E_TEST","batch_id":"E2E"}'::jsonb,
  'Pending',
  now()
)
RETURNING id, recipient_email, template_key, status, created_at;