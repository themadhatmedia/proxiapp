import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/core_value_model.dart';
import '../data/models/interest_model.dart';
import '../data/models/plan_model.dart';
import '../data/services/api_service.dart';
import '../utils/toast_helper.dart';
import 'auth_controller.dart';

class ProfileController extends GetxController {
  final ApiService apiService = ApiService();
  final AuthController authController = Get.find<AuthController>();
  final ImagePicker _picker = ImagePicker();

  final isLoading = false.obs;
  final availableInterests = <InterestModel>[].obs;
  final availableCoreValues = <CoreValueModel>[].obs;
  final availablePlans = <PlanModel>[].obs;
  final selectedInterestNames = <String>[].obs;
  final selectedCoreValueNames = <String>[].obs;
  final customCoreValue = Rxn<String>();

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
        customCoreValue.value = null;

        for (var value in userCoreValues) {
          if (availableNames.contains(value)) {
            selectedCoreValueNames.add(value);
          } else {
            customCoreValue.value = value;
          }
        }
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
    } else if (selectedCoreValueNames.length < 5) {
      selectedCoreValueNames.add(coreValueName);
    } else {
      ToastHelper.showError('You can select up to 5 core values');
    }
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

      final coreValuesToSave = List<String>.from(selectedCoreValueNames);
      if (customCoreValue.value != null && customCoreValue.value!.isNotEmpty) {
        coreValuesToSave.add(customCoreValue.value!);
      }

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

  Future<void> pickAndUploadProfileImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      final token = authController.token;
      if (token == null) return;

      ToastHelper.showInfo('Uploading image...');

      await apiService.updateProfile(
        token: token,
        avatar: File(image.path),
      );

      await authController.fetchUserProfile();
      ToastHelper.showSuccess('Profile picture updated');
    } catch (e) {
      ToastHelper.showError('Failed to upload image');
    }
  }

  void showImageSourceDialog(Function(ImageSource) onSourceSelected) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF3D5A80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Choose Image Source',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                onSourceSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Colors.white),
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
}
