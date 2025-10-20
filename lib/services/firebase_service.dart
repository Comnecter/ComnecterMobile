import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._internal();

  FirebaseService._internal();

  // Firebase instances
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late FirebaseStorage _storage;
  late FirebaseMessaging _messaging;
  late FirebaseAnalytics _analytics;
  late FirebaseCrashlytics _crashlytics;

  // Getters
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => _storage;
  FirebaseMessaging get messaging => _messaging;
  FirebaseAnalytics get analytics => _analytics;
  FirebaseCrashlytics get crashlytics => _crashlytics;

  /// Initialize Firebase services
  Future<void> initialize() async {
    try {
      // Check if running on web platform
      if (kIsWeb) {
        print('🌐 Web platform detected - Firebase web has compatibility issues');
        print('📱 Firebase will work on mobile platforms (iOS/Android)');
        return;
      }

      // Initialize Firebase Core only if not already initialized
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        if (e.toString().contains('duplicate-app')) {
          // Firebase already initialized, this is fine
          print('🔥 Firebase already initialized, continuing with services setup');
        } else {
          rethrow;
        }
      }

      // Initialize Firebase services
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      _messaging = FirebaseMessaging.instance;
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Configure Firebase services
      await _configureFirebaseServices();

      print('🔥 Firebase initialized successfully!');
    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      await logFatalError('Firebase initialization failed', e, StackTrace.current, 
        customKeys: {'platform': kIsWeb ? 'web' : 'mobile'});
      rethrow;
    }
  }

  /// Configure Firebase services
  Future<void> _configureFirebaseServices() async {
    try {
      // Configure Firestore settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configure Firebase Auth settings
      await _configureAuthSettings();

      // Configure messaging permissions
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Configure crashlytics
      await _crashlytics.setCrashlyticsCollectionEnabled(true);

      // Configure analytics
      await _analytics.setAnalyticsCollectionEnabled(true);

      print('✅ Firebase services configured successfully!');
    } catch (e) {
      print('⚠️ Firebase service configuration failed: $e');
      await logError('Firebase service configuration failed', e, StackTrace.current);
      // Don't rethrow - these are optional configurations
    }
  }

  /// Configure Firebase Auth settings
  Future<void> _configureAuthSettings() async {
    try {
      // Set language code for better error messages
      _auth.setLanguageCode('en');
      
      print('🔐 Firebase Auth configured for development');
    } catch (e) {
      print('⚠️ Firebase Auth configuration failed: $e');
      await logError('Firebase Auth configuration failed', e, StackTrace.current);
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Sign out user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('👋 User signed out successfully');
    } catch (e) {
      print('❌ Sign out failed: $e');
      await logError('User sign out failed', e, StackTrace.current, 
        customKeys: {'user_id': currentUser?.uid ?? 'unknown'});
      rethrow;
    }
  }

  /// Log non-fatal error to Crashlytics
  Future<void> logError(String message, dynamic error, StackTrace? stackTrace, {Map<String, String>? customKeys}) async {
    try {
      if (!kIsWeb) {
        // Set custom keys for additional context
        if (customKeys != null) {
          for (final entry in customKeys.entries) {
            await _crashlytics.setCustomKey(entry.key, entry.value);
          }
        }
        
        // Log the error
        await _crashlytics.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: false,
        );
        
        print('📊 Error logged to Crashlytics: $message');
      } else {
        print('⚠️ Crashlytics not available on web platform: $message - $error');
      }
    } catch (e) {
      print('❌ Failed to log error to Crashlytics: $e');
    }
  }

  /// Log fatal crash to Crashlytics
  Future<void> logFatalError(String message, dynamic error, StackTrace? stackTrace, {Map<String, String>? customKeys}) async {
    try {
      if (!kIsWeb) {
        // Set custom keys for additional context
        if (customKeys != null) {
          for (final entry in customKeys.entries) {
            await _crashlytics.setCustomKey(entry.key, entry.value);
          }
        }
        
        // Log the fatal error
        await _crashlytics.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: true,
        );
        
        print('💥 Fatal error logged to Crashlytics: $message');
      } else {
        print('⚠️ Crashlytics not available on web platform: $message - $error');
      }
    } catch (e) {
      print('❌ Failed to log fatal error to Crashlytics: $e');
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserIdentifier(String userId) async {
    try {
      if (!kIsWeb) {
        await _crashlytics.setUserIdentifier(userId);
        print('👤 User ID set in Crashlytics: $userId');
      }
    } catch (e) {
      print('❌ Failed to set user ID in Crashlytics: $e');
    }
  }

  /// Log custom event to Crashlytics
  Future<void> logCustomEvent(String event, {Map<String, String>? parameters}) async {
    try {
      if (!kIsWeb) {
        if (parameters != null) {
          for (final entry in parameters.entries) {
            await _crashlytics.setCustomKey(entry.key, entry.value);
          }
        }
        await _crashlytics.log(event);
        print('📝 Custom event logged to Crashlytics: $event');
      }
    } catch (e) {
      print('❌ Failed to log custom event to Crashlytics: $e');
    }
  }

  /// Test crash reporting (DEBUG ONLY)
  Future<void> testCrash() async {
    if (kDebugMode && !kIsWeb) {
      try {
        _crashlytics.crash();
        print('🧪 Test crash triggered');
      } catch (e) {
        print('🧪 Test crash error: $e');
      }
    }
  }

  /// Dispose Firebase service
  Future<void> dispose() async {
    try {
      await _auth.signOut();
      print('🧹 Firebase service disposed');
    } catch (e) {
      print('⚠️ Firebase service disposal failed: $e');
      await logError('Firebase service disposal failed', e, StackTrace.current);
    }
  }
}


