import 'dart:async' show unawaited;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../controllers/navigation_controller.dart';
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
    if (_looksLikeMessage(message)) {
      AppVibration.newMessageSoft();
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().softRefresh();
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (_looksLikeMessage(message)) {
      _openMessagesAndRefresh();
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
    if (!_looksLikeMessage(message)) return;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      _openMessagesAndRefresh();
    });
  });
}

void _openMessagesAndRefresh() {
  void applyRefresh() {
    if (Get.isRegistered<MessagesController>()) {
      final controller = Get.find<MessagesController>();
      controller.softRefresh();
      unawaited(controller.loadConversations(showSpinner: true));
    }
  }

  if (Get.isRegistered<NavigationController>()) {
    final nav = Get.find<NavigationController>();
    nav.skipInitialHomeReset.value = true;
    nav.navigateToMessages();
    applyRefresh();
    return;
  }

  // App can still be bootstrapping from cold start.
  Future<void>.delayed(const Duration(milliseconds: 350), () {
    if (Get.isRegistered<NavigationController>()) {
      final nav = Get.find<NavigationController>();
      nav.skipInitialHomeReset.value = true;
      nav.navigateToMessages();
      applyRefresh();
    }
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
