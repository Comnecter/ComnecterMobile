const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

admin.initializeApp();

// SendGrid API key will be read from config
// Set using: firebase functions:config:set sendgrid.apikey="YOUR_KEY"
function getSendGridApiKey() {
  // Try environment variable first (modern approach)
  if (process.env.SENDGRID_API_KEY) {
    return process.env.SENDGRID_API_KEY;
  }
  // Use legacy config (works until March 2026)
  if (functions.config().sendgrid?.apikey) {
    return functions.config().sendgrid.apikey;
  }
  throw new Error('SENDGRID_API_KEY not set. Set it using: firebase functions:config:set sendgrid.apikey="YOUR_KEY"');
}

// Get SendGrid sender email from config, or use default
// Set using: firebase functions:config:set sendgrid.senderemail="your-verified-email@example.com"
function getSendGridSenderEmail() {
  // Try environment variable first
  if (process.env.SENDGRID_SENDER_EMAIL) {
    console.log('📧 Using SENDGRID_SENDER_EMAIL from env:', process.env.SENDGRID_SENDER_EMAIL);
    return process.env.SENDGRID_SENDER_EMAIL;
  }
  // Use legacy config
  try {
    const config = functions.config();
    if (config.sendgrid?.senderemail) {
      console.log('📧 Using senderemail from config:', config.sendgrid.senderemail);
      return config.sendgrid.senderemail;
    }
  } catch (e) {
    console.warn('⚠️ Error reading config:', e.message);
  }
  // Default fallback (must be verified in SendGrid!)
  console.log('⚠️ Using default sender email: noreply@comnecter.com');
  return 'noreply@comnecter.com';
}

/**
 * Cloud Function triggered when a verification code is created in Firestore
 * Sends an email with the 6-digit verification code
 * Using 1st generation functions (no permission issues)
 */
exports.sendVerificationEmail = functions.firestore
  .document('verification_codes/{email}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const email = data.email;
    const code = data.code;

    if (!email || !code) {
      console.error('Missing email or code in verification document');
      return null;
    }

    const senderEmail = getSendGridSenderEmail();
    console.log(`📧 Attempting to send email from: ${senderEmail}`);
    
    const msg = {
      to: email,
      from: {
        email: senderEmail, // Get from config or use default
        name: 'Comnecter'
      },
      subject: 'Your Comnecter Verification Code',
      text: `Your Comnecter verification code is: ${code}\n\nThis code will expire in 5 minutes.\n\nIf you didn't request this code, please ignore this email.`,
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Verification Code</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px;">
          <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; padding: 40px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #6366f1; margin: 0; font-size: 28px;">Comnecter</h1>
              <p style="color: #6b7280; margin-top: 8px; font-size: 14px;">Your verification code</p>
            </div>
            
            <div style="background-color: #f9fafb; border-radius: 8px; padding: 30px; text-align: center; margin: 30px 0;">
              <p style="color: #374151; font-size: 14px; margin: 0 0 10px 0;">Your verification code is:</p>
              <div style="background-color: #ffffff; border: 2px dashed #6366f1; border-radius: 8px; padding: 20px; margin: 20px 0;">
                <p style="font-size: 36px; font-weight: bold; color: #6366f1; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">${code}</p>
              </div>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0 0;">This code will expire in 5 minutes</p>
            </div>
            
            <div style="border-top: 1px solid #e5e7eb; padding-top: 20px; margin-top: 30px;">
              <p style="color: #6b7280; font-size: 12px; line-height: 1.6; margin: 0;">
                If you didn't request this verification code, you can safely ignore this email.
              </p>
              <p style="color: #6b7280; font-size: 12px; line-height: 1.6; margin: 10px 0 0 0;">
                For security reasons, never share this code with anyone.
              </p>
            </div>
            
            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; text-align: center;">
              <p style="color: #9ca3af; font-size: 11px; margin: 0;">
                © ${new Date().getFullYear()} Comnecter. All rights reserved.
              </p>
            </div>
          </div>
        </body>
        </html>
      `,
    };

    try {
      // Set API key before sending
      const apiKey = getSendGridApiKey();
      console.log('🔑 API key retrieved, length:', apiKey ? apiKey.length : 0);
      sgMail.setApiKey(apiKey);
      
      console.log(`📤 Sending email to: ${email}, from: ${senderEmail}`);
      await sgMail.send(msg);
      console.log(`✅ Verification email sent successfully to ${email}`);
      
      // Update the document to mark email as sent
      try {
        await snap.ref.update({
          emailSent: true,
          emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ Firestore document updated successfully');
      } catch (firestoreError) {
        console.error('❌ Error updating Firestore document:', firestoreError);
        // Don't throw - email was sent successfully
      }
      
      return null;
    } catch (error) {
      console.error(`❌ Error sending verification email to ${email}:`, error);
      
      // Log error details
      if (error.response) {
        console.error('SendGrid error response:', JSON.stringify(error.response.body, null, 2));
        if (error.response.body && error.response.body.errors) {
          error.response.body.errors.forEach((err) => {
            console.error(`  - ${err.message || 'Unknown error'} (field: ${err.field || 'N/A'})`);
          });
        }
      }
      
      // Still mark as attempted (so we don't retry indefinitely)
      try {
        await snap.ref.update({
          emailSent: false,
          emailError: error.message || 'Unknown error',
          emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        console.error('❌ Error updating Firestore document after failure:', firestoreError);
      }
      
      return null;
    }
  });

/**
 * HTTP callable function to manually trigger email sending (fallback)
 * Can be called from the app if needed
 */
exports.sendVerificationEmailManual = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const code = data.code;

  if (!email || !code) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email and code are required'
    );
  }

  const msg = {
    to: email,
    from: {
      email: getSendGridSenderEmail(), // Get from config or use default
      name: 'Comnecter'
    },
    subject: 'Your Comnecter Verification Code',
    text: `Your Comnecter verification code is: ${code}\n\nThis code will expire in 5 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px; text-align: center;">
        <h2 style="color: #6366f1;">Comnecter Verification Code</h2>
        <div style="background-color: #f9fafb; padding: 20px; margin: 20px 0; border-radius: 8px;">
          <p style="font-size: 32px; font-weight: bold; color: #6366f1; letter-spacing: 4px; margin: 0;">${code}</p>
        </div>
        <p style="color: #6b7280; font-size: 14px;">This code will expire in 5 minutes.</p>
      </div>
    `,
  };

  try {
    // Set API key before sending
    sgMail.setApiKey(getSendGridApiKey());
    await sgMail.send(msg);
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send email',
      error.message
    );
  }
});

