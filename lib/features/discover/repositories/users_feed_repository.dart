import 'dart:async';
import 'dart:math';
import '../models/feed_item.dart';

/// Repository for fetching users-only feed data
/// 
/// ⚠️ WARNING: This repository contains MOCK DATA for development only!
/// 
/// TODO: Replace all mock data generation with real API/Firebase calls:
/// - fetchInitial() should call real backend API
/// - fetchNext() should call real backend API with pagination
/// - Remove all _generateMock*() methods
/// - Connect to actual data sources (Firebase, REST API, GraphQL, etc.)
class UsersFeedRepository {
  static final UsersFeedRepository _instance = UsersFeedRepository._internal();
  factory UsersFeedRepository() => _instance;
  UsersFeedRepository._internal();

  final Random _random = Random();
  int _currentPage = 0;
  
  /// Fetch initial users
  Future<FeedResponse> fetchInitial({
    required double lat,
    required double lng,
    required double radiusMeters,
    bool hideBoosted = false,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    _currentPage = 0;
    final items = _generateMockUsers(
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

  /// Fetch next page of users
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
    
    final items = _generateMockUsers(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      count: 8,
      hideBoosted: hideBoosted,
    );
    
    final hasMore = _currentPage < 4;
    
    return FeedResponse(
      items: items,
      cursor: hasMore ? 'page_${_currentPage + 1}' : null,
      hasMore: hasMore,
    );
  }

  /// ⚠️ MOCK DATA GENERATOR - FOR DEVELOPMENT ONLY ⚠️
  /// 
  /// This method generates fake data for testing and development.
  /// TODO: REMOVE THIS METHOD and replace with real API calls in production
  /// 
  /// Generate mock users for development
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
        id: 'user_${_currentPage}_$i',
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

  /// ⚠️ MOCK DATA - REMOVE IN PRODUCTION ⚠️
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

  /// Reset pagination
  void reset() {
    _currentPage = 0;
  }
}

