import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/selection_styles.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

class SelectSkillsScreen extends StatefulWidget {
  const SelectSkillsScreen({super.key});

  @override
  State<SelectSkillsScreen> createState() => _SelectSkillsScreenState();
}

class _SelectSkillsScreenState extends State<SelectSkillsScreen> {
  final OnboardingController controller = Get.find<OnboardingController>();
  final AuthController authController = Get.find<AuthController>();
  bool _isSaving = false;

  Future<void> _handleContinue() async {
    if (!controller.validateSkillsSelection()) return;
    if (authController.token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);
    final success = await controller.saveSkillsToApi(authController.token!);
    setState(() => _isSaving = false);

    if (success) {
      Get.toNamed('/select-ambitions');
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
                        'Select Your Skills',
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
                      Obx(() {
                        final n = controller.selectedSkillIds.length;
                        return Text(
                          n > 0
                              ? 'Choose skills that describe you ($n selected, at least 1 required)'
                              : 'Choose skills that describe you (at least 1 required)',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return Center(
                            child: CircularProgressIndicator(color: cs.primary),
                          );
                        }

                        if (controller.availableSkills.isEmpty) {
                          return Center(
                            child: Text(
                              'No skills available',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 5,
                            mainAxisSpacing: 5,
                            childAspectRatio: 2.5,
                          ),
                          itemCount: controller.availableSkills.length,
                          itemBuilder: (context, index) {
                            final skill = controller.availableSkills[index];

                            return Obx(() {
                              final selected = controller.selectedSkillIds.contains(skill.id);
                              return GestureDetector(
                                onTap: () => controller.toggleSkill(skill.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                  decoration: SelectionStyles.chipBox(context, selected),
                                  child: Center(
                                    child: Text(
                                      skill.name,
                                      textAlign: TextAlign.center,
                                      style: SelectionStyles.chipLabel(context, selected),
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
