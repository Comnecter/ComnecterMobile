import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/sound_service.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/sound_provider.dart';
import '../welcome/welcome_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../discover/discover_screen.dart';
import '../../routing/app_router.dart';



class SignUpWizardScreen extends ConsumerStatefulWidget {
  const SignUpWizardScreen({super.key});

  @override
  ConsumerState<SignUpWizardScreen> createState() => _SignUpWizardScreenState();
}

class _SignUpWizardScreenState extends ConsumerState<SignUpWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Step 1: Email
  final _emailController = TextEditingController();
  bool _isCheckingEmail = false;
  bool _emailExists = false;
  String? _emailVerificationId;
  
  // Step 2: Email Verification
  final _verificationCodeController = TextEditingController();
  bool _isVerifying = false;
  
  // Step 3: Personal Info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _birthdate;
  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  
  // Step 4: Username
  final _usernameController = TextEditingController();
  bool _isCheckingUsername = false;
  bool _usernameAvailable = false;
  
  // Step 5: Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Step 6: Interests & Bio
  final _bioController = TextEditingController();
  List<String> _selectedInterests = [];
  final List<String> _availableInterests = [
    'Music', 'Sports', 'Travel', 'Food', 'Technology',
    'Art', 'Fitness', 'Gaming', 'Reading', 'Movies',
    'Photography', 'Dancing', 'Cooking', 'Nature', 'Fashion'
  ];
  
  // Step 7: Terms
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  
  final int _totalSteps = 7;
  
  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
      ref.read(soundServiceProvider).playButtonClickSound();
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
      ref.read(soundServiceProvider).playButtonClickSound();
    }
  }
  
  Future<void> _checkEmailExists() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    
    setState(() {
      _isCheckingEmail = true;
      _emailExists = false;
    });
    
    try {
      // !!!!!! Changed to firestore implementation by me, Abayomi, because fetchSignInMethodsForEmail implementation
      // !!!!!! has been removed in the latest version
      // final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      final getUserByEmail = await FirebaseFirestore.instance.collection('users').where("email", isEqualTo: email).get();
      
      setState(() {
        _emailExists = getUserByEmail.docs.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _emailExists = false;
      });
    } finally {
      setState(() {
        _isCheckingEmail = false;
      });
    }
  }
  
  Future<void> _sendEmailVerification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _emailExists) return;
    
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.send2FACode(email);
      
      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code sent to $email'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        _nextStep();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to send verification code'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _verifyEmailCode() async {
    final code = _verificationCodeController.text.trim();
    if (code.isEmpty) return;
    
    setState(() => _isVerifying = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.verify2FACode(_emailController.text.trim(), code);
      
      if (result.isSuccess) {
        _nextStep();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Invalid verification code'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isVerifying = false);
    }
  }
  
  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty || username.length < 3) {
      setState(() => _usernameAvailable = false);
      return;
    }
    
    setState(() {
      _isCheckingUsername = true;
      _usernameAvailable = false;
    });
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username)
          .get();
      
      print({"Username exists", snapshot.exists});
      
      setState(() {
        _usernameAvailable = !snapshot.exists;
      });
    } catch (e) {
      setState(() => _usernameAvailable = false);
    } finally {
      setState(() => _isCheckingUsername = false);
    }
  }
  
  Future<void> _finishSignUp(BuildContext context) async {
    if (!_acceptTerms || !_acceptPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms of Service and Privacy Policy')),
      );
      return;
    }
    
    try {
      final authService = ref.read(authServiceProvider);
      
      final result = await authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        phoneNumber: null, // Removed for now
        birthdate: _birthdate,
        gender: _selectedGender,
        interests: _selectedInterests,
        bio: _bioController.text.trim(),
      );
      
      if (result.isSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign up successful!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          context.go('/');
        }

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Sign up failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Email
        return _emailController.text.trim().isNotEmpty && 
               !_emailExists && 
               RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim());
      case 1: // Email verification
        return _verificationCodeController.text.trim().length == 6;
      case 2: // Personal info
        return _firstNameController.text.trim().isNotEmpty &&
               _lastNameController.text.trim().isNotEmpty &&
               _birthdate != null &&
               _selectedGender != null;
      case 3: // Username
        return _usernameController.text.trim().length >= 3 &&
               _usernameAvailable &&
               !_isCheckingUsername;
      case 4: // Password
        return _passwordController.text.length >= 8 &&
               _passwordController.text == _confirmPasswordController.text;
      case 5: // Interests & Bio
        return _selectedInterests.isNotEmpty;
      case 6: // Terms
        return _acceptTerms && _acceptPrivacy;
      default:
        return false;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(soundServiceProvider).playButtonClickSound();
            if (_currentStep > 0) {
              _previousStep();
            } else {
              // On first step, go back to welcome screen
              context.canPop() ? context.pop() : context.go('/welcome');
              // Navigator.of(context).pushReplacement(
              //   MaterialPageRoute(
              //     builder: (context) => const WelcomeScreen(),
              //   ),
              // );
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildEmailStep(theme),
          _buildEmailVerificationStep(theme),
          _buildPersonalInfoStep(theme),
          _buildUsernameStep(theme),
          _buildPasswordStep(theme),
          _buildInterestsStep(theme),
          _buildTermsStep(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousStep,
                    child: const Text('Previous'),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 16),
              Expanded(
                flex: _currentStep == 0 ? 1 : 2,
                child: ElevatedButton(
                  onPressed: _canProceedToNextStep() ? () async {
                    if (_currentStep == 0) {
                      _sendEmailVerification();
                    } else if (_currentStep == 1) {
                      _verifyEmailCode();
                    } else if (_currentStep == _totalSteps - 1) {
                      await _finishSignUp(context);
                    } else {
                      _nextStep();
                    }
                  } : null,
                  child: Text(
                    _currentStep == _totalSteps - 1 ? 'Finish' :
                    _currentStep == 0 ? 'Send Verification Code' :
                    _currentStep == 1 ? 'Verify' : 'Next',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmailStep(ThemeData theme) {
    final _formKey = GlobalKey<FormState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Account',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email address to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            // key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email *',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email, color: theme.colorScheme.primary),
              suffixIcon: _isCheckingEmail
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _emailExists
                      ? Icon(Icons.error, color: theme.colorScheme.error)
                      : _emailController.text.isNotEmpty && !_emailExists
                          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                          : null,
            ),
            onChanged: (value) {
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return;
              _checkEmailExists();
              setState(() {});
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              if (_emailExists) {
                return 'This email is already registered';
              }
              return null;
            },
          ),
          if (_emailExists)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This email is already registered. Please sign in instead.',
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEmailVerificationStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify Your Email',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a verification code to ${_emailController.text}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _verificationCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Verification Code *',
              hintText: 'Enter 6-digit code',
              prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_isVerifying)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'First Name *',
              prefixIcon: Icon(Icons.person, color: theme.colorScheme.primary),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Last Name *',
              prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _birthdate = date);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Birthdate *',
                prefixIcon: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
              ),
              child: Text(
                _birthdate != null
                    ? DateFormat('yyyy-MM-dd').format(_birthdate!)
                    : 'Select your birthdate',
                style: TextStyle(
                  color: _birthdate != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Gender *',
              prefixIcon: Icon(Icons.people, color: theme.colorScheme.primary),
            ),
            items: _genderOptions.map((gender) {
              return DropdownMenuItem(value: gender, child: Text(gender));
            }).toList(),
            onChanged: (value) => setState(() => _selectedGender = value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUsernameStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Username',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a unique username (3-32 characters)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username *',
              hintText: 'username',
              prefixIcon: Icon(Icons.alternate_email, color: theme.colorScheme.primary),
              suffixIcon: _isCheckingUsername
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _usernameController.text.isNotEmpty
                      ? Icon(
                          _usernameAvailable ? Icons.check_circle : Icons.error,
                          color: _usernameAvailable
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        )
                      : null,
            ),
            onChanged: (_) {
              _checkUsernameAvailability();
              setState(() {});
            },
          ),
          if (_usernameController.text.isNotEmpty && !_isCheckingUsername)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _usernameAvailable
                    ? 'Username is available'
                    : 'Username is already taken',
                style: TextStyle(
                  color: _usernameAvailable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPasswordStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Password',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a strong password (at least 8 characters)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_passwordController.text.isNotEmpty &&
              _passwordController.text != _confirmPasswordController.text)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Passwords do not match',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInterestsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interests & Bio',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Interests *',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedInterests.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please select at least one interest',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 280,
            decoration: InputDecoration(
              labelText: 'Bio (optional)',
              hintText: 'Tell us about yourself',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTermsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Privacy',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          CheckboxListTile(
            title: const Text('I agree to the Terms of Service'),
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            title: const Text('I agree to the Privacy Policy'),
            value: _acceptPrivacy,
            onChanged: (value) => setState(() => _acceptPrivacy = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

