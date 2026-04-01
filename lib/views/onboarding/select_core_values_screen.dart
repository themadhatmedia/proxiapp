import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/selection_styles.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

class SelectCoreValuesScreen extends StatefulWidget {
  const SelectCoreValuesScreen({super.key});

  @override
  State<SelectCoreValuesScreen> createState() => _SelectCoreValuesScreenState();
}

class _SelectCoreValuesScreenState extends State<SelectCoreValuesScreen> {
  final OnboardingController controller = Get.find<OnboardingController>();
  final AuthController authController = Get.find<AuthController>();
  bool _isSaving = false;

  void _showCustomValueDialog() {
    final TextEditingController customValueController = TextEditingController(
      text: controller.customCoreValue.value ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            controller.customCoreValue.value == null ? 'Add Custom Core Value' : 'Edit Custom Core Value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a core value that is important to you:',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customValueController,
                  autofocus: true,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'e.g., Sustainability',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.8)),
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline.withOpacity(0.45)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (controller.customCoreValue.value != null)
              TextButton(
                onPressed: () {
                  controller.customCoreValue.value = null;
                  Navigator.of(ctx).pop();
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final value = customValueController.text.trim();
                if (value.isNotEmpty) {
                  controller.customCoreValue.value = value;
                }
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 100), () {
        customValueController.dispose();
      });
    });
  }

  Future<void> _handleContinue() async {
    if (!controller.validateCoreValuesSelection()) return;
    if (authController.token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);
    final success = await controller.saveCoreValuesToApi(authController.token!);
    setState(() => _isSaving = false);

    if (success) {
      Get.toNamed('/select-plan');
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
                        'Select Your Core Values',
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
                        final selectedCount = controller.selectedCoreValueIds.length +
                            (controller.customCoreValue.value != null && controller.customCoreValue.value!.isNotEmpty ? 1 : 0);
                        return Text(
                          'Choose 3-5 values that define who you are${selectedCount > 0 ? ' ($selectedCount/5 selected)' : ''}',
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

                        if (controller.availableCoreValues.isEmpty) {
                          return Center(
                            child: Text(
                              'No core values available',
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
                          itemCount: controller.availableCoreValues.length + 1,
                          itemBuilder: (context, index) {
                            if (index == controller.availableCoreValues.length) {
                              return Obx(() {
                                final hasCustomValue =
                                    controller.customCoreValue.value != null && controller.customCoreValue.value!.isNotEmpty;
                                return GestureDetector(
                                  onTap: _showCustomValueDialog,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                    decoration: SelectionStyles.chipBox(context, hasCustomValue),
                                    child: Center(
                                      child: Text(
                                        hasCustomValue ? controller.customCoreValue.value! : 'Custom',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: SelectionStyles.chipLabel(context, hasCustomValue),
                                      ),
                                    ),
                                  ),
                                );
                              });
                            }

                            final coreValue = controller.availableCoreValues[index];

                            return Obx(() {
                              final isSelected = controller.selectedCoreValueIds.contains(coreValue.id);
                              return GestureDetector(
                                onTap: () => controller.toggleCoreValue(coreValue.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: SelectionStyles.chipBox(context, isSelected),
                                  child: Center(
                                    child: Text(
                                      coreValue.name,
                                      textAlign: TextAlign.center,
                                      style: SelectionStyles.chipLabel(context, isSelected),
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
