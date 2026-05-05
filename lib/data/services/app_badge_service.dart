import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home-screen launcher badge: combines API unread count with pushes that don’t hit the API
/// (e.g. Firebase Console test messages).
class AppBadgeService {
  AppBadgeService._();

  static const _kPushBump = 'app_badge_push_bump_v1';
  static const _kLastApiUnread = 'app_badge_last_api_unread_v1';
  static const _kLastProcessedBadgeMsgId = 'app_badge_last_processed_msg_id_v1';

  static Future<void> _applyRawTotal(int total) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final supported = await AppBadgePlus.isSupported();
    if (!supported) {
      if (kDebugMode) {
        debugPrint(
          'AppBadgeService: icon badge not supported on this device/launcher.',
        );
      }
      return;
    }
    final n = total <= 0 ? 0 : (total > 99 ? 99 : total);
    await AppBadgePlus.updateBadge(n);
  }

  /// Call after loading unread count from your notifications API.
  static Future<void> persistApiUnreadAndApplyBadge(int apiUnread) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastApiUnread, apiUnread.clamp(0, 9999));
    final bump = prefs.getInt(_kPushBump) ?? 0;
    await _applyRawTotal(apiUnread + bump);
  }

  static Future<void> _incrementPushBump() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final bump = (prefs.getInt(_kPushBump) ?? 0) + 1;
    await prefs.setInt(_kPushBump, bump);
    final api = prefs.getInt(_kLastApiUnread) ?? 0;
    await _applyRawTotal(api + bump);
  }

  /// User opened the in-app notifications screen — drop FCM-only bumps so badge matches API.
  static Future<void> clearPushBumpAfterViewingInbox(int currentApiUnread) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPushBump, 0);
    await prefs.setInt(_kLastApiUnread, currentApiUnread.clamp(0, 9999));
    await _applyRawTotal(currentApiUnread);
  }

  /// Absolute badge when payload sends `badge` (APNS-style), e.g. custom data `badge`: `3`.
  static Future<void> applyAbsoluteBadgeFromPayload(int count) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPushBump, 0);
    await prefs.setInt(_kLastApiUnread, count.clamp(0, 9999));
    await _applyRawTotal(count);
  }

  /// Background / foreground FCM delivery — bumps badge for visible notifications.
  static Future<void> applyBadgeFromRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final mid = message.messageId;
    if (mid != null && mid.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final prev = prefs.getString(_kLastProcessedBadgeMsgId);
      if (prev == mid) return;
      await prefs.setString(_kLastProcessedBadgeMsgId, mid);
    }

    final badgeRaw = message.data['badge'];
    if (badgeRaw != null) {
      final n = int.tryParse(badgeRaw.toString());
      if (n != null && n >= 0) {
        await applyAbsoluteBadgeFromPayload(n);
        return;
      }
    }

    if (message.notification != null) {
      await _incrementPushBump();
    }
  }

  static Future<void> clearPersistedBadgeExtras() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPushBump);
    await prefs.remove(_kLastApiUnread);
    await prefs.remove(_kLastProcessedBadgeMsgId);
  }

  static Future<void> clear() async {
    await clearPersistedBadgeExtras();
    await _applyRawTotal(0);
  }
}
