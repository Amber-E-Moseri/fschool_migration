insert into public.email_templates (template_key, subject, body_html, active)
values
(
  'direct_message',
  '{{subject}}',
  '<p>Hello {{recipient_name}},</p><p>{{message}}</p>',
  true
)
on conflict (template_key) do update
set subject = excluded.subject,
    body_html = excluded.body_html,
    active = excluded.active,
    updated_at = now();
