# Fix Artifact Registry Permission for Cloud Functions

## Current Error

```
Permission "artifactregistry.repositories.downloadArtifacts" denied on resource "projects/comnecter-mobile-staging-711a7/locations/us-central1/repositories/gcf-artifacts"
```

## Solution

The Compute Engine service account needs **Artifact Registry Reader** permission.

### Via Google Cloud Console:

1. **Go to IAM:**
   https://console.cloud.google.com/iam-admin/iam?project=comnecter-mobile-staging-711a7

2. **Find the service account:**
   Search for: `641865839333-compute@developer.gserviceaccount.com`

3. **Edit permissions:**
   - Click the **pencil icon** (Edit) next to the service account
   - Click **+ ADD ANOTHER ROLE**
   - Search for: `Artifact Registry Reader`
   - Select: **Artifact Registry Reader**
   - Click **SAVE**

### Alternative: Grant via gcloud CLI

```bash
gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

## After Granting Permission

Wait **2-3 minutes** for propagation, then:

```bash
firebase deploy --only functions
```

This should fix the deployment! 🎉

## Full Permission List Needed

For Cloud Functions to work, the Compute Engine service account should have:
- ✅ **Artifact Registry Reader** (this is what was missing)
- ✅ **Storage Object Viewer** (for source code access)
- ✅ **Cloud Run Invoker** (already has this)
- ✅ **Eventarc Event Receiver** (already has this)


