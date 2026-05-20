-- Email templates for class editor notifications

-- class_time_changed
INSERT INTO public.notification_templates (template_key, subject, body_html, active)
VALUES (
  'class_time_changed',
  'Update: Your Foundation School class time has changed',
  '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Class Time Update</title>
</head>
<body style="margin:0;padding:0;background:#f5f3ff;font-family:Manrope,''Segoe UI'',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f3ff;padding:32px 16px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(76,42,146,.10);">
        <tr>
          <td style="background:#4C2A92;padding:28px 40px;text-align:center;">
            <div style="font-size:22px;font-weight:800;color:#ffffff;">Class Schedule Update</div>
            <div style="font-size:14px;color:#d4c5f9;margin-top:4px;">Foundation School · BLW Canada</div>
          </td>
        </tr>
        <tr>
          <td style="padding:32px 40px;">
            <p style="font-size:17px;font-weight:700;color:#171327;margin:0 0 14px;">Hi {{first_name}},</p>
            <p style="font-size:15px;color:#444;line-height:1.7;margin:0 0 22px;">
              We want to let you know that your Foundation School class schedule has been updated. Your teacher, <strong>{{teacher_name}}</strong>, is the same — only the time has changed.
            </p>
            <table width="100%" cellpadding="0" cellspacing="0" style="border-radius:12px;overflow:hidden;margin:0 0 28px;border:1px solid #e5e0f5;">
              <tr style="background:#fff1f0;">
                <td style="padding:16px 24px;border-bottom:1px solid #e5e0f5;">
                  <div style="font-size:12px;font-weight:700;color:#c0392b;text-transform:uppercase;letter-spacing:.08em;margin-bottom:4px;">Previous Time</div>
                  <div style="font-size:16px;color:#888;text-decoration:line-through;">{{old_day}} at {{old_time}}</div>
                </td>
              </tr>
              <tr style="background:#f0fff4;">
                <td style="padding:16px 24px;">
                  <div style="font-size:12px;font-weight:700;color:#27ae60;text-transform:uppercase;letter-spacing:.08em;margin-bottom:4px;">New Time</div>
                  <div style="font-size:18px;font-weight:700;color:#27ae60;">{{new_day}} at {{new_time}}</div>
                </td>
              </tr>
            </table>
            <p style="font-size:15px;color:#444;line-height:1.7;margin:0 0 20px;">
              If this new time does not work for you, please <strong>reply to this email</strong> as soon as possible so we can explore other options.
            </p>
            <p style="font-size:14px;color:#888;line-height:1.6;margin:0;">
              We apologize for any inconvenience and appreciate your flexibility. See you in class!
            </p>
          </td>
        </tr>
        <tr>
          <td style="background:#f5f3ff;padding:20px 40px;text-align:center;">
            <div style="font-size:12px;color:#9b8cb5;">Rock Solid Foundation School · BLW Canada</div>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>',
  true
)
ON CONFLICT (template_key) DO UPDATE
  SET subject   = EXCLUDED.subject,
      body_html = EXCLUDED.body_html,
      active    = EXCLUDED.active;

-- class_slot_cancelled
INSERT INTO public.notification_templates (template_key, subject, body_html, active)
VALUES (
  'class_slot_cancelled',
  'Important: Your Foundation School class has been cancelled',
  '<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Class Cancellation Notice</title>
</head>
<body style="margin:0;padding:0;background:#fff5f5;font-family:Manrope,''Segoe UI'',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff5f5;padding:32px 16px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(200,16,46,.08);">
        <tr>
          <td style="background:#C8102E;padding:28px 40px;text-align:center;">
            <div style="font-size:22px;font-weight:800;color:#ffffff;">Class Cancellation Notice</div>
            <div style="font-size:14px;color:#ffb3be;margin-top:4px;">Foundation School · BLW Canada</div>
          </td>
        </tr>
        <tr>
          <td style="padding:32px 40px;">
            <p style="font-size:17px;font-weight:700;color:#171327;margin:0 0 14px;">Dear {{first_name}},</p>
            <p style="font-size:15px;color:#444;line-height:1.7;margin:0 0 18px;">
              We are writing to let you know that your Foundation School class — <strong>{{class_day}} at {{class_time}}</strong> with <strong>{{teacher_name}}</strong> — has unfortunately been <strong>cancelled</strong>.
            </p>
            <p style="font-size:15px;color:#444;line-height:1.7;margin:0 0 18px;">
              We sincerely apologize for this disruption. Our team is actively working on alternatives, and someone will be in touch with you shortly to discuss your options and next steps.
            </p>
            <p style="font-size:15px;color:#444;line-height:1.7;margin:0 0 24px;">
              If you have any questions or concerns in the meantime, please <strong>reply to this email</strong> and we will get back to you as soon as possible.
            </p>
            <p style="font-size:14px;color:#888;line-height:1.6;margin:0;">
              Thank you for your patience and understanding. We value your commitment to Foundation School.
            </p>
          </td>
        </tr>
        <tr>
          <td style="background:#fff5f5;padding:20px 40px;text-align:center;">
            <div style="font-size:12px;color:#c0748a;">Rock Solid Foundation School · BLW Canada</div>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>',
  true
)
ON CONFLICT (template_key) DO UPDATE
  SET subject   = EXCLUDED.subject,
      body_html = EXCLUDED.body_html,
      active    = EXCLUDED.active;
