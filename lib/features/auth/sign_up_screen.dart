import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/sound_service.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sound_provider.dart';
import 'two_factor_screen.dart';

class _PasswordStrength {
  final String label;
  final double value;
  final Color color;
  
  _PasswordStrength(this.label, this.value, this.color);
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    
    // Add listener to password controller for live validation
    _passwordController.addListener(() {
      setState(() {}); // Rebuild to update requirement indicators
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to Comnecter!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'By using our app, you agree to:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Be respectful and kind to other users'),
              Text('• Not share inappropriate or harmful content'),
              Text('• Respect others\' privacy and personal information'),
              Text('• Use the app for its intended purpose'),
              Text('• Follow all applicable laws and regulations'),
              SizedBox(height: 8),
              Text(
                'We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of any changes.',
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
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Privacy Matters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'We collect and use your data to:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Provide and improve our services'),
              Text('• Connect you with nearby users'),
              Text('• Ensure app security and prevent abuse'),
              Text('• Send important notifications'),
              SizedBox(height: 8),
              Text(
                'We do not sell your personal information to third parties. Your data is protected using industry-standard security measures.',
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
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMet 
                  ? Theme.of(context).colorScheme.onSurface 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    final strength = _calculatePasswordStrength(password);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              strength.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: strength.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength.value,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(strength.color),
        ),
      ],
    );
  }

  _PasswordStrength _calculatePasswordStrength(String password) {
    int score = 0;
    
    if (password.length >= 8) score++;
    if (RegExp(r'(?=.*[a-z])').hasMatch(password)) score++;
    if (RegExp(r'(?=.*[A-Z])').hasMatch(password)) score++;
    if (RegExp(r'(?=.*\d)').hasMatch(password)) score++;
    if (RegExp(r'(?=.*[!@#\$%^&*])').hasMatch(password)) score++;
    
    switch (score) {
      case 0:
      case 1:
        return _PasswordStrength('Very Weak', 0.2, Colors.red);
      case 2:
        return _PasswordStrength('Weak', 0.4, Colors.orange);
      case 3:
        return _PasswordStrength('Fair', 0.6, Colors.yellow);
      case 4:
        return _PasswordStrength('Good', 0.8, Colors.lightGreen);
      case 5:
        return _PasswordStrength('Strong', 1.0, Colors.green);
      default:
        return _PasswordStrength('Very Weak', 0.2, Colors.red);
    }
  }

  void _showRetryDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Up Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage),
            const SizedBox(height: 16),
            const Text(
              'This error is usually caused by a temporary authentication system issue. Would you like to retry?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _retrySignUp();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _retrySignUp() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signUpWithEmailAndPasswordEnhanced(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );

      if (result.isSuccess) {
        await ref.read(soundServiceProvider).playSuccessSound();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Account created successfully! Please verify your email.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          
          // Navigate to 2FA verification screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TwoFactorScreen(
                email: _emailController.text.trim(),
                displayName: _displayNameController.text.trim(),
              ),
            ),
          );
        }
      } else {
        await ref.read(soundServiceProvider).playErrorSound();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Retry failed: ${result.errorMessage}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      await ref.read(soundServiceProvider).playErrorSound();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Retry error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept the Terms of Service and Privacy Policy to continue'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );

      if (result.isSuccess) {
        await ref.read(soundServiceProvider).playSuccessSound();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account created successfully! Please verify your email.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          
          // Navigate to 2FA verification screen using GoRouter
          context.pushReplacement('/two-factor', extra: {
            'email': _emailController.text.trim(),
            'displayName': _displayNameController.text.trim(),
          });
        }
      } else {
        await ref.read(soundServiceProvider).playErrorSound();
        if (context.mounted) {
          // Show error with retry option for common errors
          final errorMessage = result.errorMessage ?? 'Sign up failed';
          if (errorMessage.contains('unexpected error') || 
              errorMessage.contains('PigeonUserDetails') ||
              errorMessage.contains('authentication system error') ||
              errorMessage.contains('network') ||
              errorMessage.contains('connection') ||
              errorMessage.contains('timeout')) {
            _showRetryDialog(context, errorMessage);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      await ref.read(soundServiceProvider).playErrorSound();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo/Title
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.auroraGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.radar,
                        size: 64,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Comnecter',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Join the community',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Sign Up Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create Account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Sign up to get started',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Display Name Field
                      TextFormField(
                        controller: _displayNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'Enter your display name',
                          prefixIcon: Icon(Icons.person, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your display name';
                          }
                          if (value.length < 2) {
                            return 'Display name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*])').hasMatch(value)) {
                            return 'Password must include uppercase, lowercase, number, and special character';
                          }
                          return null;
                        },
                      ),
                      
                      // Password Requirements with Live Validation
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
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
                              _passwordController.text.length >= 8,
                            ),
                            _buildRequirementItem(
                              'Include uppercase and lowercase letters',
                              RegExp(r'(?=.*[a-z])(?=.*[A-Z])').hasMatch(_passwordController.text),
                            ),
                            _buildRequirementItem(
                              'Include at least one number',
                              RegExp(r'(?=.*\d)').hasMatch(_passwordController.text),
                            ),
                            _buildRequirementItem(
                              'Include at least one special character (!@#\$%^&*)',
                              RegExp(r'(?=.*[!@#\$%^&*])').hasMatch(_passwordController.text),
                            ),
                          ],
                        ),
                      ),
                      
                      // Password Strength Indicator
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildPasswordStrengthIndicator(),
                        const SizedBox(height: 8),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm your password',
                          prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Terms and Privacy Policy Acceptance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                              });
                            },
                            activeColor: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => _showTermsOfService(context),
                                      child: Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => _showPrivacyPolicy(context),
                                      child: Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: '. I understand that Comnecter will collect and use my data as described in these documents.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Sign Up Button
                      ElevatedButton(
                        onPressed: (_isLoading || !_acceptTerms) ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Create Account',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Sign In Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
