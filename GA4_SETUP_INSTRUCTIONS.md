# GA4 Setup Instructions - Comnecter Mobile

## 📊 Google Analytics 4 (GA4) Configuration Guide

### **STAP 1: GA4 Ins行的 Fillen in Firebase Console**

#### Voor Staging Project (`comnecter-mobile-staging-711a7`):

1. **Ga naar Firebase Console**
   - Login: https://console.firebase.google.com/
   - Selecteer project: `comnecter-mobile-staging-711a7`

2. **Enable Google Analytics**
   - Klik op ⚙️ **Project Settings**
   - Scroll naar **Google Analytics**
   - Klik **Enable Google Analytics** (als het nog niet aan staat)
   - Selecteer een bestaande GA4 property OF maak een nieuwe aan

3. **Maak GA4 App Data Streams aan**
   
   **Voor Android:**
   - Ga naar **Analytics** → **Admin** → **Data Streams**
   - Klik **Add Stream** → **Android app**
   - Package name: `com.comnecter.mobile.staging`
   - App name: `Comnecter Staging Android`
   - Klik **Register app**
   - **BELANGRIJK**: Kopieer de **Measurement ID** (bijv. `G-XXXXXXXXXX`)

   **Voor iOS:**
   - Klik opnieuw **Add Stream** → **iOS app**
   - Bundle ID: `com.comnecter.mobile.staging`
   - App name: `Comnecter Staging iOS`
   - Klik **Register app**
   - **BELANGRIJK**: Kopieer de **Measurement ID**

#### Herhaal voor Production Project (`comnecter-mobile-product-dc4ea`):

- Package/Bundle ID's: `com.comnecter.mobile.production`
- App names: `Comnecter Production Android/iOS`

---

### **STAP 2: Update Firebase Config Files**

Na het aanmaken van de data streams, download je nieuwe config bestanden:

#### Android:
1. In Firebase Console: **Project Settings** → **Your apps**
2. Klik op Android app: `com.comnecter.mobile.staging`
3. Download `google-services.json`
4. Vervang: `android/app/src/staging/google-services.json`

Herhaal voor production: `android/app/src/production/google-services.json`

#### iOS:
1. Klik op iOS app: `com.comnecter.mobile.staging`
2. Download `GoogleService-Info.plist`
3. Vervang: `ios/Runner/GoogleService-Info-staging.plist`

Herhaal voor production: `ios/Runner/GoogleService-Info-production.plist`

---

### **STAP 3: Update firebase_options.dart**

Voeg de measurementId toe aan alle FirebaseOptions:

```dart
// STAGING - Voeg dit toe:
static const FirebaseOptions androidStaging = FirebaseOptions(
  // ... bestaande velden ...
  measurementId: 'G-XXXXXXXXXX', // ← Voeg toe!
);

static const FirebaseOptions iosStaging = FirebaseOptions(
  // ... bestaande velden ...
  measurementId: 'G-XXXXXXXXXX', // ← Voeg toe!
);

// PRODUCTION - Voeg dit toe:
static const FirebaseOptions androidProduction = FirebaseOptions(
  // ... bestaande velden ...
  measurementId: 'G-XXXXXXXXXX', // ← Voeg toe!
);

static const FirebaseOptions iosProduction = FirebaseOptions(
  // ... bestaande velden ...
  measurementId: 'G-XXXXXXXXXX', // ← Voeg toe!
);
```

---

### **STAP 4: Verifieer dat Analytics Werkt**

Na het deployen:

1. **Test in de app:**
   ```dart
   // Log een test event
   await FirebaseService.instance.analytics.logEvent(
     name: 'app_started',
   );
   ```

2. **Check in GA4 Real-time:**
   - Ga naar GA4 dashboard
   - Open **Reports** → **Real-time**
   - Je zou events moeten zien binnen 1-2 minuten

---

## 🚨 Belangrijk

- **Staging en Production gebruiken verschillende GA4 properties**
- **Elk platform (iOS/Android) heeft een eigen Measurement ID**
- **Update ALTIJD beide environments (staging en production)**

---

## ✅ Checklist

- [ ] GA4 enabled in staging Firebase project
- [ ] GA4 enabled in production Firebase project
- [ ] Android data stream aangemaakt voor staging
- [ ] iOS data stream aangemaakt voor staging
- [ ] Android data stream aangemaakt voor production
- [ ] iOS data stream aangemaakt voor production
- [ ] Nieuwe `google-services.json` bestanden gedownload
- [ ] Nieuwe `GoogleService-Info.plist` bestanden gedownload
- [ ] `firebase_options.dart` geüpdatet met measurementId's
- [ ] App getest en events komen door in GA4

---

## 📝 Notities

- GA4 heeft 24-48 uur nodig voor volledige data verzameling
- Real-time reports werken direct (1-2 minuten delay)
- Firestore, Auth, Storage werken ALTIJD, met of zonder GA4


