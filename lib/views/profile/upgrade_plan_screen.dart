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

  int? get _currentMembershipPlanId => authController.currentUser.value?.membership?.membershipId;

  bool get _isSameAsCurrentPlan =>
      selectedPlanId != null && _currentMembershipPlanId != null && selectedPlanId == _currentMembershipPlanId;

  PlanModel? get _selectedPlanModel {
    if (selectedPlanId == null) return null;
    for (final p in controller.availablePlans) {
      if (p.id == selectedPlanId) return p;
    }
    return null;
  }

  bool get _canUpdateSubscription {
    if (_isSaving || selectedPlanId == null || _isSameAsCurrentPlan) return false;
    return _selectedPlanModel?.availableForPurchase == true;
  }

  @override
  void initState() {
    super.initState();
    final currentUser = authController.currentUser.value;
    if (currentUser?.membership?.membershipId != null) {
      selectedPlanId = currentUser!.membership!.membershipId;
    }
    controller.loadPlans().then((_) {
      if (!mounted) return;
      final plans = controller.availablePlans;
      if (plans.isEmpty) return;

      var found = false;
      if (selectedPlanId != null) {
        for (final p in plans) {
          if (p.id == selectedPlanId) {
            found = true;
            break;
          }
        }
      }
      setState(() {
        if (!found) {
          selectedPlanId = PlanModel.initialSelectionForUpgrade(plans)?.id;
        }
      });
    });
  }

  Future<void> _handleSubscribe() async {
    if (selectedPlanId == null) {
      ToastHelper.showError('Please select a plan');
      return;
    }
    if (_isSameAsCurrentPlan) {
      ToastHelper.showError('You are already on this plan');
      return;
    }

    final selectedPlan = _selectedPlanModel;
    if (selectedPlan?.availableForPurchase != true) {
      ToastHelper.showError('This plan is not available for purchase');
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
                              currentMembershipPlanId: _currentMembershipPlanId,
                              onTap: plan.availableForPurchase
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
                child: Obx(() {
                  controller.availablePlans.length;
                  return CustomButton(
                    text: _isSaving ? 'Updating...' : 'Update Subscription',
                    isEnabled: _canUpdateSubscription,
                    onPressed: _handleSubscribe,
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
