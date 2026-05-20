-- Student re-engagement email templates
insert into public.notification_templates
  (template_key, subject, body_html, active)
values

-- Never Started
('engagement_never_started',
 'We saved your spot at Foundation School — {{first_name}}',
 '<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width,initial-scale=1.0" />
<title>Foundation School — Your Spot Is Reserved</title></head>
<body style="margin:0;padding:0;background:#f7f7fb;font-family:''Manrope'',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f7f7fb;padding:32px 0;">
  <tr><td align="center">
    <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;border:1px solid #e8e8f0;box-shadow:0 8px 32px rgba(26,20,43,.08);overflow:hidden;max-width:100%;">
      <tr><td style="background:#4C2A92;padding:28px 32px;text-align:center;">
        <div style="font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.02em;">Rock Solid Foundation School</div>
        <div style="font-size:13px;color:rgba(255,255,255,.75);margin-top:4px;">BLW Canada</div>
      </td></tr>
      <tr><td style="padding:32px;">
        <p style="margin:0 0 16px;font-size:22px;font-weight:800;color:#1a1a2e;">Hi {{first_name}} 👋</p>
        <p style="margin:0 0 16px;font-size:15px;color:#374151;line-height:1.6;">We noticed you''ve been registered for Foundation School but haven''t joined your class yet — and we wanted to reach out personally to let you know: <strong>your spot is still reserved for you.</strong></p>
        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4ff;border:1px solid #c7d2fe;border-radius:12px;padding:16px 20px;margin:0 0 20px;">
          <tr><td>
            <div style="font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:#6366f1;font-weight:700;margin-bottom:8px;">Your Class Details</div>
            <div style="font-size:14px;color:#1a1a2e;">📅 <strong>{{class_time}}</strong></div>
            <div style="font-size:14px;color:#1a1a2e;margin-top:4px;">👩‍🏫 Teacher: <strong>{{teacher_name}}</strong></div>
            <div style="font-size:14px;color:#1a1a2e;margin-top:4px;">🏛️ Fellowship: <strong>{{fellowship_code}}</strong></div>
          </td></tr>
        </table>
        <p style="margin:0 0 16px;font-size:15px;color:#374151;line-height:1.6;">Your Moodle learning account has already been set up and is ready for you at <a href="https://rocksolid.lwcanada.org/" style="color:#4C2A92;font-weight:600;">rocksolid.lwcanada.org</a>. Log in using the email address this message was sent to.</p>
        <p style="margin:0 0 24px;font-size:15px;color:#374151;line-height:1.6;">If you need help getting started or have any questions, simply reply to this email — we''re here for you!</p>
        <table cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
          <tr><td style="background:#C8102E;border-radius:10px;padding:14px 28px;">
            <a href="https://rocksolid.lwcanada.org/" style="color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;">Go to My Class →</a>
          </td></tr>
        </table>
        <p style="margin:0;font-size:13px;color:#9ca3af;">We''re excited to have you in Foundation School. See you soon!<br>— The Rock Solid Foundation School Team</p>
      </td></tr>
      <tr><td style="background:#f7f7fb;padding:16px 32px;text-align:center;border-top:1px solid #e8e8f0;">
        <p style="margin:0;font-size:11px;color:#9ca3af;">Rock Solid Foundation School · BLW Canada · lwcanada.org</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>',
 true),

-- Dropped Off
('engagement_dropped_off',
 'We miss you at Foundation School — {{first_name}}',
 '<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width,initial-scale=1.0" />
<title>Foundation School — We Miss You</title></head>
<body style="margin:0;padding:0;background:#f7f7fb;font-family:''Manrope'',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f7f7fb;padding:32px 0;">
  <tr><td align="center">
    <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;border:1px solid #e8e8f0;box-shadow:0 8px 32px rgba(26,20,43,.08);overflow:hidden;max-width:100%;">
      <tr><td style="background:#4C2A92;padding:28px 32px;text-align:center;">
        <div style="font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.02em;">Rock Solid Foundation School</div>
        <div style="font-size:13px;color:rgba(255,255,255,.75);margin-top:4px;">BLW Canada</div>
      </td></tr>
      <tr><td style="padding:32px;">
        <p style="margin:0 0 16px;font-size:22px;font-weight:800;color:#1a1a2e;">Hi {{first_name}} 💙</p>
        <p style="margin:0 0 16px;font-size:15px;color:#374151;line-height:1.6;">The team has been thinking about you. We noticed it''s been a little while since we last saw you in class, and we just wanted to check in — <strong>how are you doing?</strong></p>
        <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff7ed;border:1px solid #fed7aa;border-radius:12px;padding:16px 20px;margin:0 0 20px;">
          <tr><td>
            <div style="font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:#c2410c;font-weight:700;margin-bottom:8px;">Your Class</div>
            <div style="font-size:14px;color:#1a1a2e;">📅 <strong>{{class_time}}</strong> with <strong>{{teacher_name}}</strong></div>
            <div style="font-size:14px;color:#6b7280;margin-top:4px;">Your last attended session: <strong>{{last_attended_date}}</strong></div>
            <div style="font-size:14px;color:#6b7280;margin-top:2px;">Sessions you may have missed: <strong>{{sessions_missed}}</strong></div>
          </td></tr>
        </table>
        <p style="margin:0 0 16px;font-size:15px;color:#374151;line-height:1.6;">There is still so much wonderful content ahead, and your classmates and teacher would love to see you back. If something has come up or you need to switch to a different class time, we''re happy to help!</p>
        <p style="margin:0 0 24px;font-size:15px;color:#374151;line-height:1.6;">Simply reply to this email and let us know, or jump back in at <a href="https://rocksolid.lwcanada.org/" style="color:#4C2A92;font-weight:600;">rocksolid.lwcanada.org</a>.</p>
        <table cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
          <tr><td style="background:#C8102E;border-radius:10px;padding:14px 28px;">
            <a href="https://rocksolid.lwcanada.org/" style="color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;">Return to My Class →</a>
          </td></tr>
        </table>
        <p style="margin:0;font-size:13px;color:#9ca3af;">We care about your growth and want to see you thrive in this course.<br>— The Rock Solid Foundation School Team</p>
      </td></tr>
      <tr><td style="background:#f7f7fb;padding:16px 32px;text-align:center;border-top:1px solid #e8e8f0;">
        <p style="margin:0;font-size:11px;color:#9ca3af;">Rock Solid Foundation School · BLW Canada · lwcanada.org</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>',
 true),

-- Final Notice
('engagement_final_notice',
 'An important update about your Foundation School enrollment',
 '<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width,initial-scale=1.0" />
<title>Foundation School — Important Update</title></head>
<body style="margin:0;padding:0;background:#f7f7fb;font-family:''Manrope'',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f7f7fb;padding:32px 0;">
  <tr><td align="center">
    <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;border:1px solid #e8e8f0;box-shadow:0 8px 32px rgba(26,20,43,.08);overflow:hidden;max-width:100%;">
      <tr><td style="background:#C8102E;padding:28px 32px;text-align:center;">
        <div style="font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.02em;">Rock Solid Foundation School</div>
        <div style="font-size:13px;color:rgba(255,255,255,.75);margin-top:4px;">BLW Canada</div>
      </td></tr>
      <tr><td style="padding:32px;">
        <p style="margin:0 0 16px;font-size:22px;font-weight:800;color:#1a1a2e;">Hi {{first_name}},</p>
        <p style="margin:0 0 16px;font-size:15px;color:#374151;line-height:1.6;">We have reached out to you a couple of times over the past few weeks and haven''t heard back. We want to make sure you''re okay first and foremost — if there''s something we can do to help, please don''t hesitate to reach out.</p>
        <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff5f5;border:1px solid #fca5a5;border-radius:12px;padding:16px 20px;margin:0 0 20px;">
          <tr><td>
            <div style="font-size:14px;color:#b42318;font-weight:700;">Important notice about your enrollment</div>
            <div style="font-size:14px;color:#374151;margin-top:8px;line-height:1.6;">If we do not hear from you within <strong>7 days</strong>, your spot in this Foundation School batch may be made available to another student on the waitlist. We want every seat to go to someone who is ready to engage.</div>
          </td></tr>
        </table>
        <p style="margin:0 0 24px;font-size:15px;color:#374151;line-height:1.6;">To keep your spot, simply reply to this email with a brief note letting us know you''d like to continue. We will take it from there.</p>
        <table cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
          <tr>
            <td style="background:#C8102E;border-radius:10px;padding:14px 28px;margin-right:8px;">
              <a href="mailto:admin@lwcanada.org?subject=I%20want%20to%20keep%20my%20spot%20in%20Foundation%20School" style="color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;">Reply to Keep My Spot</a>
            </td>
          </tr>
        </table>
        <p style="margin:0;font-size:13px;color:#9ca3af;">We genuinely hope to hear from you.<br>— The Rock Solid Foundation School Team</p>
      </td></tr>
      <tr><td style="background:#f7f7fb;padding:16px 32px;text-align:center;border-top:1px solid #e8e8f0;">
        <p style="margin:0;font-size:11px;color:#9ca3af;">Rock Solid Foundation School · BLW Canada · lwcanada.org</p>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>',
 true)

on conflict (template_key) do update
  set subject   = excluded.subject,
      body_html = excluded.body_html,
      active    = excluded.active;
