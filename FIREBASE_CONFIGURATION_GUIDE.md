# Firebase Configuration Guide - Staging & Production

This guide explains how to manage Firebase configuration files for Android and iOS, and how to switch between staging and production environments.

## Table of Contents
1. [Overview](#overview)
2. [Android Configuration](#android-configuration)
3. [iOS Configuration](#ios-configuration)
4. [Switching Between Environments](#switching-between-environments)
5. [Troubleshooting](#troubleshooting)

---

## Overview

### Firebase Configuration Files

- **Android**: `google-services.json`
- **iOS**: `GoogleService-Info.plist`

These files contain your Firebase project credentials and must match your app's package name/bundle identifier.

### Why Separate Files?

Using separate configuration files for staging and production provides:
- **Data Isolation**: Test data doesn't mix with production data
- **Security**: Different API keys and quotas
- **Easy Switching**: Build different environments without code changes
- **Safe Testing**: Test features without affecting production users

---

## Android Configuration

### Current Setup

We use **Android Build Flavors** to manage different Firebase configurations:

```
android/app/
├── src/
│   ├── staging/
│   │   └── google-services.json       # Staging configuration
│   └── production/
│       └── google-services.json       # Production configuration
└── build.gradle.kts                   # Build configuration
```

### Package Names

- **Staging**: `com.comnecter.mobile.staging`
- **Production**: `com.comnecter.mobile.production`

### How It Works

The Gradle build system automatically selects the correct `google-services.json` based on the build flavor:

```kotlin
// android/app/build.gradle.kts
productFlavors {
    create("staging") {
        applicationId = "com.comnecter.mobile.staging"
        versionNameSuffix = "-staging"
    }
    create("production") {
        applicationId = "com.comnecter.mobile.production"
    }
}
```

### Setup Instructions

#### Step 1: Download Configuration Files

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **staging project**
3. Go to **Project Settings** → **Your apps**
4. Click **Android app** or **Add app** if none exists
5. Enter package name: `com.comnecter.mobile.staging`
6. Download `google-services.json`
7. Save to: `android/app/src/staging/google-services.json`

Repeat for **production** project with package name `com.comnecter.mobile.production`:
- Save to: `android/app/src/production/google-services.json`

#### Step 2: Verify Configuration

Ensure each `google-services.json` has the correct package name:

**Staging:**
```json
{
  "client_info": {
    "android_client_info": {
      "package_name": "com.comnecter.mobile.staging"
    }
  }
}
```

**Production:**
```json
{
  "client_info": {
    "android_client_info": {
      "package_name": "com.comnecter.mobile.production"
    }
  }
}
```

#### Step 3: Build Commands

```bash
# Build staging APK
flutter build apk --flavor staging --release

# Build production APK
flutter build apk --flavor production --release

# Run staging on device
flutter run --flavor staging

# Run production on device
flutter run --flavor production
```

---

## iOS Configuration

### Current Setup

iOS uses separate build targets or schemes to manage different configurations:

```
ios/Runner/
├── GoogleService-Info-staging.plist    # Staging configuration
├── GoogleService-Info-production.plist # Production configuration
└── Info.plist                          # Bundle identifier configuration
```

### Bundle Identifiers

Update `ios/Runner/Info.plist` manually when switching:

**Staging:**
```xml
<key>CFBundleIdentifier</key>
<string>com.comnecter.mobile.staging</string>
```

**Production:**
```xml
<key>CFBundleIdentifier</key>
<string>com.comnecter.mobile.production</string>
```

### Setup Instructions

#### Step 1: Download Configuration Files

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **staging project**
3. Go to **Project Settings** → **Your apps**
4. Click **iOS app** or **Add app** if none exists
5. Enter bundle ID: `com.comnecter.mobile.staging`
6. Download `GoogleService-Info.plist`
7. Rename and save to: `ios/Runner/GoogleService-Info-staging.plist`

Repeat for **production** project with bundle ID `com.comnecter.mobile.production`:
- Save to: `ios/Runner/GoogleService-Info-production.plist`

#### Step 2: Update Xcode Configuration

**Option A: Manual Copy (Current Method)**
1. Before building staging, copy:
   ```bash
   cp ios/Runner/GoogleService-Info-staging.plist ios/Runner/GoogleService-Info.plist
   ```
2. Update `ios/Runner/Info.plist` bundle identifier
3. Build in Xcode or via Flutter

**Option B: Use Build Script (Recommended)**

Create a build script to automate copying:

```bash
# ios/build-config.sh
#!/bin/bash

ENV=${1:-staging}

if [ "$ENV" = "staging" ]; then
    cp ios/Runner/GoogleService-Info-staging.plist ios/Runner/GoogleService-Info.plist
    sed -i '' 's/com.comnecter.mobile.production/com.comnecter.mobile.staging/g' ios/Runner/Info.plist
    echo "✅ Configured for staging"
elif [ "$ENV" = "production" ]; then
    cp ios/Runner/GoogleService-Info-production.plist ios/Runner/GoogleService-Info.plist
    sed -i '' 's/com.comnecter.mobile.staging/com.comnecter.mobile.production/g' ios/Runner/Info.plist
    echo "✅ Configured for production"
else
    echo "❌ Invalid environment. Use 'staging' or 'production'"
    exit 1
fi
```

Usage:
```bash
chmod +x ios/build-config.sh
./ios/build-config.sh staging   # Switch to staging
./ios/build-config.sh production # Switch to production
flutter run
```

#### Step 3: Build Commands

```bash
# Build staging iOS app
./ios/build-config.sh staging
flutter build ios --release

# Build production iOS app
./ios/build-config.sh production
flutter build ios --release

# Run on device (after switching config)
flutter run
```

---

## Switching Between Environments

### Android (Automatic)

Android automatically uses the correct configuration based on the flavor:

```bash
# Staging
flutter run --flavor staging

# Production  
flutter run --flavor production
```

### iOS (Manual)

iOS requires manual switching:

1. **Switch configuration:**
   ```bash
   ./ios/build-config.sh staging  # or production
   ```

2. **Verify bundle identifier** in `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleIdentifier</key>
   <string>com.comnecter.mobile.staging</string>
   ```

3. **Build and run:**
   ```bash
   flutter run
   ```

---

## Troubleshooting

### Common Issues

#### 1. Package Name Mismatch

**Error:**
```
No matching client found for package name 'com.comnecter.mobile.app'
```

**Solution:**
- Ensure your `google-services.json` package name matches the `applicationId` in `build.gradle.kts`
- For staging: must be `com.comnecter.mobile.staging`
- For production: must be `com.comnecter.mobile.production`

#### 2. Missing Firebase Configuration

**Error:**
```
Missing GoogleService-Info.plist
```

**Solution:**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in `ios/Runner/`
3. Ensure it's added to Xcode project

#### 3. Wrong Firebase Project

**Error:**
```
Firestore permission denied
```

**Solution:**
- Verify you're using the correct Firebase project for the environment
- Check Firestore rules are deployed for that project
- Ensure user authentication is working

#### 4. CocoaPods Dependency Conflicts

**Error:**
```
CocoaPods could not find compatible versions for pod "Firebase/Auth"
```

**Solution:**
```bash
cd ios
pod repo update
pod deintegrate
pod install
```

#### 5. Network Connectivity Issues

**Error:**
```
Unable to resolve host "firestore.googleapis.com"
```

**Solution:**
- Check device internet connection
- Verify VPN/firewall isn't blocking Google services
- Try restarting the device/emulator

---

## Best Practices

### 1. Version Control

**DO:**
- ✅ Commit configuration files to version control
- ✅ Keep staging and production configs in separate files
- ✅ Use `.gitignore` for sensitive API keys (if needed)

**DON'T:**
- ❌ Mix staging and production data
- ❌ Use production configs for development
- ❌ Commit secrets or API keys directly

### 2. Build Process

**Before Building:**
1. Verify you have the correct configuration files
2. Check package name/bundle ID matches
3. Ensure Firebase project is set up correctly

**After Building:**
1. Test Firebase Authentication
2. Verify Firestore access
3. Check Analytics and Crashlytics

### 3. Security

- Never expose Firebase API keys in public repositories
- Use environment-specific API keys
- Regularly rotate API keys
- Monitor Firebase usage and quotas

---

## Quick Reference

### Android Commands
```bash
# Staging
flutter run --flavor staging
flutter build apk --flavor staging --release

# Production
flutter run --flavor production
flutter build apk --flavor production --release
```

### iOS Commands
```bash
# Switch to staging
./ios/build-config.sh staging
flutter run

# Switch to production
./ios/build-config.sh production
flutter run
```

### File Locations

**Android:**
- Staging: `android/app/src/staging/google-services.json`
- Production: `android/app/src/production/google-services.json`

**iOS:**
- Staging: `ios/Runner/GoogleService-Info-staging.plist`
- Production: `ios/Runner/GoogleService-Info-production.plist`

---

## Additional Resources

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Android Build Flavors](https://developer.android.com/studio/build/build-variants)
- [iOS Build Configurations](https://developer.apple.com/documentation/xcode/build-settings)

---

## Need Help?

If you encounter issues:
1. Check this guide's troubleshooting section
2. Verify Firebase Console settings
3. Review Flutter and Firebase logs
4. Check network connectivity

---

**Last Updated:** 2025-01-25
**Maintained By:** Comnecter Development Team



