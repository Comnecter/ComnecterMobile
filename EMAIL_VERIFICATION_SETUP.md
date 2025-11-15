# Email Verification Setup Guide

This guide explains how to set up real email sending for verification codes in Comnecter Mobile.

## Overview

The app uses **SendGrid** (free tier: 100 emails/day) to send verification codes via email. Cloud Functions automatically send emails when verification codes are created.

## Setup Steps

### 1. Create SendGrid Account

1. Go to [SendGrid.com](https://sendgrid.com)
2. Sign up for a free account (100 emails/day free forever)
3. Verify your email address

### 2. Create SendGrid API Key

1. In SendGrid Dashboard → **Settings** → **API Keys**
2. Click **Create API Key**
3. Name it: `Comnecter Cloud Functions`
4. Permissions: **Full Access** (or restrict to Mail Send only)
5. Copy the API key (you'll only see it once!)

### 3. Verify Sender Email in SendGrid

1. In SendGrid Dashboard → **Settings** → **Sender Authentication**
2. Go to **Single Sender Verification**
3. Click **Create New Sender**
4. Fill in:
   - **From Email**: `noreply@comnecter.app` (or your domain)
   - **From Name**: `Comnecter`
   - **Reply To**: Your support email
5. Verify the email address (check inbox and click verification link)

**Note**: For production, use **Domain Authentication** instead of Single Sender for better deliverability.

### 4. Deploy Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Set SendGrid API key in Firebase
firebase functions:config:set sendgrid.apikey="YOUR_SENDGRID_API_KEY_HERE"

# Deploy functions
firebase deploy --only functions

# Or deploy just the email function
firebase deploy --only functions:sendVerificationEmail
```

### 5. Alternative: Set Environment Variable

If you prefer environment variables (recommended for CI/CD):

```bash
# Set environment variable
firebase functions:config:set sendgrid.apikey="YOUR_SENDGRID_API_KEY_HERE"

# Or use Firebase Console:
# Functions → Configuration → Environment variables
# Add: sendgrid.apikey = YOUR_API_KEY
```

## How It Works

1. **User enters email** in sign-up wizard
2. **App creates verification code** and stores it in Firestore (`verification_codes` collection)
3. **Cloud Function triggers** automatically when document is created
4. **Email is sent** via SendGrid with the 6-digit code
5. **User receives email** and enters code in app

## Testing

### Test Locally (Optional)

```bash
# Start Firebase emulators
firebase emulators:start --only functions,firestore

# Set test API key
export SENDGRID_API_KEY="your-test-key"

# Test the function
# Trigger by creating a document in verification_codes collection
```

### Test in Production

1. Go through sign-up flow
2. Enter your email address
3. Check your inbox for verification code
4. Verify the email arrives within a few seconds

## Monitoring

### Check Function Logs

```bash
# View logs
firebase functions:log

# Filter by function
firebase functions:log --only sendVerificationEmail
```

### Firebase Console

1. Go to Firebase Console → **Functions**
2. Click on `sendVerificationEmail`
3. View **Logs** tab for execution history
4. Check **Metrics for usage stats

## Troubleshooting

### Emails Not Sending

1. **Check SendGrid API Key**
   ```bash
   firebase functions:config:get
   ```

2. **Check Function Logs**
   ```bash
   firebase functions:log --only sendVerificationEmail
   ```

3. **Verify Sender Email**
   - Make sure sender email is verified in SendGrid
   - Check spam folder

4. **Check SendGrid Dashboard**
   - Go to **Activity** → **Email Activity**
   - See if emails are being sent and delivery status

### Common Errors

- **"Invalid API Key"**: API key not set correctly in Firebase
- **"Sender not verified"**: Sender email not verified in SendGrid
- **"Rate limit exceeded"**: SendGrid free tier limit reached (100/day)

## Cost

- **SendGrid Free Tier**: 100 emails/day forever
- **Firebase Cloud Functions**: 
  - Free tier: 2 million invocations/month
  - $0.40 per million after that

**Estimated Cost**: **$0/month** for first ~3,000 users/day (assuming 1 email per sign-up)

## Alternative Email Services

If you prefer other services:

### Mailgun
- Free tier: 5,000 emails/month (3 months free)
- Update `functions/index.js` to use Mailgun SDK

### AWS SES
- Free tier: 62,000 emails/month (if sending from EC2)
- Requires AWS account setup

### Resend
- Free tier: 3,000 emails/month
- Modern API, good developer experience

## Production Recommendations

1. **Domain Authentication**: Use your own domain for better deliverability
2. **Email Templates**: Create branded templates in SendGrid
3. **Monitoring**: Set up alerts for failed emails
4. **Rate Limiting**: Implement rate limiting on code requests
5. **Email Validation**: Validate email format before sending

## Security

- API key is stored securely in Firebase Functions config
- Never commit API keys to git
- Use different keys for staging/production
- Rotate keys periodically


