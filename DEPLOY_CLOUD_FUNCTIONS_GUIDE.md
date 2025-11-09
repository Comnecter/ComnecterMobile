# Complete Guide: Deploying Cloud Functions for Email Verification

This guide provides detailed step-by-step instructions for deploying Firebase Cloud Functions.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Node.js installed (v18 or higher) - Check: `node --version`
- [ ] Firebase CLI installed - Check: `firebase --version`
- [ ] Firebase project created and initialized
- [ ] Logged into Firebase CLI - Run: `firebase login`
- [ ] SendGrid account created with API key (or use alternative service)

---

## Step 1: Install Node.js (If Not Installed)

```bash
# Check if Node.js is installed
node --version

# If not installed, on macOS:
brew install node@18

# Or download from: https://nodejs.org/
```

**Expected Output:** `v18.x.x` or higher

---

## Step 2: Install Firebase CLI (If Not Installed)

```bash
# Check if Firebase CLI is installed
firebase --version

# If not installed:
npm install -g firebase-tools

# Verify installation
firebase --version
```

**Expected Output:** `13.x.x` or higher

---

## Step 3: Login to Firebase

```bash
# Login to Firebase (opens browser)
firebase login

# Verify you're logged in
firebase projects:list
```

**Expected Output:** Should show your Firebase projects

---

## Step 4: Navigate to Functions Directory

```bash
# From project root
cd functions

# Verify you're in the right directory
ls -la
# Should see: package.json, index.js
```

---

## Step 5: Install Node.js Dependencies

```bash
# Install all required packages
npm install

# This installs:
# - firebase-admin
# - firebase-functions
# - @sendgrid/mail
```

**Expected Output:**
```
added 200+ packages in 30s
```

**Troubleshooting:**
- If `npm` command not found → Install Node.js (Step 1)
- If permission errors → Use `sudo npm install` (not recommended) or fix npm permissions

---

## Step 6: Set SendGrid API Key

You have **two options**:

### Option A: Firebase Config (Recommended)

```bash
# Set the API key
firebase functions:config:set sendgrid.apikey="YOUR_SENDGRID_API_KEY_HERE"

# Verify it was set
firebase functions:config:get
```

**Example:**
```bash
firebase functions:config:set sendgrid.apikey="SG.abcdefghijklmnopqrstuvwxyz.1234567890"
```

**Output:**
```
✔  Functions config updated.
```

### Option B: Environment Variable (For CI/CD)

```bash
# Set as environment variable
export SENDGRID_API_KEY="YOUR_SENDGRID_API_KEY_HERE"

# Then update functions/index.js to use:
# sgMail.setApiKey(process.env.SENDGRID_API_KEY);
```

**Where to get SendGrid API Key:**
1. Go to [SendGrid Dashboard](https://app.sendgrid.com)
2. **Settings** → **API Keys**
3. Click **Create API Key**
4. Name: `Comnecter Cloud Functions`
5. Permissions: **Full Access** or **Restricted Access** (Mail Send only)
6. **Copy the key** (shown only once!)

---

## Step 7: Verify Firebase Project

```bash
# Check which project is active
firebase use

# If not set, select your project
firebase use --add

# Select your project from the list:
# 1. comnecter-mobile-staging
# 2. comnecter-mobile-production
```

**Expected Output:**
```
Now using project comnecter-mobile-staging
```

---

## Step 8: Enable Required APIs

Firebase Cloud Functions requires certain Google Cloud APIs:

```bash
# Enable Cloud Functions API
gcloud services enable cloudfunctions.googleapis.com

# Enable Cloud Build API
gcloud services enable cloudbuild.googleapis.com

# Or enable via Firebase Console:
# Project Settings → General → Enable APIs
```

**Alternative (via Firebase Console):**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. **Project Settings** → **General**
4. Scroll to **APIs** section
5. Enable:
   - ☑ Cloud Functions API
   - ☑ Cloud Build API

---

## Step 9: Initialize Firebase Functions (If Not Already Done)

```bash
# From project root (not functions directory)
firebase init functions

# When prompted:
# - Use existing functions directory? → Yes
# - Language: JavaScript
# - ESLint: No (for now)
# - Install dependencies: Yes
```

**Note:** If `firebase.json` already exists, skip this step.

---

## Step 10: Deploy Functions

```bash
# Make sure you're in the project root (not functions directory)
cd ..

# Deploy all functions
firebase deploy --only functions

# Or deploy only the email function
firebase deploy --only functions:sendVerificationEmail
```

**Expected Output:**
```
✔  functions[sendVerificationEmail(us-central1)] Successful create operation.
Function URL (sendVerificationEmail): https://us-central1-xxx.cloudfunctions.net/sendVerificationEmail
✔  Deploy complete!
```

**Deployment takes 2-5 minutes** - be patient!

---

## Step 11: Verify Deployment

### Check in Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. **Functions** → Should see `sendVerificationEmail`
4. Status should be: **Active** ✓

### Check Function Logs:
```bash
# View recent logs
firebase functions:log

# Filter by function
firebase functions:log --only sendVerificationEmail
```

---

## Step 12: Test Email Sending

### Option 1: Test via App
1. Open the app
2. Go to sign-up
3. Enter an email address
4. Check inbox for verification code

### Option 2: Test Manually
```bash
# Create a test document in Firestore
# This will trigger the function

# Via Firebase Console:
# 1. Go to Firestore Database
# 2. Create collection: verification_codes
# 3. Add document with ID = test@example.com
# 4. Add fields:
#    - email: "test@example.com"
#    - code: "123456"
#    - createdAt: (timestamp)
#    - expiresAt: (timestamp)
#    - used: false
#    - attempts: 0
#    - maxAttempts: 5
```

---

## Troubleshooting Common Issues

### Issue 1: "npm: command not found"
**Solution:**
```bash
# Install Node.js
brew install node@18  # macOS
# Or download from nodejs.org
```

### Issue 2: "firebase: command not found"
**Solution:**
```bash
npm install -g firebase-tools
```

### Issue 3: "Permission denied"
**Solution:**
```bash
# Fix npm permissions (macOS/Linux)
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
source ~/.zshrc

# Then reinstall Firebase CLI
npm install -g firebase-tools
```

### Issue 4: "API not enabled"
**Solution:**
```bash
# Enable via gcloud (requires Google Cloud SDK)
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Or enable via Firebase Console (Project Settings → APIs)
```

### Issue 5: "Billing account required"
**Solution:**
- Firebase Functions requires a billing account (Blaze plan)
- Free tier: 2 million invocations/month
- Go to: Firebase Console → Project Settings → Billing
- Enable billing (won't charge until you exceed free tier)

### Issue 6: "SendGrid API key not found"
**Solution:**
```bash
# Verify API key is set
firebase functions:config:get

# Should show:
# {
#   "sendgrid": {
#     "apikey": "SG.xxxxx"
#   }
# }

# If not, set it again:
firebase functions:config:set sendgrid.apikey="YOUR_KEY"
firebase deploy --only functions
```

### Issue 7: "Function deployment failed"
**Solution:**
```bash
# Check detailed logs
firebase deploy --only functions --debug

# Check Node.js version (should be 18+)
node --version

# Try rebuilding
cd functions
rm -rf node_modules package-lock.json
npm install
cd ..
firebase deploy --only functions
```

### Issue 8: "Email not sending"
**Solution:**
1. **Check SendGrid sender verification:**
   - SendGrid Dashboard → Settings → Sender Authentication
   - Verify sender email is verified

2. **Check function logs:**
   ```bash
   firebase functions:log --only sendVerificationEmail
   ```

3. **Check SendGrid Activity:**
   - SendGrid Dashboard → Activity → Email Activity
   - See if emails are being sent and delivery status

4. **Verify API key permissions:**
   - SendGrid API key must have "Mail Send" permission

---

## Alternative: Using Firebase Extensions (Easier)

If Cloud Functions setup is too complex, you can use Firebase Extensions:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. **Extensions** → **Browse Extensions**
3. Search: **"Trigger Email"**
4. Install extension
5. Configure with SendGrid API key
6. Done! (No code needed)

**But:** This requires SendGrid anyway, so manual setup gives more control.

---

## Quick Command Reference

```bash
# Check Node.js
node --version

# Check Firebase CLI
firebase --version

# Login
firebase login

# Set project
firebase use comnecter-mobile-staging

# Navigate to functions
cd functions

# Install dependencies
npm install

# Set API key
firebase functions:config:set sendgrid.apikey="YOUR_KEY"

# Deploy
cd ..
firebase deploy --only functions

# View logs
firebase functions:log

# Check status
firebase functions:list
```

---

## Cost Information

- **Firebase Functions Free Tier:**
  - 2 million invocations/month
  - 400,000 GB-seconds compute time
  - 200,000 CPU-seconds

- **SendGrid Free Tier:**
  - 100 emails/day forever
  - No credit card required

**Total Cost for MVP:** $0/month (up to ~3,000 sign-ups/day)

---

## Next Steps After Deployment

1. ✅ Test email sending with real email address
2. ✅ Monitor function logs for errors
3. ✅ Set up alerts for failed emails
4. ✅ Consider rate limiting (prevent spam)
5. ✅ Add email templates for better branding

---

## Need Help?

If you encounter issues:

1. **Check logs:** `firebase functions:log`
2. **Check Firebase Console:** Functions → Logs
3. **Check SendGrid Dashboard:** Activity → Email Activity
4. **Verify configuration:** `firebase functions:config:get`

Common fixes:
- Re-deploy: `firebase deploy --only functions --force`
- Clear cache: `firebase functions:delete sendVerificationEmail` then redeploy
- Check billing: Ensure Blaze plan is enabled


