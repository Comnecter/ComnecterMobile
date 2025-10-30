import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

/// Mock Firebase services for testing
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockQuerySnapshot extends Mock implements QuerySnapshot {}

class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}

class MockQuery extends Mock implements Query {}

class MockFirebaseApp extends Mock implements FirebaseApp {}

/// Test setup utilities for Firebase
class FirebaseTestHelper {
  static late MockFirebaseFirestore mockFirestore;
  static late MockFirebaseAuth mockAuth;
  static late MockUser mockUser;
  static late MockQuerySnapshot mockQuerySnapshot;
  static late MockQueryDocumentSnapshot mockDocumentSnapshot;
  static late MockDocumentSnapshot mockDocument;
  static late MockQuery mockQuery;
  static late MockFirebaseApp mockApp;

  /// Initialize Firebase mocks for testing
  static Future<void> setupFirebaseMocks() async {
    // Create mock instances
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockQuerySnapshot = MockQuerySnapshot();
    mockDocumentSnapshot = MockQueryDocumentSnapshot();
    mockDocument = MockDocumentSnapshot();
    mockQuery = MockQuery();
    mockApp = MockFirebaseApp();

    // Setup Firebase Core mock
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock Firebase.initializeApp
    when(mockApp.name).thenReturn('[DEFAULT]');
    when(mockApp.options).thenReturn(
      const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project-id',
      ),
    );

    // Setup Firestore mocks
    when(mockFirestore.collection(any)).thenReturn(mockQuery);
    when(mockQuery.where(any, isEqualTo: any)).thenReturn(mockQuery);
    when(mockQuery.where(any, isGreaterThanOrEqualTo: any)).thenReturn(mockQuery);
    when(mockQuery.where(any, isLessThanOrEqualTo: any)).thenReturn(mockQuery);
    when(mockQuery.limit(any)).thenReturn(mockQuery);
    when(mockQuery.startAfterDocument(any)).thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
    
    // Setup QuerySnapshot mocks
    when(mockQuerySnapshot.docs).thenReturn([mockDocumentSnapshot]);
    when(mockDocumentSnapshot.id).thenReturn('test_user_1');
    when(mockDocumentSnapshot.data()).thenReturn({
      'displayName': 'Test User',
      'photoURL': '👤',
      'bio': 'Test bio',
      'interests': ['Music', 'Travel'],
      'mutualFriendsCount': 5,
      'isOnline': true,
      'isBoosted': false,
      'isDetectable': true,
      'location': {
        'latitude': 37.7749,
        'longitude': -122.4194,
      },
      'lastSeen': Timestamp.now(),
    });

    // Setup Auth mocks
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_user_id');

    // Mock Firebase static instances
    // Note: This is a simplified approach. In a real implementation,
    // you'd need to use dependency injection or service locators
  }

  /// Clean up mocks after tests
  static void tearDown() {
    reset(mockFirestore);
    reset(mockAuth);
    reset(mockUser);
    reset(mockQuerySnapshot);
    reset(mockDocumentSnapshot);
    reset(mockDocument);
    reset(mockQuery);
    reset(mockApp);
  }
}

