insert into public.notification_templates (template_key, subject, body_html, active)
values (
  'registration_under_review_checkin',
  'An update on your Foundation School registration',
  '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>An update on your Foundation School registration</title>
  <style>
    body { margin: 0; padding: 0; background: #f7f7f7; font-family: ''Manrope'', ''DM Sans'', Arial, sans-serif; }
    .wrapper { max-width: 600px; margin: 32px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,.08); }
    .header { background: #C8102E; padding: 28px 40px 22px; text-align: center; }
    .header h1 { margin: 0; color: #fff; font-size: 22px; font-weight: 800; letter-spacing: -.01em; }
    .header p  { margin: 6px 0 0; color: rgba(255,255,255,.80); font-size: 14px; }
    .body { padding: 32px 40px; color: #1a1a2e; }
    .body p { margin: 0 0 16px; line-height: 1.65; font-size: 15px; }
    .name { font-weight: 800; color: #C8102E; }
    .timeline-box {
      background: #fff5f5; border-left: 4px solid #C8102E; border-radius: 8px;
      padding: 14px 18px; margin: 20px 0; font-size: 14px; color: #7f1d1d; line-height: 1.6;
    }
    .timeline-box strong { display: block; margin-bottom: 4px; font-size: 15px; }
    .cta { text-align: center; margin: 28px 0; }
    .cta a {
      display: inline-block; background: #C8102E; color: #fff; text-decoration: none;
      padding: 13px 32px; border-radius: 999px; font-weight: 800; font-size: 15px;
    }
    .divider { border: none; border-top: 1px solid #f0f0f0; margin: 24px 0; }
    .footer { padding: 20px 40px; text-align: center; color: #888; font-size: 12px; line-height: 1.7; }
    .footer strong { color: #C8102E; }
    .footer a { color: #C8102E; text-decoration: none; }
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
      <p>
        Thank you so much for registering for Rock Solid Foundation School. We want you to know that we
        have received your application and our team is currently reviewing it.
      </p>
      <p>
        You have <strong>not</strong> been forgotten — our team personally reviews every registration
        to ensure you are placed in the right class for your schedule and fellowship community.
      </p>
      <div class="timeline-box">
        <strong>What to expect next</strong>
        Our team aims to complete all reviews within <strong>3&ndash;5 business days</strong>.
        Once your registration is approved, you will receive a separate email with your class assignment
        details.
      </div>
      <p>
        If you have any questions in the meantime, or if anything has changed in your availability,
        please do not hesitate to reply to this email — we are happy to help.
      </p>
      <p>
        We are genuinely excited to have you join Foundation School, and we look forward to
        welcoming you soon!
      </p>
      <div class="cta">
        <a href="mailto:foundation@lwcanada.org">Contact Us</a>
      </div>
      <hr class="divider" />
      <p style="font-size:13px;color:#555;">
        God bless you,<br />
        <strong>The Rock Solid Foundation School Team</strong><br />
        BLW Canada
      </p>
    </div>
    <div class="footer">
      <strong>LoveWorld Canada &mdash; BLW Canada</strong><br />
      You are receiving this because you submitted a registration for Rock Solid Foundation School.<br />
      Questions? Email <a href="mailto:foundation@lwcanada.org">foundation@lwcanada.org</a>
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
