insert into public.notification_templates (template_key, subject, body_html, active)
values (
  'batch_rollover_notice',
  'A new Foundation School batch is starting — you are enrolled',
  '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>New Batch Starting</title>
  <style>
    body { margin:0; padding:0; background:#f7f7f7; font-family:''Manrope'',''DM Sans'',Arial,sans-serif; }
    .wrapper { max-width:600px; margin:32px auto; background:#fff; border-radius:16px; overflow:hidden; box-shadow:0 2px 12px rgba(0,0,0,.08); }
    .header { background:#C8102E; padding:28px 40px 22px; text-align:center; }
    .header h1 { margin:0; color:#fff; font-size:20px; font-weight:800; }
    .header p  { margin:6px 0 0; color:rgba(255,255,255,.80); font-size:13px; }
    .body { padding:32px 40px; color:#1a1a2e; }
    .body p { margin:0 0 16px; line-height:1.65; font-size:15px; }
    .name { font-weight:800; color:#C8102E; }
    .info-box { background:#fff0f0; border-left:4px solid #C8102E; border-radius:8px; padding:14px 18px; margin:20px 0; font-size:14px; color:#7f1d1d; line-height:1.6; }
    .cta { text-align:center; margin:28px 0; }
    .cta a { display:inline-block; background:#C8102E; color:#fff; text-decoration:none; padding:12px 30px; border-radius:999px; font-weight:800; font-size:14px; }
    .footer { border-top:1px solid #f0f0f0; padding:20px 40px; text-align:center; color:#888; font-size:12px; line-height:1.7; }
    .footer a { color:#C8102E; text-decoration:none; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>Rock Solid Foundation School</h1>
      <p>BLW Canada &mdash; LoveWorld Canada</p>
    </div>
    <div class="body">
      <p>Dear <span class="name">{{first_name}}</span>,</p>
      <p>Exciting news — a new Foundation School batch is beginning and you have been enrolled!</p>
      <div class="info-box">
        <strong>New Batch: {{new_batch_name}}</strong><br />
        Start Date: {{start_date}}<br />
        Your Class: {{class_day}} at {{class_time}} with {{teacher_name}}
      </div>
      {{#announcement}}
      <p>{{announcement}}</p>
      {{/announcement}}
      <p>We look forward to an amazing term with you. Stay blessed and keep growing!</p>
      <div class="cta">
        <a href="https://rocksolidsuite.netlify.app/foundation/auth/login.html">Log In</a>
      </div>
      <p style="font-size:13px;color:#555;">
        God bless you,<br />
        <strong>The Rock Solid Foundation School Team</strong><br />
        BLW Canada
      </p>
    </div>
    <div class="footer">
      <strong>LoveWorld Canada &mdash; BLW Canada</strong><br />
      Questions? Email <a href="mailto:foundation@lwcanada.org">foundation@lwcanada.org</a>
    </div>
  </div>
</body>
</html>',
  true
)
on conflict (template_key) do update
  set subject   = excluded.subject,
      body_html = excluded.body_html,
      active    = excluded.active,
      updated_at = now();
