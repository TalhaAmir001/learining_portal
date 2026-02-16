import 'package:flutter/material.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/widgets/custom_text_field.dart';
import 'package:learining_portal/utils/widgets/error_message.dart';
import 'package:learining_portal/utils/widgets/gradient_button.dart';
import 'package:learining_portal/utils/widgets/simple_banner.dart';
import 'package:learining_portal/utils/widgets/success_snackbar.dart';
import 'package:learining_portal/utils/widgets/user_type_button.dart';
import 'package:provider/provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  UserType? _selectedUserType;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectUserType(UserType userType) {
    setState(() {
      _selectedUserType = userType;
      _emailController.clear();
      _passwordController.clear();
      context.read<AuthProvider>().clearError();
    });
    _animationController.forward();
  }

  void _goBack() {
    setState(() {
      _selectedUserType = null;
      _emailController.clear();
      _passwordController.clear();
      context.read<AuthProvider>().clearError();
    });
    _animationController.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUserType == null) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
      _selectedUserType!,
    );

    if (success && mounted) {
      final userTypeText = _getUserTypeName(_selectedUserType!);
      SuccessSnackBar.show(context, 'Login successful! Welcome $userTypeText!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // colorScheme.primaryContainer.withOpacity(0.3),
              // colorScheme.secondaryContainer.withOpacity(0.2),
              Colors.white.withOpacity(0.3),
              Colors.white.withOpacity(0.2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Banner - only show when user type is selected
                if (_selectedUserType != null)
                  SimpleBanner(
                    imagePath:
                        (_selectedUserType == UserType.student ||
                            _selectedUserType == UserType.guardian)
                        ? 'assets/auth_banner.png'
                        : 'assets/auth_banner_staff.png',
                    height: 0.25,
                  ),

                // Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? size.width * 0.2 : 24.0,
                    vertical: 32.0,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _selectedUserType == null
                          ? _buildUserTypeSelection(colorScheme)
                          : _buildLoginForm(colorScheme),
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

  Widget _buildUserTypeSelection(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome Logo
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        Text(
          'Welcome to GCSE with Rosi',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Please select your account type to continue',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600], height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Student Login Button
        UserTypeButton(
          userType: UserType.student,
          icon: Icons.person_outline,
          title: 'Sign in as Student',
          subtitle: 'Access your courses and learning materials',
          color: Colors.blue,
          onTap: () => _selectUserType(UserType.student),
        ),
        const SizedBox(height: 20),

        // Guardian Login Button
        UserTypeButton(
          userType: UserType.guardian,
          icon: Icons.family_restroom_outlined,
          title: 'Sign in as Guardian',
          subtitle: 'Be Updated on your Children Performance',
          color: Colors.green,
          onTap: () => _selectUserType(UserType.guardian),
        ),
        const SizedBox(height: 20),

        // Teacher Login Button
        UserTypeButton(
          userType: UserType.teacher,
          icon: Icons.school_outlined,
          title: 'Sign in as Teacher',
          subtitle: 'Manage courses and student progress',
          color: Colors.orange,
          onTap: () => _selectUserType(UserType.teacher),
        ),
        const SizedBox(height: 20),

        // Admin Login Button
        UserTypeButton(
          userType: UserType.admin,
          icon: Icons.admin_panel_settings_outlined,
          title: 'Sign in as Admin',
          subtitle: 'Manage the entire learning portal system',
          color: Colors.purple,
          onTap: () => _selectUserType(UserType.admin),
        ),
      ],
    );
  }

  Widget _buildLoginForm(ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back Button and Title
          Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Sign in as ${_getUserTypeName(_selectedUserType!)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Error Message
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.errorMessage != null) {
                return ErrorMessage(message: authProvider.errorMessage!);
              }
              return const SizedBox.shrink();
            },
          ),

          // Username/Email Field (Username for Student/Guardian, Email for Teacher/Admin)
          CustomTextField(
            controller: _emailController,
            label:
                (_selectedUserType == UserType.student ||
                    _selectedUserType == UserType.guardian)
                ? 'Username'
                : 'Email',
            icon:
                (_selectedUserType == UserType.student ||
                    _selectedUserType == UserType.guardian)
                ? Icons.person_outlined
                : Icons.email_outlined,
            keyboardType:
                (_selectedUserType == UserType.student ||
                    _selectedUserType == UserType.guardian)
                ? TextInputType.text
                : TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                if (_selectedUserType == UserType.student ||
                    _selectedUserType == UserType.guardian) {
                  return 'Please enter your username';
                }
                return 'Please enter your email';
              }
              // Only validate email format for Teacher/Admin
              if (_selectedUserType == UserType.teacher ||
                  _selectedUserType == UserType.admin) {
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Password Field
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Forgot password feature coming soon!'),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Submit Button
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return GradientButton(
                text: 'Sign In',
                onPressed: _submit,
                isLoading: authProvider.isLoading,
                icon: Icons.arrow_forward_rounded,
              );
            },
          ),
        ],
      ),
    );
  }

  String _getUserTypeName(UserType userType) {
    switch (userType) {
      case UserType.student:
        return 'Student';
      case UserType.guardian:
        return 'Guardian';
      case UserType.teacher:
        return 'Teacher';
      case UserType.admin:
        return 'Admin';
    }
  }
}
