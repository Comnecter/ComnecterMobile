# Fix Storage Permission for Cloud Functions

## Current Issue

The Compute Engine service account needs **Storage Object Viewer** permission to access the Cloud Functions source bucket.

## Quick Fix

### Via Google Cloud Console:

1. **Go to IAM:**
   https://console.cloud.google.com/iam-admin/iam?project=comnecter-mobile-staging-711a7

2. **Find the service account:**
   Search for: `641865839333-compute@developer.gserviceaccount.com`

3. **Edit permissions:**
   - Click the **pencil icon** (Edit) next to the service account
   - Click **+ ADD ANOTHER ROLE**
   - Search for: `Storage Object Viewer`
   - Select: **Storage Object Viewer**
   - Click **SAVE**

### Alternative: Grant via gcloud CLI

```bash
gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333-compute@developer.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

## After Granting Permission

Wait **2-3 minutes** for propagation, then:

```bash
firebase deploy --only functions
```

This should work now! 🎉


