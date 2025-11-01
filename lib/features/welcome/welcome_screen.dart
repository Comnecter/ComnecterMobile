import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../theme/app_theme.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  
  @override
  void initState() {
    super.initState();
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Start confetti after a delay
    Future.delayed(const Duration(milliseconds: 800), () {
      _confettiController.play();
    });
    
    // Navigate to auth screen after animations complete
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _navigateToAuth();
      }
    });
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0A1A),
                    const Color(0xFF1A0A2E),
                    const Color(0xFF16213E),
                  ]
                : [
                    const Color(0xFFE8F4F8),
                    const Color(0xFFF0E6FF),
                    Colors.white,
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            ...List.generate(20, (index) => _buildParticle(context, index)),
            
            // Rotating gradient orbs
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * pi,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.electricAurora.withValues(alpha: 0.2),
                            AppTheme.purpleAurora.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            Positioned(
              bottom: -150,
              left: -150,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_rotationController.value * 2 * pi,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.purpleAurora.withValues(alpha: 0.15),
                            AppTheme.electricAurora.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing app icon/logo
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (sin(_pulseController.value * 2 * pi) * 0.1);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: AppTheme.auroraGradient,
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.electricAurora.withValues(alpha: 0.4 * (0.5 + sin(_glowController.value * 2 * pi) * 0.5)),
                                blurRadius: 30 + (sin(_glowController.value * 2 * pi) * 10),
                                spreadRadius: 5 + (sin(_glowController.value * 2 * pi) * 3),
                              ),
                              BoxShadow(
                                color: AppTheme.purpleAurora.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.people,
                            color: Colors.white,
                            size: 70,
                          ),
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                      .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
                  
                  const SizedBox(height: 40),
                  
                  // "Comnecter" text with animated gradient
                  ShaderMask(
                    shaderCallback: (bounds) => AppTheme.auroraGradient.createShader(bounds),
                    child: const Text(
                      'Comnecter',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 800.ms)
                      .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 800.ms, curve: Curves.easeOutCubic),
                  
                  const SizedBox(height: 16),
                  
                  // Slogan with typewriter effect
                  Text(
                    'Let us connect',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      letterSpacing: 3,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeIn(delay: 800.ms, duration: 600.ms)
                      .then()
                      .shimmer(delay: 1200.ms, duration: 2000.ms, color: AppTheme.electricAurora.withValues(alpha: 0.3))
                      .then()
                      .shake(delay: 3000.ms, hz: 4, curve: Curves.easeInOut)
                      .then()
                      .fadeOut(),
                  
                  const SizedBox(height: 60),
                  
                  // Loading indicator with aurora colors
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.electricAurora),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1500.ms, duration: 500.ms)
                      .then()
                      .scale(delay: 1500.ms, duration: 500.ms),
                ],
              ),
            ),
            
            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 8,
                minBlastForce: 3,
                emissionFrequency: 0.03,
                numberOfParticles: 80,
                gravity: 0.2,
                colors: const [
                  AppTheme.electricAurora,
                  AppTheme.purpleAurora,
                  Colors.blue,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticle(BuildContext context, int index) {
    final random = Random(index);
    final size = MediaQuery.of(context).size;
    final delay = random.nextDouble() * 2;
    final duration = 3 + random.nextDouble() * 2;
    final startX = random.nextDouble() * size.width;
    final startY = random.nextDouble() * size.height;
    
    return Positioned(
      left: startX,
      top: startY,
      child: Container(
        width: 4 + random.nextDouble() * 4,
        height: 4 + random.nextDouble() * 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (index % 2 == 0 ? AppTheme.electricAurora : AppTheme.purpleAurora)
              .withValues(alpha: 0.3 + random.nextDouble() * 0.3),
        ),
      )
          .animate(onPlay: (controller) => controller.repeat())
          .fadeIn(delay: (delay * 1000).toInt().ms, duration: 500.ms)
          .then()
          .move(
            delay: (delay * 1000).toInt().ms,
            duration: (duration * 1000).toInt().ms,
            begin: Offset(startX, startY),
            end: Offset(
              startX + (random.nextDouble() - 0.5) * 200,
              startY + (random.nextDouble() - 0.5) * 200,
            ),
            curve: Curves.easeInOut,
          )
          .then()
          .fadeOut(duration: 500.ms)
          .then(),
    );
  }
}

// Authentication selection screen (shows Sign Up and Sign In options)
class AuthSelectionScreen extends StatelessWidget {
  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0A1A),
                    const Color(0xFF1A0A2E),
                    const Color(0xFF16213E),
                  ]
                : [
                    const Color(0xFFE8F4F8),
                    const Color(0xFFF0E6FF),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppTheme.auroraGradient,
                      borderRadius: BorderRadius.circular(25),
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
                      size: 50,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    'Welcome to Comnecter',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 600.ms),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Connect with people nearby',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms),
                  
                  const SizedBox(height: 60),
                  
                  // Sign Up button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: AppTheme.electricAurora.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 500.ms)
                      .slideY(begin: 0.3, end: 0, delay: 600.ms, duration: 500.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignInScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 500.ms)
                      .slideY(begin: 0.3, end: 0, delay: 800.ms, duration: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
