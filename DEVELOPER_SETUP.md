# 👥 Developer Setup Guide - Comnecter Mobile

**Complete guide for developers working on Comnecter Mobile**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Firebase Configuration](#firebase-configuration)
4. [Running the App](#running-the-app)
5. [Development Workflow](#development-workflow)
6. [Troubleshooting](#troubleshooting)

---

## 🛠 Prerequisites

Before you begin, ensure you have the following installed:

### Required Tools
- **Flutter SDK** (3.0+): [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (included with Flutter)
- **Git**: [Install Git](https://git-scm.com/downloads)
- **Android Studio** or **VS Code** with Flutter extensions
- **Xcode** (macOS only, for iOS development): Available on App Store

### Verify Installation

```bash
flutter --version
git --version
dart --version
```

---

## 🚀 Initial Setup

### 1. Clone the Repository

```bash
git clone git@github.com:Comnecter/ComnecterMobile.git
cd ComnecterMobile
```

### 2. Checkout Development Branch

```bash
git checkout development
```

**Note:** Always work on the `development` branch, not `master`. `master` is protected and requires pull requests.

### 3. Install Flutter Dependencies

```bash
flutter pub get
```

### 4. Install iOS Dependencies (macOS only)

```bash
cd ios
pod install
cd ..
```

### 5. Verify Setup

```bash
flutter doctor
```

Fix any issues reported by `flutter doctor` before proceeding.

---

## 🔥 Firebase Configuration

### Important: Staging Config is Already Included ✅

**Good news!** The staging Firebase configuration files are **already committed** to the repository, so you don't need to download them manually.

**Files already in repository:**
- ✅ `android/app/src/staging/google-services.json` - **Committed and ready to use**
- ✅ `ios/Runner/GoogleService-Info-staging.plist` - **Committed and ready to use**

**Files NOT in repository (production):**
- ❌ `android/app/src/production/google-services.json` - **Not committed (security)**
- ❌ `ios/Runner/GoogleService-Info-production.plist` - **Not committed (security)**

### No Additional Firebase Setup Needed!

As a developer, you can start working immediately because:
1. Staging Firebase config files are already in the repo
2. They're automatically used when you build with the `staging` flavor
3. You'll connect to the staging Firebase project automatically

---

## 📱 Running the App

### Android

#### Run Staging Version (Recommended for Development)

```bash
flutter run --flavor staging
```

#### Build Staging APK

```bash
flutter build apk --flavor staging --release
```

#### Build Staging App Bundle

```bash
flutter build appbundle --flavor staging --release
```

### iOS (macOS only)

#### Run Staging Version

```bash
flutter run --flavor staging
```

**Note:** For iOS, you may need to:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the staging scheme
3. Build and run from Xcode, or use Flutter command above

#### Build Staging IPA

```bash
flutter build ipa --flavor staging --release
```

---

## 🔄 Development Workflow

### Standard Workflow

1. **Always start from development branch:**
   ```bash
   git checkout development
   git pull origin development
   ```

2. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes and commit:**
   ```bash
   git add .
   git commit -m "feat: your descriptive commit message"
   ```

4. **Push your feature branch:**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request on GitHub:**
   - Go to: https://github.com/Comnecter/ComnecterMobile
   - Click "New Pull Request"
   - Select `feature/your-feature-name` → `development`
   - Wait for review and approval
   - Only authorized users can merge PRs

### Branch Protection Rules

- ✅ **development branch**: Protected, requires PR to merge
- ✅ **master branch**: Protected, requires PR + verified signatures
- ❌ **Cannot delete**: `master` and `development` branches cannot be deleted
- ❌ **Cannot force push**: Force pushes are disabled for protected branches

---

## 🧪 Testing

### Run Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/features/discover/all_feed_test.dart

# With coverage
flutter test --coverage
```

### Manual Testing Checklist

Before pushing code, test:
- [ ] App builds successfully with `--flavor staging`
- [ ] Authentication (sign in/sign up)
- [ ] Radar detection works
- [ ] Chat functionality
- [ ] Friends management
- [ ] No console errors or crashes

---

## 📦 Build Flavors Explained

### Staging (Development)

**Use this for:**
- ✅ Development and testing
- ✅ Debugging
- ✅ Feature testing
- ✅ Internal testing

**Configuration:**
- Firebase Project: `comnecter-mobile-staging`
- Package/Bundle ID: `com.comnecter.mobile.staging`
- Config files: Already in repository ✅

### Production

**Use this for:**
- ❌ **DO NOT USE** unless you have production Firebase credentials
- ❌ Production builds require additional setup
- ❌ Production config files are NOT in repository (security)

---

## 🔐 Firebase Projects

### Staging Project (You Have Access)

- **Project ID**: `comnecter-mobile-staging-711a7`
- **Access**: You can use this for development
- **Config**: Already in repository, ready to use

### Production Project (Restricted)

- **Project ID**: `comnecter-mobile-product-dc4ea`
- **Access**: Restricted to authorized personnel only
- **Config**: Not in repository (security reasons)

---

## ⚠️ Important Notes

### ✅ Do This

- ✅ Always use `--flavor staging` when running the app
- ✅ Pull latest changes before starting work: `git pull origin development`
- ✅ Create feature branches for your work
- ✅ Test your changes before pushing
- ✅ Write descriptive commit messages

### ❌ Don't Do This

- ❌ **NEVER commit** production Firebase config files
- ❌ **NEVER commit** API keys or secrets
- ❌ **NEVER push directly** to `master` or `development`
- ❌ **NEVER force push** to protected branches
- ❌ **NEVER delete** `master` or `development` branches

---

## 🐛 Troubleshooting

### Issue: App won't build

**Solution:**
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..  # macOS only
flutter run --flavor staging
```

### Issue: Firebase not initializing

**Solution:**
- Verify you're using `--flavor staging`
- Check that `android/app/src/staging/google-services.json` exists
- Check that `ios/Runner/GoogleService-Info-staging.plist` exists (iOS)

### Issue: Cannot push to development

**Solution:**
- Development branch is protected
- You must create a feature branch and open a Pull Request
- Only authorized users can merge PRs

### Issue: Permission denied (git push)

**Solution:**
```bash
# Check your SSH key
ssh -T git@github.com

# If it fails, add your SSH key to GitHub
# See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
```

### Issue: CocoaPods errors (iOS)

**Solution:**
```bash
cd ios
rm Podfile.lock
pod deintegrate
pod install --repo-update
cd ..
```

### Issue: Android build fails

**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run --flavor staging
```

---

## 📚 Additional Resources

### Documentation Files

- **README.md** - Project overview and features
- **DEVELOPMENT.md** - Detailed development guide
- **TESTING_GUIDE.md** - Testing procedures
- **FIREBASE_CONFIGURATION_GUIDE.md** - Firebase setup details
- **STACK_EVALUATION.md** - Technology stack analysis

### Useful Commands

```bash
# Check current branch
git branch

# Switch to development
git checkout development

# Pull latest changes
git pull origin development

# View recent commits
git log --oneline -10

# Check what files changed
git status

# Run app with staging flavor
flutter run --flavor staging

# Build release APK
flutter build apk --flavor staging --release

# Analyze code
flutter analyze

# Format code
dart format .
```

---

## 🤝 Getting Help

### If You're Stuck

1. **Check documentation** - Read the relevant `.md` files in the repository
2. **Check existing issues** - Search GitHub Issues for similar problems
3. **Ask in team chat** - Reach out to other developers
4. **Check Flutter/Dart docs** - [flutter.dev](https://flutter.dev) and [dart.dev](https://dart.dev)

### Reporting Issues

If you find a bug or have a suggestion:
1. Create an issue on GitHub
2. Use descriptive title and description
3. Include steps to reproduce
4. Add relevant screenshots/logs

---

## ✅ Quick Start Checklist

For new developers, complete these steps:

- [ ] Install Flutter SDK (3.0+)
- [ ] Install Git
- [ ] Clone repository: `git clone git@github.com:Comnecter/ComnecterMobile.git`
- [ ] Checkout development: `git checkout development`
- [ ] Install dependencies: `flutter pub get`
- [ ] Install iOS pods (macOS only): `cd ios && pod install && cd ..`
- [ ] Run app: `flutter run --flavor staging`
- [ ] Verify app runs successfully
- [ ] Read this documentation completely
- [ ] Review `DEVELOPMENT.md` for detailed workflows

---

## 🎯 Summary

**Key Points for Developers:**

1. ✅ **Staging Firebase config is already in the repo** - No setup needed!
2. ✅ **Always use `--flavor staging`** when running the app
3. ✅ **Work on feature branches**, not directly on `development`
4. ✅ **Create Pull Requests** to merge your work
5. ✅ **Never commit production config files** or secrets

**You're ready to start developing! 🚀**

---

*Last Updated: Current Date*  
*For questions, contact the development team*

