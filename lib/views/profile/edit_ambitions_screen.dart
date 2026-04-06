import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/selection_styles.dart';
import '../../controllers/profile_controller.dart';
import '../../widgets/custom_button.dart';

class EditAmbitionsScreen extends StatefulWidget {
  const EditAmbitionsScreen({super.key});

  @override
  State<EditAmbitionsScreen> createState() => _EditAmbitionsScreenState();
}

class _EditAmbitionsScreenState extends State<EditAmbitionsScreen> {
  final ProfileController controller = Get.put(ProfileController());
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    controller.loadAmbitions();
  }

  Future<void> _handleSave() async {
    if (controller.selectedAmbitionNames.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    final success = await controller.saveAmbitions();
    setState(() => _isSaving = false);

    if (success) {
      Get.back();
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
                        'Edit Ambitions',
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
                        final n = controller.selectedAmbitionNames.length;
                        return Text(
                          n > 0
                              ? 'Choose any that apply ($n selected)'
                              : 'Choose any that apply',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return Center(
                            child: CircularProgressIndicator(color: cs.primary),
                          );
                        }

                        if (controller.availableAmbitions.isEmpty) {
                          return Center(
                            child: Text(
                              'No ambitions available',
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
                          itemCount: controller.availableAmbitions.length,
                          itemBuilder: (context, index) {
                            final ambition = controller.availableAmbitions[index];

                            return Obx(() {
                              final isSelected = controller.selectedAmbitionNames.contains(ambition.name);
                              return GestureDetector(
                                onTap: () => controller.toggleAmbition(ambition.name),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                  decoration: SelectionStyles.chipBox(context, isSelected),
                                  child: Center(
                                    child: Text(
                                      ambition.name,
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
                padding: const EdgeInsets.all(24.0),
                child: CustomButton(
                  text: _isSaving ? 'Saving...' : 'Save Changes',
                  onPressed: _isSaving ? () {} : _handleSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
