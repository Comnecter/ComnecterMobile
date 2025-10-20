import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../radar/radar_screen.dart';
import '../radar/services/radar_service.dart';
import '../radar/services/detection_history_service.dart';
import '../radar/models/user_model.dart';
import '../friends/services/friend_service.dart';
import '../../providers/discover_view_provider.dart';
import 'widgets/map_view.dart';
import 'widgets/scroll_view.dart' as discover_widgets;

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  bool isLoading = true;
  List<NearbyUser> detectedUsers = [];
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> communities = [];
  List<Map<String, dynamic>> events = [];
  bool _isDetectable = true;
  
  late RadarService radarService;
  late DetectionHistoryService detectionHistoryService;
  late FriendService friendService;

  @override
  void initState() {
    super.initState();
    radarService = RadarService();
    detectionHistoryService = DetectionHistoryService();
    friendService = FriendService();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load saved view preference
    final savedView = await _loadSavedView();
    ref.read(discoverViewProvider.notifier).setView(savedView);
    
    setState(() {
      isLoading = false;
    });
    
    // Initialize services
    await radarService.initialize();
    radarService.startScanning();
    
    // Load data
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // State management
    final currentView = ref.watch(discoverViewProvider);

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            context.push('/settings');
          },
          icon: Icon(
            Icons.settings,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          tooltip: 'Settings',
        ),
        title: Text(
          _getViewTitle(currentView),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // View selector button
          IconButton(
            icon: Icon(
              _getViewIcon(currentView),
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            onPressed: () => _showViewSelectorModal(context),
            tooltip: 'Switch View',
          ),
          IconButton(
            onPressed: () {
              context.push('/notifications');
            },
            icon: Icon(
              Icons.notifications,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () {
              context.push('/friends');
            },
            icon: Icon(
              Icons.people,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            tooltip: 'Friends',
          ),
          // Show/Hide Radar button (only visible in radar view)
          if (currentView == DiscoverViewType.radar)
            IconButton(
              onPressed: () => _toggleRadarVisibility(),
              icon: Icon(
                _isDetectable ? Icons.visibility : Icons.visibility_off,
                color: _isDetectable ? Colors.green.shade600 : Colors.grey.shade600,
                size: 24,
              ),
              tooltip: _isDetectable ? 'Hide from Radar' : 'Show on Radar',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Content area
            Expanded(
              child: _buildContentView(context, currentView, {
                'detectedUsers': detectedUsers,
                'friends': friends,
                'communities': communities,
                'events': events,
                'radarService': radarService,
                'detectionHistoryService': detectionHistoryService,
                'friendService': friendService,
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(BuildContext context, DiscoverViewType viewType, Map<String, dynamic> data) {
    switch (viewType) {
      case DiscoverViewType.radar:
        return RadarView(
          detectedUsers: data['detectedUsers'] as List<NearbyUser>,
          radarService: data['radarService'] as RadarService,
          detectionHistoryService: data['detectionHistoryService'] as DetectionHistoryService,
          friendService: data['friendService'] as FriendService,
          isDetectable: _isDetectable,
        );
      case DiscoverViewType.map:
        return MapView(
          detectedUsers: data['detectedUsers'] as List<NearbyUser>,
          communities: data['communities'] as List<Map<String, dynamic>>,
          events: data['events'] as List<Map<String, dynamic>>,
        );
      case DiscoverViewType.scroll:
        return discover_widgets.ScrollView(
          detectedUsers: data['detectedUsers'] as List<NearbyUser>,
          friends: data['friends'] as List<Map<String, dynamic>>,
          communities: data['communities'] as List<Map<String, dynamic>>,
          events: data['events'] as List<Map<String, dynamic>>,
          friendService: data['friendService'] as FriendService,
        );
    }
  }

  Future<DiscoverViewType> _loadSavedView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedViewIndex = prefs.getInt('discover_selected_view') ?? 0;
      return DiscoverViewType.values[savedViewIndex];
    } catch (e) {
      return DiscoverViewType.radar; // Default to radar view
    }
  }

  void _toggleRadarVisibility() {
    setState(() {
      _isDetectable = !_isDetectable;
    });
    radarService.toggleRadarVisibility(_isDetectable);
  }

  Future<void> _loadData() async {
    try {
      // Initialize radar visibility state
      _isDetectable = radarService.getDetectabilityStatus();
      
      // Load friends
      final friendsList = friendService.getFriends();
      setState(() {
        friends = friendsList.map((friend) => {
          'id': friend.id,
          'name': friend.name,
          'avatar': friend.avatar,
          'isOnline': friend.isOnline,
          'status': friend.status.name,
        }).toList();
      });
      
      // TODO: Load communities from Firebase/API
      setState(() {
        communities = [];
      });
      
      // TODO: Load events from Firebase/API
      setState(() {
        events = [];
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  String _getViewTitle(DiscoverViewType viewType) {
    switch (viewType) {
      case DiscoverViewType.radar:
        return 'Radar';
      case DiscoverViewType.map:
        return 'Map';
      case DiscoverViewType.scroll:
        return 'Scroll';
    }
  }

  IconData _getViewIcon(DiscoverViewType viewType) {
    switch (viewType) {
      case DiscoverViewType.radar:
        return Icons.radar;
      case DiscoverViewType.map:
        return Icons.map;
      case DiscoverViewType.scroll:
        return Icons.list;
    }
  }

  String _getViewDescription(DiscoverViewType viewType) {
    switch (viewType) {
      case DiscoverViewType.radar:
        return 'Pulse radar detection for nearby users';
      case DiscoverViewType.map:
        return 'Real-time map with users and events';
      case DiscoverViewType.scroll:
        return 'Scrollable list of users, friends, and communities';
    }
  }

  void _showViewSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Choose View',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // View options
            ...DiscoverViewType.values.map((viewType) => 
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ref.watch(discoverViewProvider) == viewType 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getViewIcon(viewType),
                    color: ref.watch(discoverViewProvider) == viewType 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  _getViewTitle(viewType),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: ref.watch(discoverViewProvider) == viewType 
                        ? FontWeight.w600 
                        : FontWeight.normal,
                    color: ref.watch(discoverViewProvider) == viewType 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  _getViewDescription(viewType),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                trailing: ref.watch(discoverViewProvider) == viewType 
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(discoverViewProvider.notifier).setView(viewType);
                  Navigator.of(context).pop();
                },
              ),
            ).toList(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

}

// Radar View Component
class RadarView extends StatelessWidget {
  final List<NearbyUser> detectedUsers;
  final RadarService radarService;
  final DetectionHistoryService detectionHistoryService;
  final FriendService friendService;
  final bool isDetectable;

  const RadarView({
    super.key,
    required this.detectedUsers,
    required this.radarService,
    required this.detectionHistoryService,
    required this.friendService,
    required this.isDetectable,
  });

  @override
  Widget build(BuildContext context) {
    // This will be the existing radar screen content
    return RadarScreen(isDetectableParam: isDetectable);
  }
}