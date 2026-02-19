import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

class SelectInterestsScreen extends StatefulWidget {
  const SelectInterestsScreen({super.key});

  @override
  State<SelectInterestsScreen> createState() => _SelectInterestsScreenState();
}

class _SelectInterestsScreenState extends State<SelectInterestsScreen> {
  final OnboardingController controller = Get.find<OnboardingController>();
  final AuthController authController = Get.find<AuthController>();
  bool _isSaving = false;

  Future<void> _handleContinue() async {
    if (!controller.validateInterestsSelection()) return;
    if (authController.token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);
    final success = await controller.saveInterestsToApi(authController.token!);
    setState(() => _isSaving = false);

    if (success) {
      Get.toNamed('/select-core-values');
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
                        'Select Your Interests',
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
                      Obx(() {
                        final selectedCount = controller.selectedInterestIds.length;
                        return Text(
                          selectedCount > 0 ? 'Choose activities you enjoy ($selectedCount selected, at least 1 required)' : 'Choose activities you enjoy (at least 1 required)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        if (controller.availableInterests.isEmpty) {
                          return const Center(
                            child: Text(
                              'No interests available',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.5,
                          ),
                          itemCount: controller.availableInterests.length,
                          itemBuilder: (context, index) {
                            final interest = controller.availableInterests[index];

                            return Obx(() {
                              final isCurrentlySelected = controller.selectedInterestIds.contains(interest.id);
                              return GestureDetector(
                                onTap: () => controller.toggleInterest(interest.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isCurrentlySelected ? Colors.white : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCurrentlySelected ? Colors.white : Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      interest.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isCurrentlySelected ? const Color(0xFF4A90E2) : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: CustomButton(
                  text: _isSaving ? 'Saving...' : 'Continue',
                  onPressed: _isSaving ? () {} : _handleContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
