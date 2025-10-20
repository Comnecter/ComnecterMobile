import 'dart:async';
import 'dart:math';
import '../models/feed_item.dart';

/// Repository for fetching discover feed data
/// 
/// ⚠️ WARNING: This repository contains MOCK DATA for development only!
/// 
/// TODO: Replace all mock data generation with real API/Firebase calls:
/// - fetchInitial() should call real backend API
/// - fetchNext() should call real backend API with pagination
/// - Remove all _generateMock*() methods
/// - Connect to actual data sources (Firebase, REST API, GraphQL, etc.)
/// 
/// In production, this MUST be replaced with real API calls to your backend
class AllFeedRepository {
  static final AllFeedRepository _instance = AllFeedRepository._internal();
  factory AllFeedRepository() => _instance;
  AllFeedRepository._internal();

  final Random _random = Random();
  int _currentPage = 0;
  
  /// Fetch initial feed items
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
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    _currentPage = 0;
    final items = _generateMockFeedItems(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      count: 10,
      hideBoosted: hideBoosted,
    );
    
    return FeedResponse(
      items: items,
      cursor: 'page_1',
      hasMore: true,
    );
  }

  /// Fetch next page of feed items
  /// 
  /// [cursor] Pagination cursor from previous response
  /// [lat] Latitude
  /// [lng] Longitude
  /// [radiusMeters] Search radius in meters
  /// [hideBoosted] Whether to hide boosted items (premium feature)
  Future<FeedResponse> fetchNext({
    required String cursor,
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));
    
    _currentPage++;
    
    // Simulate running out of content after a few pages
    if (_currentPage >= 5) {
      return const FeedResponse(
        items: [],
        cursor: null,
        hasMore: false,
      );
    }
    
    final items = _generateMockFeedItems(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      count: 8,
      hideBoosted: hideBoosted,
    );
    
    return FeedResponse(
      items: items,
      cursor: 'page_${_currentPage + 1}',
      hasMore: _currentPage < 4,
    );
  }

  /// ⚠️ MOCK DATA GENERATOR - FOR DEVELOPMENT ONLY ⚠️
  /// 
  /// This method generates fake data for testing and development.
  /// TODO: REMOVE THIS METHOD and replace with real API calls in production
  /// 
  /// Generate mock feed items for development
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
          id = 'user_${_currentPage}_$i';
          payload = _generateMockUserCard();
          break;
        case FeedItemType.community:
          id = 'community_${_currentPage}_$i';
          payload = _generateMockCommunityCard();
          break;
        case FeedItemType.event:
          id = 'event_${_currentPage}_$i';
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

  /// Reset pagination (useful for pull-to-refresh)
  void reset() {
    _currentPage = 0;
  }
}

