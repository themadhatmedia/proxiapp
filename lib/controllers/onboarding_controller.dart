import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/core_value_model.dart';
import '../data/models/interest_model.dart';
import '../data/models/plan_model.dart';
import '../data/services/api_service.dart';
import '../utils/toast_helper.dart';

class OnboardingController extends GetxController {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  File? profileImage;
  String name = '';
  String bio = '';
  DateTime? dateOfBirth;
  String? gender;
  String city = '';
  String? state;
  String profession = '';

  bool acceptedTerms = false;

  final RxList<InterestModel> availableInterests = <InterestModel>[].obs;
  final RxList<int> selectedInterestIds = <int>[].obs;

  final RxList<CoreValueModel> availableCoreValues = <CoreValueModel>[].obs;
  final RxList<int> selectedCoreValueIds = <int>[].obs;
  final Rx<String?> customCoreValue = Rx<String?>(null);

  final RxList<PlanModel> availablePlans = <PlanModel>[].obs;
  final Rx<PlanModel?> selectedPlan = Rx<PlanModel?>(null);

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadMasterData();
  }

  Future<void> loadMasterData() async {
    try {
      isLoading.value = true;
      await Future.wait([
        fetchInterests(),
        fetchCoreValues(),
      ]);
    } catch (e) {
      ToastHelper.showError('Failed to load data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchInterests() async {
    try {
      final interests = await _apiService.getInterests();
      availableInterests.value = interests;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchCoreValues() async {
    try {
      final coreValues = await _apiService.getCoreValues();
      availableCoreValues.value = coreValues;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchPlans(String token) async {
    try {
      isLoading.value = true;
      final plans = await _apiService.getMemberships(token);
      availablePlans.value = plans;

      final freePlan = plans.firstWhereOrNull((plan) => plan.isFree);
      if (freePlan != null) {
        selectedPlan.value = freePlan;
      } else if (plans.isNotEmpty) {
        selectedPlan.value = plans.first;
      }
    } catch (e) {
      ToastHelper.showError('Failed to load plans: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        profileImage = File(image.path);
        update();
      }
    } catch (e) {
      ToastHelper.showError('Failed to pick image: $e');
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        profileImage = File(image.path);
        update();
      }
    } catch (e) {
      ToastHelper.showError('Failed to take photo: $e');
    }
  }

  void toggleInterest(int interestId) {
    if (selectedInterestIds.contains(interestId)) {
      selectedInterestIds.remove(interestId);
    } else {
      selectedInterestIds.add(interestId);
    }
  }

  void toggleCoreValue(int coreValueId) {
    if (selectedCoreValueIds.contains(coreValueId)) {
      selectedCoreValueIds.remove(coreValueId);
    } else {
      if (selectedCoreValueIds.length < 5) {
        selectedCoreValueIds.add(coreValueId);
      } else {
        ToastHelper.showInfo('You can only select up to 5 core values');
      }
    }
  }

  void selectPlan(PlanModel plan) {
    selectedPlan.value = plan;
  }

  Future<bool> saveProfileToApi(String token) async {
    try {
      isLoading.value = true;

      final dob = dateOfBirth != null ? '${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}' : null;
      await _apiService.updateProfile(
        token: token,
        // displayName: name.trim(),
        bio: bio.trim(),
        dateOfBirth: dob,
        gender: gender,
        city: city.trim(),
        state: state,
        profession: profession.trim(),
        avatar: profileImage,
      );
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to save profile: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  List<String> _getSelectedInterestNames() {
    return selectedInterestIds.map((id) => availableInterests.firstWhereOrNull((i) => i.id == id)?.name).whereType<String>().toList();
  }

  List<String> _getSelectedCoreValueNames() {
    final names = selectedCoreValueIds.map((id) => availableCoreValues.firstWhereOrNull((cv) => cv.id == id)?.name).whereType<String>().toList();
    if (customCoreValue.value != null && customCoreValue.value!.isNotEmpty) {
      names.add(customCoreValue.value!);
    }
    return names;
  }

  Future<bool> saveInterestsToApi(String token) async {
    try {
      isLoading.value = true;
      await _apiService.updateProfile(
        token: token,
        interests: _getSelectedInterestNames(),
      );
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to save interests: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveCoreValuesToApi(String token) async {
    try {
      isLoading.value = true;
      await _apiService.updateProfile(
        token: token,
        coreValues: _getSelectedCoreValueNames(),
      );
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to save core values: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> subscribeMembershipToApi(String token) async {
    if (selectedPlan.value == null) return false;
    try {
      isLoading.value = true;
      await _apiService.subscribeMembership(
        token: token,
        membershipId: selectedPlan.value!.id,
      );
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to subscribe: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  bool validateProfileForm() {
    // if (name.trim().isEmpty) {
    //   ToastHelper.showError('Please enter your name');
    //   return false;
    // }
    if (bio.trim().isEmpty) {
      ToastHelper.showError('Please enter your bio');
      return false;
    }
    if (dateOfBirth == null) {
      ToastHelper.showError('Please select your date of birth');
      return false;
    }
    if (gender == null || gender!.isEmpty) {
      ToastHelper.showError('Please select your gender');
      return false;
    }
    if (city.trim().isEmpty) {
      ToastHelper.showError('Please enter your city');
      return false;
    }
    if (state == null || state!.isEmpty) {
      ToastHelper.showError('Please select your state');
      return false;
    }
    if (profession.trim().isEmpty) {
      ToastHelper.showError('Please enter your profession');
      return false;
    }
    return true;
  }

  bool validateInterestsSelection() {
    if (selectedInterestIds.isEmpty) {
      ToastHelper.showError('Please select at least one interest');
      return false;
    }
    return true;
  }

  bool validateCoreValuesSelection() {
    final hasSelection = selectedCoreValueIds.isNotEmpty || (customCoreValue.value != null && customCoreValue.value!.isNotEmpty);
    if (!hasSelection) {
      ToastHelper.showError('Please select at least one core value');
      return false;
    }
    return true;
  }

  void reset() {
    profileImage = null;
    name = '';
    dateOfBirth = null;
    gender = null;
    city = '';
    state = null;
    profession = '';
    acceptedTerms = false;
    selectedInterestIds.clear();
    selectedCoreValueIds.clear();
    customCoreValue.value = null;
    selectedPlan.value = null;
  }
}
