import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';
import '../utils/toast_helper.dart';

class AuthController extends GetxController {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  final _user = Rxn<User>();
  final _token = Rxn<String>();
  final _isLoading = false.obs;

  User? get user => _user.value;
  Rxn<User> get currentUser => _user;
  String? get token => _token.value;
  bool get isLoading => _isLoading.value;
  bool get isAuthenticated => _token.value != null;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  void checkAuthStatus() {
    final token = _storageService.getToken();
    final userData = _storageService.getUserData();

    if (token != null && userData != null) {
      _token.value = token;
      _user.value = User.fromJson(jsonDecode(userData));
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? displayName,
    String? bio,
    String? dateOfBirth,
    String? gender,
    List<String>? interests,
    File? avatar,
  }) async {
    try {
      _isLoading.value = true;

      final response = await _apiService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        displayName: displayName,
        bio: bio,
        dateOfBirth: dateOfBirth,
        gender: gender,
        interests: interests,
        avatar: avatar,
      );

      _token.value = response.token;
      _user.value = response.user;

      _storageService.saveToken(response.token);
      _storageService.saveUserData(jsonEncode(response.user.toJson()));

      _isLoading.value = false;
      ToastHelper.showSuccess('Account created successfully');
      return true;
    } catch (e) {
      _isLoading.value = false;
      ToastHelper.showError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading.value = true;

      final response = await _apiService.login(
        email: email,
        password: password,
      );

      _token.value = response.token;
      _user.value = response.user;

      _storageService.saveToken(response.token);
      _storageService.saveUserData(jsonEncode(response.user.toJson()));

      _isLoading.value = false;
      ToastHelper.showSuccess('Logged in successfully');
      return true;
    } catch (e) {
      _isLoading.value = false;
      ToastHelper.showError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_token.value != null) {
        await _apiService.logout(_token.value!);
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _token.value = null;
      _user.value = null;
      _storageService.clearAll();
      Get.offAllNamed('/auth');
    }
  }

  Future<bool> getProfile() async {
    if (_token.value == null) return false;

    try {
      _isLoading.value = true;

      final user = await _apiService.getProfile(_token.value!);

      _user.value = user;
      _storageService.saveUserData(jsonEncode(user.toJson()));

      _isLoading.value = false;
      return true;
    } catch (e) {
      _isLoading.value = false;
      ToastHelper.showError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> fetchUserProfile() async {
    return await getProfile();
  }

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_token.value == null) return false;

    try {
      _isLoading.value = true;

      final user = await _apiService.updateProfile(
        token: _token.value!,
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
      );

      _user.value = user;
      _storageService.saveUserData(jsonEncode(user.toJson()));

      _isLoading.value = false;
      ToastHelper.showSuccess('Profile updated successfully');
      return true;
    } catch (e) {
      _isLoading.value = false;
      ToastHelper.showError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }
}
