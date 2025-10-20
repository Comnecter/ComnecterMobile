import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_model.dart';
import '../../../services/sound_service.dart';

/// Friend service with real Firebase Firestore integration
/// Manages friend relationships, friend requests, and friend status
class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<List<Friend>> _friendsController = StreamController<List<Friend>>.broadcast();
  final StreamController<List<FriendRequest>> _requestsController = StreamController<List<FriendRequest>>.broadcast();
  final StreamController<FriendStats> _statsController = StreamController<FriendStats>.broadcast();
  
  Stream<List<Friend>> get friendsStream => _friendsController.stream;
  Stream<List<FriendRequest>> get requestsStream => _requestsController.stream;
  Stream<FriendStats> get statsStream => _statsController.stream;

  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  StreamSubscription<QuerySnapshot>? _friendsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  /// Initialize the friend service and start listening to Firebase
  Future<void> initialize() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        print('⚠️ Cannot initialize FriendService - not signed in');
      }
      return;
    }

    if (kDebugMode) {
      print('🔄 Initializing FriendService for user: ${currentUser.uid}');
    }

    // Listen to friends collection
    _friendsSubscription = _firestore
        .collection('friends')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      _friends = snapshot.docs.map((doc) {
        return _friendFromFirestore(doc);
      }).toList();
      
      _friendsController.add(_friends);
      _updateStats();
      
      if (kDebugMode) {
        print('✅ Loaded ${_friends.length} friends from Firestore');
      }
    });

    // Listen to friend requests (received)
    _requestsSubscription = _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      final receivedRequests = await Future.wait(
        snapshot.docs.map((doc) => _friendRequestFromFirestore(doc))
      );
      
      // Also get sent requests
      final sentSnapshot = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      
      final sentRequests = await Future.wait(
        sentSnapshot.docs.map((doc) => _friendRequestFromFirestore(doc))
      );
      
      _requests = [...receivedRequests, ...sentRequests];
      _requestsController.add(_requests);
      _updateStats();
      
      if (kDebugMode) {
        print('✅ Loaded ${receivedRequests.length} received + ${sentRequests.length} sent friend requests');
      }
    });
  }

  /// Convert Firestore document to Friend model
  Friend _friendFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Friend(
      id: doc.id,
      userId: data['userId'] as String,
      friendId: data['friendId'] as String,
      name: data['name'] as String? ?? 'Unknown',
      avatar: data['avatar'] as String? ?? '👤',
      bio: data['bio'] as String?,
      interests: (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert Firestore document to FriendRequest model
  Future<FriendRequest> _friendRequestFromFirestore(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final currentUserId = _auth.currentUser?.uid ?? '';
    
    // Determine if this is a sent or received request
    final isReceived = data['toUserId'] == currentUserId;
    
    // Fetch user info for the other person
    String fromUserName = 'User';
    String fromUserAvatar = '👤';
    
    try {
      final userId = isReceived ? data['fromUserId'] as String : data['toUserId'] as String;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        fromUserName = userData['displayName'] as String? ?? 'User';
        fromUserAvatar = userData['photoURL'] as String? ?? '👤';
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error fetching user info for request: $e');
      }
    }
    
    return FriendRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] as String,
      toUserId: data['toUserId'] as String,
      fromUserName: fromUserName,
      fromUserAvatar: fromUserAvatar,
      message: data['message'] as String?,
      type: isReceived ? FriendRequestType.received : FriendRequestType.sent,
      response: data['status'] == 'accepted' ? FriendStatus.accepted : 
                data['status'] == 'rejected' ? FriendStatus.rejected : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Parse status string to FriendStatus enum
  FriendStatus _parseStatus(String? status) {
    switch (status) {
      case 'accepted':
        return FriendStatus.accepted;
      case 'pending':
        return FriendStatus.pending;
      case 'rejected':
        return FriendStatus.rejected;
      case 'blocked':
        return FriendStatus.blocked;
      case 'removed':
        return FriendStatus.removed;
      default:
        return FriendStatus.pending;
    }
  }

  /// Get all friends
  List<Friend> getFriends() {
    return List.unmodifiable(_friends);
  }

  /// Get friends by status
  List<Friend> getFriendsByStatus(FriendStatus status) {
    return _friends.where((friend) => friend.status == status).toList();
  }

  /// Get online friends
  List<Friend> getOnlineFriends() {
    return _friends.where((friend) => friend.isOnline && friend.status == FriendStatus.accepted).toList();
  }

  /// Get friend requests
  List<FriendRequest> getRequests() {
    return List.unmodifiable(_requests);
  }

  /// Get requests by type
  List<FriendRequest> getRequestsByType(FriendRequestType type) {
    return _requests.where((request) => request.type == type).toList();
  }

  /// Send friend request
  Future<void> sendFriendRequest(String toUserId, String toUserName, String toUserAvatar, {String? message}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not signed in');
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        if (kDebugMode) {
          print('⚠️ Friend request already exists');
        }
        return;
      }

      // Check if already friends
      final existingFriendship = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: toUserId)
          .get();

      if (existingFriendship.docs.isNotEmpty) {
        if (kDebugMode) {
          print('⚠️ Already friends with this user');
        }
        return;
      }

      // Create friend request
      await _firestore.collection('friend_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': toUserId,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Friend request sent to $toUserName');
      }

      SoundService().playSuccessSound();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending friend request: $e');
      }
      rethrow;
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not signed in');
      }

      // Get the request
      final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final requestData = requestDoc.data()!;
      final fromUserId = requestData['fromUserId'] as String;
      final toUserId = requestData['toUserId'] as String;

      // Update request status
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Get user info for both users
      final fromUserDoc = await _firestore.collection('users').doc(fromUserId).get();
      final toUserDoc = await _firestore.collection('users').doc(toUserId).get();

      final fromUserData = fromUserDoc.data() ?? {};
      final toUserData = toUserDoc.data() ?? {};

      // Create friendship for current user
      await _firestore.collection('friends').add({
        'userId': currentUser.uid,
        'friendId': fromUserId,
        'name': fromUserData['displayName'] ?? 'User',
        'avatar': fromUserData['photoURL'] ?? '👤',
        'bio': fromUserData['bio'],
        'interests': fromUserData['interests'] ?? [],
        'isOnline': fromUserData['isOnline'] ?? false,
        'lastSeen': fromUserData['lastSeen'],
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create friendship for the other user
      await _firestore.collection('friends').add({
        'userId': fromUserId,
        'friendId': currentUser.uid,
        'name': toUserData['displayName'] ?? 'User',
        'avatar': toUserData['photoURL'] ?? '👤',
        'bio': toUserData['bio'],
        'interests': toUserData['interests'] ?? [],
        'isOnline': toUserData['isOnline'] ?? false,
        'lastSeen': toUserData['lastSeen'],
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Friend request accepted');
      }

      SoundService().playSuccessSound();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error accepting friend request: $e');
      }
      rethrow;
    }
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Friend request rejected');
      }

      SoundService().playErrorSound();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error rejecting friend request: $e');
      }
      rethrow;
    }
  }

  /// Remove friend
  Future<void> removeFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not signed in');
      }

      // Find and delete friendship document for current user
      final friendshipQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: friendId)
          .get();

      for (final doc in friendshipQuery.docs) {
        await doc.reference.delete();
      }

      // Find and delete friendship document for the other user
      final reverseFriendshipQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: currentUser.uid)
          .get();

      for (final doc in reverseFriendshipQuery.docs) {
        await doc.reference.delete();
      }

      if (kDebugMode) {
        print('✅ Friend removed');
      }

      SoundService().playButtonClickSound();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing friend: $e');
      }
      rethrow;
    }
  }

  /// Block friend
  Future<void> blockFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not signed in');
      }

      // Update friendship status to blocked
      final friendshipQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: friendId)
          .get();

      for (final doc in friendshipQuery.docs) {
        await doc.reference.update({
          'status': 'blocked',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (kDebugMode) {
        print('✅ Friend blocked');
      }

      SoundService().playErrorSound();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error blocking friend: $e');
      }
      rethrow;
    }
  }

  /// Unblock friend
  Future<void> unblockFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Not signed in');
      }

      // Update friendship status to accepted
      final friendshipQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: friendId)
          .get();

      for (final doc in friendshipQuery.docs) {
        await doc.reference.update({
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (kDebugMode) {
        print('✅ Friend unblocked');
      }

      SoundService().playSuccessSound();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unblocking friend: $e');
      }
      rethrow;
    }
  }

  /// Search friends
  List<Friend> searchFriends(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _friends.where((friend) => 
      friend.name.toLowerCase().contains(lowercaseQuery) ||
      friend.bio?.toLowerCase().contains(lowercaseQuery) == true ||
      friend.interests.any((interest) => interest.toLowerCase().contains(lowercaseQuery))
    ).toList();
  }

  /// Update friend online status (usually done by presence system)
  void updateFriendStatus(String friendId, bool isOnline) {
    final friendIndex = _friends.indexWhere((f) => f.friendId == friendId);
    if (friendIndex == -1) return;

    final friend = _friends[friendIndex];
    final updatedFriend = friend.copyWith(
      isOnline: isOnline,
      lastSeen: DateTime.now(),
    );

    _friends[friendIndex] = updatedFriend;
    _friendsController.add(_friends);
    _updateStats();
  }

  /// Update stats
  void _updateStats() {
    final stats = FriendStats(
      totalFriends: _friends.where((f) => f.status == FriendStatus.accepted).length,
      onlineFriends: _friends.where((f) => f.isOnline && f.status == FriendStatus.accepted).length,
      pendingRequests: _requests.where((r) => r.response == null && r.type == FriendRequestType.received).length,
      sentRequests: _requests.where((r) => r.type == FriendRequestType.sent && r.response == null).length,
    );
    _statsController.add(stats);
  }

  /// Dispose resources
  void dispose() {
    _friendsSubscription?.cancel();
    _requestsSubscription?.cancel();
    _friendsController.close();
    _requestsController.close();
    _statsController.close();
  }
}
