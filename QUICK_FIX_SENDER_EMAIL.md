# Quick Fix: Use Verified Email for SendGrid

## Problem

The domain `comnecter.com` is not verified in SendGrid, so emails from `noreply@comnecter.com` cannot be sent.

## Quick Solution: Verify a Single Sender Email

### Step 1: Verify Your Email in SendGrid

1. Go to: https://app.sendgrid.com
2. **Settings** → **Sender Authentication** → **Verify a Single Sender**
3. Click **Create**
4. Fill in:
   - **From Email Address:** Your email (e.g., `info@comnecter.com`, `developer@comnecter.com`, or even your Gmail for testing)
   - **From Name:** Comnecter
   - **Reply To:** Same as From Email
   - Fill in the rest of the required fields
5. Click **Create**
6. **Check your email** and click the verification link

### Step 2: Set Verified Email in Firebase

Once verified, run:

```bash
firebase functions:config:set sendgrid.senderemail="your-verified-email@example.com"
```

For example, if you verified `info@comnecter.com`:
```bash
firebase functions:config:set sendgrid.senderemail="info@comnecter.com"
```

### Step 3: Test Again

Try signing up again - emails should work now!

## For Production: Verify Domain (Later)

For production, you should verify the entire domain:
1. **Settings** → **Sender Authentication** → **Domain Authentication**
2. Add your domain: `comnecter.com`
3. Add DNS records to your domain hosting
4. Once verified, you can use any email from that domain (e.g., `noreply@comnecter.com`, `info@comnecter.com`, etc.)

## Current Status

- ❌ Domain not verified: Can't use `noreply@comnecter.com`
- ✅ Solution: Verify a single sender email (quick fix for testing)


