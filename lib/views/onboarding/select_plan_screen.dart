import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/plan_option_card.dart';

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
    final selected = onboardingController.selectedPlan.value;
    if (selected == null) {
      ToastHelper.showError('Please select a plan');
      return;
    }
    if (selected.isComingSoonPlan) {
      ToastHelper.showError('This plan is not available yet');
      return;
    }
    if (!selected.isFree) {
      ToastHelper.showError('Only the free plan can be selected');
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
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
                      icon: Icon(Icons.arrow_back, color: cs.onSurface),
                    ),
                    Expanded(
                      child: Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
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
                      Text(
                        'Select the subscription that works best for you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Obx(() {
                        if (onboardingController.isLoading.value) {
                          return Center(
                            child: CircularProgressIndicator(color: cs.primary),
                          );
                        }

                        if (onboardingController.availablePlans.isEmpty) {
                          return Center(
                            child: Text(
                              'No plans available',
                              style: TextStyle(color: cs.onSurface),
                            ),
                          );
                        }

                        return Column(
                          children: onboardingController.availablePlans.map((plan) {
                            final isSelected = onboardingController.selectedPlan.value?.id == plan.id;
                            return PlanOptionCard(
                              plan: plan,
                              isSelected: isSelected,
                              onTap: plan.isFree && !plan.isComingSoonPlan
                                  ? () => onboardingController.selectPlan(plan)
                                  : null,
                            );
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
