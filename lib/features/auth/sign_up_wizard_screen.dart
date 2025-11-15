import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/sound_service.dart';
import '../../../theme/app_theme.dart';
import '../welcome/welcome_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../discover/discover_screen.dart';
import '../../routing/app_router.dart';
import '../../../widgets/legal_documents_dialog.dart';



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
  
  // Step 2: Email Verification
  final _verificationCodeController = TextEditingController();
  bool _isVerifying = false;
  String? _emailVerificationId;
  
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
  bool _hasReadTerms = false;
  bool _hasReadPrivacy = false;
  
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

  void _showDateRoller(BuildContext context) {
    final now = DateTime.now();
    final initialDate = _birthdate ?? DateTime(now.year - 18, 1, 1);
    
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;
    int selectedDay = initialDate.day;
    
    // Generate lists for years, months, and days
    final years = List.generate(now.year - 1899, (index) => now.year - index);
    final months = List.generate(12, (index) => index + 1);
    
    // Function to get days in a month
    int getDaysInMonth(int year, int month) {
      return DateTime(year, month + 1, 0).day;
    }
    
    // Update days list when year or month changes
    List<int> getDays(int year, int month) {
      final daysInMonth = getDaysInMonth(year, month);
      return List.generate(daysInMonth, (index) => index + 1);
    }
    
    var days = getDays(selectedYear, selectedMonth);
    if (selectedDay > days.length) {
      selectedDay = days.length;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        Text(
                          'Select Birthdate',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);
                            if (selectedDate.isBefore(now) || selectedDate.isAtSameMomentAs(now)) {
                              setState(() {
                                _birthdate = selectedDate;
                              });
                              ref.read(soundServiceProvider).playButtonClickSound();
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select a valid birthdate'),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          },
                          child: Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  // Date Rollers
                  Expanded(
                    child: Row(
                      children: [
                        // Year Picker
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: years.indexOf(selectedYear),
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (int index) {
                              selectedYear = years[index];
                              final newDays = getDays(selectedYear, selectedMonth);
                              if (selectedDay > newDays.length) {
                                selectedDay = newDays.length;
                              }
                              days = newDays;
                              ref.read(soundServiceProvider).playSwipeSound();
                              setModalState(() {});
                            },
                            children: years.map((year) {
                              return Center(
                                child: Text(
                                  year.toString(),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        // Month Picker
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedMonth - 1,
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (int index) {
                              selectedMonth = months[index];
                              final newDays = getDays(selectedYear, selectedMonth);
                              if (selectedDay > newDays.length) {
                                selectedDay = newDays.length;
                              }
                              days = newDays;
                              ref.read(soundServiceProvider).playSwipeSound();
                              setModalState(() {});
                            },
                            children: months.map((month) {
                              return Center(
                                child: Text(
                                  DateFormat('MMMM').format(DateTime(2000, month)),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        // Day Picker
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: days.indexOf(selectedDay),
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (int index) {
                              selectedDay = days[index];
                              ref.read(soundServiceProvider).playSwipeSound();
                              setModalState(() {});
                            },
                            children: days.map((day) {
                              return Center(
                                child: Text(
                                  day.toString(),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        return true;
      case 6: // Terms
        return _acceptTerms && _acceptPrivacy;
      default:
        return false;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) {
          // Go back to previous screen (welcome screen)
          ref.read(soundServiceProvider).playButtonClickSound();
          if (context.canPop()) {
            context.pop();
          } else {
            // Fallback to welcome if can't pop
            context.go('/welcome');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Step ${_currentStep + 1} of $_totalSteps'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(soundServiceProvider).playButtonClickSound();
              // Go back to previous screen (welcome screen)
              if (context.canPop()) {
                context.pop();
              } else {
                // Fallback to welcome if can't pop
                context.go('/welcome');
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
          
          const SizedBox(height: 24),
          
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
                onPressed: () {
                  ref.read(soundServiceProvider).playButtonClickSound();
                  context.push('/signin');
                },
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
            onTap: () => _showDateRoller(context),
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
            'Interests',
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
          const SizedBox(height: 24),
          Text(
            'Bio',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 280,
            decoration: InputDecoration(
              hintText: 'You can type your bio text here...',
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
          const SizedBox(height: 8),
          Text(
            'Please read each document and agree to proceed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          
          // Terms of Service Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasReadTerms
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: _hasReadTerms ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            const TextSpan(text: 'Terms of Service'),
                            if (_hasReadTerms) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                child: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final hasViewed = await LegalDocumentsDialog.showTermsOfService(context);
                    if (hasViewed && mounted) {
                      setState(() {
                        _hasReadTerms = true;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _hasReadTerms ? 'Re-read Terms of Service' : 'Read Terms of Service',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('I agree to the Terms of Service'),
                  value: _acceptTerms,
                  onChanged: _hasReadTerms
                      ? (value) => setState(() => _acceptTerms = value ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: theme.colorScheme.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Privacy Policy Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasReadPrivacy
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: _hasReadPrivacy ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            const TextSpan(text: 'Privacy Policy'),
                            if (_hasReadPrivacy) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                child: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final hasViewed = await LegalDocumentsDialog.showPrivacyPolicy(context);
                    if (hasViewed && mounted) {
                      setState(() {
                        _hasReadPrivacy = true;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.privacy_tip,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _hasReadPrivacy ? 'Re-read Privacy Policy' : 'Read Privacy Policy',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('I agree to the Privacy Policy'),
                  value: _acceptPrivacy,
                  onChanged: _hasReadPrivacy
                      ? (value) => setState(() => _acceptPrivacy = value ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: theme.colorScheme.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Status Message
          if (!_hasReadTerms || !_hasReadPrivacy)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please read both documents by clicking the "Read" buttons above, then check the boxes to agree.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_hasReadTerms && _hasReadPrivacy && _acceptTerms && _acceptPrivacy)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All documents read and agreed. You can proceed!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

