-- Ensure Moodle credential template exists with expected placeholders.
insert into public.notification_templates (template_key, subject, body_html, active)
values (
  'moodle_credentials',
  'Your Moodle Access - {{class_label}}',
  '<p>Hi {{first_name}},</p><p>Your Moodle access is ready.</p><p><strong>Portal:</strong> <a href="{{moodle_url}}">{{moodle_url}}</a><br><strong>Username:</strong> {{moodle_username}}<br><strong>Temporary password:</strong> {{moodle_temp_password}}</p><p>Please sign in and reset your password immediately from your Moodle profile settings.</p>',
  true
)
on conflict (template_key) do update
set subject = excluded.subject,
    body_html = excluded.body_html,
    active = true,
    updated_at = now();

do $$
begin
  if to_regclass('public.email_templates') is not null then
    insert into public.email_templates (template_key, subject, body_html, active)
    values (
      'moodle_credentials',
      'Your Moodle Access - {{class_label}}',
      '<p>Hi {{first_name}},</p><p>Your Moodle access is ready.</p><p><strong>Portal:</strong> <a href="{{moodle_url}}">{{moodle_url}}</a><br><strong>Username:</strong> {{moodle_username}}<br><strong>Temporary password:</strong> {{moodle_temp_password}}</p><p>Please sign in and reset your password immediately from your Moodle profile settings.</p>',
      true
    )
    on conflict (template_key) do update
    set subject = excluded.subject,
        body_html = excluded.body_html,
        active = true,
        updated_at = now();
  end if;
end $$;
