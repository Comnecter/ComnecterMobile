# GA4 Setup Instructions - Comnecter Mobile

## 📊 Google Analytics 4 (GA4) Configuration Guide

### **STEP 1: Enable GA4 in Firebase Console**

#### For Staging Project (`comnecter-mobile-staging-711a7`):

1. **Go to Firebase Console**
   - Login: https://console.firebase.google.com/
   - Select project: `comnecter-mobile-staging-711a7`

2. **Enable Google Analytics**
   - Click on ⚙️ **Project Settings**
   - Scroll to **Google Analytics**
   - Click **Enable Google Analytics** (if not already enabled)
   - Select an existing GA4 property OR create a new one

3. **Create GA4 App Data Streams**
   
   **For Android:**
   - Go to **Analytics** → **Admin** → **Data Streams**
   - Click **Add Stream** → **Android app**
   - Package name: `com.comnecter.mobile.staging`
   - App name: `Comnecter Staging Android`
   - Click **Register app**
   - **IMPORTANT**: Copy the **Measurement ID** (e.g., `G-XXXXXXXXXX`)

   **For iOS:**
   - Click **Add Stream** again → **iOS app**
   - Bundle ID: `com.comnecter.mobile.staging`
   - App name: `Comnecter Staging iOS`
   - Click **Register app**
   - **IMPORTANT**: Copy the **Measurement ID**

#### Repeat for Production Project (`comnecter-mobile-product-dc4ea`):

- Package/Bundle ID's: `com.comnecter.mobile.production`
- App names: `Comnecter Production Android/iOS`

---

### **STEP 2: Update Firebase Config Files**

After creating the data streams, download new config files:

#### Android:
1. In Firebase Console: **Project Settings** → **Your apps**
2. Click on Android app: `com.comnecter.mobile.staging`
3. Download `google-services.json`
4. Replace: `android/app/src/staging/google-services.json`

Repeat for production: `android/app/src/production/google-services.json`

#### iOS:
1. Click on iOS app: `com.comnecter.mobile.staging`
2. Download `GoogleService-Info.plist`
3. Replace: `ios/Runner/GoogleService-Info-staging.plist`

Repeat for production: `ios/Runner/GoogleService-Info-production.plist`

---

### **STEP 3: Update firebase_options.dart**

Add the measurementId to all FirebaseOptions:

```dart
// STAGING - Add this:
static const FirebaseOptions androidStaging = FirebaseOptions(
  // ... existing fields ...
  measurementId: 'G-XXXXXXXXXX', // ← Add this!
);

static const FirebaseOptions iosStaging = FirebaseOptions(
  // ... existing fields ...
  measurementId: 'G-XXXXXXXXXX', // ← Add this!
);

// PRODUCTION - Add this:
static const FirebaseOptions androidProduction = FirebaseOptions(
  // ... existing fields ...
  measurementId: 'G-XXXXXXXXXX', // ← Add this!
);

static const FirebaseOptions iosProduction = FirebaseOptions(
  // ... existing fields ...
  measurementId: 'G-XXXXXXXXXX', // ← Add this!
);
```

---

### **STEP 4: Verify that Analytics Works**

After deploying:

1. **Test in the app:**
   ```dart
   // Log a test event
   await FirebaseService.instance.analytics.logEvent(
     name: 'app_started',
   );
   ```

2. **Check in GA4 Real-time:**
   - Go to GA4 dashboard
   - Open **Reports** → **Real-time**
   - You should see events within 1-2 minutes

---

## 🚨 Important

- **Staging and Production use different GA4 properties**
- **Each platform (iOS/Android) has its own Measurement ID**
- **Always update both environments (staging and production)**

---

## ✅ Checklist

- [ ] GA4 enabled in staging Firebase project
- [ ] GA4 enabled in production Firebase project
- [ ] Android data stream created for staging
- [ ] iOS data stream created for staging
- [ ] Android data stream created for production
- [ ] iOS data stream created for production
- [ ] New `google-services.json` files downloaded
- [ ] New `GoogleService-Info.plist` files downloaded
- [ ] `firebase_options.dart` updated with measurementId's
- [ ] App tested and events are coming through in GA4

---

## 📝 Notes

- GA4 takes 24-48 hours for complete data collection
- Real-time reports work immediately (1-2 minutes delay)
- Firestore, Auth, Storage work ALWAYS, with or without GA4
