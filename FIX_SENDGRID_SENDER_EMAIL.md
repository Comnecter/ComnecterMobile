# Fix SendGrid Sender Email Verification

## Current Error

```
The from address does not match a verified Sender Identity. 
Mail cannot be sent until this error is resolved.
```

The sender email `noreply@comnecter.app` is not verified in SendGrid.

## Solution: Verify Sender Email in SendGrid

### Option 1: Verify Single Sender (Easiest for Testing)

1. **Go to SendGrid Dashboard:**
   https://app.sendgrid.com

2. **Settings → Sender Authentication:**
   - Click **Verify a Single Sender**
   - Click **Create**

3. **Fill in the form:**
   - **From Email Address:** Your email (e.g., `your-email@gmail.com` or `info@comnecter.com`)
   - **From Name:** Comnecter
   - **Reply To:** Your email
   - **Company Address:** Your address
   - **City, State, Zip:** Your location
   - **Country:** Your country

4. **Click Create**
   - Check your email inbox
   - Click the verification link

5. **Update Cloud Function:**
   After verification, update `functions/index.js` to use your verified email.

### Option 2: Use Your Personal Email (Quick Fix)

For testing, you can temporarily use an email that's easier to verify (like your Gmail).

**After verification, update the code:**
```javascript
from: {
  email: 'your-verified-email@gmail.com', // Your verified SendGrid sender
  name: 'Comnecter'
}
```

Then redeploy:
```bash
firebase deploy --only functions:sendVerificationEmail
```

## Recommended: Make Sender Email Configurable

We can update the code to read the sender email from config, so you don't need to redeploy each time.


