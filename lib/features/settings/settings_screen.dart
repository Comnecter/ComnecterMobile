import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../../services/sound_service.dart';
import '../../test_crashlytics.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import 'models/app_settings.dart';
import 'services/settings_service.dart';
import '../radar/services/radar_service.dart';
import 'widgets/glowing_switch.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with TickerProviderStateMixin {
  AppSettings? settings;
  bool isLoading = true;
  late ConfettiController confettiController;
  late SoundService soundService;
  late RadarService radarService;

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    soundService = SoundService();
    radarService = RadarService();
    _loadSettings();
  }

  @override
  void dispose() {
    confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    final settingsService = SettingsService();
    final loadedSettings = await settingsService.getSettings();
    setState(() {
      settings = loadedSettings;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme mode provider
    final currentThemeMode = ref.watch(themeModeProvider);

    if (isLoading || settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentSettings = settings!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Flexible(
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Go Back',
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: const Text(
                      'Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(
                        Icons.help_outline,
                        color: AppTheme.electricAurora,
                        size: 24,
                      ),
                      onPressed: () async {
                        await soundService.playButtonClickSound();
                        _showHelpDialog(context);
                      },
                      tooltip: 'Help',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Monetization Section
              _buildSettingsCard(
                context,
                'Premium & Monetization',
                Icons.workspace_premium,
                [
                  _buildSubscriptionSection(context, soundService),
                  const SizedBox(height: 16),
                  _buildAdSettingsSection(context, soundService),
                ],
              ),
              const SizedBox(height: 20),

              // Sound Settings
              _buildSettingsCard(
                context,
                'Sound & Feedback',
                Icons.volume_up,
                [
                  _buildToggleSetting(
                    context,
                    'Sound Effects',
                    'Play sounds for interactions',
                    Icons.music_note,
                    currentSettings.soundEnabled,
                    (value) async {
                      await soundService.toggleSound();
                      final settingsService = SettingsService();
                      await settingsService.updateSoundEnabled(value);
                      final updatedSettings = await settingsService.getSettings();
                      setState(() {
                        settings = updatedSettings;
                      });
                    },
                    soundService,
                  ),
                  const SizedBox(height: 16),
                  _buildSliderSetting(
                    context,
                    'Sound Volume',
                    'Adjust sound effect volume',
                    currentSettings.soundVolume,
                    0.0,
                    1.0,
                    (value) async {
                      await soundService.setVolume(value);
                      final settingsService = SettingsService();
                      await settingsService.updateSoundVolume(value);
                      final updatedSettings = await settingsService.getSettings();
                      setState(() {
                        settings = updatedSettings;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildToggleSetting(
                    context,
                    'Haptic Feedback',
                    'Vibrate on interactions',
                    Icons.vibration,
                    currentSettings.hapticFeedbackEnabled,
                    (value) async {
                      final settingsService = SettingsService();
                      await settingsService.updateHapticFeedbackEnabled(value);
                      final updatedSettings = await settingsService.getSettings();
                      setState(() {
                        settings = updatedSettings;
                      });
                    },
                    soundService,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Privacy Settings
              _buildSettingsCard(
                context,
                'Privacy & Detection',
                Icons.privacy_tip_outlined,
                [
                  _buildPrivacySection(context),
                ],
              ),
              const SizedBox(height: 20),

              // App Settings
              _buildSettingsCard(
                context,
                'App Settings',
                Icons.app_settings_alt,
                [
                  _buildActionSetting(
                    context,
                    'Privacy',
                    'Control your privacy settings',
                    Icons.privacy_tip,
                    () async {
                      await soundService.playButtonClickSound();
                      _showPrivacyDialog(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildThemeModeSetting(
                    context,
                    'Theme Mode',
                    'Choose your preferred theme',
                    Icons.dark_mode,
                    currentThemeMode,
                    (mode) async {
                      // Update the theme mode provider
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                      
                      soundService.playToggleEffect();
                      confettiController.play();
                    },
                    soundService,
                  ),
                  const SizedBox(height: 16),
                  _buildActionSetting(
                    context,
                    'Notifications',
                    'Manage notification preferences',
                    Icons.notifications,
                    () async {
                      await soundService.playButtonClickSound();
                      _showNotificationsDialog(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionSetting(
                    context,
                    'Help & Support',
                    'Get help and contact support',
                    Icons.help,
                    () async {
                      await soundService.playButtonClickSound();
                      _showHelpDialog(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionSetting(
                    context,
                    'Privacy Policy',
                    'Read our privacy policy',
                    Icons.security,
                    () async {
                      await soundService.playButtonClickSound();
                      _showPrivacyDialog(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionSetting(
                    context,
                    'Terms of Service',
                    'Read our terms of service',
                    Icons.description,
                    () async {
                      await soundService.playButtonClickSound();
                      _showTermsDialog(context);
                    },
                  ),
                  // Debug option (only visible in debug mode)
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    _buildActionSetting(
                      context,
                      '🐛 Debug Tools',
                      'Firebase Crashlytics testing',
                      Icons.bug_report,
                      () async {
                        await soundService.playButtonClickSound();
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CrashlyticsTestScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // About Section
              _buildSettingsCard(
                context,
                'About',
                Icons.info,
                [
                  _buildActionSetting(
                    context,
                    'App Version',
                    'Version 1.0.0',
                    Icons.apps,
                    () async {
                      await soundService.playButtonClickSound();
                      _showAboutDialog(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionSetting(
                    context,
                    'Rate App',
                    'Rate us on the app store',
                    Icons.star,
                    () async {
                      await soundService.playButtonClickSound();
                      _showRateDialog(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionSetting(
                    context,
                    'Contact Support',
                    'Get help and support',
                    Icons.support_agent,
                    () async {
                      await soundService.playButtonClickSound();
                      _showSupportDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Account Section
              _buildSettingsCard(
                context,
                'Account',
                Icons.account_circle,
                [
                  _buildActionSetting(
                    context,
                    'Update Email',
                    'Change your email address',
                    Icons.email,
                    () async {
                      await soundService.playButtonClickSound();
                      _showUpdateEmailDialog(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionSetting(
                    context,
                    'Change Password',
                    'Update your password with new requirements',
                    Icons.lock_reset,
                    () async {
                      await soundService.playButtonClickSound();
                      _showChangePasswordDialog(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionSetting(
                    context,
                    'Sign Out',
                    'Sign out of your account',
                    Icons.logout,
                    () async {
                      await soundService.playButtonClickSound();
                      _showSignOutDialog(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionSetting(
                    context,
                    'Delete Account',
                    'Permanently delete your account and all data',
                    Icons.delete_forever,
                    () async {
                      await soundService.playButtonClickSound();
                      _showDeleteAccountDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ).animate().fadeIn(duration: const Duration(milliseconds: 400)).slideY(begin: 0.2, duration: const Duration(milliseconds: 400)),
          
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(BuildContext context, SoundService soundService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subscription Plans',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 12),
          _buildSubscriptionCard(
          context,
          'Free Plan',
          'Basic features',
          'Free',
          false,
          () async {
            await soundService.playButtonClickSound();
              if (!mounted) return;
              if (context.mounted) context.push('/subscription');
          },
        ),
        const SizedBox(height: 8),
          _buildSubscriptionCard(
          context,
          'Premium Plan',
          'Ad-free experience + advanced features',
          '\$9.99/month',
          true,
          () async {
            await soundService.playButtonClickSound();
              if (!mounted) return;
              if (context.mounted) context.push('/subscription');
          },
        ),
        const SizedBox(height: 8),
          _buildSubscriptionCard(
          context,
          'Pro Plan',
          'Everything + priority support',
          '\$19.99/month',
          false,
          () async {
            await soundService.playButtonClickSound();
              if (!mounted) return;
              if (context.mounted) context.push('/subscription');
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    String title,
    String description,
    String price,
    bool isRecommended,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: isRecommended ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended 
            ? BorderSide(color: AppTheme.electricAurora, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isRecommended ? [
            BoxShadow(
                              color: AppTheme.electricAurora.withValues(alpha: 0.4),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
                              color: AppTheme.purpleAurora.withValues(alpha: 0.3),
              blurRadius: 25,
              spreadRadius: 1,
              offset: const Offset(0, 12),
            ),
          ] : [
            BoxShadow(
                              color: AppTheme.electricAurora.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppTheme.auroraGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.electricAurora.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isRecommended ? AppTheme.electricAurora : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdSettingsSection(BuildContext context, SoundService soundService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advertisement Settings',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 12),
        _buildToggleSetting(
          context,
          'Show Ads',
          'Display advertisements in the app',
          Icons.ad_units,
          true, // Default to showing ads
          (value) async {
            await soundService.playButtonClickSound();
            _showAdSettingsDialog(context, value);
          },
          soundService,
        ),
        const SizedBox(height: 16),
        _buildActionSetting(
          context,
          'Ad Preferences',
          'Customize ad experience',
          Icons.tune,
          () async {
            await soundService.playButtonClickSound();
            _showAdPreferencesDialog(context);
          },
        ),
      ],
    );
  }

  Widget _buildThemeModeSetting(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    AppThemeMode currentMode,
    Function(AppThemeMode) onChanged,
    SoundService soundService,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child:                   _buildThemeModeOption(
                    context,
                    'Light',
                    Icons.light_mode,
                    AppThemeMode.light,
                    currentMode,
                    onChanged,
                  ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:                   _buildThemeModeOption(
                    context,
                    'System',
                    Icons.brightness_auto,
                    AppThemeMode.system,
                    currentMode,
                    onChanged,
                  ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:                   _buildThemeModeOption(
                    context,
                    'Dark',
                    Icons.brightness_auto,
                    AppThemeMode.dark,
                    currentMode,
                    onChanged,
                  ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context,
    String label,
    IconData icon,
    AppThemeMode mode,
    AppThemeMode currentMode,
    Function(AppThemeMode) onChanged,
  ) {
    final isSelected = currentMode == mode;
    return InkWell(
      onTap: () => onChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
    SoundService soundService,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              soundService.playToggleEffect();
              onChanged(newValue);
            },
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(
    BuildContext context,
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
            inactiveColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400)).slideY(begin: 0.2, duration: const Duration(milliseconds: 400));
  }

  // Removed legacy subscription dialog; navigation to '/subscription' is handled directly from cards.

  void _showAdSettingsDialog(BuildContext context, bool showAds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ad Settings'),
        content: Text('Ads are currently ${showAds ? 'enabled' : 'disabled'}. This feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAdPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ad Preferences'),
        content: const Text('Customize your ad experience. This feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    final notificationService = NotificationService();
    final currentSettings = notificationService.settings;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.notifications, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Notification Settings'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNotificationToggle(
                    'Enable Notifications',
                    'Turn all notifications on/off',
                    currentSettings.enabled,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(enabled: value));
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationToggle(
                    'Sound Effects',
                    'Play sound for notifications',
                    currentSettings.soundEnabled,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(soundEnabled: value));
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationToggle(
                    'Vibration',
                    'Vibrate for notifications',
                    currentSettings.vibrationEnabled,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(vibrationEnabled: value));
                      });
                    },
                  ),
                  const Divider(height: 32),
                  _buildNotificationToggle(
                    'Friend Requests',
                    'Notify when someone sends a friend request',
                    currentSettings.friendRequests,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(friendRequests: value));
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationToggle(
                    'Messages',
                    'Notify when you receive messages',
                    currentSettings.messages,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(messages: value));
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationToggle(
                    'Radar Detections',
                    'Notify when users are detected nearby',
                    currentSettings.radarDetections,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(radarDetections: value));
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationToggle(
                    'System Updates',
                    'Notify about app updates and news',
                    currentSettings.systemUpdates,
                    (value) {
                      setState(() {
                        notificationService.updateSettings(currentSettings.copyWith(systemUpdates: value));
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  soundService.playButtonClickSound();
                  notificationService.sendSystemNotification(
                    'Test Notification',
                    'This is a test notification to verify your settings!',
                  );
                },
                child: const Text('Test Notification'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primary,
        ),
      ],
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Effective Date: January 2025',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Comnecter, a mobile application designed to help you connect with people nearby using radar technology.',
              ),
              const SizedBox(height: 8),
              const Text(
                'This Privacy Policy explains how we collect, use, and protect your information when you use our app.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Points:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• We collect location data for radar functionality'),
              const Text('• Your data is encrypted and secure'),
              const Text('• Location data is automatically deleted after 30 days'),
              const Text('• You control what information you share'),
              const SizedBox(height: 16),
              const Text(
                'For the complete privacy policy, please visit our website or contact us.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open full privacy policy (web or full screen)
            },
            child: const Text('View Full Policy'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Effective Date: January 2025',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'By downloading, installing, or using the Comnecter mobile application, you agree to be bound by these Terms of Service.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Terms:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• You must be at least 13 years old'),
              const Text('• Use the app respectfully and safely'),
              const Text('• Report inappropriate behavior'),
              const Text('• We may terminate accounts for violations'),
              const SizedBox(height: 16),
              const Text(
                'For the complete terms of service, please visit our website or contact us.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open full terms of service (web or full screen)
            },
            child: const Text('View Full Terms'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Comnecter'),
        content: const Text('Version 1.0.0\n\nA social discovery app for connecting with people nearby.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Comnecter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              size: 48,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Enjoying Comnecter?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your rating helps us improve and reach more users who want to connect with people nearby.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) => Icon(
                Icons.star,
                color: index < 4 ? AppTheme.accent : Colors.grey,
                size: 32,
              )),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open app store rating page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App store rating feature coming soon!'),
                  backgroundColor: AppTheme.info,
                ),
              );
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.support_agent,
              size: 48,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Need Help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'re here to help you get the most out of Comnecter.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Contact us:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('📧 support@comnecter.com'),
            const Text('🌐 [Your Website]/support'),
            const Text('📱 In-app chat (coming soon)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open support email or website
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support contact feature coming soon!'),
                  backgroundColor: AppTheme.info,
                ),
              );
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help'),
        content: const Text('Need help? Contact our support team. This feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Use the auth service from the provider
                final authService = ref.read(authServiceProvider);
                
                // Show loading indicator
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signing out...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                
                // Perform sign out
                await authService.signOut();
                

                
                // Force a complete app rebuild to show sign-in screen
                if (context.mounted) {
                  // The app will automatically rebuild and show sign-in screen
                  // due to the auth state change in the provider
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your current password and choose a new one that meets our security requirements.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Current Password
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter your current password',
                    prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          obscureCurrentPassword = !obscureCurrentPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // New Password
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter your new password',
                    prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                // Password Requirements
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password Requirements:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRequirementItem(
                        'At least 8 characters long',
                        newPasswordController.text.length >= 8,
                        theme,
                      ),
                      _buildRequirementItem(
                        'Include uppercase and lowercase letters',
                        RegExp(r'(?=.*[a-z])(?=.*[A-Z])').hasMatch(newPasswordController.text),
                        theme,
                      ),
                      _buildRequirementItem(
                        'Include at least one number',
                        RegExp(r'(?=.*\d)').hasMatch(newPasswordController.text),
                        theme,
                      ),
                      _buildRequirementItem(
                        'Include at least one special character (!@#\$%^&*)',
                        RegExp(r'(?=.*[!@#\$%^&*])').hasMatch(newPasswordController.text),
                        theme,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Confirm New Password
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    hintText: 'Confirm your new password',
                    prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate current password
                if (currentPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter your current password'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                // Validate new password
                final newPassword = newPasswordController.text;
                if (newPassword.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('New password must be at least 8 characters long'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*])').hasMatch(newPassword)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('New password must meet all requirements'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                // Validate password confirmation
                if (newPassword != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('New passwords do not match'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  // TODO: Implement actual password change logic
                  // This would require re-authentication and then password update
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Password change feature coming soon!'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error changing password: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isMet 
                  ? theme.colorScheme.onSurface 
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateEmailDialog(BuildContext context) {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isUpdating = false;
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while updating
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.email,
                color: AppTheme.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'Update Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your new email address and current password to update your account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Current Email Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current: ${ref.read(authServiceProvider).currentUser?.email ?? 'Unknown'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // New Email
                TextFormField(
                  controller: newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isUpdating,
                  decoration: InputDecoration(
                    labelText: 'New Email Address',
                    hintText: 'Enter your new email address',
                    prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new email address';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Current Password
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  enabled: !isUpdating,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter your current password',
                    prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Warning message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will need to verify your new email address before it becomes active.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (isUpdating) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Updating email...',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                // Validate new email
                final newEmail = newEmailController.text.trim();
                if (newEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a new email address'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid email address'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                // Check if email is different from current
                final currentEmail = ref.read(authServiceProvider).currentUser?.email;
                if (newEmail == currentEmail) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('New email must be different from current email'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                // Validate password
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter your current password'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  isUpdating = true;
                });
                
                try {
                  final authService = ref.read(authServiceProvider);
                  
                  // Re-authenticate user
                  final credential = EmailAuthProvider.credential(
                    email: currentEmail!,
                    password: passwordController.text,
                  );
                  
                  await authService.currentUser?.reauthenticateWithCredential(credential);
                  
                  // Update email
                  await authService.currentUser?.verifyBeforeUpdateEmail(newEmail);
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Verification email sent to your new address'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    setState(() {
                      isUpdating = false;
                    });
                    String errorMessage = 'Failed to update email';
                    
                    if (e is FirebaseAuthException) {
                      switch (e.code) {
                        case 'wrong-password':
                          errorMessage = 'Incorrect password';
                          break;
                        case 'invalid-email':
                          errorMessage = 'Invalid email address';
                          break;
                        case 'email-already-in-use':
                          errorMessage = 'Email is already in use';
                          break;
                        case 'requires-recent-login':
                          errorMessage = 'Please sign out and sign in again, then try updating your email';
                          break;
                        default:
                          errorMessage = e.message ?? 'Failed to update email';
                      }
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ $errorMessage'),
                        backgroundColor: theme.colorScheme.error,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Update Email'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final theme = Theme.of(context);
    bool isDeleting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while deleting
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'To confirm deletion, please enter your password:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                enabled: !isDeleting,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will permanently remove your account, profile, and all associated data.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDeleting) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Deleting account...',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter your password'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  isDeleting = true;
                });
                
                try {
                  final authService = ref.read(authServiceProvider);
                  final result = await authService.deleteAccountEnhanced(passwordController.text);
                  
                  if (result.isSuccess) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('✅ Account deleted successfully'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      
                      // The app will automatically navigate to sign-in screen
                      // due to the auth state change in the provider
                    }
                  } else {
                    if (context.mounted) {
                      setState(() {
                        isDeleting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ ${result.errorMessage ?? 'Failed to delete account'}'),
                          backgroundColor: theme.colorScheme.error,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    setState(() {
                      isDeleting = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: theme.colorScheme.error,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return Column(
      children: [
        // Radar Visibility Toggle with Glowing Switch
        _buildGlowingToggleSetting(
          context,
          'Radar Visibility',
          'Show on radar and detect other users',
          Icons.visibility,
          radarService.getDetectabilityStatus(),
          (value) {
            radarService.toggleRadarVisibility(value);
            setState(() {}); // Refresh UI
          },
          soundService,
        ),
        const SizedBox(height: 16),
        
        // Privacy Information
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'When radar visibility is off, you cannot detect other users and they cannot detect you. Radar range can be adjusted on the radar screen.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlowingToggleSetting(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    SoundService soundService,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Glowing Switch
          GlowingSwitch(
            value: value,
            onChanged: (newValue) async {
              await soundService.playButtonClickSound();
              onChanged(newValue);
            },
            activeColor: Colors.green,
            inactiveColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
} 