import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'models/feed_item.dart';
import 'providers/all_feed_provider.dart';
import 'widgets/feed_card_widgets.dart';
import '../subscription/services/subscription_service.dart';
import '../subscription/models/subscription_model.dart';
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';
import '../../services/saved_items_service.dart';

/// Discover All Feed Screen with TikTok-style vertical scrolling
class AllFeedScreen extends ConsumerStatefulWidget {
  const AllFeedScreen({super.key});

  @override
  ConsumerState<AllFeedScreen> createState() => _AllFeedScreenState();
}

class _AllFeedScreenState extends ConsumerState<AllFeedScreen> {
  late PageController _pageController;
  final _subscriptionService = SubscriptionService();
  final _savedItemsService = SavedItemsService();
  int _currentPage = 0;
  
  // User's actual location (obtained from GPS)
  double _userLat = 0.0;
  double _userLng = 0.0;
  static const double _defaultRadius = 5000.0; // 5km in meters

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _subscriptionService.initialize();
    _savedItemsService.initialize();
    _getUserLocation();
    
    // Listen to page changes for loading more
    _pageController.addListener(_onPageChanged);
  }

  Future<void> _getUserLocation() async {
    try {
      // Get user's actual location from GPS
      // This will be populated by the app's location service
      // For now, we'll use a default that can be overridden
      _userLat = 0.0;
      _userLng = 0.0;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      _currentPage = page;
      
      // Load more when approaching the end
      final feedState = ref.read(_feedProvider.notifier);
      final state = ref.read(_feedProvider);
      
      if (page >= state.filteredItems.length - 2 && 
          state.hasMore && 
          !state.isLoadingMore) {
        feedState.loadMore();
      }
      
      // Track analytics
      _trackFeedScroll(page, state.filteredItems.length);
    }
  }

  AutoDisposeStateNotifierProvider<AllFeedController, AllFeedState> get _feedProvider {
    return allFeedControllerProvider(FeedParams(
      lat: _userLat,
      lng: _userLng,
      radiusMeters: _defaultRadius,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(_feedProvider);
    final isPremium = _subscriptionService.currentSubscription?.plan != SubscriptionPlan.free;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        elevation: 0,
        actions: [
          // Hide Boosted toggle (premium feature)
          _buildHideBoostedToggle(context, isPremium, feedState.hideBoosted),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: feedState.isLoading
            ? _buildLoadingState(context)
            : feedState.hasError
                ? _buildErrorState(context, feedState.error!)
                : feedState.isEmpty
                    ? _buildEmptyState(context)
                    : _buildFeedContent(context, feedState),
      ),
    );
  }

  /// Build hide boosted toggle
  Widget _buildHideBoostedToggle(BuildContext context, bool isPremium, bool hideBoosted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Text(
            'Hide Boosted',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isPremium 
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onHideBoostedTapped(isPremium, hideBoosted),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isPremium
                    ? (hideBoosted 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.surfaceContainerHighest)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 24,
                alignment: hideBoosted ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isPremium && hideBoosted
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          if (!isPremium)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.lock,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// Handle hide boosted toggle tap
  void _onHideBoostedTapped(bool isPremium, bool currentValue) {
    if (!isPremium) {
      // Show paywall for non-premium users
      _showPremiumPaywall(context);
      _trackPremiumToggle(false);
    } else {
      // Toggle for premium users
      ref.read(_feedProvider.notifier).toggleHideBoosted(!currentValue);
      SoundService().playButtonClickSound();
      _trackPremiumToggle(true);
    }
  }

  /// Build feed content with PageView
  Widget _buildFeedContent(BuildContext context, AllFeedState feedState) {
    final items = feedState.filteredItems;
    
    return RefreshIndicator(
      onRefresh: () async {
        SoundService().playSwipeSound();
        await ref.read(_feedProvider.notifier).refresh();
      },
      child: PageStorage(
        bucket: PageStorageBucket(),
        child: PageView.builder(
          key: const PageStorageKey('discover-all'),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: items.length + (feedState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the end
            if (index >= items.length) {
              return _buildLoadingCard(context);
            }
            
            final item = items[index];
            return _buildFeedCard(context, item);
          },
        ),
      ),
    );
  }

  /// Build individual feed card based on type
  Widget _buildFeedCard(BuildContext context, FeedItem item) {
    switch (item.type) {
      case FeedItemType.user:
        final user = item.payload as UserCard;
        return UserFeedCard(
          user: user,
          distance: item.distance,
          isBoosted: item.isBoosted,
          isSaved: _savedItemsService.isUserSaved(user.id),
          onTap: () => _onUserCardTapped(item.id, user),
          onConnect: () => _onConnectUser(user),
          onSave: () => _onSaveUser(user),
        );
        
      case FeedItemType.community:
        final community = item.payload as CommunityCard;
        return CommunityFeedCard(
          community: community,
          distance: item.distance,
          isBoosted: item.isBoosted,
          isSaved: _savedItemsService.isCommunitySaved(community.id),
          onTap: () => _onCommunityCardTapped(item.id, community),
          onJoin: () => _onJoinCommunity(community),
          onSave: () => _onSaveCommunity(community),
        );
        
      case FeedItemType.event:
        final event = item.payload as EventCard;
        return EventFeedCard(
          event: event,
          distance: item.distance,
          isBoosted: item.isBoosted,
          isSaved: _savedItemsService.isEventSaved(event.id),
          onTap: () => _onEventCardTapped(item.id, event),
          onRSVP: () => _onRSVPEvent(event),
          onSave: () => _onSaveEvent(event),
        );
    }
  }

  /// Build loading state
  Widget _buildLoadingState(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 3,
      itemBuilder: (context, index) => _buildShimmerCard(context),
    );
  }

  /// Build shimmer loading card
  Widget _buildShimmerCard(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  /// Build loading card for pagination
  Widget _buildLoadingCard(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(_feedProvider.notifier).refresh();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing detected nearby',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search radius or check back later',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(_feedProvider.notifier).refresh();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show premium paywall
  void _showPremiumPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            Icon(
              Icons.workspace_premium,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Premium Feature',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Hide boosted content and enjoy an ad-free experience with Premium',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/subscription');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Card action handlers
  void _onUserCardTapped(String itemId, UserCard user) {
    _trackBoostedImpression(itemId, 'user');
    SoundService().playTapSound();
    // Navigate to user profile
    context.push('/user/${user.id}');
  }

  void _onConnectUser(UserCard user) {
    SoundService().playSuccessSound();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connection request sent to ${user.name}')),
    );
  }

  void _onSaveUser(UserCard user) async {
    final wasSaved = await _savedItemsService.toggleSaveUser(
      user.id,
      user.name,
      user.avatar,
      bio: user.bio,
    );
    SoundService().playTapSound();
    setState(() {}); // Rebuild to update bookmark icon
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasSaved ? 'Removed ${user.name} from saved' : 'Saved ${user.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onSaveCommunity(CommunityCard community) async {
    final wasSaved = await _savedItemsService.toggleSaveCommunity(
      community.id,
      community.name,
      community.avatar,
      description: community.description,
      memberCount: community.memberCount,
    );
    SoundService().playTapSound();
    setState(() {}); // Rebuild to update bookmark icon
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasSaved ? 'Removed ${community.name} from saved' : 'Saved ${community.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onSaveEvent(EventCard event) async {
    final wasSaved = await _savedItemsService.toggleSaveEvent(
      event.id,
      event.title,
      description: event.description,
      startTime: event.startTime,
      location: event.location,
    );
    SoundService().playTapSound();
    setState(() {}); // Rebuild to update bookmark icon
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasSaved ? 'Removed ${event.title} from saved' : 'Saved ${event.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onCommunityCardTapped(String itemId, CommunityCard community) {
    _trackBoostedImpression(itemId, 'community');
    SoundService().playTapSound();
    // Navigate to community detail
    context.push('/community/${community.id}');
  }

  void _onJoinCommunity(CommunityCard community) {
    SoundService().playSuccessSound();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joined ${community.name}!')),
    );
  }

  void _onEventCardTapped(String itemId, EventCard event) {
    _trackBoostedImpression(itemId, 'event');
    SoundService().playTapSound();
    // Navigate to event detail
    context.push('/event/${event.id}');
  }

  void _onRSVPEvent(EventCard event) {
    SoundService().playSuccessSound();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('RSVP confirmed for ${event.title}!')),
    );
  }

  // Analytics tracking
  void _trackFeedScroll(int page, int totalItems) {
    try {
      FirebaseService.instance.analytics.logEvent(
        name: 'feed_scroll',
        parameters: {
          'page': page,
          'total_items': totalItems,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Analytics not initialized or failed - ignore
    }
  }

  void _trackBoostedImpression(String itemId, String type) {
    try {
      FirebaseService.instance.analytics.logEvent(
        name: 'boosted_impression',
        parameters: {
          'item_id': itemId,
          'item_type': type,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Analytics not initialized or failed - ignore
    }
  }

  void _trackPremiumToggle(bool isPremium) {
    try {
      FirebaseService.instance.analytics.logEvent(
        name: 'premium_toggle',
        parameters: {
          'is_premium': isPremium,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Analytics not initialized or failed - ignore
    }
  }
}

