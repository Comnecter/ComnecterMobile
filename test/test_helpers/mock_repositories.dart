import 'dart:math';
import 'package:comnecter_mobile/features/discover/models/feed_item.dart';

/// Mock repository for testing that generates realistic test data
/// without requiring Firebase initialization
class MockUsersFeedRepository {
  static final MockUsersFeedRepository _instance = MockUsersFeedRepository._internal();
  factory MockUsersFeedRepository() => _instance;
  MockUsersFeedRepository._internal();

  final Random _random = Random();
  int _currentPage = 0;
  static const int _itemsPerPage = 10;
  static const int _totalPages = 3; // Simulate limited data

  /// Fetch initial users with mock data
  Future<FeedResponse> fetchInitial({
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    _currentPage = 0;
    return _generateMockResponse(lat, lng, radiusMeters, hideBoosted);
  }

  /// Fetch next page of users
  Future<FeedResponse> fetchNext({
    required String cursor,
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    _currentPage++;
    if (_currentPage >= _totalPages) {
      return const FeedResponse(items: [], cursor: null, hasMore: false);
    }
    return _generateMockResponse(lat, lng, radiusMeters, hideBoosted);
  }

  /// Reset pagination
  void reset() {
    _currentPage = 0;
  }

  /// Generate mock response
  FeedResponse _generateMockResponse(
    double lat,
    double lng,
    double radiusMeters,
    bool hideBoosted,
  ) {
    final items = <FeedItem>[];
    final startIndex = _currentPage * _itemsPerPage;
    
    for (int i = 0; i < _itemsPerPage; i++) {
      final globalIndex = startIndex + i;
      final isBoosted = !hideBoosted && _random.nextDouble() < 0.3; // 30% boosted
      final distance = _random.nextDouble() * radiusMeters;
      
      final user = _generateMockUser(globalIndex);
      
      items.add(FeedItem(
        id: 'user_$globalIndex',
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
    
    final hasMore = _currentPage < _totalPages - 1;
    final cursor = hasMore ? 'page_${_currentPage + 1}' : null;
    
    return FeedResponse(
      items: items,
      cursor: cursor,
      hasMore: hasMore,
    );
  }

  /// Generate a mock user
  UserCard _generateMockUser(int index) {
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
      id: 'user_$index',
      name: names[index % names.length],
      avatar: avatars[index % avatars.length],
      bio: bios[index % bios.length],
      interests: interestsList[index % interestsList.length],
      mutualFriendsCount: _random.nextInt(20),
      isOnline: _random.nextDouble() < 0.4, // 40% online
      lastSeen: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );
  }
}

/// Mock repository for All Feed
class MockAllFeedRepository {
  static final MockAllFeedRepository _instance = MockAllFeedRepository._internal();
  factory MockAllFeedRepository() => _instance;
  MockAllFeedRepository._internal();

  final Random _random = Random();
  int _currentPage = 0;
  static const int _itemsPerPage = 10;
  static const int _totalPages = 3;

  /// Fetch initial feed with mixed content
  Future<FeedResponse> fetchInitial({
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    _currentPage = 0;
    return _generateMixedFeedResponse(lat, lng, radiusMeters, hideBoosted);
  }

  /// Fetch next page
  Future<FeedResponse> fetchNext({
    required String cursor,
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    _currentPage++;
    if (_currentPage >= _totalPages) {
      return const FeedResponse(items: [], cursor: null, hasMore: false);
    }
    return _generateMixedFeedResponse(lat, lng, radiusMeters, hideBoosted);
  }

  /// Reset pagination
  void reset() {
    _currentPage = 0;
  }

  /// Generate mixed feed response (users, communities, events)
  FeedResponse _generateMixedFeedResponse(
    double lat,
    double lng,
    double radiusMeters,
    bool hideBoosted,
  ) {
    final items = <FeedItem>[];
    final startIndex = _currentPage * _itemsPerPage;
    
    for (int i = 0; i < _itemsPerPage; i++) {
      final globalIndex = startIndex + i;
      final isBoosted = !hideBoosted && _random.nextDouble() < 0.3;
      final distance = _random.nextDouble() * radiusMeters;
      
      // Mix of different content types
      final contentType = globalIndex % 3;
      FeedItem item;
      
      switch (contentType) {
        case 0: // User
          final user = _generateMockUser(globalIndex);
          item = FeedItem(
            id: 'user_$globalIndex',
            type: FeedItemType.user,
            isBoosted: isBoosted,
            distance: distance,
            payload: user,
            detectedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
          );
          break;
        case 1: // Community
          final community = _generateMockCommunity(globalIndex);
          item = FeedItem(
            id: 'community_$globalIndex',
            type: FeedItemType.community,
            isBoosted: isBoosted,
            distance: distance,
            payload: community,
            detectedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
          );
          break;
        case 2: // Event
          final event = _generateMockEvent(globalIndex);
          item = FeedItem(
            id: 'event_$globalIndex',
            type: FeedItemType.event,
            isBoosted: isBoosted,
            distance: distance,
            payload: event,
            detectedAt: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
          );
          break;
        default:
          continue;
      }
      
      items.add(item);
    }
    
    // Sort: boosted items first, then by distance
    items.sort((a, b) {
      if (a.isBoosted && !b.isBoosted) return -1;
      if (!a.isBoosted && b.isBoosted) return 1;
      return a.distance.compareTo(b.distance);
    });
    
    final hasMore = _currentPage < _totalPages - 1;
    final cursor = hasMore ? 'page_${_currentPage + 1}' : null;
    
    return FeedResponse(
      items: items,
      cursor: cursor,
      hasMore: hasMore,
    );
  }

  /// Generate mock user (reuse from MockUsersFeedRepository)
  UserCard _generateMockUser(int index) {
    final names = ['Alex Rivera', 'Emma Thompson', 'Jordan Lee', 'Taylor Swift'];
    final avatars = ['👨', '👩', '👨‍🦱', '👩‍🦰'];
    final interestsList = [['Music', 'Travel'], ['Sports', 'Gaming'], ['Art', 'Reading']];
    final bios = ['Love exploring new places! 🌍', 'Tech enthusiast ☕', 'Artist by day ✨'];
    
    final minutesAgo = _random.nextInt(120);
    
    return UserCard(
      id: 'user_$index',
      name: names[index % names.length],
      avatar: avatars[index % avatars.length],
      bio: bios[index % bios.length],
      interests: interestsList[index % interestsList.length],
      mutualFriendsCount: _random.nextInt(20),
      isOnline: _random.nextDouble() < 0.4,
      lastSeen: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );
  }

  /// Generate mock community
  CommunityCard _generateMockCommunity(int index) {
    final names = ['Tech Enthusiasts', 'Art Lovers', 'Fitness Community', 'Foodies'];
    final descriptions = ['A community for tech lovers', 'Creative minds unite', 'Stay fit together', 'Culinary adventures'];
    final avatars = ['💻', '🎨', '💪', '🍕'];
    final tags = [['Technology', 'Innovation'], ['Art', 'Design'], ['Fitness', 'Health'], ['Food', 'Cooking']];
    
    return CommunityCard(
      id: 'community_$index',
      name: names[index % names.length],
      description: descriptions[index % descriptions.length],
      avatar: avatars[index % avatars.length],
      memberCount: 100 + _random.nextInt(1000),
      tags: tags[index % tags.length],
      isJoined: _random.nextBool(),
      isVerified: _random.nextBool(),
    );
  }

  /// Generate mock event
  EventCard _generateMockEvent(int index) {
    final titles = ['Tech Meetup', 'Art Exhibition', 'Fitness Workshop', 'Food Festival'];
    final descriptions = ['Join us for tech talks', 'Amazing art on display', 'Get fit together', 'Taste amazing food'];
    final locations = ['Tech Hub', 'Art Gallery', 'Fitness Center', 'Food Court'];
    final organizers = ['TechHub', 'ArtSpace', 'FitLife', 'FoodCorp'];
    
    final startTime = DateTime.now().add(Duration(days: _random.nextInt(30)));
    final attendeeCount = _random.nextInt(100);
    final maxAttendees = attendeeCount + _random.nextInt(50);
    
    return EventCard(
      id: 'event_$index',
      title: titles[index % titles.length],
      description: descriptions[index % descriptions.length],
      startTime: startTime,
      location: locations[index % locations.length],
      attendeeCount: attendeeCount,
      maxAttendees: maxAttendees,
      organizerId: 'org_${index % 4}',
      organizerName: organizers[index % organizers.length],
    );
  }
}

