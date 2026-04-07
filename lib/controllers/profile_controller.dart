import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/ambition_model.dart';
import '../data/models/core_value_model.dart';
import '../data/models/interest_model.dart';
import '../data/models/skill_model.dart';
import '../data/models/plan_model.dart';
import '../data/services/api_service.dart';
import '../utils/profile_avatar_cropper.dart';
import '../utils/toast_helper.dart';
import 'auth_controller.dart';

class ProfileController extends GetxController {
  final ApiService apiService = ApiService();
  final AuthController authController = Get.find<AuthController>();
  final ImagePicker _picker = ImagePicker();

  final isLoading = false.obs;
  final availableInterests = <InterestModel>[].obs;
  final availableCoreValues = <CoreValueModel>[].obs;
  final availableSkills = <SkillModel>[].obs;
  final availableAmbitions = <AmbitionModel>[].obs;
  final availablePlans = <PlanModel>[].obs;
  final selectedInterestNames = <String>[].obs;
  final selectedCoreValueNames = <String>[].obs;
  final selectedSkillNames = <String>[].obs;
  final selectedAmbitionNames = <String>[].obs;
  final customCoreValues = <String>[].obs;

  static const int maxCustomCoreValues = 5;

  final linkedinUrl = ''.obs;
  final facebookUrl = ''.obs;
  final instagramUrl = ''.obs;
  final xUrl = ''.obs;
  final snapchatUrl = ''.obs;
  final tiktokUrl = ''.obs;
  final otherUrl = ''.obs;

  void reset() {
    availableInterests.clear();
    availableCoreValues.clear();
    availableSkills.clear();
    availableAmbitions.clear();
    availablePlans.clear();
    selectedInterestNames.clear();
    selectedCoreValueNames.clear();
    selectedSkillNames.clear();
    selectedAmbitionNames.clear();
    customCoreValues.clear();
    linkedinUrl.value = '';
    facebookUrl.value = '';
    instagramUrl.value = '';
    xUrl.value = '';
    snapchatUrl.value = '';
    tiktokUrl.value = '';
    otherUrl.value = '';
    isLoading.value = false;
  }

  Future<void> loadInterests() async {
    try {
      isLoading.value = true;
      final interests = await apiService.getInterests();
      availableInterests.value = interests;

      final currentUser = authController.currentUser.value;
      if (currentUser?.interests != null) {
        selectedInterestNames.value = List<String>.from(currentUser!.interests!);
      }
    } catch (e) {
      ToastHelper.showError('Failed to load interests');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadSkills() async {
    try {
      isLoading.value = true;
      final skills = await apiService.getSkills();
      availableSkills.value = skills;

      final currentUser = authController.currentUser.value;
      if (currentUser?.skills != null) {
        selectedSkillNames.value = List<String>.from(currentUser!.skills!);
      }
    } catch (e) {
      ToastHelper.showError('Failed to load skills');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAmbitions() async {
    try {
      isLoading.value = true;
      final ambitions = await apiService.getAmbitions();
      availableAmbitions.value = ambitions;

      final currentUser = authController.currentUser.value;
      if (currentUser?.ambitions != null) {
        selectedAmbitionNames.value = List<String>.from(currentUser!.ambitions!);
      }
    } catch (e) {
      ToastHelper.showError('Failed to load ambitions');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadCoreValues() async {
    try {
      isLoading.value = true;
      final coreValues = await apiService.getCoreValues();
      availableCoreValues.value = coreValues;

      final currentUser = authController.currentUser.value;
      if (currentUser?.coreValues != null) {
        final userCoreValues = List<String>.from(currentUser!.coreValues!);
        final availableNames = coreValues.map((cv) => cv.name).toList();

        selectedCoreValueNames.clear();
        customCoreValues.clear();

        for (var value in userCoreValues) {
          if (availableNames.contains(value)) {
            selectedCoreValueNames.add(value);
          } else if (value.trim().isNotEmpty) {
            customCoreValues.add(value);
          }
        }
      } else {
        selectedCoreValueNames.clear();
        customCoreValues.clear();
      }
    } catch (e) {
      ToastHelper.showError('Failed to load core values');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPlans() async {
    try {
      isLoading.value = true;
      final token = authController.token;
      if (token == null) return;

      final plans = await apiService.getMemberships(token);
      availablePlans.value = plans;
    } catch (e) {
      ToastHelper.showError('Failed to load plans');
    } finally {
      isLoading.value = false;
    }
  }

  void toggleInterest(String interestName) {
    if (selectedInterestNames.contains(interestName)) {
      selectedInterestNames.remove(interestName);
    } else {
      selectedInterestNames.add(interestName);
    }
  }

  void toggleCoreValue(String coreValueName) {
    if (selectedCoreValueNames.contains(coreValueName)) {
      selectedCoreValueNames.remove(coreValueName);
    } else {
      selectedCoreValueNames.add(coreValueName);
    }
  }

  void toggleSkill(String skillName) {
    if (selectedSkillNames.contains(skillName)) {
      selectedSkillNames.remove(skillName);
    } else {
      selectedSkillNames.add(skillName);
    }
  }

  void toggleAmbition(String ambitionName) {
    if (selectedAmbitionNames.contains(ambitionName)) {
      selectedAmbitionNames.remove(ambitionName);
    } else {
      selectedAmbitionNames.add(ambitionName);
    }
  }

  /// Returns true if [raw] was added; false if empty or invalid (toast already shown).
  bool addCustomCoreValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      ToastHelper.showError('Enter a core value');
      return false;
    }

    final lower = value.toLowerCase();
    final presetLower = availableCoreValues.map((cv) => cv.name.toLowerCase()).toList();
    if (presetLower.contains(lower)) {
      ToastHelper.showError('This matches a value in the list above — tap it to select');
      return false;
    }
    if (customCoreValues.any((s) => s.toLowerCase() == lower)) {
      ToastHelper.showError('You already added this custom value');
      return false;
    }
    if (customCoreValues.length >= maxCustomCoreValues) {
      ToastHelper.showError('You can add up to $maxCustomCoreValues custom values');
      return false;
    }
    customCoreValues.add(value);
    return true;
  }

  /// Updates the custom entry matching [previous] (exact string as stored).
  /// Returns true on success or if the text is unchanged; false if invalid (toast shown).
  bool updateCustomCoreValue(String previous, String raw) {
    final index = customCoreValues.indexOf(previous);
    if (index < 0) return false;

    final value = raw.trim();
    if (value.isEmpty) {
      ToastHelper.showError('Enter a core value');
      return false;
    }
    if (value == previous) {
      return true;
    }

    final lower = value.toLowerCase();
    final presetLower = availableCoreValues.map((cv) => cv.name.toLowerCase()).toList();
    if (presetLower.contains(lower)) {
      ToastHelper.showError('This matches a value in the list above — tap it to select');
      return false;
    }
    final duplicateOther = customCoreValues.asMap().entries.any(
          (e) => e.key != index && e.value.toLowerCase() == lower,
        );
    if (duplicateOther) {
      ToastHelper.showError('You already added this custom value');
      return false;
    }

    final next = List<String>.from(customCoreValues);
    next[index] = value;
    customCoreValues.assignAll(next);
    return true;
  }

  void removeCustomCoreValue(String value) {
    customCoreValues.remove(value);
  }

  Future<bool> saveInterests() async {
    try {
      final token = authController.token;
      if (token == null) return false;

      await apiService.updateProfile(
        token: token,
        interests: selectedInterestNames.toList(),
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Interests updated');
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to update interests');
      return false;
    }
  }

  Future<bool> saveCoreValues() async {
    try {
      final token = authController.token;
      if (token == null) return false;

      final coreValuesToSave = [
        ...List<String>.from(selectedCoreValueNames),
        ...List<String>.from(customCoreValues),
      ];

      await apiService.updateProfile(
        token: token,
        coreValues: coreValuesToSave,
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Core values updated');
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to update core values');
      return false;
    }
  }

  Future<bool> saveSkills() async {
    try {
      final token = authController.token;
      if (token == null) return false;

      await apiService.updateProfile(
        token: token,
        skills: selectedSkillNames.toList(),
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Skills updated');
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to update skills');
      return false;
    }
  }

  Future<bool> saveAmbitions() async {
    try {
      final token = authController.token;
      if (token == null) return false;

      await apiService.updateProfile(
        token: token,
        ambitions: selectedAmbitionNames.toList(),
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Ambitions updated');
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to update ambitions');
      return false;
    }
  }

  Future<void> pickAndUploadProfileImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );

      if (image == null) return;

      final ctx = Get.context;
      if (ctx == null) return;

      final croppedPath = await cropProfilePictureFromPath(ctx, image.path);
      if (croppedPath == null) return;

      final token = authController.token;
      if (token == null) return;

      ToastHelper.showInfo('Uploading image...');

      await apiService.updateProfile(
        token: token,
        avatar: File(croppedPath),
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Profile picture updated');
    } catch (e) {
      ToastHelper.showError('Failed to upload image');
    }
  }

  void showImageSourceDialog(Function(ImageSource) onSourceSelected) {
    final ctx = Get.context;
    if (ctx == null) return;
    final cs = Theme.of(ctx).colorScheme;

    Get.dialog(
      AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Choose Image Source',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: cs.primary),
              title: Text(
                'Camera',
                style: TextStyle(color: cs.onSurface),
              ),
              onTap: () {
                Get.back();
                onSourceSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: cs.primary),
              title: Text(
                'Gallery',
                style: TextStyle(color: cs.onSurface),
              ),
              onTap: () {
                Get.back();
                onSourceSelected(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadSocialLinks() async {
    final currentUser = authController.currentUser.value;
    if (currentUser != null) {
      linkedinUrl.value = currentUser.linkedinUrl ?? '';
      facebookUrl.value = currentUser.facebookUrl ?? '';
      instagramUrl.value = currentUser.instagramUrl ?? '';
      xUrl.value = currentUser.xUrl ?? '';
      snapchatUrl.value = currentUser.snapchatUrl ?? '';
      tiktokUrl.value = currentUser.tiktokUrl ?? '';
      otherUrl.value = currentUser.otherUrl ?? '';
    }
  }

  Future<bool> saveSocialLinks() async {
    try {
      final token = authController.token;
      if (token == null) return false;

      isLoading.value = true;

      await apiService.updateProfile(
        token: token,
        linkedinUrl: linkedinUrl.value.isEmpty ? null : linkedinUrl.value,
        facebookUrl: facebookUrl.value.isEmpty ? null : facebookUrl.value,
        instagramUrl: instagramUrl.value.isEmpty ? null : instagramUrl.value,
        xUrl: xUrl.value.isEmpty ? null : xUrl.value,
        snapchatUrl: snapchatUrl.value.isEmpty ? null : snapchatUrl.value,
        tiktokUrl: tiktokUrl.value.isEmpty ? null : tiktokUrl.value,
        otherUrl: otherUrl.value.isEmpty ? null : otherUrl.value,
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Social links updated');
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to update social links');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
