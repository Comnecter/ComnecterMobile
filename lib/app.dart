import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routing/app_router.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

import 'services/sound_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/welcome/welcome_screen.dart';

class ComnecterApp extends ConsumerStatefulWidget {
  const ComnecterApp({super.key});

  @override
  ConsumerState<ComnecterApp> createState() => _ComnecterAppState();
}

class _ComnecterAppState extends ConsumerState<ComnecterApp> with TickerProviderStateMixin {
  AnimationController? _splashController;
  Animation<double>? _splashAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize sound service
      await SoundService().initialize();
      
      // Initialize notification service
      await NotificationService().initialize();
      

      
      // Initialize splash animation
      _splashController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      );
      
      _splashAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _splashController!,
        curve: Curves.easeInOut,
      ));
      
      // Start splash animation
      await _splashController!.forward();
      
      // Play startup sound
      await SoundService().playSuccessSound();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // If initialization fails, still show the app
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _splashController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme data provider for changes
    final themeData = ref.watch(themeDataProvider);
    final authState = ref.watch(authStateProvider);
    
    if (!_isInitialized) {
      return MaterialApp(
        home: _buildSplashScreen(themeData),
        theme: themeData,
      );
    }

    // Check Firebase Auth state
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // If no user is signed in, show welcome screen
    // if (currentUser == null) {
    //   return MaterialApp(
    //     title: 'Comnecter',
    //     theme: themeData,
    //     home: const WelcomeScreen(),
    //     debugShowCheckedModeBanner: false,
    //   );
    // }
    
    // If user is signed in, show the main app
    return MaterialApp.router(
      title: 'Comnecter',
      theme: themeData,
      routerConfig: createRouter(),
      debugShowCheckedModeBanner: false,
    );
  }



  Widget _buildSplashScreen(ThemeData themeData) {
    final isDarkMode = themeData.brightness == Brightness.dark;
    return Scaffold(
              backgroundColor: themeData.colorScheme.surface,
      body: Center(
        child: _splashAnimation != null
            ? FadeTransition(
                opacity: _splashAnimation!,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo with aurora gradient
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: AppTheme.auroraGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricAurora.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Comnecter',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect with people nearby',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}