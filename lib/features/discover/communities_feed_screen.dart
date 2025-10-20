import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'models/feed_item.dart';
import 'providers/communities_feed_provider.dart';
import 'widgets/feed_card_widgets.dart';
import '../subscription/services/subscription_service.dart';
import '../subscription/models/subscription_model.dart';
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';

/// Communities-Only Feed Screen with TikTok-style vertical scrolling
class CommunitiesFeedScreen extends ConsumerStatefulWidget {
  const CommunitiesFeedScreen({super.key});

  @override
  ConsumerState<CommunitiesFeedScreen> createState() => _CommunitiesFeedScreenState();
}

class _CommunitiesFeedScreenState extends ConsumerState<CommunitiesFeedScreen> {
  late PageController _pageController;
  final _subscriptionService = SubscriptionService();
  int _currentPage = 0;
  
  // User's actual location (obtained from GPS)
  double _userLat = 0.0;
  double _userLng = 0.0;
  static const double _defaultRadius = 10000.0; // 10km in meters

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _subscriptionService.initialize();
    _getUserLocation();
    
    // Listen to page changes for loading more
    _pageController.addListener(_onPageChanged);
  }

  Future<void> _getUserLocation() async {
    try {
      // Get user's actual location from GPS
      // This will be populated by the app's location service
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
      _trackCommunityView(page, state.filteredItems.length);
    }
  }

  AutoDisposeStateNotifierProvider<CommunitiesFeedController, CommunitiesFeedState> get _feedProvider {
    return communitiesFeedControllerProvider(CommunitiesFeedParams(
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
          'Communities Nearby',
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
  Widget _buildFeedContent(BuildContext context, CommunitiesFeedState feedState) {
    final items = feedState.filteredItems;
    
    return RefreshIndicator(
      onRefresh: () async {
        SoundService().playSwipeSound();
        await ref.read(_feedProvider.notifier).refresh();
      },
      child: PageStorage(
        bucket: PageStorageBucket(),
        child: PageView.builder(
          key: const PageStorageKey('discover-communities'),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: items.length + (feedState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the end
            if (index >= items.length) {
              return _buildLoadingCard(context);
            }
            
            final item = items[index];
            final community = item.payload as CommunityCard;
            
            return CommunityFeedCard(
              community: community,
              distance: item.distance,
              isBoosted: item.isBoosted,
              onTap: () => _onCommunityCardTapped(item.id, community),
              onJoin: () => _onJoinCommunity(community),
            );
          },
        ),
      ),
    );
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
              Icons.groups_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No communities nearby',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to create a community in your area!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to create community screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Create community feature coming soon!')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Community'),
            ),
            const SizedBox(height: 12),
            TextButton(
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
              'Hide boosted content and discover communities organically with Premium',
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
  void _onCommunityCardTapped(String itemId, CommunityCard community) {
    _trackCommunityView(_currentPage, ref.read(_feedProvider).filteredItems.length);
    SoundService().playTapSound();
    // Navigate to community detail
    context.push('/community/${community.id}');
  }

  void _onJoinCommunity(CommunityCard community) {
    SoundService().playSuccessSound();
    _trackCommunityJoinTap(community.id);
    
    final action = community.isJoined ? 'left' : 'joined';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You ${action} ${community.name}!')),
    );
  }

  // Analytics tracking
  void _trackCommunityView(int page, int totalItems) {
    try {
      FirebaseService.instance.analytics.logEvent(
        name: 'communities_tab_view',
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

  void _trackCommunityJoinTap(String communityId) {
    try {
      FirebaseService.instance.analytics.logEvent(
        name: 'community_join_tap',
        parameters: {
          'community_id': communityId,
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
          'screen': 'communities_feed',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Analytics not initialized or failed - ignore
    }
  }
}

