# Step-by-Step: Deploy Cloud Functions

## Current Status ✅

- ✅ Node.js installed (v23.11.0)
- ✅ Firebase CLI installed (v14.23.0)
- ✅ Dependencies installed (`npm install` completed)
- ✅ Runtime version updated to Node.js 20 (required for deployment)
- ⏸️ **NEXT:** Login to Firebase

---

## Step 4: Login to Firebase (Interactive - Opens Browser)

```bash
firebase login
```

**What happens:**
1. Opens your default browser
2. Asks you to sign in with your Google account
3. Asks for permissions (allow Firebase CLI access)
4. Returns to terminal when complete

**Expected Output:**
```
✔  Success! Logged in as your-email@gmail.com
```

**If browser doesn't open:**
```bash
firebase login --no-localhost
# Copy the URL and open in browser manually
```

---

## Step 5: Select Your Firebase Project

```bash
# See available projects
firebase projects:list

# Set the project you want to use
firebase use --add

# Or set directly (if you know the project ID):
# firebase use comnecter-mobile-staging
# firebase use comnecter-mobile-production
```

**Choose the correct project:**
- **For testing/development:** `comnecter-mobile-staging`
- **For production:** `comnecter-mobile-production` (later)

**Expected Output:**
```
? Which project do you want to add?
  1. comnecter-mobile-staging
  2. comnecter-mobile-production

✔ Now using project comnecter-mobile-staging
```

---

## Step 6: Enable Billing (Required for Cloud Functions)

**Important:** Firebase Cloud Functions requires a billing account, but you get a generous free tier.

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click ⚙️ **Project Settings**
4. Click **Usage and billing** tab
5. Click **Upgrade project** or **Modify plan**
6. Select **Blaze Plan** (Pay as you go)
7. Add billing information

**Free Tier Includes:**
- ✅ 2 million function invocations/month
- ✅ 400,000 GB-seconds compute time
- ✅ 200,000 CPU-seconds

**Cost:** $0 until you exceed free tier (very generous for MVP)

---

## Step 7: Get SendGrid API Key

Since Firebase doesn't have built-in email sending, we need SendGrid (free: 100 emails/day).

### Quick Setup:

1. **Go to SendGrid:**
   - Visit: https://sendgrid.com
   - Click **Start for free**
   - Sign up with your email

2. **Verify Your Email:**
   - Check inbox
   - Click verification link

3. **Create API Key:**
   - Go to: **Settings** → **API Keys**
   - Click **Create API Key**
   - Name: `Comnecter Email Verification`
   - Permissions: **Full Access** (or restrict to "Mail Send")
   - **Copy the API key** (you'll only see it once!)

4. **Verify Sender Email:**
   - Go to: **Settings** → **Sender Authentication**
   - Click **Verify a Single Sender**
   - Fill in:
     - **From Email:** Your email (e.g., `noreply@yourdomain.com` or use a personal email for testing)
     - **From Name:** Comnecter
     - **Reply To:** Your email
   - Click **Create**
   - **Check your email** and click verification link

**Alternative Services (if you prefer):**
- **Resend:** 3,000 emails/month free (resend.com)
- **Mailgun:** 5,000 emails/month free for 3 months
- **AWS SES:** Very cheap ($0.10 per 1,000 emails)

---

## Step 8: Set SendGrid API Key in Firebase

```bash
# Make sure you're in the project root (not functions directory)
cd /Users/tolgaarslan/ComnecterMobile

# Set the API key (replace with your actual key)
firebase functions:config:set sendgrid.apikey="SG.YOUR_ACTUAL_SENDGRID_API_KEY_HERE"

# Verify it was set
firebase functions:config:get
```

**Expected Output:**
```json
{
  "sendgrid": {
    "apikey": "SG.xxxxx"
  }
}
```

**Important:** 
- Replace `SG.YOUR_ACTUAL_SENDGRID_API_KEY_HERE` with your real SendGrid API key
- Keep the quotes around the key
- The key starts with `SG.`

---

## Step 9: Enable Required APIs

Cloud Functions needs these Google Cloud APIs enabled:

### Option A: Via Firebase Console (Easier)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. ⚙️ **Project Settings** → **General** tab
4. Scroll to **Your apps** section
5. Look for **APIs** section or click **Enable APIs**
6. Enable:
   - ☑ Cloud Functions API
   - ☑ Cloud Build API

### Option B: Via Command Line

```bash
# Install Google Cloud SDK first (if not installed)
# macOS:
brew install google-cloud-sdk

# Then enable APIs:
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

---

## Step 10: Deploy Functions

```bash
# Make sure you're in project root
cd /Users/tolgaarslan/ComnecterMobile

# Deploy all functions
firebase deploy --only functions

# This will:
# 1. Build the functions (1-2 minutes)
# 2. Upload to Firebase (1-2 minutes)
# 3. Deploy and activate (30 seconds)
```

**Expected Output:**
```
✔  functions[sendVerificationEmail(us-central1)] Successful create operation.
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/your-project/functions
```

**Total time:** 2-5 minutes (first deployment is slower)

**If deployment fails:**
```bash
# Check detailed error
firebase deploy --only functions --debug

# Common fixes:
# - Make sure billing is enabled (Step 6)
# - Make sure APIs are enabled (Step 9)
# - Check Node.js version compatibility
```

---

## Step 11: Verify Deployment

### Check in Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click **Functions** in left sidebar
4. You should see: `sendVerificationEmail`
5. Status: **Active** ✅

### Check Logs:
```bash
# View function logs
firebase functions:log

# Filter by function
firebase functions:log --only sendVerificationEmail
```

---

## Step 12: Test Email Sending

1. **Run your app:**
   ```bash
   flutter run --flavor staging
   ```

2. **Test sign-up:**
   - Navigate to sign-up
   - Enter your email address
   - Click "Send Verification Code"

3. **Check:**
   - **Console:** Should see code printed (for debugging)
   - **Inbox:** Should receive email within 10-30 seconds
   - **Function logs:** `firebase functions:log` should show email sent

4. **If email doesn't arrive:**
   - Check spam folder
   - Check SendGrid Activity Dashboard
   - Check function logs for errors
   - Verify sender email is verified in SendGrid

---

## Troubleshooting

### "Billing account required"
- Go to Firebase Console → Project Settings → Usage and billing
- Enable Blaze plan (free tier applies)

### "API not enabled"
- Follow Step 9 to enable APIs

### "SendGrid API key invalid"
- Verify API key is correct: `firebase functions:config:get`
- Check SendGrid Dashboard → API Keys
- Make sure key has "Mail Send" permission

### "Email not sending"
1. Check function logs: `firebase functions:log`
2. Check SendGrid Activity Dashboard
3. Verify sender email is verified
4. Check spam folder

### "Function deployment failed"
```bash
# Check error details
firebase deploy --only functions --debug

# Try rebuilding
cd functions
rm -rf node_modules
npm install
cd ..
firebase deploy --only functions
```

---

## Quick Reference: All Commands

```bash
# 1. Login
firebase login

# 2. Select project
firebase use --add
# Or: firebase use comnecter-mobile-staging

# 3. Navigate to functions
cd functions

# 4. Install dependencies (already done)
npm install

# 5. Go back to root
cd ..

# 6. Set API key
firebase functions:config:set sendgrid.apikey="SG.YOUR_KEY"

# 7. Deploy
firebase deploy --only functions

# 8. Check logs
firebase functions:log
```

---

## Alternative: Using Firebase Extensions (No Code Required)

If manual deployment is too complex, you can use Firebase's official extension:

1. Go to Firebase Console → **Extensions**
2. Search: **"Trigger Email"**
3. Install extension
4. Configure with SendGrid API key
5. Done! (Works automatically)

**But:** Still requires SendGrid account, and gives less control than custom code.

---

## Next: Start Deployment

Run these commands in order:

```bash
# Step 1: Login (opens browser)
firebase login

# Step 2: Select project
firebase use --add

# Step 3: Set API key (get from SendGrid first!)
firebase functions:config:set sendgrid.apikey="YOUR_KEY_HERE"

# Step 4: Deploy
firebase deploy --only functions
```

Need help with any step? Let me know!

