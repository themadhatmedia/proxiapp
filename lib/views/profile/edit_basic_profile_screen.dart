import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditBasicProfileScreen extends StatefulWidget {
  const EditBasicProfileScreen({super.key});

  @override
  State<EditBasicProfileScreen> createState() => _EditBasicProfileScreenState();
}

class _EditBasicProfileScreenState extends State<EditBasicProfileScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();

  late TextEditingController nameController;
  late TextEditingController bioController;
  late TextEditingController cityController;
  late TextEditingController professionController;

  DateTime? selectedDate;
  String? selectedGender;
  String? selectedState;
  String? selectedAccountType;
  bool _isSaving = false;

  final List<String> genders = ['Male', 'Female'];
  final List<String> accountTypes = ['Personal', 'Professional'];
  final List<String> stateOptions = ['Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'];

  @override
  void initState() {
    super.initState();
    final user = authController.currentUser.value;

    nameController = TextEditingController(text: user?.displayName ?? user?.name ?? '');
    bioController = TextEditingController(text: user?.profile?.bio ?? '');
    cityController = TextEditingController(text: user?.city ?? '');
    professionController = TextEditingController(text: user?.profession ?? '');
    selectedDate = user?.dateOfBirth;
    selectedGender = user?.gender;
    selectedState = user?.state;
    selectedAccountType = user?.accountType ?? 'Personal';
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    cityController.dispose();
    professionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // colorScheme: const ColorScheme.light(
            //   primary: Colors.white,
            //   onPrimary: Colors.white,
            //   onSurface: Colors.black,
            // ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
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
                      selectedState = stateOptions[index];
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
            children: accountTypes.map((type) {
              return ListTile(
                title: Text(
                  type.capitalize.toString(),
                  style: TextStyle(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  setState(() {
                    selectedAccountType = type;
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

  Future<void> _handleSave() async {
    if (nameController.text.trim().isEmpty) {
      ToastHelper.showError('Name is required');
      return;
    }

    // if (bioController.text.trim().isEmpty) {
    //   ToastHelper.showError('Bio is required');
    //   return;
    // }

    final token = authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await apiService.updateProfile(
        token: token,
        displayName: nameController.text.trim(),
        bio: bioController.text.trim(),
        dateOfBirth: selectedDate?.toIso8601String(),
        gender: selectedGender,
        city: cityController.text.trim().isNotEmpty ? cityController.text.trim() : null,
        state: selectedState,
        profession: professionController.text.trim().isNotEmpty ? professionController.text.trim() : null,
        accountType: selectedAccountType!.toLowerCase(),
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Profile updated successfully');
      Get.back();
    } catch (e) {
      ToastHelper.showError('Failed to update profile');
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
                        'Edit Profile',
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
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        hint: 'Name',
                        controller: nameController,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showAccountTypePicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedAccountType.toString().capitalize ?? 'Account Type',
                                style: TextStyle(
                                  color: selectedAccountType != null ? cs.onSurface : cs.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: cs.onSurfaceVariant,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bioController,
                        maxLines: 4,
                        maxLength: 200,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Bio',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.85)),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withOpacity(0.65),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: cs.outline.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: cs.outline.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate != null ? DateFormat('MMM dd, yyyy').format(selectedDate!) : 'Date of Birth',
                                style: TextStyle(
                                  color: selectedDate != null ? cs.onSurface : cs.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: cs.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.45),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedGender,
                            hint: Text(
                              'Gender',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            isExpanded: true,
                            dropdownColor: context.proxi.surfaceCard,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                            ),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: cs.onSurfaceVariant,
                            ),
                            items: genders.map((String gender) {
                              return DropdownMenuItem<String>(
                                value: gender,
                                child: Text(gender),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedGender = newValue;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        hint: 'City',
                        controller: cityController,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showStatePicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedState ?? 'State',
                                style: TextStyle(
                                  color: selectedState != null ? cs.onSurface : cs.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: cs.onSurfaceVariant,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Professional',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        hint: 'Profession',
                        controller: professionController,
                        keyboardType: TextInputType.text,
                      ),
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
