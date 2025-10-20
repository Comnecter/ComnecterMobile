import 'package:firebase_auth/firebase_auth.dart';

/// Debug helper to check Firebase Authentication status
/// This helps diagnose permission issues
class DebugAuthCheck {
  static void printAuthStatus() {
    final user = FirebaseAuth.instance.currentUser;
    
    print('==========================================');
    print('🔍 FIREBASE AUTH DEBUG INFO');
    print('==========================================');
    
    if (user == null) {
      print('❌ NOT SIGNED IN');
      print('   → You must be signed in to create communities');
      print('   → Go to sign in screen and authenticate');
    } else {
      print('✅ SIGNED IN');
      print('   User ID: ${user.uid}');
      print('   Email: ${user.email ?? 'No email'}');
      print('   Display Name: ${user.displayName ?? 'No name'}');
      print('   Email Verified: ${user.emailVerified}');
      print('   Provider: ${user.providerData.map((e) => e.providerId).join(', ')}');
    }
    
    print('==========================================');
  }

  static bool isSignedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  static String? getUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}

