import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final OnboardingController controller = Get.find<OnboardingController>();
  final AuthController authController = Get.find<AuthController>();
  // final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController professionController = TextEditingController();

  final List<String> genderOptions = ['Male', 'Female'];
  final List<String> stateOptions = ['Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'];

  @override
  void dispose() {
    // nameController.dispose();
    bioController.dispose();
    cityController.dispose();
    professionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1924),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Color(0xFF4A90E2),
              surface: Color(0xFF3D5A80),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.dateOfBirth = picked;
      });
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D5A80),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Photo Library', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                controller.pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                controller.pickImageFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D5A80),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: genderOptions.map((gender) {
            return ListTile(
              title: Text(
                gender,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              onTap: () {
                setState(() {
                  controller.gender = gender;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D5A80),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 400,
          child: ListView.builder(
            itemCount: stateOptions.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                  stateOptions[index],
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  setState(() {
                    controller.state = stateOptions[index];
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isSaving = false;

  Future<void> _handleContinue() async {
    // controller.name = nameController.text;
    controller.bio = bioController.text;
    controller.city = cityController.text;
    controller.profession = professionController.text;

    if (!controller.validateProfileForm()) return;
    if (authController.token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);
    final success = await controller.saveProfileToApi(authController.token!);
    setState(() => _isSaving = false);

    if (success) {
      Get.toNamed('/terms-conditions');
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
                        'Create Your Profile',
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Tell us about yourself to help us connect you with the right people',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      GetBuilder<OnboardingController>(
                        builder: (ctrl) {
                          return GestureDetector(
                            onTap: _showImageOptions,
                            child: Stack(
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    image: ctrl.profileImage != null
                                        ? DecorationImage(
                                            image: FileImage(ctrl.profileImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: ctrl.profileImage == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 80,
                                          color: Colors.white60,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => controller.pickImageFromGallery(),
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Photo Library'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => controller.pickImageFromCamera(),
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Align(
                      //   alignment: Alignment.centerLeft,
                      //   child: RichText(
                      //     text: const TextSpan(
                      //       children: [
                      //         TextSpan(
                      //           text: 'Name ',
                      //           style: TextStyle(
                      //             fontSize: 16,
                      //             fontWeight: FontWeight.w500,
                      //             color: Colors.white,
                      //           ),
                      //         ),
                      //         TextSpan(
                      //           text: '*',
                      //           style: TextStyle(
                      //             fontSize: 16,
                      //             fontWeight: FontWeight.w500,
                      //             color: Colors.red,
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 8),
                      // CustomTextField(
                      //   controller: nameController,
                      //   hint: 'Enter your name',
                      // ),
                      // const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bio',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bioController,
                        maxLines: 4,
                        maxLength: 200,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tell us something about yourself...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Date of Birth ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            // mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                controller.dateOfBirth != null ? DateFormat('MMMM dd, yyyy').format(controller.dateOfBirth!) : 'Select Date of Birth',
                                style: TextStyle(
                                  color: controller.dateOfBirth != null ? Colors.white : Colors.white60,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Gender ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showGenderPicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.gender ?? 'Select Gender',
                                style: TextStyle(
                                  color: controller.gender != null ? Colors.white : Colors.white60,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white60,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'City ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: cityController,
                        hint: 'Enter your city',
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'State ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showStatePicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.state ?? 'Select State',
                                style: TextStyle(
                                  color: controller.state != null ? Colors.white : Colors.white60,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white60,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Profession ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: professionController,
                        hint: 'Enter your profession',
                      ),
                      // const SizedBox(height: 32),
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
