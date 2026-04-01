import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
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
  final List<String> accountTypeOptions = ['Personal', 'Professional'];
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
            // colorScheme: const ColorScheme.dark(
            //   primary: Colors.white,
            //   onPrimary: Colors.white,
            //   surface: Color(0xFF1A1A1A),
            //   onSurface: Colors.white,
            // ),
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
      backgroundColor: context.proxi.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: cs.onSurface),
                title: Text('Photo Library', style: TextStyle(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: cs.onSurface),
                title: Text('Camera', style: TextStyle(color: cs.onSurface)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.pickImageFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.proxi.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: genderOptions.map((gender) {
              return ListTile(
                title: Text(
                  gender,
                  style: TextStyle(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  setState(() {
                    controller.gender = gender;
                  });
                  Navigator.pop(sheetContext);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showAccountTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.proxi.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: accountTypeOptions.map((type) {
              return ListTile(
                title: Text(
                  type,
                  style: TextStyle(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  setState(() {
                    controller.accountType = type;
                  });
                  Navigator.pop(sheetContext);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showStatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.proxi.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: stateOptions.length,
              itemBuilder: (listContext, index) {
                return ListTile(
                  title: Text(
                    stateOptions[index],
                    style: TextStyle(color: cs.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () {
                    setState(() {
                      controller.state = stateOptions[index];
                    });
                    Navigator.pop(sheetContext);
                  },
                );
              },
            ),
          ),
        );
      },
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
                        'Create Your Profile',
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Tell us about yourself to help us connect you with the right people',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
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
                                    color: cs.surfaceContainerHighest.withOpacity(0.65),
                                    image: ctrl.profileImage != null
                                        ? DecorationImage(
                                            image: FileImage(ctrl.profileImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: ctrl.profileImage == null
                                      ? Icon(
                                          Icons.person,
                                          size: 80,
                                          color: cs.onSurfaceVariant,
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
                            icon: Icon(Icons.photo_library, size: 18, color: cs.onPrimary),
                            label: Text('Photo Library', style: TextStyle(color: cs.onPrimary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => controller.pickImageFromCamera(),
                            icon: Icon(Icons.camera_alt, size: 18, color: cs.onPrimary),
                            label: Text('Camera', style: TextStyle(color: cs.onPrimary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
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
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Account Type ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const TextSpan(
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
                        onTap: _showAccountTypePicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.accountType,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bioController,
                        maxLines: 4,
                        maxLength: 200,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Tell us something about yourself...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.85)),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withOpacity(0.65),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Date of Birth ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const TextSpan(
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
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            // mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                controller.dateOfBirth != null ? DateFormat('MMMM dd, yyyy').format(controller.dateOfBirth!) : 'Select Date of Birth',
                                style: TextStyle(
                                  color: controller.dateOfBirth != null ? cs.onSurface : cs.onSurfaceVariant,
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
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Gender ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const TextSpan(
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
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.gender ?? 'Select Gender',
                                style: TextStyle(
                                  color: controller.gender != null ? cs.onSurface : cs.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'City ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const TextSpan(
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
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'State ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const TextSpan(
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
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.state ?? 'Select State',
                                style: TextStyle(
                                  color: controller.state != null ? cs.onSurface : cs.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Profession ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const TextSpan(
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
