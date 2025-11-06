# Fix Cloud Build Service Account Permissions

## Current Issue

The Cloud Build service account (`641865839333@cloudbuild.gserviceaccount.com`) is missing or doesn't have the required permissions for deploying 2nd gen Cloud Functions.

## Quick Fix: Add Permissions via Google Cloud Console

### Step 1: Go to IAM Page

1. Open: https://console.cloud.google.com/iam-admin/iam?project=comnecter-mobile-staging-711a7
2. You should see the service accounts list

### Step 2: Find or Create Cloud Build Service Account

Look for:
- `641865839333@cloudbuild.gserviceaccount.com`

**If it doesn't exist**, it will be created automatically when you try to deploy. But we can add it manually:

1. Click **+ GRANT ACCESS**
2. In "New principals", enter: `641865839333@cloudbuild.gserviceaccount.com`
3. Add these roles:
   - `Cloud Functions Admin`
   - `Eventarc Admin`  
   - `Service Account User`
   - `Storage Admin`
   - `Cloud Build Service Account` (if available)
4. Click **SAVE**

### Step 3: Alternative - Use Your Owner Account

Since `info@comnecter.com` has Owner role, you could also:

1. Make sure you're deploying while logged in as this account
2. Or grant the permissions via gcloud CLI (see below)

## Option 2: Use gcloud CLI (If You Have Access)

```bash
# Set the project
gcloud config set project comnecter-mobile-staging-711a7

# Grant Cloud Build service account the required roles
gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333@cloudbuild.gserviceaccount.com" \
  --role="roles/cloudfunctions.admin"

gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333@cloudbuild.gserviceaccount.com" \
  --role="roles/eventarc.admin"

gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333@cloudbuild.gserviceaccount.com" \
  --role="roles/storage.admin"
```

## Option 3: Enable Cloud Build API First

Sometimes the service account doesn't exist until Cloud Build API is enabled:

1. Go to: https://console.cloud.google.com/apis/library?project=comnecter-mobile-staging-711a7
2. Search for: "Cloud Build API"
3. Click **ENABLE**
4. Wait 2-3 minutes
5. Retry deployment: `firebase deploy --only functions`

## Verify Permissions Are Set

After adding permissions:

1. Go to: https://console.cloud.google.com/iam-admin/iam?project=comnecter-mobile-staging-711a7
2. Search for: `641865839333@cloudbuild.gserviceaccount.com`
3. Verify it has the roles listed above

## Wait and Retry

After adding permissions, wait **5-10 minutes** for propagation, then:

```bash
firebase deploy --only functions
```

## Still Having Issues?

If permissions still don't work after 10 minutes, the issue might be:
1. Organization policies blocking service account usage
2. Billing not enabled (Blaze plan required)
3. API not fully enabled

Check the detailed build logs:
```
https://console.cloud.google.com/cloud-build/builds?project=comnecter-mobile-staging-711a7
```

The most recent failed build will show the exact permission error.


