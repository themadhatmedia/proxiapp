import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

class SelectPlanScreen extends StatefulWidget {
  const SelectPlanScreen({super.key});

  @override
  State<SelectPlanScreen> createState() => _SelectPlanScreenState();
}

class _SelectPlanScreenState extends State<SelectPlanScreen> {
  final OnboardingController onboardingController = Get.find<OnboardingController>();
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
  }

  Future<void> _loadPlans() async {
    if (authController.token != null) {
      await onboardingController.fetchPlans(authController.token!);
    }
  }

  bool _isSaving = false;

  Future<void> _handleContinue() async {
    if (onboardingController.selectedPlan.value == null) {
      ToastHelper.showError('Please select a plan');
      return;
    }
    if (authController.token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);
    final success = await onboardingController.subscribeMembershipToApi(authController.token!);
    setState(() => _isSaving = false);

    if (success) {
      Get.toNamed('/setup-permissions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF3D5A80)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the subscription that works best for you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Obx(() {
                        if (onboardingController.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        if (onboardingController.availablePlans.isEmpty) {
                          return const Center(
                            child: Text(
                              'No plans available',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        }

                        return Column(
                          children: onboardingController.availablePlans.map((plan) {
                            return Obx(() {
                              final isSelected = onboardingController.selectedPlan.value?.id == plan.id;

                              return GestureDetector(
                                onTap: plan.isFree ? () => onboardingController.selectPlan(plan) : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            plan.name,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? const Color(0xFF4A90E2) : Colors.white,
                                            ),
                                          ),
                                          Text(
                                            plan.isFree ? 'Free' : plan.displayPrice.split(' ').first,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? const Color(0xFF4A90E2) : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        plan.description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.7) : Colors.white60,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        plan.displayLimits,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.8) : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            });
                          }).toList(),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Obx(() {
                  final selectedPlan = onboardingController.selectedPlan.value;
                  String buttonText;
                  if (_isSaving) {
                    buttonText = 'Saving...';
                  } else if (selectedPlan != null && selectedPlan.isFree) {
                    buttonText = 'Continue with Free';
                  } else {
                    buttonText = 'Continue';
                  }
                  return CustomButton(
                    text: buttonText,
                    onPressed: _isSaving ? () {} : _handleContinue,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
