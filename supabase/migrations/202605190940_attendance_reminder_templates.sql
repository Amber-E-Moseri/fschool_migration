insert into public.email_templates (template_key, subject, body_html, active)
values
(
  'attendance_reminder',
  'Attendance reminder — {{class_name}} Session {{session_number}}',
  '<p>Please submit attendance for your class session on {{session_date}}.</p><p>Log in at {{portal_url}} to submit.</p>',
  true
),
(
  'attendance_escalation',
  'Missing attendance — {{teacher_name}} {{class_name}}',
  '<p>Attendance has not been submitted for {{class_name}} Session {{session_number}} ({{session_date}}).</p><p>Teacher: {{teacher_name}}.</p>',
  true
)
on conflict (template_key) do update
set subject = excluded.subject,
    body_html = excluded.body_html,
    active = excluded.active,
    updated_at = now();

