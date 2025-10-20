import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/feed_item.dart';

/// Repository for fetching users-only feed data from Firebase
/// Queries real users from Firestore based on GPS location
class UsersFeedRepository {
  static final UsersFeedRepository _instance = UsersFeedRepository._internal();
  factory UsersFeedRepository() => _instance;
  UsersFeedRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();
  
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  
  /// Fetch initial users from Firestore
  Future<FeedResponse> fetchInitial({
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    try {
      _lastDocument = null;
      _hasMore = true;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('⚠️ Cannot fetch users - not signed in');
        }
        return const FeedResponse(items: [], cursor: null, hasMore: false);
      }

      // Calculate bounding box for efficient query
      final radiusKm = radiusMeters / 1000.0;
      final latDelta = radiusKm / 111.0;
      
      final minLat = lat - latDelta;
      final maxLat = lat + latDelta;

      if (kDebugMode) {
        print('📡 Fetching users within ${radiusKm}km of ($lat, $lng)');
      }

      // Query Firestore for nearby users
      Query query = _firestore
          .collection('users')
          .where('isDetectable', isEqualTo: true)
          .where('location.latitude', isGreaterThanOrEqualTo: minLat)
          .where('location.latitude', isLessThanOrEqualTo: maxLat)
          .limit(10);

      final snapshot = await query.get();
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= 10;

      final items = await _convertToFeedItems(
        snapshot.docs,
        lat,
        lng,
        radiusKm,
        currentUser.uid,
        hideBoosted,
      );

      if (kDebugMode) {
        print('✅ Fetched ${items.length} real users from Firestore');
      }

      return FeedResponse(
        items: items,
        cursor: _lastDocument?.id,
        hasMore: _hasMore,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching users: $e');
      }
      return const FeedResponse(items: [], cursor: null, hasMore: false);
    }
  }

  /// Fetch next page of users from Firestore
  Future<FeedResponse> fetchNext({
    required String cursor,
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    try {
      if (_lastDocument == null || !_hasMore) {
        return const FeedResponse(items: [], cursor: null, hasMore: false);
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return const FeedResponse(items: [], cursor: null, hasMore: false);
      }

      // Calculate bounding box
      final radiusKm = radiusMeters / 1000.0;
      final latDelta = radiusKm / 111.0;
      
      final minLat = lat - latDelta;
      final maxLat = lat + latDelta;

      // Query Firestore with pagination
      Query query = _firestore
          .collection('users')
          .where('isDetectable', isEqualTo: true)
          .where('location.latitude', isGreaterThanOrEqualTo: minLat)
          .where('location.latitude', isLessThanOrEqualTo: maxLat)
          .startAfterDocument(_lastDocument!)
          .limit(10);

      final snapshot = await query.get();
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= 10;

      final items = await _convertToFeedItems(
        snapshot.docs,
        lat,
        lng,
        radiusKm,
        currentUser.uid,
        hideBoosted,
      );

      if (kDebugMode) {
        print('✅ Fetched ${items.length} more users (pagination)');
      }

      return FeedResponse(
        items: items,
        cursor: _lastDocument?.id,
        hasMore: _hasMore,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching next page: $e');
      }
      return const FeedResponse(items: [], cursor: null, hasMore: false);
    }
  }

  /// Convert Firestore documents to FeedItem objects
  Future<List<FeedItem>> _convertToFeedItems(
    List<QueryDocumentSnapshot> docs,
    double userLat,
    double userLng,
    double radiusKm,
    String currentUserId,
    bool hideBoosted,
  ) async {
    final items = <FeedItem>[];

    for (final doc in docs) {
      try {
        // Skip current user
        if (doc.id == currentUserId) continue;

        final data = doc.data() as Map<String, dynamic>;
        final locationData = data['location'] as Map<String, dynamic>?;

        if (locationData == null) continue;

        final userLat2 = locationData['latitude'] as double?;
        final userLng2 = locationData['longitude'] as double?;

        if (userLat2 == null || userLng2 == null) continue;

        // Calculate precise distance
        final distanceMeters = Geolocator.distanceBetween(
          userLat,
          userLng,
          userLat2,
          userLng2,
        );
        final distanceKm = distanceMeters / 1000.0;

        // Only include users within radius
        if (distanceKm > radiusKm) continue;

        // Check if user is boosted (premium feature)
        final isBoosted = data['isBoosted'] as bool? ?? false;
        if (hideBoosted && isBoosted) continue;

        // Create UserCard from Firestore data
        final userCard = UserCard(
          id: doc.id,
          name: data['displayName'] as String? ?? 'User',
          avatar: data['photoURL'] as String? ?? '👤',
          bio: data['bio'] as String? ?? '',
          interests: (data['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
          mutualFriendsCount: data['mutualFriendsCount'] as int? ?? 0,
          isOnline: data['isOnline'] as bool? ?? false,
          lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
        );

        items.add(FeedItem(
          id: doc.id,
          type: FeedItemType.user,
          isBoosted: isBoosted,
          distance: distanceMeters,
          payload: userCard,
          detectedAt: DateTime.now(),
        ));
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error processing user ${doc.id}: $e');
        }
        continue;
      }
    }

    // Sort: boosted first, then by distance
    items.sort((a, b) {
      if (a.isBoosted && !b.isBoosted) return -1;
      if (!a.isBoosted && b.isBoosted) return 1;
      return a.distance.compareTo(b.distance);
    });

    return items;
  }

  /// Reset pagination
  void reset() {
    _lastDocument = null;
    _hasMore = true;
  }

  /// ⚠️ DEPRECATED - MOCK DATA GENERATOR - KEPT FOR BACKWARDS COMPATIBILITY ⚠️
  /// 
  /// This method generates fake data for testing and development.
  /// NO LONGER USED - Real data comes from Firestore via fetchInitial/fetchNext
  @deprecated
  List<FeedItem> _generateMockUsers({
    required double lat,
    required double lng,
    required double radiusMeters,
    required int count,
    bool hideBoosted = false,
  }) {
    final items = <FeedItem>[];
    
    for (int i = 0; i < count; i++) {
      final isBoosted = !hideBoosted && _random.nextDouble() < 0.3; // 30% boosted
      final distance = _random.nextDouble() * radiusMeters;
      
      final user = _generateMockUser();
      
      items.add(FeedItem(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: FeedItemType.user,
        isBoosted: isBoosted,
        distance: distance,
        payload: user,
        detectedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
      ));
    }
    
    // Sort: boosted items first, then by distance
    items.sort((a, b) {
      if (a.isBoosted && !b.isBoosted) return -1;
      if (!a.isBoosted && b.isBoosted) return 1;
      return a.distance.compareTo(b.distance);
    });
    
    return items;
  }

  /// ⚠️ DEPRECATED - MOCK DATA - NO LONGER USED ⚠️
  @deprecated
  UserCard _generateMockUser() {
    final names = [
      'Alex Rivera', 'Emma Thompson', 'Jordan Lee', 'Taylor Swift',
      'Morgan Davis', 'Casey Johnson', 'Riley Martinez', 'Quinn Anderson',
      'Drew Wilson', 'Blake Brown', 'Avery Garcia', 'Cameron Miller',
      'Dylan White', 'Parker Jones', 'Sage Robinson', 'River Clark',
      'Skyler Moore', 'Jamie Foster', 'Dakota Reed', 'Phoenix Hayes',
    ];
    
    final avatars = ['👨', '👩', '👨‍🦱', '👩‍🦰', '👨‍🦳', '👩‍🦳', '🧑', '👤', '🙋‍♂️', '🙋‍♀️'];
    
    final interestsList = [
      ['Music', 'Travel', 'Photography'],
      ['Sports', 'Gaming', 'Tech'],
      ['Art', 'Reading', 'Cooking'],
      ['Fitness', 'Yoga', 'Meditation'],
      ['Movies', 'Coffee', 'Writing'],
      ['Dancing', 'Fashion', 'Design'],
      ['Hiking', 'Nature', 'Adventure'],
      ['Food', 'Wine', 'Culinary'],
    ];
    
    final bios = [
      'Love exploring new places and meeting interesting people! 🌍',
      'Tech enthusiast | Coffee addict ☕ | Always up for an adventure',
      'Artist by day, dreamer by night ✨',
      'Fitness junkie 💪 | Healthy lifestyle advocate',
      'Passionate about photography and storytelling 📸',
      'Music lover | Concert goer | Vinyl collector 🎵',
      'Foodie exploring the best local spots 🍕',
      'Outdoor enthusiast | Nature photographer 🏔️',
      'Creative soul with a passion for design 🎨',
      'Bookworm | Tea lover | Writer ✍️',
    ];
    
    // Calculate last active time (recent activity)
    final minutesAgo = _random.nextInt(120); // 0-120 minutes ago
    
    return UserCard(
      id: 'user_${_random.nextInt(10000)}',
      name: names[_random.nextInt(names.length)],
      avatar: avatars[_random.nextInt(avatars.length)],
      bio: bios[_random.nextInt(bios.length)],
      interests: interestsList[_random.nextInt(interestsList.length)],
      mutualFriendsCount: _random.nextInt(20),
      isOnline: _random.nextDouble() < 0.4, // 40% online
      lastSeen: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );
  }
}

