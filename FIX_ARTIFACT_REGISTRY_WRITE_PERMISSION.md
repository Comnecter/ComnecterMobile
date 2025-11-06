# Fix Artifact Registry Write Permission

## Current Error

```
Permission "artifactregistry.repositories.uploadArtifacts" denied
```

The service account needs **WRITE** permission to Artifact Registry, not just READ.

## Solution

Grant **Artifact Registry Writer** role (this includes both read and write).

### Via Google Cloud Console:

1. **Go to IAM:**
   https://console.cloud.google.com/iam-admin/iam?project=comnecter-mobile-staging-711a7

2. **Find the service account:**
   `641865839333-compute@developer.gserviceaccount.com`

3. **Edit permissions:**
   - Click the **pencil icon** (Edit)
   - **REMOVE** "Artifact Registry Reader" (if you added it)
   - Click **+ ADD ANOTHER ROLE**
   - Search for: `Artifact Registry Writer`
   - Select: **Artifact Registry Writer** ✅ (this includes both read and write)
   - Click **SAVE**

### Alternative: Grant via gcloud CLI

```bash
gcloud projects add-iam-policy-binding comnecter-mobile-staging-711a7 \
  --member="serviceAccount:641865839333-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

## Full Permission List

The Compute Engine service account should have:
- ✅ **Artifact Registry Writer** (replaces Reader - includes both read and write)
- ✅ **Storage Object Viewer** (for source code access)
- ✅ **Cloud Run Invoker** (already has this)
- ✅ **Eventarc Event Receiver** (already has this)

## After Granting Permission

Wait **2-3 minutes** for propagation, then:

```bash
firebase deploy --only functions
```

This should fix it! 🎉


