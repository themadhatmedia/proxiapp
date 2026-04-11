import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../data/models/plan_model.dart';
import '../../data/services/api_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/plan_option_card.dart';

class UpgradePlanScreen extends StatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  final ProfileController controller = Get.put(ProfileController());
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();
  int? selectedPlanId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentUser = authController.currentUser.value;
    if (currentUser?.membership?.membershipId != null) {
      selectedPlanId = currentUser!.membership!.membershipId;
    }
    controller.loadPlans().then((_) {
      if (!mounted) return;
      final id = selectedPlanId;
      if (id == null) return;
      PlanModel? match;
      for (final p in controller.availablePlans) {
        if (p.id == id) {
          match = p;
          break;
        }
      }
      if (match != null && (match.isComingSoonPlan || !match.isFree)) {
        setState(() => selectedPlanId = null);
      }
    });
  }

  Future<void> _handleSubscribe() async {
    if (selectedPlanId == null) {
      ToastHelper.showError('Please select a plan');
      return;
    }

    PlanModel? selectedPlan;
    for (final p in controller.availablePlans) {
      if (p.id == selectedPlanId) {
        selectedPlan = p;
        break;
      }
    }
    if (selectedPlan?.isComingSoonPlan == true) {
      ToastHelper.showError('This plan is not available yet');
      return;
    }
    if (selectedPlan?.isFree != true) {
      ToastHelper.showError('Only the free plan can be selected');
      return;
    }

    final token = authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await apiService.subscribeMembership(
        token: token,
        membershipId: selectedPlanId!,
      );
      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Subscription updated successfully');
      Get.back();
    } catch (e) {
      ToastHelper.showError('Failed to update subscription');
    } finally {
      setState(() => _isSaving = false);
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
                        'Upgrade Plan',
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
                      const SizedBox(height: 24),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return Center(
                            child: CircularProgressIndicator(color: cs.primary),
                          );
                        }

                        if (controller.availablePlans.isEmpty) {
                          return Center(
                            child: Text(
                              'No plans available',
                              style: TextStyle(color: cs.onSurface),
                            ),
                          );
                        }

                        return Column(
                          children: controller.availablePlans.map((plan) {
                            return PlanOptionCard(
                              plan: plan,
                              isSelected: selectedPlanId == plan.id,
                              onTap: plan.isFree && !plan.isComingSoonPlan
                                  ? () {
                                      setState(() {
                                        selectedPlanId = plan.id;
                                      });
                                    }
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
                padding: const EdgeInsets.all(24.0),
                child: CustomButton(
                  text: _isSaving ? 'Updating...' : 'Update Subscription',
                  onPressed: _isSaving ? () {} : _handleSubscribe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
