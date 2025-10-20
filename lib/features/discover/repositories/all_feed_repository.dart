import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/feed_item.dart';

/// Repository for fetching discover feed data (users, communities, events) from Firebase
/// 
/// ⚠️ PARTIALLY IMPLEMENTED: Users use real Firebase data
/// TODO: Connect communities and events to Firebase/API
class AllFeedRepository {
  static final AllFeedRepository _instance = AllFeedRepository._internal();
  factory AllFeedRepository() => _instance;
  AllFeedRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();
  
  DocumentSnapshot? _lastUserDoc;
  // TODO: Add _lastCommunityDoc and _lastEventDoc when communities/events are implemented
  bool _hasMore = true;
  
  /// Fetch initial feed items (mixed: real users + mock communities/events)
  /// 
  /// [lat] Latitude
  /// [lng] Longitude
  /// [radiusMeters] Search radius in meters
  /// [hideBoosted] Whether to hide boosted items (premium feature)
  Future<FeedResponse> fetchInitial({
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    try {
      _lastUserDoc = null;
      // TODO: Reset community and event cursors when implemented
      _hasMore = true;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('⚠️ Cannot fetch feed - not signed in');
        }
        return const FeedResponse(items: [], cursor: null, hasMore: false);
      }

      final items = <FeedItem>[];

      // Fetch real users from Firestore
      final userItems = await _fetchRealUsers(
        lat: lat,
        lng: lng,
        radiusKm: radiusMeters / 1000.0,
        limit: 7,
        hideBoosted: hideBoosted,
        currentUserId: currentUser.uid,
      );
      items.addAll(userItems);

      // TODO: Fetch real communities from Firestore (currently using mock)
      final communityItems = _generateMockCommunityItems(count: 2, hideBoosted: hideBoosted);
      items.addAll(communityItems);

      // TODO: Fetch real events from Firestore (currently using mock)
      final eventItems = _generateMockEventItems(count: 1, hideBoosted: hideBoosted);
      items.addAll(eventItems);

      // Mix and sort: boosted first, then by distance/relevance
      items.sort((a, b) {
        if (a.isBoosted && !b.isBoosted) return -1;
        if (!a.isBoosted && b.isBoosted) return 1;
        return a.distance.compareTo(b.distance);
      });

      if (kDebugMode) {
        print('✅ Fetched ${items.length} items (${userItems.length} real users, ${communityItems.length} communities, ${eventItems.length} events)');
      }

      return FeedResponse(
        items: items,
        cursor: _lastUserDoc?.id ?? 'page_1',
        hasMore: _hasMore,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching feed: $e');
      }
      return const FeedResponse(items: [], cursor: null, hasMore: false);
    }
  }

  /// Fetch next page of feed items
  Future<FeedResponse> fetchNext({
    required String cursor,
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    try {
      if (_lastUserDoc == null || !_hasMore) {
        return const FeedResponse(items: [], cursor: null, hasMore: false);
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return const FeedResponse(items: [], cursor: null, hasMore: false);
      }

      final items = <FeedItem>[];

      // Fetch more real users
      final userItems = await _fetchRealUsers(
        lat: lat,
        lng: lng,
        radiusKm: radiusMeters / 1000.0,
        limit: 8,
        hideBoosted: hideBoosted,
        currentUserId: currentUser.uid,
        startAfter: _lastUserDoc,
      );
      items.addAll(userItems);

      // Mix and sort
      items.sort((a, b) {
        if (a.isBoosted && !b.isBoosted) return -1;
        if (!a.isBoosted && b.isBoosted) return 1;
        return a.distance.compareTo(b.distance);
      });

      if (kDebugMode) {
        print('✅ Fetched ${items.length} more items (pagination)');
      }

      return FeedResponse(
        items: items,
        cursor: _lastUserDoc?.id,
        hasMore: _hasMore,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching next page: $e');
      }
      return const FeedResponse(items: [], cursor: null, hasMore: false);
    }
  }

  /// Fetch real users from Firestore
  Future<List<FeedItem>> _fetchRealUsers({
    required double lat,
    required double lng,
    required double radiusKm,
    required int limit,
    required bool hideBoosted,
    required String currentUserId,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // Calculate bounding box
      final latDelta = radiusKm / 111.0;
      final minLat = lat - latDelta;
      final maxLat = lat + latDelta;

      // Query Firestore
      Query query = _firestore
          .collection('users')
          .where('isDetectable', isEqualTo: true)
          .where('location.latitude', isGreaterThanOrEqualTo: minLat)
          .where('location.latitude', isLessThanOrEqualTo: maxLat);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      _lastUserDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= limit;

      final items = <FeedItem>[];

      for (final doc in snapshot.docs) {
        try {
          if (doc.id == currentUserId) continue;

          final data = doc.data() as Map<String, dynamic>;
          final locationData = data['location'] as Map<String, dynamic>?;

          if (locationData == null) continue;

          final userLat2 = locationData['latitude'] as double?;
          final userLng2 = locationData['longitude'] as double?;

          if (userLat2 == null || userLng2 == null) continue;

          final distanceMeters = Geolocator.distanceBetween(lat, lng, userLat2, userLng2);
          final distanceKm = distanceMeters / 1000.0;

          if (distanceKm > radiusKm) continue;

          final isBoosted = data['isBoosted'] as bool? ?? false;
          if (hideBoosted && isBoosted) continue;

          final userCard = UserCard(
            id: doc.id,
            name: data['displayName'] as String? ?? 'User',
            avatar: data['photoURL'] as String? ?? '👤',
            bio: data['bio'] as String? ?? '',
            interests: (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
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

      return items;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching real users: $e');
      }
      return [];
    }
  }

  /// Generate mock community items (TODO: Replace with Firestore)
  List<FeedItem> _generateMockCommunityItems({
    required int count,
    required bool hideBoosted,
  }) {
    final items = <FeedItem>[];
    
    for (int i = 0; i < count; i++) {
      final isBoosted = _random.nextDouble() < 0.2;
      if (hideBoosted && isBoosted) continue;
      
      items.add(FeedItem(
        id: 'community_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: FeedItemType.community,
        isBoosted: isBoosted,
        distance: _random.nextDouble() * 5000,
        payload: _generateMockCommunityCard(),
        detectedAt: DateTime.now(),
      ));
    }
    
    return items;
  }

  /// Generate mock event items (TODO: Replace with Firestore)
  List<FeedItem> _generateMockEventItems({
    required int count,
    required bool hideBoosted,
  }) {
    final items = <FeedItem>[];
    
    for (int i = 0; i < count; i++) {
      final isBoosted = _random.nextDouble() < 0.3;
      if (hideBoosted && isBoosted) continue;
      
      items.add(FeedItem(
        id: 'event_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: FeedItemType.event,
        isBoosted: isBoosted,
        distance: _random.nextDouble() * 8000,
        payload: _generateMockEventCard(),
        detectedAt: DateTime.now(),
      ));
    }
    
    return items;
  }

  /// Reset pagination
  void reset() {
    _lastUserDoc = null;
    // TODO: Reset _lastCommunityDoc and _lastEventDoc when implemented
    _hasMore = true;
  }

  /// ⚠️ DEPRECATED - MOCK DATA - NO LONGER USED ⚠️
  /// Real users come from Firestore via _fetchRealUsers
  @deprecated
  List<FeedItem> _generateMockFeedItems({
    required double lat,
    required double lng,
    required double radiusMeters,
    required int count,
    bool hideBoosted = false,
  }) {
    final items = <FeedItem>[];
    
    for (int i = 0; i < count; i++) {
      final type = FeedItemType.values[_random.nextInt(FeedItemType.values.length)];
      final isBoosted = !hideBoosted && _random.nextDouble() < 0.3; // 30% chance of being boosted
      final distance = _random.nextDouble() * radiusMeters;
      
      dynamic payload;
      String id;
      
      switch (type) {
        case FeedItemType.user:
          id = 'user_${DateTime.now().millisecondsSinceEpoch}_$i';
          payload = _generateMockUserCard();
          break;
        case FeedItemType.community:
          id = 'community_${DateTime.now().millisecondsSinceEpoch}_$i';
          payload = _generateMockCommunityCard();
          break;
        case FeedItemType.event:
          id = 'event_${DateTime.now().millisecondsSinceEpoch}_$i';
          payload = _generateMockEventCard();
          break;
      }
      
      items.add(FeedItem(
        id: id,
        type: type,
        isBoosted: isBoosted,
        distance: distance,
        payload: payload,
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

  /// ⚠️ MOCK DATA - REMOVE IN PRODUCTION ⚠️
  UserCard _generateMockUserCard() {
    final names = [
      'Alex Rivera', 'Emma Thompson', 'Jordan Lee', 'Taylor Swift',
      'Morgan Davis', 'Casey Johnson', 'Riley Martinez', 'Quinn Anderson',
      'Drew Wilson', 'Blake Brown', 'Avery Garcia', 'Cameron Miller',
      'Dylan White', 'Parker Jones', 'Sage Robinson', 'River Clark',
    ];
    
    final avatars = ['👨', '👩', '👨‍🦱', '👩‍🦰', '👨‍🦳', '👩‍🦳', '🧑', '👤'];
    
    final interestsList = [
      ['Music', 'Travel', 'Photography'],
      ['Sports', 'Gaming', 'Tech'],
      ['Art', 'Reading', 'Cooking'],
      ['Fitness', 'Yoga', 'Meditation'],
      ['Movies', 'Coffee', 'Writing'],
      ['Dancing', 'Fashion', 'Design'],
    ];
    
    final bios = [
      'Love exploring new places and meeting interesting people! 🌍',
      'Tech enthusiast | Coffee addict ☕ | Always up for an adventure',
      'Artist by day, dreamer by night ✨',
      'Fitness junkie 💪 | Healthy lifestyle advocate',
      'Passionate about photography and storytelling 📸',
      'Music lover | Concert goer | Vinyl collector 🎵',
    ];
    
    return UserCard(
      id: 'user_${_random.nextInt(10000)}',
      name: names[_random.nextInt(names.length)],
      avatar: avatars[_random.nextInt(avatars.length)],
      bio: bios[_random.nextInt(bios.length)],
      interests: interestsList[_random.nextInt(interestsList.length)],
      mutualFriendsCount: _random.nextInt(20),
      isOnline: _random.nextBool(),
      lastSeen: _random.nextBool() 
          ? DateTime.now().subtract(Duration(minutes: _random.nextInt(120))) 
          : null,
    );
  }

  /// ⚠️ MOCK DATA - REMOVE IN PRODUCTION ⚠️
  CommunityCard _generateMockCommunityCard() {
    final names = [
      'Tech Innovators', 'Fitness Warriors', 'Book Lovers Club',
      'Photography Enthusiasts', 'Foodie Paradise', 'Travel Buddies',
      'Music Makers', 'Art Collective', 'Gaming Squad', 'Startup Founders',
      'Yoga & Wellness', 'Coffee Connoisseurs', 'Film Buffs', 'Nature Lovers',
    ];
    
    final avatars = ['💻', '🏃‍♂️', '📚', '📸', '🍕', '✈️', '🎵', '🎨', '🎮', '🚀', '🧘', '☕', '🎬', '🌿'];
    
    final descriptions = [
      'A vibrant community of like-minded individuals passionate about innovation',
      'Join us for weekly meetups and exciting activities!',
      'Connect, share, and grow together in this amazing community',
      'Where enthusiasts become friends and ideas come to life',
      'Building meaningful connections one event at a time',
      'Your local community for all things awesome!',
    ];
    
    final tags = [
      ['Technology', 'Innovation'],
      ['Health', 'Wellness'],
      ['Arts', 'Culture'],
      ['Food', 'Drinks'],
      ['Travel', 'Adventure'],
      ['Music', 'Entertainment'],
    ];
    
    return CommunityCard(
      id: 'community_${_random.nextInt(10000)}',
      name: names[_random.nextInt(names.length)],
      description: descriptions[_random.nextInt(descriptions.length)],
      avatar: avatars[_random.nextInt(avatars.length)],
      memberCount: _random.nextInt(5000) + 10,
      tags: tags[_random.nextInt(tags.length)],
      isJoined: _random.nextDouble() < 0.2,
      isVerified: _random.nextDouble() < 0.3,
    );
  }

  /// ⚠️ MOCK DATA - REMOVE IN PRODUCTION ⚠️
  EventCard _generateMockEventCard() {
    final titles = [
      'Tech Meetup 2025', 'Summer Music Festival', 'Fitness Bootcamp',
      'Art Exhibition', 'Food Tasting Event', 'Networking Night',
      'Yoga Workshop', 'Book Club Gathering', 'Film Screening',
      'Startup Pitch Night', 'Photography Walk', 'Cooking Class',
    ];
    
    final descriptions = [
      'Join us for an amazing experience you won\'t forget!',
      'Connect with fellow enthusiasts and have a great time',
      'Limited spots available - register now!',
      'An evening of fun, learning, and networking',
      'Bring your friends and make new connections',
      'Expert-led session with hands-on activities',
    ];
    
    final locations = [
      'Downtown Convention Center',
      'City Park Pavilion',
      'Community Center Hall',
      'Tech Hub Co-working Space',
      'Riverside Amphitheater',
      'Local Coffee Shop',
    ];
    
    final organizerNames = [
      'TechHub', 'Community Leaders', 'Event Masters',
      'Local Organizers', 'Meetup Group', 'Event Collective',
    ];
    
    final tags = [
      ['Technology', 'Networking'],
      ['Music', 'Entertainment'],
      ['Health', 'Fitness'],
      ['Food', 'Social'],
      ['Arts', 'Culture'],
      ['Business', 'Professional'],
    ];
    
    // Generate random date within next 30 days
    final startTime = DateTime.now().add(
      Duration(
        days: _random.nextInt(30),
        hours: _random.nextInt(24),
      ),
    );
    
    return EventCard(
      id: 'event_${_random.nextInt(10000)}',
      title: titles[_random.nextInt(titles.length)],
      description: descriptions[_random.nextInt(descriptions.length)],
      startTime: startTime,
      endTime: startTime.add(Duration(hours: _random.nextInt(4) + 1)),
      location: locations[_random.nextInt(locations.length)],
      venue: _random.nextBool() ? 'Room ${_random.nextInt(10) + 1}' : null,
      attendeeCount: _random.nextInt(100),
      maxAttendees: _random.nextBool() ? _random.nextInt(150) + 50 : 0,
      isAttending: _random.nextDouble() < 0.2,
      tags: tags[_random.nextInt(tags.length)],
      organizerId: 'org_${_random.nextInt(1000)}',
      organizerName: organizerNames[_random.nextInt(organizerNames.length)],
    );
  }
}

