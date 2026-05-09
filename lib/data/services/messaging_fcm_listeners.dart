import 'dart:async' show unawaited;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../controllers/notification_controller.dart';
import '../../data/services/app_badge_service.dart';
import '../../data/services/notification_deep_link_service.dart';
import '../../utils/app_vibration.dart';
import '../../controllers/messages_controller.dart';

bool _fcmMessageListenersRegistered = false;
bool _initialFcmMessageHandled = false;

void registerMessagingFcmListeners() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (_fcmMessageListenersRegistered) return;
  _fcmMessageListenersRegistered = true;

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    unawaited(AppBadgeService.applyBadgeFromRemoteMessage(message));
    if (_looksLikeMessage(message)) {
      AppVibration.newMessageSoft();
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().softRefresh();
      }
    } else {
      if (Get.isRegistered<NotificationController>()) {
        unawaited(
          Get.find<NotificationController>().fetchNotifications(showLoader: false),
        );
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    unawaited(AppBadgeService.applyBadgeFromRemoteMessage(message));
    NotificationDeepLinkService.handle(message);
    if (!_looksLikeMessage(message) && Get.isRegistered<NotificationController>()) {
      unawaited(
        Get.find<NotificationController>().fetchNotifications(showLoader: false),
      );
    }
  });
}

void handleInitialMessagingFcm() {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (_initialFcmMessageHandled) return;
  _initialFcmMessageHandled = true;
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message == null) return;
    unawaited(AppBadgeService.applyBadgeFromRemoteMessage(message));
    NotificationDeepLinkService.handle(message, fromColdStart: true);
  });
}

bool _looksLikeMessage(RemoteMessage m) {
  final d = m.data;
  final t = d['type']?.toString().toLowerCase() ?? '';
  if (t == 'message' || t == 'new_message' || t == 'chat' || t.contains('new_message') || t.contains('chat_')) {
    if (t.contains('post_')) {
      return false;
    }
    return true;
  }
  if (d.containsKey('message_id') || d.containsKey('message_to')) {
    return true;
  }
  if (d.containsKey('conversation_id') || d.containsKey('receiver_id')) {
    return true;
  }
  if (d.containsKey('sender_id') && t.isEmpty) {
    return d.containsKey('other_user_id') || d.containsKey('conversation_id');
  }
  final b = m.notification?.body?.toLowerCase() ?? '';
  final title = m.notification?.title?.toLowerCase() ?? '';
  if (b.contains('sent a message') || b.contains('new message') || b.contains('messaged you') || title.contains('message')) {
    return true;
  }
  return false;
}
