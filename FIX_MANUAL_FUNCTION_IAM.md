# Fix Manual Function IAM Permission

## Current Error

```
Failed to set the IAM Policy on the function sendVerificationEmailManual
Unable to set the invoker for the IAM policy
```

## Cause

The deployment needs `functions.admin` role to set IAM policies for callable functions, or there's an organization policy restricting IAM changes.

## Solution Options

### Option 1: Grant Functions Admin Role (Recommended)

1. **Go to IAM:**
   https://console.cloud.google.com/iam-admin/iam?project=comnecter-mobile-staging-711a7

2. **Find your account** (the one you're logged in as Firebase CLI)

3. **Edit permissions:**
   - Click **Edit** (pencil icon)
   - Click **+ ADD ANOTHER ROLE**
   - Search for: `Cloud Functions Admin`
   - Select: **Cloud Functions Admin**
   - Click **SAVE**

4. **Retry deployment:**
   ```bash
   firebase deploy --only functions:sendVerificationEmailManual
   ```

### Option 2: Set IAM Policy Manually After Deployment

If you can't get functions.admin role, we can make the function public (allUsers can invoke) after deployment:

1. **Deploy without setting invoker** (modify code temporarily)
2. **Set IAM manually via Console:**
   - Go to: Cloud Functions → sendVerificationEmailManual → Permissions
   - Add: `allUsers` with role `Cloud Functions Invoker`

### Option 3: Use Your Owner Account

Since `info@comnecter.com` has Owner role, try deploying while logged in as that account:

```bash
firebase login
# Login with info@comnecter.com
firebase deploy --only functions:sendVerificationEmailManual
```

### Option 4: Remove the Manual Function (Simplest)

If the manual function isn't critical (the automatic one works), we can remove it from the code for now:

- The automatic `sendVerificationEmail` function already works
- The manual one is just a fallback
- You can add it back later when permissions are sorted

## Recommended Action

Try **Option 1** first (grant Functions Admin role to your account), then redeploy:

```bash
firebase deploy --only functions:sendVerificationEmailManual
```


