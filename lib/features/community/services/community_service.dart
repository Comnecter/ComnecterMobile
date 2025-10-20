import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/community_model.dart';

/// Service for managing communities
class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static const String _communitiesCollection = 'communities';
  static const String _communityMembersCollection = 'community_members';

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Create a new community
  Future<Community> createCommunity({
    required String name,
    required String description,
    String avatar = '👥',
    List<String> tags = const [],
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to create a community');
    }

    if (name.trim().isEmpty) {
      throw Exception('Community name cannot be empty');
    }

    try {
      final now = DateTime.now();
      final communityData = {
        'name': name.trim(),
        'description': description.trim(),
        'avatar': avatar,
        'creatorId': _currentUserId!,
        'memberIds': [_currentUserId!], // Creator is automatically a member
        'tags': tags,
        'isVerified': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'metadata': {},
      };

      // Create community document
      final docRef = await _firestore
          .collection(_communitiesCollection)
          .add(communityData);

      // Create community member entry for creator
      await _addCommunityMember(
        communityId: docRef.id,
        userId: _currentUserId!,
        role: 'creator',
      );

      // Fetch and return the created community
      final doc = await docRef.get();
      return Community.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to create community: $e');
    }
  }

  /// Get a specific community by ID
  Future<Community?> getCommunity(String communityId) async {
    try {
      final doc = await _firestore
          .collection(_communitiesCollection)
          .doc(communityId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Community.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get community: $e');
    }
  }

  /// Get communities where user is a member
  Future<List<Community>> getUserCommunities() async {
    if (_currentUserId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_communitiesCollection)
          .where('memberIds', arrayContains: _currentUserId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Community.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user communities: $e');
    }
  }

  /// Stream of user communities
  Stream<List<Community>> getUserCommunitiesStream() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_communitiesCollection)
        .where('memberIds', arrayContains: _currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Community.fromFirestore(doc))
            .toList());
  }

  /// Update community details
  Future<void> updateCommunity({
    required String communityId,
    String? name,
    String? description,
    String? avatar,
    List<String>? tags,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in');
    }

    try {
      // Check if user has permission to update
      final community = await getCommunity(communityId);
      if (community == null) {
        throw Exception('Community not found');
      }

      if (!community.isCreator(_currentUserId!)) {
        throw Exception('Only creator can update community details');
      }

      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null && name.trim().isNotEmpty) {
        updates['name'] = name.trim();
      }
      if (description != null) {
        updates['description'] = description.trim();
      }
      if (avatar != null) {
        updates['avatar'] = avatar;
      }
      if (tags != null) {
        updates['tags'] = tags;
      }

      await _firestore
          .collection(_communitiesCollection)
          .doc(communityId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update community: $e');
    }
  }

  /// Join a community
  Future<void> joinCommunity(String communityId) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to join a community');
    }

    try {
      final community = await getCommunity(communityId);
      if (community == null) {
        throw Exception('Community not found');
      }

      if (community.isMember(_currentUserId!)) {
        throw Exception('Already a member of this community');
      }

      // Add user to community members
      await _firestore
          .collection(_communitiesCollection)
          .doc(communityId)
          .update({
        'memberIds': FieldValue.arrayUnion([_currentUserId!]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Create community member entry
      await _addCommunityMember(
        communityId: communityId,
        userId: _currentUserId!,
        role: 'member',
      );
    } catch (e) {
      throw Exception('Failed to join community: $e');
    }
  }

  /// Leave a community
  Future<void> leaveCommunity(String communityId) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in');
    }

    try {
      final community = await getCommunity(communityId);
      if (community == null) {
        throw Exception('Community not found');
      }

      if (community.isCreator(_currentUserId!)) {
        throw Exception('Creator cannot leave their own community. Delete it instead.');
      }

      if (!community.isMember(_currentUserId!)) {
        throw Exception('Not a member of this community');
      }

      // Remove user from community members
      await _firestore
          .collection(_communitiesCollection)
          .doc(communityId)
          .update({
        'memberIds': FieldValue.arrayRemove([_currentUserId!]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update community member status
      await _updateCommunityMemberStatus(
        communityId: communityId,
        userId: _currentUserId!,
        isActive: false,
      );
    } catch (e) {
      throw Exception('Failed to leave community: $e');
    }
  }

  /// Delete a community (creator only)
  Future<void> deleteCommunity(String communityId) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in');
    }

    try {
      final community = await getCommunity(communityId);
      if (community == null) {
        throw Exception('Community not found');
      }

      if (!community.isCreator(_currentUserId!)) {
        throw Exception('Only creator can delete the community');
      }

      // Delete community document
      await _firestore
          .collection(_communitiesCollection)
          .doc(communityId)
          .delete();

      // Delete all community member entries
      final memberDocs = await _firestore
          .collection(_communityMembersCollection)
          .where('communityId', isEqualTo: communityId)
          .get();

      final batch = _firestore.batch();
      for (final doc in memberDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete community: $e');
    }
  }

  /// Search communities by name
  Future<List<Community>> searchCommunities(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      // Firestore doesn't support full-text search, so we'll use a simple approach
      // In production, consider using Algolia or ElasticSearch
      final snapshot = await _firestore
          .collection(_communitiesCollection)
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => Community.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search communities: $e');
    }
  }

  /// Get all communities (paginated)
  Future<List<Community>> getAllCommunities({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(_communitiesCollection)
          .orderBy('memberCount', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Community.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get communities: $e');
    }
  }

  /// Add a community member entry
  Future<void> _addCommunityMember({
    required String communityId,
    required String userId,
    required String role,
  }) async {
    try {
      await _firestore.collection(_communityMembersCollection).add({
        'communityId': communityId,
        'userId': userId,
        'role': role,
        'joinedAt': Timestamp.fromDate(DateTime.now()),
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Failed to add community member: $e');
    }
  }

  /// Update community member status
  Future<void> _updateCommunityMemberStatus({
    required String communityId,
    required String userId,
    required bool isActive,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_communityMembersCollection)
          .where('communityId', isEqualTo: communityId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'isActive': isActive,
        });
      }
    } catch (e) {
      throw Exception('Failed to update member status: $e');
    }
  }

  /// Get community members
  Future<List<CommunityMember>> getCommunityMembers(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection(_communityMembersCollection)
          .where('communityId', isEqualTo: communityId)
          .where('isActive', isEqualTo: true)
          .orderBy('joinedAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => CommunityMember.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get community members: $e');
    }
  }
}

