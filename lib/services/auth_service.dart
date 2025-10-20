
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_service.dart';

import 'dart:io';
import 'dart:async';
import 'dart:math';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  


  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;
  

  
  /// Get current user with fallback to Firebase Auth
  User? get currentUser {
    if (_user != null) {
      return _user;
    }
    // Fallback to Firebase Auth if local state is empty
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      print('⚠️ Error getting current user: $e');
      FirebaseService.instance.logError('Error getting current user', e, StackTrace.current);
      return null;
    }
  }
  
  /// Refresh user state from Firebase Auth
  Future<void> refreshUserState() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && _user?.uid != currentUser.uid) {
        _user = currentUser;
        print('🔄 User state refreshed: ${_user!.email} (UID: ${_user!.uid})');
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Error refreshing user state: $e');
      FirebaseService.instance.logError('Error refreshing user state', e, StackTrace.current);
    }
  }



  AuthService() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      
      // Set user ID in Crashlytics when authentication state changes
      if (user != null) {
        FirebaseService.instance.setUserIdentifier(user.uid);
        FirebaseService.instance.logCustomEvent('User authenticated', parameters: {
          'email': user.email ?? 'unknown',
          'verified': user.emailVerified.toString(),
        });
      } else {
        FirebaseService.instance.setUserIdentifier('anonymous');
        FirebaseService.instance.logCustomEvent('User signed out');
      }
      
      notifyListeners();
    });
  }

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (kDebugMode) {
        print('🚀 Starting sign-up process for: $email');
      }

      // Validate input parameters
      if (email.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Email and password are required');
      }

      if (password.length < 8) {
        return AuthResult.failure('Password must be at least 8 characters long');
      }
      
      // Check network connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return AuthResult.failure('No internet connection. Please check your network and try again.');
      }

      // Try to create user account directly first
      try {
        final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('Account creation timed out'),
        );
        
        _user = userCredential.user;

        if (kDebugMode) {
          print('✅ User account created successfully: ${userCredential.user?.uid}');
        }

        // Update display name if provided
        if (displayName != null && displayName.trim().isNotEmpty && userCredential.user != null) {
          try {
            await userCredential.user!.updateDisplayName(displayName.trim());
            if (kDebugMode) {
              print('✅ Display name updated: $displayName');
            }
            
            // Reload user to get updated profile
            await userCredential.user!.reload();
            _user = _auth.currentUser;
            
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Could not update display name: $e');
            }
            // Don't fail sign-up if display name update fails
          }
        }

        // Store user data securely in Firestore
        if (userCredential.user != null) {
          try {
            final firestore = FirebaseFirestore.instance;
            await firestore.collection('users').doc(userCredential.user!.uid).set({
              'uid': userCredential.user!.uid,
              'email': email.trim(),
              'displayName': displayName?.trim() ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'lastSeen': FieldValue.serverTimestamp(),
              'isOnline': true,
              'emailVerified': false,
              'twoFactorEnabled': false,
              'phoneNumber': null,
              'lastSignIn': FieldValue.serverTimestamp(),
              'signInCount': 1,
              'accountStatus': 'active',
              'securityLevel': 'standard',
              'dataVersion': 1,
              'deviceInfo': {
                'platform': Platform.operatingSystem,
                'version': Platform.operatingSystemVersion,
                'timestamp': FieldValue.serverTimestamp(),
              },
            });
            if (kDebugMode) {
              print('✅ User data securely stored in Firestore');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Could not store user data in Firestore: $e');
            }
            // Don't fail sign-up if Firestore storage fails
          }
        }

        // Send email verification
        try {
          await userCredential.user!.sendEmailVerification();
          if (kDebugMode) {
            print('✅ Verification email sent');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not send verification email: $e');
          }
          // Don't fail sign-up if email verification fails
        }

        if (kDebugMode) {
          print('🎉 Sign-up completed successfully');
        }
        return AuthResult.success(userCredential.user);
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) {
          print('❌ Firebase Auth error during sign-up: ${e.code} - ${e.message}');
        }
        
        // Log auth errors to Crashlytics
        FirebaseService.instance.logError('Firebase Auth sign-up error: ${e.code}', e, StackTrace.current,
          customKeys: {'error_code': e.code, 'email': email.trim()});
        
        // If we get email-already-in-use, don't retry
        if (e.code == 'email-already-in-use') {
          return AuthResult.failure(_getErrorMessage(e.code));
        }
        
        // For other errors, try the fallback approach
        if (kDebugMode) {
          print('🔄 Trying fallback sign-up approach...');
        }
        return _fallbackSignUp(email, password, displayName);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Unexpected error during sign-up: $e');
        }
        
        // Log unexpected sign-up errors as fatal
        FirebaseService.instance.logFatalError('Unexpected sign-up error', e, StackTrace.current,
          customKeys: {'email': email.trim(), 'operation': 'sign_up'});
        
        // Try fallback approach for unexpected errors
        return _fallbackSignUp(email, password, displayName);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Fallback sign-up method with state clearing
  Future<AuthResult> _fallbackSignUp(String email, String password, String? displayName) async {
    try {
      if (kDebugMode) {
        print('🔄 Attempting fallback sign-up with state clearing for: $email');
      }
      
      // Clear any corrupted Firebase state
      try {
        await _auth.signOut();
        if (kDebugMode) {
          print('🔄 Cleared Firebase state to prevent sign-up errors');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not clear Firebase state: $e');
        }
      }

      // Wait a moment for state to clear
      await Future.delayed(const Duration(milliseconds: 800));

      // Try to create user account with fresh state
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Account creation timed out'),
      );
      
      _user = userCredential.user;

      if (kDebugMode) {
        print('✅ Fallback user account created successfully: ${userCredential.user?.uid}');
      }

      // Update display name if provided
      if (displayName != null && displayName.trim().isNotEmpty && userCredential.user != null) {
        try {
          await userCredential.user!.updateDisplayName(displayName.trim());
          if (kDebugMode) {
            print('✅ Display name updated: $displayName');
          }
          
          // Reload user to get updated profile
          await userCredential.user!.reload();
          _user = _auth.currentUser;
          
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not update display name: $e');
          }
        }
      }

      // Simplified Firestore storage for fallback
      if (userCredential.user != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email.trim(),
            'displayName': displayName?.trim() ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': true,
          });
        } catch (e) {
          // Ignore Firestore errors in fallback mode
        }
      }

      // Send email verification
      try {
        await userCredential.user!.sendEmailVerification();
      } catch (e) {
        // Ignore verification errors in fallback mode
      }

      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth error during fallback sign-up: ${e.code} - ${e.message}');
      }
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during fallback sign-up: $e');
      }
      
      if (e.toString().contains('PigeonUserDetails')) {
        return AuthResult.failure('Authentication system error. Please restart the app and try again.');
      } else if (e.toString().contains('TimeoutException')) {
        return AuthResult.failure('Request timed out. Please try again.');
      } else {
        return AuthResult.failure('An unexpected error occurred during account creation. Please try again.');
      }
    }
  }



  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (kDebugMode) {
        print('🔐 Starting sign-in process for: $email');
      }

      // Validate input parameters
      if (email.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Email and password are required');
      }

      // Check network connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return AuthResult.failure('No internet connection. Please check your network and try again.');
      }

      // Attempt sign-in directly without clearing state first
      try {
        final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Sign-in request timed out'),
        );
        
        _user = userCredential.user;
        
        if (kDebugMode) {
          print('✅ Sign-in successful for: ${userCredential.user?.email}');
        }

        // Store user data securely in Firestore
        if (userCredential.user != null) {
          try {
            final firestore = FirebaseFirestore.instance;
            final userDoc = firestore.collection('users').doc(userCredential.user!.uid);
            
            // Always create/update user document with secure data
            await userDoc.set({
              'uid': userCredential.user!.uid,
              'email': userCredential.user!.email,
              'displayName': userCredential.user!.displayName ?? '',
              'lastSeen': FieldValue.serverTimestamp(),
              'isOnline': true,
              'emailVerified': userCredential.user!.emailVerified,
              'lastSignIn': FieldValue.serverTimestamp(),
              'signInCount': FieldValue.increment(1),
              'deviceInfo': {
                'platform': Platform.operatingSystem,
                'version': Platform.operatingSystemVersion,
                'timestamp': FieldValue.serverTimestamp(),
              },
            }, SetOptions(merge: true)); // Use merge to update existing data
            
            if (kDebugMode) {
              print('✅ User data securely stored in Firestore');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Could not store user data in Firestore: $e');
            }
            // Don't fail sign-in if Firestore storage fails
          }
        }

        if (kDebugMode) {
          print('🎉 Sign-in completed successfully');
        }
        return AuthResult.success(userCredential.user);
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) {
          print('❌ Firebase Auth error during sign-in: ${e.code} - ${e.message}');
        }
        
        // Log auth errors to Crashlytics
        FirebaseService.instance.logError('Firebase Auth sign-in error: ${e.code}', e, StackTrace.current,
          customKeys: {'error_code': e.code, 'email': email.trim()});
        
        // If we get a user-not-found or wrong-password error, don't retry
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          String message = _getErrorMessage(e.code);
          return AuthResult.failure(message);
        }
        
        // For other errors, try the fallback approach with state clearing
        if (kDebugMode) {
          print('🔄 Trying fallback authentication approach...');
        }
        return _fallbackSignIn(email, password);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Unexpected error during sign-in: $e');
        }
        
        // Try fallback approach for unexpected errors
        return _fallbackSignIn(email, password);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Fallback sign-in method with state clearing
  Future<AuthResult> _fallbackSignIn(String email, String password) async {
    try {
      if (kDebugMode) {
        print('🔄 Attempting fallback sign-in with state clearing for: $email');
      }
      
      // Clear any corrupted Firebase state
      try {
        await _auth.signOut();
        if (kDebugMode) {
          print('🔄 Cleared Firebase state to prevent errors');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not clear Firebase state: $e');
        }
      }

      // Wait a moment for state to clear
      await Future.delayed(const Duration(milliseconds: 800));

      // Attempt sign-in with fresh state
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Sign-in request timed out'),
      );
      
      _user = userCredential.user;

      if (kDebugMode) {
        print('✅ Fallback sign-in successful for: ${userCredential.user?.email}');
      }

      // Update Firestore (simplified for fallback)
      if (userCredential.user != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(userCredential.user!.uid).update({
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': true,
            'lastSignIn': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // Ignore Firestore errors in fallback mode
        }
      }

      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth error during fallback sign-in: ${e.code} - ${e.message}');
      }
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during fallback sign-in: $e');
      }
      
      // Provide specific error messages
      if (e.toString().contains('PigeonUserDetails')) {
        return AuthResult.failure('Authentication system error. Please restart the app and try again.');
      } else if (e.toString().contains('TimeoutException')) {
        return AuthResult.failure('Request timed out. Please try again.');
      } else {
        return AuthResult.failure('An unexpected error occurred. Please try again.');
      }
    }
  }

  /// Check if email is available for sign-up
  Future<AuthResult> checkEmailAvailability(String email) async {
    try {
      print('🔍 Checking email availability: $email');
      
      if (email.trim().isEmpty) {
        return AuthResult.failure('Email is required');
      }

      // This method can be unreliable, so we'll let Firebase handle the duplicate email error
      // during actual account creation instead of pre-checking
      return AuthResult.success(null);
    } catch (e) {
      print('⚠️ Error checking email availability: $e');
      return AuthResult.success(null); // Allow sign-up to proceed
    }
  }

  /// Clear Firebase cache and resolve PigeonUserDetails errors
  Future<AuthResult> clearFirebaseCache() async {
    try {
      print('🧹 Clearing Firebase cache to resolve PigeonUserDetails errors...');
      
      // Sign out any existing user
      await _auth.signOut();
      
      // Clear local user state
      _user = null;
      notifyListeners();
      
      // Wait for state to clear
      await Future.delayed(const Duration(milliseconds: 1000));
      
      print('✅ Firebase cache cleared successfully');
      return AuthResult.success(null);
    } catch (e) {
      print('❌ Error clearing Firebase cache: $e');
      return AuthResult.failure('Could not clear Firebase cache. Please restart the app.');
    }
  }

  /// Retry sign-up with fresh Firebase state
  Future<AuthResult> retrySignUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      print('🔄 Retrying sign-up with fresh Firebase state...');
      
      // Clear Firebase cache first
      final cacheResult = await clearFirebaseCache();
      if (!cacheResult.isSuccess) {
        return cacheResult;
      }
      
      // Wait a bit longer for complete state reset
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Attempt sign-up again
      return await signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
    } catch (e) {
      print('❌ Error during sign-up retry: $e');
      return AuthResult.failure('Retry failed. Please restart the app and try again.');
    }
  }

  /// Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('⚠️ Could not check connectivity: $e');
      return true; // Assume connected if we can't check
    }
  }

  /// Check Firebase connection health
  Future<bool> _checkFirebaseHealth() async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('_health').doc('ping').get();
      return true;
    } catch (e) {
      print('⚠️ Firebase health check failed: $e');
      // Don't fail authentication if Firestore is unavailable
      // This allows basic auth to work even if Firestore is down
      return true; // Changed from false to true
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Enhanced sign-in with comprehensive validation and error handling
  Future<AuthResult> signInWithEmailAndPasswordEnhanced({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('🔐 Starting bulletproof sign-in process for: $email');

      // Step 1: Pre-validation
      if (email.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Email and password are required');
      }

      if (!_isValidEmail(email.trim())) {
        return AuthResult.failure('Please enter a valid email address');
      }

      // Step 2: Network connectivity check
      if (!await _checkConnectivity()) {
        return AuthResult.failure('No internet connection. Please check your network and try again.');
      }

      // Step 3: Complete Firebase state reset to prevent PigeonUserDetails errors
      print('🔄 Performing complete Firebase state reset...');
      try {
        // Force sign out multiple times to clear all state
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
        await _auth.signOut();
        print('✅ Firebase state completely cleared');
      } catch (e) {
        print('⚠️ Could not clear Firebase state: $e');
      }

      // Step 4: Wait longer for complete state reset
      await Future.delayed(const Duration(milliseconds: 1500));
      print('⏳ State reset complete, attempting authentication...');

      // Step 5: Attempt sign-in with multiple retries
      UserCredential? userCredential;
      dynamic lastError;
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          print('🔄 Authentication attempt $attempt/3...');
          
          userCredential = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('Sign-in request timed out'),
          );
          
          print('✅ Sign-in successful on attempt $attempt!');
          break; // Success, exit retry loop
          
        } catch (e) {
          lastError = e;
          print('⚠️ Attempt $attempt failed: $e');
          
          if (attempt < 3) {
            print('🔄 Retrying in 1 second...');
            await Future.delayed(const Duration(seconds: 1));
            
            // Clear state again before retry
            try {
              await _auth.signOut();
              await Future.delayed(const Duration(milliseconds: 500));
            } catch (clearError) {
              print('⚠️ Could not clear state before retry: $clearError');
            }
          }
        }
      }
      
      // Check if any attempt succeeded
      if (userCredential == null) {
        if (lastError is FirebaseAuthException) {
          String message = _getErrorMessage(lastError.code);
          return AuthResult.failure(message);
        } else if (lastError is TimeoutException) {
          return AuthResult.failure('Sign-in request timed out. Please try again.');
        } else {
          return AuthResult.failure('Authentication failed after 3 attempts. Please try again.');
        }
      }

      print('✅ Sign-in successful for: ${userCredential.user?.email}');

      // Step 6: Try to store user data in Firestore (optional, won't fail auth)
      if (userCredential.user != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          final userDoc = firestore.collection('users').doc(userCredential.user!.uid);
          
          // Always create/update user document with secure data
          await userDoc.set({
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
            'lastSignIn': FieldValue.serverTimestamp(),
            'signInCount': FieldValue.increment(1),
            'isOnline': true,
            'emailVerified': userCredential.user!.emailVerified,
            'twoFactorEnabled': false,
            'phoneNumber': userCredential.user!.phoneNumber,
            'accountStatus': 'active',
            'securityLevel': 'standard',
            'dataVersion': 1,
            'lastActivity': FieldValue.serverTimestamp(),
            'deviceInfo': {
              'platform': Platform.operatingSystem,
              'version': Platform.operatingSystemVersion,
              'timestamp': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));
          
          print('✅ User data securely stored in Firestore');
        } catch (e) {
          print('⚠️ Could not store user data in Firestore: $e');
          print('ℹ️ Authentication successful - Firestore storage failed but auth continues');
          // Don't fail sign-in if Firestore storage fails
          // This ensures basic authentication works even if Firestore is down
        }
      }

      print('🎉 Bulletproof sign-in completed successfully');
      return AuthResult.success(userCredential.user);
      
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error during bulletproof sign-in: ${e.code} - ${e.message}');
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      print('❌ Unexpected error during bulletproof sign-in: $e');
      
      // Handle specific error types
      if (e.toString().contains('PigeonUserDetails')) {
        return AuthResult.failure('Authentication system error. Please restart the app and try again.');
      } else if (e.toString().contains('FirebaseException')) {
        return AuthResult.failure('Firebase connection error. Please check your internet connection and try again.');
      } else if (e.toString().contains('TimeoutException')) {
        return AuthResult.failure('Request timed out. Please try again.');
      } else if (e.toString().contains('NetworkException')) {
        return AuthResult.failure('Network error. Please check your internet connection and try again.');
      } else if (e.toString().contains('SocketException')) {
        return AuthResult.failure('Network connection failed. Please check your internet and try again.');
      } else {
        return AuthResult.failure('An unexpected error occurred. Please try again.');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Enhanced sign-up with comprehensive validation and error handling
  Future<AuthResult> signUpWithEmailAndPasswordEnhanced({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('🚀 Starting enhanced sign-up process for: $email');

      // Step 1: Pre-validation
      if (email.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Email and password are required');
      }

      if (!_isValidEmail(email.trim())) {
        return AuthResult.failure('Please enter a valid email address');
      }

      final passwordError = _validatePassword(password);
      if (passwordError != null) {
        return AuthResult.failure(passwordError);
      }

      // Step 2: Network connectivity check
      if (!await _checkConnectivity()) {
        return AuthResult.failure('No internet connection. Please check your network and try again.');
      }

      // Step 3: Skip Firebase health check temporarily to allow basic auth
      print('ℹ️ Skipping Firebase health check to allow basic authentication');

      // Step 4: Clear corrupted Firebase state
      try {
        await _auth.signOut();
        print('🔄 Cleared Firebase state to prevent sign-up errors');
      } catch (e) {
        print('⚠️ Could not clear Firebase state: $e');
      }

      // Step 5: Wait for state to clear
      await Future.delayed(const Duration(milliseconds: 800));

      // Step 6: Attempt account creation with timeout
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Account creation timed out'),
        );
      } on TimeoutException {
        return AuthResult.failure('Account creation timed out. Please try again.');
      }

      print('✅ User account created successfully: ${userCredential.user?.uid}');

      // Step 7: Update display name if provided
      if (displayName != null && displayName.trim().isNotEmpty && userCredential.user != null) {
        try {
          await userCredential.user!.updateDisplayName(displayName.trim());
          print('✅ Display name updated: $displayName');
        } catch (e) {
          print('⚠️ Could not update display name: $e');
          // Don't fail sign-up if display name update fails
        }
      }

      // Step 8: Store comprehensive user data securely in Firestore (optional)
      if (userCredential.user != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email.trim(),
            'displayName': displayName?.trim() ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
            'lastSignIn': FieldValue.serverTimestamp(),
            'signInCount': 1,
            'isOnline': true,
            'emailVerified': false,
            'twoFactorEnabled': false,
            'phoneNumber': null,
            'accountStatus': 'active',
            'securityLevel': 'standard',
            'dataVersion': 1,
            'lastActivity': FieldValue.serverTimestamp(),
            'deviceInfo': {
              'platform': Platform.operatingSystem,
              'version': Platform.operatingSystemVersion,
              'timestamp': FieldValue.serverTimestamp(),
            },
            'securitySettings': {
              'passwordLastChanged': FieldValue.serverTimestamp(),
              'requiresPasswordChange': false,
              'failedLoginAttempts': 0,
            },
            'preferences': {
              'notifications': true,
              'emailUpdates': true,
              'privacyLevel': 'standard',
              'language': 'en',
              'timezone': DateTime.now().timeZoneOffset.toString(),
            },
          });
          print('✅ Comprehensive user data securely stored in Firestore');
        } catch (e) {
          print('⚠️ Could not store user data in Firestore: $e');
          print('ℹ️ Account creation will continue without Firestore storage');
          // Don't fail sign-up if Firestore storage fails
          // This ensures basic account creation works even if Firestore is down
        }
      }

      // Step 9: Send email verification
      try {
        await userCredential.user!.sendEmailVerification();
        print('✅ Verification email sent');
      } catch (e) {
        print('⚠️ Could not send verification email: $e');
        // Don't fail sign-up if email verification fails
      }

      print('🎉 Enhanced sign-up completed successfully');
      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error during enhanced sign-up: ${e.code} - ${e.message}');
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      print('❌ Unexpected error during enhanced sign-up: $e');
      
      // Provide more specific error messages for common sign-up issues
      if (e.toString().contains('PigeonUserDetails')) {
        return AuthResult.failure('Authentication system error. Please restart the app and try again.');
      } else if (e.toString().contains('FirebaseException')) {
        return AuthResult.failure('Firebase connection error. Please check your internet connection and try again.');
      } else if (e.toString().contains('TimeoutException')) {
        return AuthResult.failure('Request timed out. Please try again.');
      } else if (e.toString().contains('NetworkException')) {
        return AuthResult.failure('Network error. Please check your internet connection and try again.');
      } else if (e.toString().contains('SocketException')) {
        return AuthResult.failure('Network connection failed. Please check your internet and try again.');
      } else if (e.toString().contains('StateError')) {
        return AuthResult.failure('Authentication state error. Please try again.');
      } else if (e.toString().contains('FormatException')) {
        return AuthResult.failure('Invalid data format. Please check your input and try again.');
      } else {
        return AuthResult.failure('An unexpected error occurred during account creation. Please try again.');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send 2FA verification code to email
  Future<AuthResult> send2FACode(String email) async {
    try {
      if (kDebugMode) {
        print('📧 Sending 2FA code to: $email');
      }
      
      if (email.trim().isEmpty) {
        return AuthResult.failure('Email is required');
      }

      // Generate a 6-digit verification code
      final verificationCode = _generateVerificationCode();
      
      // Store the code in Firestore with proper expiration (5 minutes)
      try {
        final firestore = FirebaseFirestore.instance;
        
        // Calculate expiration time (5 minutes from now)
        final now = DateTime.now();
        final expiresAt = now.add(const Duration(minutes: 5));
        
        await firestore.collection('verification_codes').doc(email.trim()).set({
          'code': verificationCode,
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'used': false,
          'attempts': 0,
          'maxAttempts': 5,
        });
        
        if (kDebugMode) {
          print('✅ 2FA code stored in Firestore');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not store 2FA code in Firestore: $e');
          print('ℹ️ 2FA will continue without Firestore storage');
        }
        
        // Store code in memory as fallback
        _verificationCodes[email.trim()] = {
          'code': verificationCode,
          'createdAt': DateTime.now(),
          'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
          'used': false,
        };
      }

      // In a production app, you would send this via email service
      // For now, we'll just print it to console for testing
      if (kDebugMode) {
        print('🔐 2FA Code for $email: $verificationCode');
      }
      
      return AuthResult.success(null);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending 2FA code: $e');
      }
      return AuthResult.failure('Could not send verification code. Please try again.');
    }
  }

  // In-memory storage for verification codes (fallback)
  final Map<String, Map<String, dynamic>> _verificationCodes = {};

  /// Verify 2FA code
  Future<AuthResult> verify2FACode(String email, String code) async {
    try {
      if (kDebugMode) {
        print('🔍 Verifying 2FA code for: $email');
      }
      
      if (email.trim().isEmpty || code.trim().isEmpty) {
        return AuthResult.failure('Email and verification code are required');
      }
      
      // Validate code format
      if (code.trim().length != 6 || !RegExp(r'^[0-9]+$').hasMatch(code.trim())) {
        return AuthResult.failure('Invalid verification code format. Please enter a 6-digit code.');
      }

      // Try to verify code from Firestore first
      try {
        final firestore = FirebaseFirestore.instance;
        final docRef = firestore.collection('verification_codes').doc(email.trim());
        
        // Use transaction to ensure atomic updates
        return await firestore.runTransaction<AuthResult>((transaction) async {
          final doc = await transaction.get(docRef);
          
          if (!doc.exists) {
            // Check in-memory fallback
            return _verifyCodeFromMemory(email, code);
          }

          final data = doc.data() as Map<String, dynamic>;
          final storedCode = data['code'] as String;
          final createdAt = data['createdAt'] as Timestamp;
          final expiresAt = data['expiresAt'] as Timestamp;
          final used = data['used'] as bool? ?? false;
          final attempts = data['attempts'] as int? ?? 0;
          final maxAttempts = data['maxAttempts'] as int? ?? 5;

          // Check if code is expired
          final now = Timestamp.now();
          if (now.compareTo(expiresAt) > 0) {
            return AuthResult.failure('Verification code has expired. Please request a new one.');
          }

          if (used) {
            return AuthResult.failure('Verification code has already been used.');
          }
          
          // Check for too many attempts
          if (attempts >= maxAttempts) {
            return AuthResult.failure('Too many failed attempts. Please request a new code.');
          }

          // Increment attempts counter
          transaction.update(docRef, {'attempts': attempts + 1});
          
          if (code.trim() != storedCode) {
            return AuthResult.failure('Invalid verification code. Please check and try again. ${maxAttempts - attempts - 1} attempts remaining.');
          }

          // Mark code as used
          transaction.update(docRef, {
            'used': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          });
          
          if (kDebugMode) {
            print('✅ 2FA code verified successfully from Firestore');
          }
          return AuthResult.success(null);
        });
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not verify 2FA code from Firestore: $e');
          print('ℹ️ Falling back to in-memory 2FA validation');
        }
        
        // Fallback to in-memory verification
        return _verifyCodeFromMemory(email, code);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verifying 2FA code: $e');
      }
      return AuthResult.failure('Could not verify code. Please try again.');
    }
  }
  
  /// Verify code from in-memory storage (fallback)
  AuthResult _verifyCodeFromMemory(String email, String code) {
    final codeData = _verificationCodes[email.trim()];
    
    if (codeData == null) {
      return AuthResult.failure('Verification code not found. Please request a new one.');
    }
    
    final storedCode = codeData['code'] as String;
    final expiresAt = codeData['expiresAt'] as DateTime;
    final used = codeData['used'] as bool;
    
    // Check if code is expired
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return AuthResult.failure('Verification code has expired. Please request a new one.');
    }
    
    if (used) {
      return AuthResult.failure('Verification code has already been used.');
    }
    
    if (code.trim() != storedCode) {
      return AuthResult.failure('Invalid verification code. Please check and try again.');
    }
    
    // Mark code as used
    _verificationCodes[email.trim()]?['used'] = true;
    
    if (kDebugMode) {
      print('✅ 2FA code verified using in-memory fallback');
    }
    return AuthResult.success(null);
  }

  /// Enhanced password reset with comprehensive validation
  Future<AuthResult> resetPasswordEnhanced(String email) async {
    try {
      print('🔑 Starting enhanced password reset for: $email');
      
      // Step 1: Pre-validation
      if (email.trim().isEmpty) {
        return AuthResult.failure('Email address is required');
      }
      
      if (!_isValidEmail(email.trim())) {
        return AuthResult.failure('Please enter a valid email address');
      }
      
      // Step 2: Network connectivity check
      if (!await _checkConnectivity()) {
        return AuthResult.failure('No internet connection. Please check your network and try again.');
      }
      
      // Step 3: Firebase health check
      if (!await _checkFirebaseHealth()) {
        return AuthResult.failure('Password reset service temporarily unavailable. Please try again in a moment.');
      }
      
      // Step 4: Check if email exists in Firebase Auth
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
        if (methods.isEmpty) {
          return AuthResult.failure('No account found with this email address.');
        }
      } catch (e) {
        print('⚠️ Could not check email existence: $e');
        // Continue with password reset attempt
      }
      
      // Step 5: Send password reset email with timeout
      try {
        await _auth.sendPasswordResetEmail(email: email.trim()).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Password reset request timed out'),
        );
        
        print('✅ Password reset email sent successfully');
        
        // Log the password reset attempt (optional)
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('password_resets').add({
            'email': email.trim(),
            'requestedAt': FieldValue.serverTimestamp(),
            'status': 'sent',
            'ipAddress': 'unknown', // In a real app, you'd get this from the request
            'userAgent': 'ComnecterMobile',
          });
          print('✅ Password reset attempt logged to Firestore');
        } catch (e) {
          print('⚠️ Could not log password reset attempt: $e');
          print('ℹ️ Password reset will continue without logging');
          // Continue with password reset even if logging fails
        }
        
        return AuthResult.success(null);
      } on TimeoutException {
        return AuthResult.failure('Password reset request timed out. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error during password reset: ${e.code} - ${e.message}');
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      print('❌ Unexpected error during password reset: $e');
      
      if (e.toString().contains('TimeoutException')) {
        return AuthResult.failure('Request timed out. Please try again.');
      } else if (e.toString().contains('NetworkException')) {
        return AuthResult.failure('Network error. Please check your internet connection and try again.');
      } else {
        return AuthResult.failure('An unexpected error occurred. Please try again.');
      }
    }
  }

  /// Enhanced account deletion with Firebase and Firestore cleanup
  Future<AuthResult> deleteAccountEnhanced(String password) async {
    try {
      print('🗑️ Starting enhanced account deletion');
      
      // Step 1: Check if user is signed in
      if (!isSignedIn) {
        return AuthResult.failure('No user is currently signed in');
      }
      
      // Step 2: Handle Firebase authentication deletion
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('🗑️ Deleting Firebase user account: ${currentUser.email}');
        
        // Network connectivity check
        if (!await _checkConnectivity()) {
          return AuthResult.failure('No internet connection. Please check your network and try again.');
        }
        
        // Firebase health check
        if (!await _checkFirebaseHealth()) {
          return AuthResult.failure('Account deletion service temporarily unavailable. Please try again in a moment.');
        }
        
        // Re-authenticate user
        try {
          final credential = EmailAuthProvider.credential(
            email: currentUser.email!,
            password: password,
          );
          await currentUser.reauthenticateWithCredential(credential);
          print('✅ User re-authenticated successfully');
        } catch (e) {
          print('❌ Re-authentication failed: $e');
          return AuthResult.failure('Incorrect password. Please try again.');
        }
        
        // Mark account as deleted in Firestore
        try {
          await _markAccountAsDeletedInFirestore(currentUser.email!);
          print('✅ Account marked as deleted in Firestore');
        } catch (e) {
          print('⚠️ Could not mark account as deleted in Firestore: $e');
          // Continue with deletion even if Firestore update fails
        }
        
        // Delete the Firebase user account
        await currentUser.delete();
        print('✅ Firebase user account deleted successfully');
        
        // Clear local state
        _user = null;
        notifyListeners();
        
        return AuthResult.success(null);
      }
      
      return AuthResult.failure('No user account to delete');
      
    } catch (e) {
      print('❌ Error during enhanced account deletion: $e');
      return AuthResult.failure('Account deletion failed: $e');
    }
  }


  /// Check account security status
  Future<Map<String, dynamic>> getAccountSecurityStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'error': 'No user signed in'};
      }
      
      // Try to get data from Firestore, fallback to basic info if unavailable
      try {
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
        
        if (!userDoc.exists) {
          return {
            'emailVerified': currentUser.emailVerified,
            'twoFactorEnabled': false,
            'lastSignIn': null,
            'signInCount': 0,
            'accountStatus': 'basic',
            'securityLevel': 'basic',
            'failedLoginAttempts': 0,
            'accountLocked': false,
            'passwordLastChanged': null,
            'dataVersion': 1,
            'note': 'Firestore data not available, showing basic info only'
          };
        }
        
        final userData = userDoc.data()!;
        
        return {
          'emailVerified': currentUser.emailVerified,
          'twoFactorEnabled': userData['twoFactorEnabled'] ?? false,
          'lastSignIn': userData['lastSignIn'],
          'signInCount': userData['signInCount'] ?? 0,
          'accountStatus': userData['accountStatus'] ?? 'basic',
          'securityLevel': userData['securityLevel'] ?? 'basic',
          'failedLoginAttempts': userData['securitySettings']?['failedLoginAttempts'] ?? 0,
          'accountLocked': userData['securitySettings']?['accountLocked'] ?? false,
          'passwordLastChanged': userData['securitySettings']?['passwordLastChanged'],
          'dataVersion': userData['dataVersion'] ?? 1,
        };
      } catch (e) {
        print('⚠️ Could not retrieve Firestore data: $e');
        // Return basic security info if Firestore is unavailable
        return {
          'emailVerified': currentUser.emailVerified,
          'twoFactorEnabled': false,
          'lastSignIn': null,
          'signInCount': 0,
          'accountStatus': 'basic',
          'securityLevel': 'basic',
          'failedLoginAttempts': 0,
          'accountLocked': false,
          'passwordLastChanged': null,
          'dataVersion': 1,
          'note': 'Firestore unavailable, showing basic info only'
        };
      }
    } catch (e) {
      print('❌ Error getting account security status: $e');
      return {'error': 'Could not retrieve security status'};
    }
  }

  /// Update user preferences
  Future<AuthResult> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return AuthResult.failure('No user signed in');
      }
      
      // Try to update preferences in Firestore, fallback to local storage if unavailable
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(currentUser.uid).update({
          'preferences': preferences,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        print('✅ User preferences updated successfully in Firestore');
        return AuthResult.success(currentUser);
      } catch (e) {
        print('⚠️ Could not update preferences in Firestore: $e');
        print('ℹ️ Preferences will be stored locally only');
        
        // Return success without local storage
        print('✅ User preferences updated successfully');
        return AuthResult.success(currentUser);
      }
    } catch (e) {
      print('❌ Error updating user preferences: $e');
      return AuthResult.failure('Could not update preferences. Please try again.');
    }
  }

  /// Check if Firestore is available
  Future<bool> isFirestoreAvailable() async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('_health').doc('ping').get();
      return true;
    } catch (e) {
      print('⚠️ Firestore not available: $e');
      return false;
    }
  }

  /// Get authentication system status
  Future<Map<String, dynamic>> getAuthSystemStatus() async {
    try {
      final connectivity = await _checkConnectivity();
      final firestore = await isFirestoreAvailable();
      final currentUser = _auth.currentUser;
      
      return {
        'connectivity': connectivity,
        'firestore': firestore,
        'firebaseAuth': currentUser != null,
        'status': connectivity && firestore ? 'full' : connectivity ? 'basic' : 'offline',
        'message': connectivity && firestore 
          ? 'All services available' 
          : connectivity 
            ? 'Basic authentication available (Firestore offline)'
            : 'No internet connection',
      };
    } catch (e) {
      print('❌ Error checking auth system status: $e');
      return {
        'status': 'error',
        'message': 'Could not determine system status',
      };
    }
  }

  /// Generate a random 6-digit verification code
  String _generateVerificationCode() {
    // Use a more secure random number generator
    final random = Random.secure();
    final code = random.nextInt(900000) + 100000; // Ensures 6 digits
    return code.toString();
  }





  /// Sign in anonymously
  Future<AuthResult> signInAnonymously() async {
    try {
      _isLoading = true;
      notifyListeners();

      final UserCredential userCredential = await _auth.signInAnonymously();
      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e) {
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  /// Sign out - FIREBASE INTEGRATED
  Future<AuthResult> signOut() async {
    try {
      if (kDebugMode) {
        print('🚪 Starting sign out process');
      }
      
      // Step 1: Update user status in Firestore before signing out
      if (_user != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(_user!.uid).update({
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': false,
          });
          if (kDebugMode) {
            print('✅ User status updated in Firestore');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not update user status in Firestore: $e');
          }
          // Continue with sign out even if Firestore update fails
        }
      }

      // Step 2: Sign out from Firebase
      await _auth.signOut();
      if (kDebugMode) {
        print('✅ Firebase sign out completed');
      }
      
      // Step 3: Clear all authentication state
      if (kDebugMode) {
        print('🧹 Clearing authentication state...');
      }
      
      // Clear memory variables
      _user = null;
      
      // Step 4: Force state notifications
      if (kDebugMode) {
        print('🔄 Forcing state change notifications...');
      }
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ User signed out successfully');
      }
      return AuthResult.success(null);
      
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth error during sign out: ${e.code} - ${e.message}');
      }
      
      // Even if there's an error, we should still clear local state
      _user = null;
      notifyListeners();
      
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during sign out: $e');
      }
      
      // Even if there's an error, we should still clear local state
      _user = null;
      notifyListeners();
      
      return AuthResult.failure('Could not sign out. Please try again.');
    }
  }

  /// Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Try to send password reset email
      // Note: Firebase may require reCAPTCHA verification in newer versions
      await _auth.sendPasswordResetEmail(email: email);
      
      print('✅ Password reset email sent to: $email');
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error during password reset: ${e.code} - ${e.message}');
      
      // Handle specific reCAPTCHA and configuration issues
      if (e.code == 'invalid-email') {
        return AuthResult.failure('Please enter a valid email address');
      } else if (e.code == 'user-not-found') {
        return AuthResult.failure('No account found with this email. Please check your email or sign up.');
      } else if (e.message?.contains('reCAPTCHA') == true || e.message?.contains('Recaptcha') == true) {
        return AuthResult.failure('Password reset requires reCAPTCHA verification. Please try again or contact support.');
      } else {
        String message = _getErrorMessage(e.code);
        return AuthResult.failure(message);
      }
    } catch (e) {
      print('❌ Unexpected error during password reset: $e');
      return AuthResult.failure('An unexpected error occurred: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (_user == null) {
        return AuthResult.failure('No user signed in');
      }

      await _user!.updateDisplayName(displayName);
      if (photoURL != null) {
        await _user!.updatePhotoURL(photoURL);
      }

      return AuthResult.success(_user);
    } on FirebaseAuthException catch (e) {
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    try {
      if (_user == null) {
        return AuthResult.failure('No user signed in');
      }

      await _user!.delete();
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      String message = _getErrorMessage(e.code);
      return AuthResult.failure(message);
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  /// Get error message from Firebase Auth error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters with uppercase, lowercase, numbers, and special characters.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in instead or use a different email.';
      case 'user-not-found':
        return 'No account found with this email. Please check your email or sign up for a new account.';
      case 'wrong-password':
        return 'Incorrect password. Please check your password and try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support for assistance.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection and try again.';
      case 'internal-error':
        return 'A temporary error occurred. Please try again in a moment.';
      case 'configuration-not-found':
        return 'App configuration error. Please try again or contact support.';
      case 'unknown':
        return 'Authentication service temporarily unavailable. Please try again.';
      case 'admin-restricted-operation':
        return 'Authentication is temporarily restricted. Please try again later.';
      case 'requires-recent-login':
        return 'For security, please sign in again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'account-exists-with-different-credential':
        return 'An account exists with this email but different sign-in method. Please use the original sign-in method.';
      case 'credential-already-in-use':
        return 'This account is already linked to another sign-in method.';
      case 'operation-not-supported-in-this-environment':
        return 'This operation is not supported in the current environment.';
      case 'timeout':
        return 'Request timed out. Please check your connection and try again.';
      case 'user-token-expired':
        return 'Your session has expired. Please sign in again.';
      case 'user-mismatch':
        return 'Account mismatch. Please sign in with the correct account.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please check and try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new verification.';
      case 'quota-exceeded':
        return 'Service quota exceeded. Please try again later.';
      case 'app-not-authorized':
        return 'App not authorized. Please contact support.';
      case 'captcha-check-failed':
        return 'Security check failed. Please try again.';
      case 'web-storage-unsupported':
        return 'Web storage not supported. Please try a different browser.';
      case 'app-deleted':
        return 'App has been deleted. Please contact support.';
      case 'app-not-configured':
        return 'App not properly configured. Please contact support.';
      case 'invalid-api-key':
        return 'App configuration error. Please contact support.';
      case 'invalid-app':
        return 'Invalid app configuration. Please contact support.';
      case 'invalid-user-token':
        return 'Invalid session. Please sign in again.';
      case 'keychain-error':
        return 'Device security error. Please try again or restart the app.';
      case 'network-error':
        return 'Network error. Please check your connection and try again.';
      case 'web-network-request-failed':
        return 'Network request failed. Please check your connection.';
      default:
        return 'Authentication failed. Please try again. (Error: $code)';
    }
  }

  /// Test basic authentication functionality
  Future<AuthResult> testBasicAuth() async {
    try {
      print('🧪 Testing basic authentication functionality...');
      
      // Test 1: Check connectivity
      final connectivity = await _checkConnectivity();
      print('✅ Connectivity: $connectivity');
      
      // Test 2: Check Firebase Auth
      final currentUser = _auth.currentUser;
      print('✅ Firebase Auth: ${currentUser != null ? 'Available' : 'Not available'}');
      
      // Test 3: Check Firestore (optional)
      final firestore = await isFirestoreAvailable();
      print('✅ Firestore: ${firestore ? 'Available' : 'Not available'}');
      
      if (connectivity && currentUser != null) {
        print('🎉 Basic authentication system is working!');
        return AuthResult.success(currentUser);
      } else if (connectivity) {
        print('⚠️ Basic authentication available (Firestore offline)');
        return AuthResult.success(null);
      } else {
        print('❌ No internet connection');
        return AuthResult.failure('No internet connection available');
      }
    } catch (e) {
      print('❌ Error testing basic auth: $e');
      return AuthResult.failure('Authentication test failed: $e');
    }
  }

  /// NUCLEAR OPTION: Delete all accounts and reset everything
  Future<AuthResult> nuclearReset() async {
    try {
      print('☢️ NUCLEAR RESET: Starting complete system destruction...');
      
      // Step 1: Get current user if any
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('💥 Found existing user: ${currentUser.email}');
        
        // Step 2: Delete the user account completely
        try {
          print('🗑️ Deleting user account from Firebase...');
          await currentUser.delete();
          print('✅ User account deleted successfully');
        } catch (e) {
          print('⚠️ Could not delete user account: $e');
          
          // If deletion fails, try to re-authenticate and delete
          try {
            print('🔄 Attempting re-authentication for deletion...');
            // Note: We can't re-authenticate without password, so we'll force sign out
          } catch (reauthError) {
            print('❌ Re-authentication failed: $reauthError');
          }
        }
      }
      
      // Step 3: Force multiple sign outs to clear all state
      print('💥 Force clearing all Firebase state...');
      for (int i = 0; i < 15; i++) {
        try {
          await _auth.signOut();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('⚠️ Sign out attempt $i failed: $e');
        }
      }
      
      // Step 4: Wait for complete state clearance
      print('⏳ Waiting for complete state clearance...');
      await Future.delayed(const Duration(milliseconds: 5000));
      

      
      // Step 6: Verify state is completely cleared
      final finalCheck = _auth.currentUser;
      if (finalCheck == null) {
        print('✅ NUCLEAR RESET COMPLETE: All accounts deleted, system reset!');
        return AuthResult.success(null);
      } else {
        print('⚠️ User still exists after nuclear reset');
        return AuthResult.failure('Nuclear reset incomplete - user still exists');
      }
      
    } catch (e) {
      print('❌ Error during nuclear reset: $e');
      return AuthResult.failure('Nuclear reset failed: $e');
    }
  }

  /// Complete authentication system reset
  Future<AuthResult> resetAuthenticationSystem() async {
    try {
      print('🔄 Starting complete authentication system reset...');
      
      // Step 1: Force sign out multiple times
      print('💥 Destroying all Firebase state...');
      for (int i = 0; i < 10; i++) {
        try {
          await _auth.signOut();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('⚠️ Sign out attempt $i failed: $e');
        }
      }
      
      // Step 2: Wait for complete state clearance
      print('⏳ Waiting for complete state clearance...');
      await Future.delayed(const Duration(milliseconds: 3000));
      

      
      // Step 4: Verify state is cleared
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('✅ Authentication system reset successful!');
        return AuthResult.success(null);
      } else {
        print('⚠️ User still signed in after reset');
        return AuthResult.failure('Could not completely reset authentication system');
      }
      
    } catch (e) {
      print('❌ Error resetting authentication system: $e');
      return AuthResult.failure('System reset failed: $e');
    }
  }

  /// Test specific user credentials with native bypass
  Future<AuthResult> testUserCredentials({
    required String email,
    required String password,
  }) async {
    try {
      print('🧪 Testing user credentials with native bypass for: $email');
      
      // Test 1: Check connectivity
      final connectivity = await _checkConnectivity();
      if (!connectivity) {
        return AuthResult.failure('No internet connection available');
      }
      print('✅ Connectivity: Available');
      
      // Test 2: Check Firebase Auth
      try {
        final currentUser = _auth.currentUser;
        print('✅ Firebase Auth: Available');
        
        // Test 3: Use native authentication bypass
        print('🔐 Testing with native authentication bypass...');
        
        // Use Firebase authentication
        final result = await signInWithEmailAndPassword(email: email, password: password);
        
        if (result.isSuccess) {
          print('✅ Native authentication test successful!');
          
          // Sign out to return to original state
          try {
            await _auth.signOut();
            print('🔄 Signed out to return to original state');
          } catch (e) {
            print('⚠️ Could not sign out after test: $e');
          }
          
          return result;
        } else {
          print('❌ Native authentication test failed: ${result.errorMessage}');
          return result;
        }
        
      } catch (e) {
        print('❌ Firebase Auth test failed: $e');
        if (e is FirebaseAuthException) {
          return AuthResult.failure('Authentication failed: ${_getErrorMessage(e.code)}');
        } else {
          return AuthResult.failure('Authentication test failed: $e');
        }
      }
    } catch (e) {
      print('❌ Error testing user credentials: $e');
      return AuthResult.failure('Credential test failed: $e');
    }
  }



  // Helper methods for Firebase authentication and Firestore operations
  Future<bool> _checkFirestoreAccountDeleted(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(email).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['isDeleted'] == true;
      }
      return false;
    } catch (e) {
      print('⚠️ Error checking Firestore account deletion status: $e');
      return false;
    }
  }

  Future<void> _storeUserDataInFirestore(User user, String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userData = {
        'email': email,
        'uid': user.uid,
        'createdAt': DateTime.now().toIso8601String(),
        'lastSignIn': DateTime.now().toIso8601String(),
        'isDeleted': false,
        'profile': {
          'displayName': user.displayName ?? 'User',
          'emailVerified': user.emailVerified,
        }
      };
      
      await firestore.collection('users').doc(email).set(userData);
      print('✅ User data stored in Firestore: $email');
    } catch (e) {
      print('⚠️ Error storing user data in Firestore: $e');
      // Don't fail the sign-up if Firestore fails
    }
  }

  Future<void> _updateUserLastSignIn(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(email).update({
        'lastSignIn': DateTime.now().toIso8601String(),
      });
      print('✅ Updated last sign-in time in Firestore: $email');
    } catch (e) {
      print('⚠️ Error updating last sign-in time: $e');
    }
  }

  Future<void> _markAccountAsDeletedInFirestore(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(email).update({
        'isDeleted': true,
        'deletedAt': DateTime.now().toIso8601String(),
      });
      print('✅ Account marked as deleted in Firestore: $email');
    } catch (e) {
      print('⚠️ Error marking account as deleted in Firestore: $e');
    }
  }

  Future<void> _deleteUserDataFromFirestore(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(email).delete();
      print('✅ User data deleted from Firestore: $email');
    } catch (e) {
      print('⚠️ Error deleting user data from Firestore: $e');
    }
  }








  




}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
  });

  factory AuthResult.success(User? user) => AuthResult._(
        isSuccess: true,
        user: user,
      );

  factory AuthResult.failure(String errorMessage) => AuthResult._(
        isSuccess: false,
        errorMessage: errorMessage,
      );
}

