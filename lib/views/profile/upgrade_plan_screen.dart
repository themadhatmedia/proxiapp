import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

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
    controller.loadPlans();
  }

  Future<void> _handleSubscribe() async {
    if (selectedPlanId == null) {
      ToastHelper.showError('Please select a plan');
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
                        'Upgrade Plan',
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
                      const SizedBox(height: 24),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        if (controller.availablePlans.isEmpty) {
                          return const Center(
                            child: Text(
                              'No plans available',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        }

                        return Column(
                          children: controller.availablePlans.map((plan) {
                            return GestureDetector(
                              onTap: plan.isFree
                                  ? () {
                                      setState(() {
                                        selectedPlanId = plan.id;
                                      });
                                    }
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: selectedPlanId == plan.id ? Colors.white : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selectedPlanId == plan.id ? Colors.white : Colors.white.withOpacity(0.3),
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
                                            color: selectedPlanId == plan.id ? const Color(0xFF4A90E2) : Colors.white,
                                          ),
                                        ),
                                        Text(
                                          plan.isFree ? 'Free' : plan.displayPrice.split(' ').first,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: selectedPlanId == plan.id ? const Color(0xFF4A90E2) : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.description,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: selectedPlanId == plan.id ? const Color(0xFF4A90E2).withOpacity(0.7) : Colors.white60,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      plan.displayLimits,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: selectedPlanId == plan.id ? const Color(0xFF4A90E2).withOpacity(0.8) : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
