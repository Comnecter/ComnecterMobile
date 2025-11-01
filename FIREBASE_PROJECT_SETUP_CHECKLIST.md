# Firebase Project Setup Checklist

## 📋 Complete Setup Checklist for Staging & Production

### ✅ STEP 1: Firebase Project Structure

#### Staging Project: `comnecter-mobile-staging-711a7`
- ✅ Project created
- ⏳ Firestore Database configured
- ⏳ Storage configured
- ⏳ Authentication methods configured
- ⏳ Cloud Messaging (FCM) configured
- ⏳ Crashlytics configured
- ⏳ Analytics (GA4) configured with data stream

#### Production Project: `comnecter-mobile-product-dc4ea`
- ✅ Project created
- ⏳ Firestore Database configured
- ⏳ Storage configured
- ⏳ Authentication methods configured
- ⏳ Cloud Messaging (FCM) configured
- ⏳ Crashlytics configured
- ⏳ Analytics (GA4) configured with data stream

---

### ✅ STEP 2: Android App Registration

#### Staging App: `com.comnecter.mobile.staging`
- ✅ App registered in Firebase Console
- ✅ `google-services.json` downloaded
- ✅ File placed at: `android/app/src/staging/google-services.json`
- ✅ Package name verified: `com.comnecter.mobile.staging`

#### Production App: `com.comnecter.mobile.production`
- ✅ App registered in Firebase Console
- ✅ `google-services.json` downloaded
- ✅ File placed at: `android/app/src/production/google-services.json`
- ✅ Package name verified: `com.comnecter.mobile.production`

---

### ✅ STEP 3: iOS App Registration

#### Staging App: `com.comnecter.mobile.staging`
- ✅ App registered in Firebase Console
- ✅ `GoogleService-Info.plist` downloaded
- ✅ File placed at: `ios/Runner/GoogleService-Info-staging.plist`
- ✅ Bundle ID verified: `com.comnecter.mobile.staging`

#### Production App: `com.comnecter.mobile.production`
- ✅ App registered in Firebase Console
- ✅ `GoogleService-Info.plist` downloaded
- ✅ File placed at: `ios/Runner/GoogleService-Info-production.plist`
- ✅ Bundle ID verified: `com.comnecter.mobile.production`

---

### ✅ STEP 4: Firestore Security Rules

#### Staging Firestore Rules
```javascript
// File: firestore.rules (staging specific)
// Rules for test environment - less restrictive
```

#### Production Firestore Rules
```javascript
// File: firestore.rules (production specific)
// Rules for production - more secure
```

**Action required:**
- [ ] Upload Firestore rules to staging project
- [ ] Upload Firestore rules to production project

---

### ✅ STEP 5: firebase_options.dart Configuration

#### Current Status:
- ✅ Staging configuration added for Android
- ⏳ Staging iOS App ID needs to be filled in
- ⏳ Production configuration needs to be fully completed (Android + iOS)

#### Placeholders to replace:
1. `YOUR_STAGING_IOS_APP_ID` → Get from staging GoogleService-Info.plist
2. `YOUR_PRODUCTION_ANDROID_API_KEY` → Get from production google-services.json
3. `YOUR_PRODUCTION_ANDROID_APP_ID` → Get from production google-services.json
4. `YOUR_PRODUCTION_SENDER_ID` → Get from production google-services.json
5. `YOUR_PRODUCTION_IOS_API_KEY` → Get from production GoogleService-Info.plist
6. `YOUR_PRODUCTION_IOS_APP_ID` → Get from production GoogleService-Info.plist

---

### ✅ STEP 6: Android Build Configuration

#### build.gradle.kts
- ✅ Product flavors configured
- ✅ Staging flavor: `com.comnecter.mobile.staging`
- ✅ Production flavor: `com.comnecter.mobile.production`
- ✅ Build types configured (debug/release)

#### Commands:
```bash
# Staging build
flutter run --flavor staging

# Production build
flutter run --flavor production
```

---

### ✅ STEP 7: iOS Build Configuration

#### Info.plist
- ✅ Bundle Identifier configured
- ⏳ Switching between staging/production

#### Build Script
- ✅ `ios/build-config.sh` created
- ⏳ Test if script works

#### Commands:
```bash
# Switch to staging
./ios/build-config.sh staging

# Switch to production
./ios/build-config.sh production
```

---

### ✅ STEP 8: Google Analytics (GA4) Setup

#### Staging Analytics
- [ ] Data stream created for staging Android app
- [ ] Data stream created for staging iOS app
- [ ] Measurement ID added to app configuration

#### Production Analytics
- [ ] Data stream created for production Android app
- [ ] Data stream created for production iOS app
- [ ] Measurement ID added to app configuration

---

### ✅ STEP 9: Security Best Practices

#### Configuration Files
- [ ] `.gitignore` check: Ensure config files are NOT in Git:
  ```
  android/app/google-services.json
  android/app/src/*/google-services.json
  ios/Runner/GoogleService-Info*.plist
  ```
- [ ] Alternative: Use environment variables in CI/CD

#### API Keys
- [ ] API Key restrictions configured in Firebase Console
- [ ] Android: App signer restriction added
- [ ] iOS: Bundle ID restriction added

---

### ✅ STEP 10: Testing & Verification

#### Staging Testing
- [ ] Android staging app builds successfully
- [ ] iOS staging app builds successfully
- [ ] Firebase Auth works in staging
- [ ] Firestore works in staging
- [ ] Storage works in staging
- [ ] FCM works in staging
- [ ] Crashlytics works in staging
- [ ] Analytics picks up events in staging

#### Production Testing
- [ ] Android production app builds successfully
- [ ] iOS production app builds successfully
- [ ] Firebase Auth works in production
- [ ] Firestore works in production
- [ ] Storage works in production
- [ ] FCM works in production
- [ ] Crashlytics works in production
- [ ] Analytics picks up events in production

---

## 🚨 CRITICAL ACTION ITEMS

### Immediate Actions Required:
1. **Get the missing values from Firebase configuration files:**
   - iOS Staging App ID → `ios/Runner/GoogleService-Info-staging.plist`
   - Production Android credentials → `android/app/src/production/google-services.json`
   - Production iOS credentials → `ios/Runner/GoogleService-Info-production.plist`

2. **Update firebase_options.dart with real values**

3. **Upload Firestore security rules to both projects**

4. **Test both environments completely**

---

## 📚 Documentation References

- **Firebase Configuration Guide**: `FIREBASE_CONFIGURATION_GUIDE.md`
- **Launch Readiness**: `LAUNCH_READINESS_CHECKLIST.md`

---

## ⚠️ Important

- **NEVER** commit Firebase configuration files to Git
- **ALWAYS** use separate Firebase projects for staging and production
- **VERIFY** that the correct build flavor is used for the correct environment
- **TEST** both environments extensively before going to production
