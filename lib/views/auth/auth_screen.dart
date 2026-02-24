import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/theme_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/social_button.dart';
import '../main/main_navigation.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthController authController = Get.find<AuthController>();
  final ThemeController themeController = Get.find<ThemeController>();

  final TextEditingController signInEmailController = TextEditingController();
  final TextEditingController signInPasswordController = TextEditingController();

  final TextEditingController signUpEmailController = TextEditingController();
  final TextEditingController signUpPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    signInEmailController.dispose();
    signInPasswordController.dispose();
    signUpEmailController.dispose();
    signUpPasswordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    if (signInEmailController.text.isEmpty || signInPasswordController.text.isEmpty) {
      ToastHelper.showError('Please fill in all fields');
      return;
    }

    final success = await authController.login(
      email: signInEmailController.text.trim(),
      password: signInPasswordController.text,
    );

    if (success) {
      Get.off(() => const MainNavigation(), transition: Transition.fadeIn);
    }
  }

  void _handleSignUp() async {
    if (signUpEmailController.text.isEmpty || signUpPasswordController.text.isEmpty || nameController.text.isEmpty) {
      ToastHelper.showError('Please fill in all required fields');
      return;
    }

    if (signUpPasswordController.text != confirmPasswordController.text) {
      ToastHelper.showError('Passwords do not match');
      return;
    }

    if (signUpPasswordController.text.length < 8) {
      ToastHelper.showError('Password must be at least 8 characters');
      return;
    }

    final success = await authController.register(
      name: nameController.text.trim(),
      email: signUpEmailController.text.trim(),
      password: signUpPasswordController.text,
      phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
    );

    if (success) {
      Get.offNamed('/profile-creation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = themeController.isDarkMode;
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.getGradient(isDark),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 30.0),
                    _buildLogo().animate().fadeIn(duration: 600.ms).scale(),
                    const SizedBox(height: 20.0),
                    _buildTitle().animate().fadeIn(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 8.0),
                    _buildSubtitle().animate().fadeIn(delay: 400.ms, duration: 600.ms),
                    const SizedBox(height: 20.0),
                    _buildTabBar().animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    const SizedBox(height: 25.0),
                    _buildTabContent(),
                    // const SizedBox(height: 30.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLogo() {
    return Container(
      width: 100.0,
      height: 100.0,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.navigation_rounded,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Proxi',
      style: TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Proximity-based networking efficiency',
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(28.0),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(28.0),
          shape: BoxShape.rectangle,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Sign In'),
          Tab(text: 'Sign Up'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: _buildSignInForm().animate().fadeIn(duration: 400.ms),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: _buildSignUpForm().animate().fadeIn(duration: 400.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    return Obx(
      () => Column(
        children: [
          CustomTextField(
            hint: 'Email',
            controller: signInEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hint: 'Password',
            controller: signInPasswordController,
            obscureText: _obscureLoginPassword,
            isPassword: true,
            onToggleVisibility: () {
              setState(() {
                _obscureLoginPassword = !_obscureLoginPassword;
              });
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Sign In',
            onPressed: _handleSignIn,
            isLoading: authController.isLoading,
          ),
          const SizedBox(height: 16),
          SocialButton(
            text: 'Sign in with Apple',
            icon: Icons.apple,
            onPressed: () {
              ToastHelper.showInfo('Apple Sign In will be available soon');
            },
          ),
          const SizedBox(height: 16),
          SocialButton(
            text: 'Sign in with Face ID / Touch ID',
            icon: Icons.fingerprint,
            onPressed: () {
              ToastHelper.showInfo('Biometric authentication will be available soon');
            },
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
          // const Spacer(),
          // const Text(
          //   'Proxi v.0.1.0.1205.2',
          //   style: TextStyle(
          //     color: Colors.white60,
          //     fontSize: 12,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Obx(
      () => Column(
        children: [
          CustomTextField(
            hint: 'Name',
            controller: nameController,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hint: 'Email',
            controller: signUpEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hint: 'Phone (optional)',
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hint: 'Password',
            controller: signUpPasswordController,
            obscureText: _obscureSignUpPassword,
            isPassword: true,
            onToggleVisibility: () {
              setState(() {
                _obscureSignUpPassword = !_obscureSignUpPassword;
              });
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hint: 'Confirm Password',
            controller: confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            isPassword: true,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Create Account',
            onPressed: _handleSignUp,
            isLoading: authController.isLoading,
          ),
          const SizedBox(height: 16),
          SocialButton(
            text: 'Sign in with Apple',
            icon: Icons.apple,
            onPressed: () {
              ToastHelper.showInfo('Apple Sign In will be available soon');
            },
          ),
          const SizedBox(height: 16),
          SocialButton(
            text: 'Sign in with Face ID / Touch ID',
            icon: Icons.fingerprint,
            onPressed: () {
              ToastHelper.showInfo('Biometric authentication will be available soon');
            },
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'By creating an account, you agree to our Terms of Service and Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
