insert into public.notification_templates (template_key, subject, body_html, active)
values (
  'missed_class_checkin',
  'We missed you at Foundation School',
  '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>We missed you at Foundation School</title>
  <style>
    body { margin: 0; padding: 0; background: #f5f3ff; font-family: ''Manrope'', ''DM Sans'', Arial, sans-serif; }
    .wrapper { max-width: 600px; margin: 32px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 2px 12px rgba(76,42,146,.10); }
    .header { background: #4C2A92; padding: 32px 40px 24px; text-align: center; }
    .header h1 { margin: 0; color: #fff; font-size: 22px; font-weight: 800; letter-spacing: -.01em; }
    .header p { margin: 6px 0 0; color: rgba(255,255,255,.75); font-size: 14px; }
    .body { padding: 32px 40px; color: #1a1a2e; }
    .body p { margin: 0 0 16px; line-height: 1.65; font-size: 15px; }
    .body .name { font-weight: 800; color: #4C2A92; }
    .detail-box { background: #f5f3ff; border-left: 4px solid #4C2A92; border-radius: 8px; padding: 14px 18px; margin: 20px 0; font-size: 14px; color: #3d2080; line-height: 1.6; }
    .cta { text-align: center; margin: 28px 0; }
    .cta a { display: inline-block; background: #4C2A92; color: #fff; text-decoration: none; padding: 13px 32px; border-radius: 999px; font-weight: 800; font-size: 15px; letter-spacing: .01em; }
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
      <p>Hi <span class="name">{{first_name}}</span>,</p>
      <p>We noticed you weren''t with us at the last Foundation School session and we just wanted to check in — you are missed!</p>
      <div class="detail-box">
        <strong>Your class:</strong> {{class_time}}<br />
        <strong>Your teacher:</strong> {{teacher_name}}
      </div>
      <p>We know life gets busy, and we completely understand. Foundation School is a journey, and every session counts toward building a strong foundation in your walk with God.</p>
      <p>If there''s anything going on or if you need any support, please don''t hesitate to reach out — we are here for you.</p>
      <p>We''d love to see you at the next session. You belong here!</p>
      <div class="cta">
        <a href="mailto:foundation@lwcanada.org">Get in Touch</a>
      </div>
      <p>With love,<br /><strong>The Rock Solid Foundation School Team</strong><br />BLW Canada</p>
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
  set subject   = excluded.subject,
      body_html = excluded.body_html,
      active    = excluded.active,
      updated_at = now();
