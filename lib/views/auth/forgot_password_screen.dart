import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/theme_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final ThemeController themeController = Get.find<ThemeController>();
  final ApiService _apiService = ApiService();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (emailController.text.isEmpty) {
      ToastHelper.showError('Please enter your email');
      return;
    }

    if (!GetUtils.isEmail(emailController.text.trim())) {
      ToastHelper.showError('Please enter a valid email address');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _apiService.forgotPassword(
        email: emailController.text.trim(),
      );

      if (response['success'] == true) {
        ToastHelper.showSuccess(
          response['message'] ?? 'Password reset link sent to your email.',
        );
        // Navigate back to login screen after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Get.back();
        }
      } else {
        ToastHelper.showError(
          response['message'] ?? 'Failed to send reset link',
        );
      }
    } catch (e) {
      ToastHelper.showError('Failed to send reset link: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                    const SizedBox(height: 20.0),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30.0),
                    _buildLogo().animate().fadeIn(duration: 600.ms).scale(),
                    const SizedBox(height: 30.0),
                    _buildTitle().animate().fadeIn(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 12.0),
                    _buildSubtitle().animate().fadeIn(delay: 400.ms, duration: 600.ms),
                    const SizedBox(height: 40.0),
                    _buildForm().animate().fadeIn(delay: 600.ms, duration: 600.ms),
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
      // child: const Icon(
      //   Icons.navigation_rounded,
      //   size: 60,
      //   color: Colors.black,
      // ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Image.asset('assets/logo-500-black.png'),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Forgot Password?',
      style: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Text(
        'Enter your email address and we\'ll send you a link to reset your password',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        CustomTextField(
          hint: 'Email',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Send Reset Link',
          onPressed: _handleForgotPassword,
          isLoading: isLoading,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Get.back(),
          child: const Text(
            'Back to Sign In',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
