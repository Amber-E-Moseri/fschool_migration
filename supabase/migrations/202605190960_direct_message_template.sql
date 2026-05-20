insert into public.notification_templates (template_key, subject, body_html, active)
values (
  'direct_message',
  '{{subject}}',
  '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{{subject}}</title>
  <style>
    body { margin: 0; padding: 0; background: #f5f3ff; font-family: ''Manrope'', ''DM Sans'', Arial, sans-serif; }
    .wrapper { max-width: 600px; margin: 32px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 2px 12px rgba(76,42,146,.10); }
    .header { background: #4C2A92; padding: 28px 40px 20px; text-align: center; }
    .header h1 { margin: 0; color: #fff; font-size: 20px; font-weight: 800; letter-spacing: -.01em; }
    .header p { margin: 5px 0 0; color: rgba(255,255,255,.75); font-size: 13px; }
    .body { padding: 32px 40px; color: #1a1a2e; }
    .body p { margin: 0 0 16px; line-height: 1.7; font-size: 15px; white-space: pre-line; }
    .footer { border-top: 1px solid #ede9ff; padding: 20px 40px; text-align: center; color: #888; font-size: 12px; line-height: 1.6; }
    .footer strong { color: #4C2A92; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>Rock Solid Foundation School</h1>
      <p>BLW Canada</p>
    </div>
    <div class="body">
      <p>{{message}}</p>
      <p style="margin-top:24px;color:#6f6881;font-size:13px;">Sent by {{sender_email}}</p>
    </div>
    <div class="footer">
      <strong>LoveWorld Canada &mdash; BLW Canada</strong><br />
      You are receiving this because you are registered for Rock Solid Foundation School.<br />
      Questions? Email <a href="mailto:foundation@lwcanada.org" style="color:#4C2A92;">foundation@lwcanada.org</a>
    </div>
  </div>
</body>
</html>',
  true
)
on conflict (template_key) do update
  set subject    = excluded.subject,
      body_html  = excluded.body_html,
      active     = excluded.active,
      updated_at = now();
