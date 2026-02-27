-- ============================================================================
-- ECOCYCLE: RICH HTML NOTIFICATION EMAIL RPC
-- This function sends a professional HTML email for verification codes.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.send_notification_email(
  recipient_email TEXT,
  email_subject TEXT,
  email_message TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp TEXT;
  v_html_body TEXT;
BEGIN
  -- Extract OTP from message for rich display if possible
  v_otp := substring(email_message from 'is: ([0-9]{6})');

  -- Create Rich HTML Template
  v_html_body := '
  <!DOCTYPE html>
  <html>
  <head>
    <style>
      .container { font-family: sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px; overflow: hidden; }
      .header { background-color: #2E7D32; color: white; padding: 24px; text-align: center; }
      .content { padding: 32px; line-height: 1.6; color: #333; }
      .otp-box { background-color: #F1F8E9; border: 2px dashed #2E7D32; border-radius: 8px; padding: 24px; margin: 24px 0; text-align: center; }
      .otp-code { font-size: 32px; font-weight: bold; color: #1B5E20; letter-spacing: 4px; }
      .footer { background-color: #f5f5f5; color: #757575; padding: 16px; text-align: center; font-size: 12px; }
      .btn { display: inline-block; padding: 12px 24px; background-color: #2E7D32; color: white; text-decoration: none; border-radius: 6px; font-weight: bold; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1>EcoCycle</h1>
      </div>
      <div class="content">
        <h2>Collection Verification</h2>
        <p>Hello,</p>
        <p>A volunteer is ready to collect your items. Please provide them with the following verification code to confirm the pickup:</p>
        
        <div class="otp-box">
          <div class="otp-code">' || COALESCE(v_otp, '------') || '</div>
        </div>
        
        <p>If you did not request this collection, please ignore this email or contact support.</p>
        <p>Thank you for contributing to a greener planet!</p>
      </div>
      <div class="footer">
        &copy; 2026 EcoCycle Inc. | Smart Recycling Solutions
      </div>
    </div>
  </body>
  </html>';

  -- 1. Log the notification
  INSERT INTO public.notifications (user_id, title, message, type)
  SELECT id, email_subject, email_message, 'email_sent'
  FROM auth.users WHERE email = recipient_email LIMIT 1;

  -- 2. INTEGRATION: Send via ESP (e.g. Resend)
  -- This part requires your Resend API Key and Supabase HTTP extension
  /*
  PERFORM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR_RESEND_API_KEY',
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', 'EcoCycle <notifications@ecocycle.com>',
      'to', ARRAY[recipient_email],
      'subject', email_subject,
      'html', v_html_body
    )
  );
  */

  RETURN json_build_object(
    'success', true, 
    'message', 'Rich HTML email logged and ready for dispatch.',
    'otp', v_otp
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_notification_email(TEXT, TEXT, TEXT) TO authenticated;
