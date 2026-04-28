import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/navigation_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../data/models/notification_model.dart';
import '../../widgets/safe_avatar.dart';
import '../posts/single_post_screen.dart';
import '../messages/conversation_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationController _controller;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<NotificationController>()) {
      _controller = Get.find<NotificationController>();
    } else {
      _controller = Get.put(NotificationController());
    }
    _controller.fetchNotifications(showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.scaffoldGradient(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: context.proxi.surfaceCard,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Notifications',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Obx(() {
              final hasUnread = _controller.unreadCount.value > 0;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: _controller.isMarkingAllRead.value ? null : _controller.markAllAsRead,
                child: _controller.isMarkingAllRead.value
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : Text(
                        'Mark all read',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              );
            }),
          ],
        ),
        body: Obx(() {
          if (_controller.isLoading.value && _controller.notifications.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: cs.primary),
            );
          }

          if (_controller.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 88,
                      color: cs.onSurfaceVariant.withOpacity(0.45),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No notifications available right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'When you have alerts, they will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _controller.fetchNotifications(showLoader: false),
            color: cs.primary,
            backgroundColor: context.proxi.surfaceCard,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _controller.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _controller.notifications[index];
                return _buildNotificationCard(context, item);
              },
            ),
          );
        }),
      ),
    );
  }

  Future<void> _handleNotificationTap(NotificationModel item) async {
    if (_isMessageNotification(item)) {
      final id = item.conversationId ?? item.senderId;
      if (id != null && id > 0) {
        await _controller.markAsRead(item.id);
        await Get.to(
          () => ConversationScreen(
            otherUserId: id,
            conversationId: item.conversationId,
            otherDisplayName: item.userName,
            otherAvatarUrl: item.userProfileImage,
          ),
        );
      } else {
        await _controller.markAsRead(item.id);
      }
      return;
    }

    if (_isInnerCircleRequest(item)) {
      await _controller.markAsRead(item.id);
      if (Get.isRegistered<NavigationController>()) {
        Get.find<NavigationController>().navigateToCircles(openPendingRequests: true);
      }
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final postId = item.postId;
    if (postId != null) {
      final type = item.normalizedType;
      final openComments = type.contains('post_comment') || type == 'comment';
      final openLikes = type.contains('post_like') || type == 'like';
      await _controller.markAsRead(item.id);
      await Get.to(
        () => SinglePostScreen(
          postId: postId,
          openCommentsOnLoad: openComments,
          openLikesOnLoad: openLikes,
        ),
      );
      return;
    }
    await _controller.markAsRead(item.id);
  }

  bool _isMessageNotification(NotificationModel item) {
    final t = item.normalizedType;
    if (t.contains('inner_circle_request')) {
      return false;
    }
    if (t.contains('post_comment') || t == 'post_comment' || t == 'post_like' || t.contains('post_like')) {
      if (!t.contains('message')) {
        return false;
      }
    }
    if (t == 'message' || t == 'new_message' || t == 'chat' || t == 'new_message' || t.contains('direct_message')) {
      return (item.conversationId ?? item.senderId) != null;
    }
    if (item.conversationId != null) {
      return t.isEmpty || t.contains('message') || t.contains('chat');
    }
    return false;
  }

  bool _isInnerCircleRequest(NotificationModel item) {
    final type = item.normalizedType;
    return type == 'inner_circle_request' || type.contains('inner_circle_request');
  }

  Widget _buildUnreadIndicator(BuildContext context, NotificationModel item) {
    final cs = Theme.of(context).colorScheme;
    if (item.isRead) return const SizedBox.shrink();
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4, left: 8),
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel item) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleNotificationTap(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? context.proxi.surfaceCard : cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead ? cs.outline.withOpacity(0.24) : cs.primary.withOpacity(0.28),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeAvatar(
                    imageUrl: item.userProfileImage,
                    size: 42,
                    fallbackText: item.userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                        if (item.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.body,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _formatTimeAgo(item.timestamp),
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withOpacity(0.82),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildUnreadIndicator(context, item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
