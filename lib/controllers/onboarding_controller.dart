import 'dart:io';

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

class OnboardingController extends GetxController {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  File? profileImage;
  String name = '';
  String accountType = 'Personal';
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
  final RxList<String> customCoreValues = <String>[].obs;

  final RxList<SkillModel> availableSkills = <SkillModel>[].obs;
  final RxList<int> selectedSkillIds = <int>[].obs;

  final RxList<AmbitionModel> availableAmbitions = <AmbitionModel>[].obs;
  final RxList<int> selectedAmbitionIds = <int>[].obs;

  static const int maxCustomCoreValues = 5;

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
        fetchSkills(),
        fetchAmbitions(),
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

  Future<void> fetchSkills() async {
    try {
      final skills = await _apiService.getSkills();
      availableSkills.value = skills;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchAmbitions() async {
    try {
      final ambitions = await _apiService.getAmbitions();
      availableAmbitions.value = ambitions;
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
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (image == null) return;

      final ctx = Get.context;
      if (ctx == null) return;
      final croppedPath = await cropProfilePictureFromPath(ctx, image.path);
      if (croppedPath == null) return;

      profileImage = File(croppedPath);
      update();
    } catch (e) {
      ToastHelper.showError('Failed to pick image: $e');
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (image == null) return;

      final ctx = Get.context;
      if (ctx == null) return;
      final croppedPath = await cropProfilePictureFromPath(ctx, image.path);
      if (croppedPath == null) return;

      profileImage = File(croppedPath);
      update();
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
      selectedCoreValueIds.add(coreValueId);
    }
  }

  void toggleSkill(int skillId) {
    if (selectedSkillIds.contains(skillId)) {
      selectedSkillIds.remove(skillId);
    } else {
      selectedSkillIds.add(skillId);
    }
  }

  void toggleAmbition(int ambitionId) {
    if (selectedAmbitionIds.contains(ambitionId)) {
      selectedAmbitionIds.remove(ambitionId);
    } else {
      selectedAmbitionIds.add(ambitionId);
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
        displayName: name.trim(),
        bio: bio.trim(),
        dateOfBirth: dob,
        gender: gender,
        city: city.trim(),
        state: state,
        profession: profession.trim(),
        avatar: profileImage,
        accountType: accountType.toLowerCase(),
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
    final names = selectedCoreValueIds
        .map((id) => availableCoreValues.firstWhereOrNull((cv) => cv.id == id)?.name)
        .whereType<String>()
        .toList();
    names.addAll(customCoreValues);
    return names;
  }

  List<String> _getSelectedSkillNames() {
    return selectedSkillIds
        .map((id) => availableSkills.firstWhereOrNull((s) => s.id == id)?.name)
        .whereType<String>()
        .toList();
  }

  List<String> _getSelectedAmbitionNames() {
    return selectedAmbitionIds
        .map((id) => availableAmbitions.firstWhereOrNull((a) => a.id == id)?.name)
        .whereType<String>()
        .toList();
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

  Future<bool> saveSkillsToApi(String token) async {
    try {
      isLoading.value = true;
      await _apiService.updateProfile(
        token: token,
        skills: _getSelectedSkillNames(),
      );
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to save skills: ${e.toString().replaceAll('Exception: ', '')}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveAmbitionsToApi(String token) async {
    try {
      isLoading.value = true;
      await _apiService.updateProfile(
        token: token,
        ambitions: _getSelectedAmbitionNames(),
      );
      return true;
    } catch (e) {
      ToastHelper.showError('Failed to save ambitions: ${e.toString().replaceAll('Exception: ', '')}');
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
    final hasSelection = selectedCoreValueIds.isNotEmpty || customCoreValues.isNotEmpty;
    if (!hasSelection) {
      ToastHelper.showError('Please select at least one core value');
      return false;
    }
    return true;
  }

  bool validateSkillsSelection() {
    if (selectedSkillIds.isEmpty) {
      ToastHelper.showError('Please select at least one skill');
      return false;
    }
    return true;
  }

  bool validateAmbitionsSelection() {
    if (selectedAmbitionIds.isEmpty) {
      ToastHelper.showError('Please select at least one ambition');
      return false;
    }
    return true;
  }

  void reset() {
    profileImage = null;
    name = '';
    bio = '';
    dateOfBirth = null;
    gender = null;
    city = '';
    state = null;
    profession = '';
    acceptedTerms = false;
    selectedInterestIds.clear();
    selectedCoreValueIds.clear();
    customCoreValues.clear();
    selectedSkillIds.clear();
    selectedAmbitionIds.clear();
    selectedPlan.value = null;
  }
}
