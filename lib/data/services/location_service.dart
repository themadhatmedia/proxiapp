import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import 'api_service.dart';

class LocationService extends GetxService {
  final ApiService _apiService = ApiService();
  Timer? _locationUpdateTimer;
  static const Duration updateInterval = Duration(minutes: 5);

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  void startBackgroundLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(updateInterval, (timer) async {
      await _updateLocationInBackground();
    });
    _updateLocationInBackground();
  }

  void stopBackgroundLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _updateLocationInBackground() async {
    try {
      final AuthController authController = Get.find<AuthController>();
      final token = authController.token;

      if (token == null) {
        return;
      }

      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        return;
      }

      final position = await getCurrentLocation();
      if (position != null) {
        await _apiService.updateLocation(
          token: token,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void onClose() {
    stopBackgroundLocationUpdates();
    super.onClose();
  }
}
