# Fix Cloud Functions Deployment Permission Error

## Current Issue

The deployment is failing with:
```
Could not build the function due to a missing permission on the build service account
```

This happens because **2nd generation Cloud Functions** require additional service account permissions.

## Solution Options

### Option 1: Grant Permissions via Google Cloud Console (Recommended)

1. **Go to Google Cloud Console:**
   - Visit: https://console.cloud.google.com
   - Select project: `comnecter-mobile-staging-711a7`

2. **Grant Cloud Build Service Account Permissions:**
   - Go to: **IAM & Admin** → **IAM**
   - Find service account: `[PROJECT-NUMBER]@cloudbuild.gserviceaccount.com`
   - Click **Edit** (pencil icon)
   - Click **Add Another Role**
   - Add these roles:
     - `Cloud Functions Admin`
     - `Eventarc Admin`
     - `Service Account User`
     - `Storage Admin` (for artifacts)
   - Click **Save**

3. **Grant Eventarc Service Agent Permissions:**
   - Still in **IAM & Admin** → **IAM**
   - Find: `service-[PROJECT-NUMBER]@gcp-sa-eventarc.iam.gserviceaccount.com`
   - If it doesn't exist, Firebase will create it automatically
   - Ensure it has: `Eventarc Service Agent` role

4. **Wait 2-5 minutes** for permissions to propagate

5. **Retry deployment:**
   ```bash
   firebase deploy --only functions
   ```

### Option 2: Use 1st Generation Functions (Easier, but deprecated)

We can switch back to 1st gen functions which don't have these permission issues:

1. **Update functions/index.js** to use v1 API instead of v2
2. **Use 1st gen syntax** (simpler setup)

This is a temporary workaround but will work immediately.

### Option 3: Wait and Retry

Sometimes permissions just need time to propagate (5-10 minutes). Try again later:

```bash
firebase deploy --only functions
```

## Quick Check: View Detailed Build Logs

The error message provided a link to view detailed logs:
```
https://console.cloud.google.com/cloud-build/builds;region=us-central1/...
```

Click the link to see exactly what permission is missing.

## Recommended Action

**Try Option 1 first** (grant permissions in Google Cloud Console). This is the proper solution for 2nd gen functions.

If that's too complicated or you want to deploy quickly, I can help you switch to **1st generation functions** which are simpler but use the older API (still fully supported).

Would you like me to:
1. **Switch to 1st gen functions** (quick fix, works immediately)
2. **Help guide you through Option 1** (proper fix, better long-term)

Let me know which you prefer!


