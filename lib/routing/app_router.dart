import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../features/auth/two_factor_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/discover/all_feed_screen.dart';
import '../features/discover/users_feed_screen.dart';
import '../features/discover/communities_feed_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/community/community_screen.dart';
import '../features/event/event_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/auth/sign_up_wizard_screen.dart';
import '../features/subscription/subscription_screen.dart';
import '../features/feedback/feedback_screen.dart';


final rootNavigatorKey = GlobalKey<NavigatorState>();
GoRouter createRouter([WidgetRef? ref]) {
  
  return GoRouter(
    initialLocation: '/signin',
    navigatorKey: rootNavigatorKey,
    errorBuilder: (context, state) => const SignInScreen(), // Fallback to signin if route not found
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges()
    ),
    redirect: (context, state) {
      // Check Firebase Auth state
      try {
        final user = FirebaseAuth.instance.currentUser;
        
        final isAuthRoute = state.matchedLocation == '/signin' || 
                            state.matchedLocation == '/signup' ||
                            state.matchedLocation.contains('two-factor');
        
        if (kDebugMode) {
          print('🔍 Router redirect check - Location: ${state.matchedLocation}, Firebase User: ${user?.email ?? 'null'}, IsAuthRoute: $isAuthRoute');
        }
        
        // If user is not signed in and trying to access protected route
        if (user == null && !isAuthRoute) {
          if (kDebugMode) {
            print('🚪 Redirecting to signin - User not authenticated');
          }
          return '/signin';
        }
        
        // If user is signed in and trying to access auth route
        if (user != null && isAuthRoute && !state.matchedLocation.contains('two-factor')) {
          if (kDebugMode) {
            print('🏠 Redirecting to home - User already authenticated');
          }
          return '/'; // !!!!!!!!!!!
        }
        
        if (kDebugMode) {
          print('✅ No redirect needed');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Auth check failed, redirecting to signin: $e');
        }
        // If auth check fails, redirect to signin
        if (state.matchedLocation != '/signin') {
          return '/signin';
        }
      }
      
      return null;
    },
    routes: [
      // Authentication routes
      GoRoute(
        path: '/signin',
        name: 'signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpWizardScreen(),
      ),
      GoRoute(
        path: '/two-factor',
        name: 'two-factor',
        builder: (context, state) {
          final params = state.extra as Map<String, dynamic>?;
          return TwoFactorScreen(
            email: params?['email'] ?? '',
            firstName: params?['firstName'] ?? '',
            lastName: params?['lastName'] ?? '',
            username: params?['username'],
          );
        },
      ),
      
      // Protected routes
      ShellRoute(
        builder: (context, state, child) => RootNavigation(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'discover',
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/community',
            name: 'community',
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/event',
            name: 'event',
            builder: (context, state) => const EventScreen(),
          ),
          GoRoute(
            path: '/friends',
            name: 'friends',
            builder: (context, state) => const FriendsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/discover/all',
            name: 'discover-all',
            builder: (context, state) => const AllFeedScreen(),
          ),
          GoRoute(
            path: '/discover/users',
            name: 'discover-users',
            builder: (context, state) => const UsersFeedScreen(),
          ),
          GoRoute(
            path: '/discover/communities',
            name: 'discover-communities',
            builder: (context, state) => const CommunitiesFeedScreen(),
          ),
          GoRoute(
            path: '/subscription',
            name: 'subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: '/feedback',
            name: 'feedback',
            builder: (context, state) => const FeedbackScreen(),
          ),
        ],
      ),
    ],
  );
}

// Stream-based refresh notifier for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  // Convert ProviderRef to WidgetRef (they're not directly compatible)
  // but we can pass null since we'll handle that case
  return createRouter();
});

class RootNavigation extends StatelessWidget {
  final Widget child;
  const RootNavigation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
    
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                // Main navigation tabs
                Expanded(
                  child: NavigationBar(
                    selectedIndex: _calculateSelectedIndex(location),
                    onDestinationSelected: (index) {
                      switch (index) {
                        case 0:
                          context.go('/');
                          break;
                        case 1:
                          context.go('/chat');
                          break;
                        case 2:
                          context.go('/profile');
                          break;
                        case 3:
                          context.go('/community');
                          break;
                        case 4:
                          context.go('/event');
                          break;
                      }
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.explore), 
                        label: 'Discover',
                        tooltip: 'Discover',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.chat_bubble), 
                        label: 'Chat',
                        tooltip: 'Chat',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person), 
                        label: 'Profile',
                        tooltip: 'Profile',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.groups), 
                        label: 'Community',
                        tooltip: 'Community',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.event), 
                        label: 'Event',
                        tooltip: 'Event',
                      ),
                    ],
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    height: 80,
                    elevation: 0,
                  ),
                ),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location.startsWith('/chat')) return 1;
    if (location.startsWith('/profile')) return 2;
    if (location.startsWith('/community')) return 3;
    if (location.startsWith('/event')) return 4;
    return 0;
  }

}
