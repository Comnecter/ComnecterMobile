# Android Build Flavors - Staging & Production

This project uses Android build flavors to switch between staging and production Firebase configurations.

## Setup

### Staging Configuration
The staging configuration is already set up at:
- `android/app/src/staging/google-services.json`

### Production Configuration
Replace the placeholder at:
- `android/app/src/production/google-services.json`

With your actual production Firebase `google-services.json` downloaded from Firebase Console.

## How to Build

### For Staging Environment:
```bash
# Debug build
flutter build apk --flavor staging --debug

# Release build
flutter build apk --flavor staging --release

# Run on device
flutter run --flavor staging
```

### For Production Environment:
```bash
# Debug build
flutter build apk --flavor production --debug

# Release build
flutter build apk --flavor production --release

# Run on device
flutter run --flavor production
```

## Package Names

- **Staging**: `com.comnecter.mobile.staging`
- **Production**: `com.comnecter.mobile.production`

## Important Notes

1. **Different Firebase Projects**: Each flavor should connect to a different Firebase project
   - Staging uses: `comnecter-mobile-staging-711a7`
   - Production uses: Your production Firebase project

2. **App Names**: 
   - Staging app shows: "Comnecter Staging"
   - Production app shows: "Comnecter"

3. **Can Install Both**: Since the package names are different, you can have both staging and production versions installed on the same device for testing.

4. **Firestore Rules**: Make sure your Firestore security rules are properly configured for both environments.

## Downloading google-services.json

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (staging or production)
3. Go to **Project Settings** ⚙️
4. Scroll to **"Your apps"** section
5. Click on your Android app
6. Click **"Download google-services.json"**
7. Place it in the correct folder:
   - Staging: `android/app/src/staging/google-services.json`
   - Production: `android/app/src/production/google-services.json`



