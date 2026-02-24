import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/profile_controller.dart';
import '../../widgets/custom_button.dart';

class EditInterestsScreen extends StatefulWidget {
  const EditInterestsScreen({super.key});

  @override
  State<EditInterestsScreen> createState() => _EditInterestsScreenState();
}

class _EditInterestsScreenState extends State<EditInterestsScreen> {
  final ProfileController controller = Get.put(ProfileController());
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    controller.loadInterests();
  }

  Future<void> _handleSave() async {
    if (controller.selectedInterestNames.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    final success = await controller.saveInterests();
    setState(() => _isSaving = false);

    if (success) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF0A0A0A)],
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
                        'Edit Interests',
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
                        final selectedCount = controller.selectedInterestNames.length;
                        return Text(
                          selectedCount > 0 ? 'Choose activities you enjoy ($selectedCount selected)' : 'Choose activities you enjoy',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
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
                              final isSelected = controller.selectedInterestNames.contains(interest.name);
                              return GestureDetector(
                                onTap: () => controller.toggleInterest(interest.name),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
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
                                        color: isSelected ? Colors.white : Colors.white,
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
