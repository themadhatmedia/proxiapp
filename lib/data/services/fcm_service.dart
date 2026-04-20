import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controllers/auth_controller.dart';
import 'api_service.dart';

/// Registers FCM token with the profile API (`firebaseToken`) when the user is logged in.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _storageKey = 'fcm_profile_token_sig';

  bool _listenerAttached = false;

  /// Call once after [Firebase.initializeApp] on Android and iOS.
  Future<void> install() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (_listenerAttached) return;
    _listenerAttached = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      syncTokenToProfileIfNeeded();
    });

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Kept for call sites that still reference the old name.
  Future<void> installAndroid() => install();

  static void clearStoredSyncSignature() {
    GetStorage().remove(_storageKey);
  }

  /// Requests notification permission, reads the FCM token, and POSTs profile
  /// with [firebase_token] only when it changed for this user.
  Future<void> syncTokenToProfileIfNeeded() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated || auth.token == null || auth.user == null) return;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok) return;
    } else {
      final perm = await Permission.notification.request();
      if (!perm.isGranted) return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    final sig = '${auth.user!.id}_$token';
    final prev = GetStorage().read<String>(_storageKey);
    if (prev == sig) return;

    try {
      await ApiService().updateProfile(
        token: auth.token!,
        firebaseToken: token,
      );
      await GetStorage().write(_storageKey, sig);
    } catch (_) {
      // Non-blocking: token sync should not break auth or navigation.
    }
  }
}
