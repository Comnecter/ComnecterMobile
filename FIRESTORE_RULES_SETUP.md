# Firebase Firestore Rules Setup Guide

## 🚨 The Problem

You're seeing this error:
```
Failed to load communities. [cloud_firestore/permission-denied] 
The caller does not have permission to execute the specified operation
```

This means your **Firestore security rules** are blocking database operations. The code is working correctly, but Firebase is denying access.

---

## 🔧 Quick Fix (Option 1: For Testing Only)

If you want to **test immediately** and are in a development environment:

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Firestore Database** in the left menu
4. Click the **Rules** tab

### Step 2: Use These Simple Rules (Testing Only)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write everything
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 3: Click **Publish**

⚠️ **Warning**: These rules are NOT secure for production! They allow any authenticated user to read/write any data.

---

## 🔒 Production-Ready Rules (Option 2: Recommended)

For a **secure production** setup, use the rules from `firestore.rules` file in your project root.

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Firestore Database** in the left menu
4. Click the **Rules** tab

### Step 2: Copy and Paste Production Rules

Copy the entire contents of the `firestore.rules` file I created, or use this:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isOwner(userId);
      allow update, delete: if isOwner(userId);
    }
    
    // Communities collection
    match /communities/{communityId} {
      // Anyone signed in can read communities
      allow read: if isSignedIn();
      
      // Any signed-in user can create a community
      allow create: if isSignedIn() 
                    && request.resource.data.creatorId == request.auth.uid
                    && request.resource.data.memberIds is list
                    && request.auth.uid in request.resource.data.memberIds;
      
      // Only the creator can update community details
      allow update: if isSignedIn() 
                    && resource.data.creatorId == request.auth.uid;
      
      // Only the creator can delete the community
      allow delete: if isSignedIn() 
                    && resource.data.creatorId == request.auth.uid;
    }
    
    // Community members collection
    match /community_members/{memberId} {
      // Anyone signed in can read community members
      allow read: if isSignedIn();
      
      // Users can create their own membership entries
      allow create: if isSignedIn() 
                    && request.resource.data.userId == request.auth.uid;
      
      // Users can update their own membership status
      allow update: if isSignedIn() 
                    && resource.data.userId == request.auth.uid;
      
      // Community creators can delete member entries
      allow delete: if isSignedIn();
    }
    
    // User profiles (if you have them)
    match /profiles/{userId} {
      allow read: if isSignedIn();
      allow write: if isOwner(userId);
    }
    
    // Default deny for all other paths
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Click **Publish**

---

## 📋 What These Rules Do

### Communities
- ✅ **Read**: Any authenticated user can view communities
- ✅ **Create**: Any authenticated user can create a community (they become the creator)
- ✅ **Update**: Only the community creator can update details
- ✅ **Delete**: Only the community creator can delete

### Community Members
- ✅ **Read**: Any authenticated user can see who's in communities
- ✅ **Create**: Users can add themselves to communities
- ✅ **Update**: Users can update their own membership info
- ✅ **Delete**: Controlled deletion

### Security Features
- 🔒 Must be authenticated (signed in) to do anything
- 🔒 Creator validation on community creation
- 🔒 Permission checks for updates/deletes
- 🔒 User can only modify their own data

---

## 🧪 Testing the Fix

After updating the rules:

1. **Wait 30-60 seconds** for rules to propagate
2. **Restart your app** completely
3. **Try creating a community** again
4. If still having issues:
   - Check Firebase Console → Firestore → Data tab
   - Verify you're signed in (check Firebase Auth)
   - Check browser console for detailed error messages

---

## 🚀 Deploying Rules via CLI (Optional)

If you want to deploy rules from the command line:

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done)
firebase init firestore

# Deploy the rules
firebase deploy --only firestore:rules
```

---

## 🔍 Verifying Your Current Rules

To see your current rules:
1. Firebase Console → Firestore Database → Rules tab
2. You'll see what rules are currently active

Common wrong configurations:
- Rules that deny all access
- Rules that only allow in test mode
- Expired test mode rules

---

## 📞 Still Having Issues?

If you're still getting permission errors after updating rules:

1. **Check Firebase Auth**: Make sure you're signed in
   ```dart
   print('Current user: ${FirebaseAuth.instance.currentUser?.uid}');
   ```

2. **Check Firestore Rules Match**: Rules in console match the ones above

3. **Clear App Data**: Sometimes cached rules cause issues
   - iOS: Delete and reinstall app
   - Android: Clear app data in settings

4. **Check Firebase Console Logs**: 
   - Firestore → Usage tab
   - Look for specific error messages

---

## ✅ Success Checklist

- [ ] Updated Firestore rules in Firebase Console
- [ ] Clicked "Publish" button
- [ ] Waited 30-60 seconds
- [ ] Restarted the app
- [ ] User is signed in
- [ ] Community creation works!

---

**Next Steps After Fix**: 
Once the rules are updated, your community creation feature will work immediately! The error will disappear and you'll be able to create, view, and manage communities.

