# Firebase Project Setup Checklist

## 📋 Complete Setup Checklist voor Staging & Production

### ✅ STAP 1: Firebase Project Structure

#### Staging Project: `comnecter-mobile-staging-711a7`
- ✅ Project aangemaakt
- ⏳ Firestore Database ingesteld
- ⏳ Storage ingesteld
- ⏳ Authentication methodes ingesteld
- ⏳ Cloud Messaging (FCM) ingesteld
- ⏳ Crashlytics ingesteld
- ⏳ Analytics (GA4) ingesteld met datastroom

#### Production Project: `comnecter-mobile-product-dc4ea`
- ✅ Project aangemaakt
- ⏳ Firestore Database ingesteld
- ⏳ Storage ingesteld
- ⏳ Authentication methodes ingesteld
- ⏳ Cloud Messaging (FCM) ingesteld
- ⏳ Crashlytics ingesteld
- ⏳ Analytics (GA4) ingesteld met datastroom

---

### ✅ STAP 2: Android App Registration

#### Staging App: `com.comnecter.mobile.staging`
- ✅ App geregistreerd in Firebase Console
- ✅ `google-services.json` gedownload
- ✅ Bestand geplaatst op: `android/app/src/staging/google-services.json`
- ✅ Package name geverifieerd: `com.comnecter.mobile.staging`

#### Production App: `com.comnecter.mobile.production`
- ✅ App geregistreerd in Firebase Console
- ✅ `google-services.json` gedownload
- ✅ Bestand geplaatst op: `android/app/src/production/google-services.json`
- ✅ Package name geverifieerd: `com.comnecter.mobile.production`

---

### ✅ STAP 3: iOS App Registration

#### Staging App: `com.comnecter.mobile.staging`
- ✅ App geregistreerd in Firebase Console
- ✅ `GoogleService-Info.plist` gedownload
- ✅ Bestand geplaatst op: `ios/Runner/GoogleService-Info-staging.plist`
- ✅ Bundle ID geverifieerd: `com.comnecter.mobile.staging`

#### Production App: `com.comnecter.mobile.production`
- ✅ App geregistreerd in Firebase Console
- ✅ `GoogleService-Info.plist` gedownload
- ✅ Bestand geplaatst op: `ios/Runner/GoogleService-Info-production.plist`
- ✅ Bundle ID geverifieerd: `com.comnecter.mobile.production`

---

### ✅ STAP 4: Firestore Security Rules

#### Staging Firestore Rules
```javascript
// Bestand: firestore.rules (staging specifiek)
// Regels voor testomgeving - minder restrictief
```

#### Production Firestore Rules
```javascript
// Bestand: firestore.rules (production specifiek)
// Regels voor productie - strenger beveiligd
```

**Actie vereist:**
- [ ] Upload Firestore rules naar staging project
- [ ] Upload Firestore rules naar production project

---

### ✅ STAP 5: firebase_options.dart Configuratie

#### Huidige Status:
- ✅ Staging configuratie toegevoegd voor Android
- ⏳ Staging iOS App ID moet worden ingevuld
- ⏳ Production configuratie volledig invullen (Android + iOS)

#### Te vervangen placeholders:
1. `YOUR_STAGING_IOS_APP_ID` → Haal uit staging GoogleService-Info.plist
2. `YOUR_PRODUCTION_ANDROID_API_KEY` → Haal uit production google-services.json
3. `YOUR_PRODUCTION_ANDROID_APP_ID` → Haal uit production google-services.json
4. `YOUR_PRODUCTION_SENDER_ID` → Haal uit production google-services.json
5. `YOUR_PRODUCTION_IOS_API_KEY` → Haal uit production GoogleService-Info.plist
6. `YOUR_PRODUCTION_IOS_APP_ID` → Haal uit production GoogleService-Info.plist

---

### ✅ STAP 6: Android Build Configuration

#### build.gradle.kts
- ✅ Product flavors geconfigureerd
- ✅ Staging flavor: `com.comnecter.mobile.staging`
- ✅ Production flavor: `com.comnecter.mobile.production`
- ✅ Build types geconfigureerd (debug/release)

#### Commands:
```bash
# Staging build
flutter run --flavor staging

# Production build
flutter run --flavor production
```

---

### ✅ STAP 7: iOS Build Configuration

#### Info.plist
- ✅ Bundle Identifier ingesteld
- ⏳ Switchen tussen staging/production

#### Build Script
- ✅ `ios/build-config.sh` aangemaakt
- ⏳ Testen of script werkt

#### Commands:
```bash
# Switch to staging
./ios/build-config.sh staging

# Switch to production
./ios/build-config.sh production
```

---

### ✅ STAP 8: Google Analytics (GA4) Setup

#### Staging Analytics
- [ ] Datastroom aangemaakt voor staging Android app
- [ ] Datastroom aangemaakt voor staging iOS app
- [ ] Measurement ID toegevoegd aan app configuratie

#### Production Analytics
- [ ] Datastroom aangemaakt voor production Android app
- [ ] Datastroom aangemaakt voor production iOS app
- [ ] Measurement ID toegevoegd aan app configuratie

---

### ✅ STAP 9: Security Best Practices

#### Configuratie Bestanden
- [ ] `.gitignore` check: Zorg dat config bestanden NIET in Git staan:
  ```
  android/app/google-services.json
  android/app/src/*/google-services.json
  ios/Runner/GoogleService-Info*.plist
  ```
- [ ] Alternatief: Gebruik environment variables in CI/CD

#### API Keys
- [ ] API Key restrictions geconfigureerd in Firebase Console
- [ ] Android: App signer restriction toegevoegd
- [ ] iOS: Bundle ID restriction toegevoegd

---

### ✅ STAP 10: Testing & Verification

#### Staging Testing
- [ ] Android staging app buildt succesvol
- [ ] iOS staging app buildt succesvol
- [ ] Firebase Auth werkt in staging
- [ ] Firestore werkt in staging
- [ ] Storage werkt in staging
- [ ] FCM werkt in staging
- [ ] Crashlytics werkt in staging
- [ ] Analytics pikt events op in staging

#### Production Testing
- [ ] Android production app buildt succesvol
- [ ] iOS production app buildt succesvol
- [ ] Firebase Auth werkt in production
- [ ] Firestore werkt in production
- [ ] Storage werkt in production
- [ ] FCM werkt in production
- [ ] Crashlytics werkt in production
- [ ] Analytics pikt events op in production

---

## 🚨 CRITICAL ACTION ITEMS

### Immediate Actions Required:
1. **Haal de ontbrekende values uit de Firebase configuratiebestanden:**
   - iOS Staging App ID → `ios/Runner/GoogleService-Info-staging.plist`
   - Production Android credentials → `android/app/src/production/google-services.json`
   - Production iOS credentials → `ios/Runner/GoogleService-Info-production.plist`

2. **Update firebase_options.dart met de echte waarden**

3. **Upload Firestore security rules naar beide projecten**

4. **Test beide environments volledig**

---

## 📚 Documentation Referenties

- **Firebase Configuration Guide**: `FIREBASE_CONFIGURATION_GUIDE.md`
- **Launch Readiness**: `LAUNCH_READINESS_CHECKLIST.md`

---

## ⚠️ Belangrijk

- **NEVER** commit Firebase configuratiebestanden naar Git
- **ALWAYS** gebruik separate Firebase projects voor staging en production
- **VERIFY** dat de juiste build flavor wordt gebruikt voor de juiste environment
- **TEST** beide environments uitgebreid voordat je naar production gaat


