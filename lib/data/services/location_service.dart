import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../utils/location_permission_flow.dart';
import '../../controllers/auth_controller.dart';
import 'api_service.dart';

class LocationService extends GetxService {
  final ApiService _apiService = ApiService();
  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionSub;

  static const Duration updateInterval = Duration(minutes: 5);
  static const Duration _minUpdateGap = Duration(minutes: 3);
  static const double _minMoveMeters = 75;

  DateTime? _lastServerPush;
  Position? _lastPushedPosition;

  @override
  void onInit() {
    super.onInit();
    if (kIsWeb) return;
    try {
      ever(Get.find<AuthController>().reactiveToken, (String? t) {
        if (t == null) {
          stopBackgroundLocationUpdates();
        }
      });
    } catch (_) {
      // AuthController not registered yet (tests / unusual startup order).
    }
  }

  LocationSettings _positionStreamSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
          intervalDuration: updateInterval,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Proxi',
            notificationText: 'Updating location for proximity alerts',
            notificationChannelName: 'Location updates',
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
          activityType: ActivityType.other,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        );
    }
  }

  Future<bool> checkAndRequestPermission() async {
    if (!kIsWeb) {
      if (!await LocationPermissionFlow.ensureDisclosureBeforeLocationAccess()) {
        return false;
      }
    }

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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

  Future<bool> _hasAlwaysLocationPermission() async {
    if (kIsWeb) return false;
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always;
  }

  Future<void> _pushLocationToServer(Position position) async {
    try {
      final AuthController authController = Get.find<AuthController>();
      final String? token = authController.token;

      if (token == null) {
        return;
      }

      final DateTime now = DateTime.now();
      if (_lastServerPush != null) {
        final Duration gap = now.difference(_lastServerPush!);
        if (gap < _minUpdateGap) {
          if (_lastPushedPosition != null) {
            final double moved = Geolocator.distanceBetween(
              _lastPushedPosition!.latitude,
              _lastPushedPosition!.longitude,
              position.latitude,
              position.longitude,
            );
            if (moved < _minMoveMeters) return;
          } else {
            return;
          }
        }
      }

      _lastServerPush = now;
      _lastPushedPosition = position;

      _apiService.queueLocationUpdate(
        token: token,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('LocationService: $e');
    }
  }

  void _onPosition(Position position) {
    unawaited(_pushLocationToServer(position));
  }

  /// Starts background refreshes only when Always permission is already granted.
  /// Permission prompts must go through [LocationPermissionFlow] (disclosure first).
  Future<void> startBackgroundLocationUpdates() async {
    if (kIsWeb) return;

    stopBackgroundLocationUpdates();

    if (!await _hasAlwaysLocationPermission()) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _positionStreamSettings(),
    ).listen(
      _onPosition,
      onError: (Object e, StackTrace st) {
        debugPrint('LocationService stream: $e');
      },
    );

    _locationUpdateTimer = Timer.periodic(updateInterval, (_) {
      unawaited(_updateLocationInBackground());
    });
    unawaited(_updateLocationInBackground());
  }

  void stopBackgroundLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    unawaited(_positionSub?.cancel());
    _positionSub = null;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final bool hasPermission = await checkAndRequestPermission();
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

  Future<void> _updateLocationInBackground() async {
    try {
      final AuthController authController = Get.find<AuthController>();
      final String? token = authController.token;

      if (token == null) {
        return;
      }

      if (!await _hasAlwaysLocationPermission()) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _pushLocationToServer(position);
    } catch (e) {
      debugPrint('LocationService: $e');
    }
  }

  @override
  void onClose() {
    stopBackgroundLocationUpdates();
    super.onClose();
  }
}
