# How to Set SendGrid API Key for Cloud Functions

After updating the code to use the modern approach, you need to set your SendGrid API key.

## Option 1: Using Legacy Config (Works Until March 2026)

This is the easiest method that works right now:

```bash
# Set the API key
firebase functions:config:set sendgrid.apikey="YOUR_SENDGRID_API_KEY_HERE"

# Verify it was set
firebase functions:config:get
```

**Replace `YOUR_SENDGRID_API_KEY_HERE` with your actual SendGrid API key** (starts with `SG.`)

## Option 2: Using Environment Variables (Modern, Recommended)

### Via Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `comnecter-mobile-staging-711a7`
3. Click **Functions** in left sidebar
4. Click **Configuration** tab
5. Click **Environment variables**
6. Click **Add variable**
7. Set:
   - **Key:** `SENDGRID_API_KEY`
   - **Value:** Your SendGrid API key (starts with `SG.`)
8. Click **Save**
9. Redeploy functions: `firebase deploy --only functions`

### Via Command Line:
```bash
# Note: This requires Firebase CLI 13.0.0+ and may not be available in all regions
# Check if available:
firebase functions:config:env:set SENDGRID_API_KEY="YOUR_KEY"
```

## Option 3: Using Firebase Secrets (Most Secure, Future-Proof)

This is the recommended long-term approach:

```bash
# Set the secret (will prompt you to paste the key)
firebase functions:secrets:set SENDGRID_API_KEY

# Then update functions/index.js to use:
# const sendGridApiKey = process.env.SENDGRID_API_KEY;
```

**Note:** Secrets require additional setup and are best for production.

## Recommended for Now

Use **Option 1** (legacy config) since it's the simplest and works immediately:

```bash
firebase functions:config:set sendgrid.apikey="SG.YOUR_ACTUAL_KEY_HERE"
```

Then deploy:
```bash
firebase deploy --only functions
```

## How to Get Your SendGrid API Key

1. Go to [SendGrid Dashboard](https://app.sendgrid.com)
2. **Settings** → **API Keys**
3. Click **Create API Key**
4. Name: `Comnecter Cloud Functions`
5. Permissions: **Full Access** or **Restricted Access** (Mail Send only)
6. **Copy the key** (starts with `SG.` - you'll only see it once!)

## Verify It's Set

```bash
# Check legacy config
firebase functions:config:get

# Should show:
# {
#   "sendgrid": {
#     "apikey": "SG.xxxxx"
#   }
# }
```

## Next Steps

After setting the API key:
1. Deploy functions: `firebase deploy --only functions`
2. Test by signing up with your email
3. Check your inbox for the verification code


