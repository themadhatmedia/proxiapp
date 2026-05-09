import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/messages_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../views/messages/conversation_screen.dart';
import '../../views/posts/single_post_screen.dart';

/// Routes user from a tapped system notification (FCM) to the right screen.
class NotificationDeepLinkService {
  NotificationDeepLinkService._();

  static String? _lastHandledMessageId;

  static void handle(RemoteMessage message, {bool fromColdStart = false}) {
    final mid = message.messageId;
    if (mid != null && mid.isNotEmpty && _lastHandledMessageId == mid) {
      return;
    }
    if (mid != null && mid.isNotEmpty) {
      _lastHandledMessageId = mid;
    }

    final delay = fromColdStart ? const Duration(milliseconds: 600) : const Duration(milliseconds: 200);
    Future<void>.delayed(delay, () => _routeWithRetries(message));
  }

  /// FCM [data] values are strings on Android; some backends nest JSON in one key.
  static Map<String, dynamic> _normalizedPayload(RemoteMessage message) {
    final raw = message.data;
    final out = <String, dynamic>{};

    void merge(Map<String, dynamic> m) {
      for (final e in m.entries) {
        final k = e.key;
        final v = e.value;
        if (v is String) {
          final t = v.trim();
          if (t.startsWith('{') && t.endsWith('}')) {
            try {
              final decoded = jsonDecode(t);
              if (decoded is Map<String, dynamic>) {
                merge(decoded);
                continue;
              }
            } catch (_) {}
          }
        }
        out[k] = v;
      }
    }

    merge(Map<String, dynamic>.from(raw));

    const nestedKeys = ['payload', 'data', 'body', 'custom', 'extra', 'meta', 'notification_data'];
    for (final key in nestedKeys) {
      final v = out[key];
      if (v is String && v.trimLeft().startsWith('{')) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is Map<String, dynamic>) {
            merge(decoded);
          }
        } catch (_) {}
      }
    }

    return out;
  }

  static String _typeString(Map<String, dynamic> d) {
    return (d['type'] ??
            d['notification_type'] ??
            d['notificationType'] ??
            d['category'] ??
            d['event'] ??
            '')
        .toString()
        .toLowerCase();
  }

  static int? _extractPostId(Map<String, dynamic> d) {
    final direct = _parseInt(d['post_id'] ?? d['postId'] ?? d['POST_ID']);
    if (direct != null && direct > 0) return direct;

    final target = d['target']?.toString().toLowerCase() ?? '';
    final targetType = (d['target_type'] ?? d['targetType'] ?? '').toString().toLowerCase();
    if (target == 'post' || targetType.contains('post')) {
      final id = _parseInt(d['target_id'] ?? d['targetId'] ?? d['entity_id']);
      if (id != null && id > 0) return id;
    }

    final postRaw = d['post'];
    if (postRaw is String && postRaw.trimLeft().startsWith('{')) {
      try {
        final m = jsonDecode(postRaw) as Map<String, dynamic>;
        final id = _parseInt(m['id'] ?? m['post_id']);
        if (id != null && id > 0) return id;
      } catch (_) {}
    }
    if (postRaw is Map) {
      final id = _parseInt(postRaw['id'] ?? postRaw['post_id']);
      if (id != null && id > 0) return id;
    }
    return null;
  }

  /// Mirrors [NotificationsScreen] / [_isMessageNotification] — avoids treating every payload as chat.
  static bool _isMessageDeepLink(Map<String, dynamic> d, String type) {
    if (type.contains('inner_circle_request')) return false;
    if ((type.contains('post_comment') || type.contains('post_like') || type == 'comment' || type == 'like') &&
        !type.contains('message')) {
      return false;
    }
    final conversationId = _parseInt(d['conversation_id'] ?? d['conversationId']);
    final senderId = _parseInt(
      d['sender_id'] ?? d['user_id'] ?? d['other_user_id'] ?? d['message_from'] ?? d['from_user_id'],
    );

    if (type == 'message' ||
        type == 'new_message' ||
        type == 'chat' ||
        type.contains('direct_message') ||
        type.contains('new_message')) {
      return (conversationId != null || senderId != null);
    }
    if (conversationId != null) {
      return type.isEmpty || type.contains('message') || type.contains('chat');
    }
    return false;
  }

  static bool _isCircleOrConnectionDeepLink(Map<String, dynamic> d, String type) {
    if (type.contains('inner_circle_request') ||
        type.contains('circle_request') ||
        type.contains('inner_circle') ||
        type.contains('connection')) {
      return true;
    }
    return d.containsKey('circle_request_id') ||
        d.containsKey('request_id') ||
        d.containsKey('circleRequestId');
  }

  static Future<void> _routeWithRetries(RemoteMessage message, {int attempt = 0}) async {
    const maxAttempts = 28;
    const gap = Duration(milliseconds: 200);

    if (!Get.isRegistered<AuthController>() || !Get.isRegistered<NavigationController>()) {
      if (attempt < maxAttempts) {
        await Future<void>.delayed(gap);
        return _routeWithRetries(message, attempt: attempt + 1);
      }
      return;
    }

    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated) {
      if (attempt < maxAttempts) {
        await Future<void>.delayed(gap);
        return _routeWithRetries(message, attempt: attempt + 1);
      }
      return;
    }

    await _route(message);
  }

  static Future<void> _route(RemoteMessage message) async {
    final nav = Get.find<NavigationController>();
    final d = _normalizedPayload(message);
    final type = _typeString(d);
    final postId = _extractPostId(d);

    final openComments = type.contains('comment') || type == 'comment' || type.contains('post_comment');
    final openLikes = type.contains('like') || type.contains('post_like');

    // Any notification that carries a post id opens that post (likes, comments, mentions).
    if (postId != null && postId > 0) {
      nav.navigateToHome();
      unawaited(
        Get.to<void>(
          () => SinglePostScreen(
            postId: postId,
            openCommentsOnLoad: openComments,
            openLikesOnLoad: openLikes,
          ),
        ),
      );
      return;
    }

    // Direct message / chat
    if (_isMessageDeepLink(d, type)) {
      final otherUserId = _parseInt(
            d['sender_id'] ?? d['user_id'] ?? d['other_user_id'] ?? d['message_from'] ?? d['from_user_id'],
          ) ??
          _parseInt(d['receiver_id']);
      final conversationId = _parseInt(d['conversation_id'] ?? d['conversationId']);

      nav.skipInitialHomeReset.value = true;
      nav.navigateToMessages();
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().softRefresh();
        unawaited(Get.find<MessagesController>().loadConversations(showSpinner: false));
      }

      if (otherUserId != null && otherUserId > 0) {
        unawaited(
          Get.to<void>(
            () => ConversationScreen(
              otherUserId: otherUserId,
              conversationId: conversationId,
              otherDisplayName: (d['sender_name'] ?? d['user_name'] ?? 'User').toString(),
              otherAvatarUrl: d['avatar']?.toString() ?? d['sender_avatar']?.toString(),
            ),
          ),
        );
      }
      return;
    }

    // Circles / connection requests
    if (_isCircleOrConnectionDeepLink(d, type)) {
      nav.navigateToCircles(openPendingRequests: true);
      return;
    }

    // No actionable routing keys — stay on default tab (Wins), do not push Notifications list.
    nav.navigateToHome();
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString().trim());
  }
}
