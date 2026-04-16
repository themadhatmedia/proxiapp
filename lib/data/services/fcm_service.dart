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

  /// Call once after [Firebase.initializeApp] on Android.
  Future<void> installAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_listenerAttached) return;
    _listenerAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      syncTokenToProfileIfNeeded();
    });
  }

  /// Clears the last successful sync so the next login or screen visit can push again.
  static void clearStoredSyncSignature() {
    GetStorage().remove(_storageKey);
  }

  /// Requests notification permission (Android 13+), reads the FCM token, and POSTs profile
  /// with [firebase_token] only when it changed for this user.
  Future<void> syncTokenToProfileIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated || auth.token == null || auth.user == null) return;

    final perm = await Permission.notification.request();
    if (!perm.isGranted) return;

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
