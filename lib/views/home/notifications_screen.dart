// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../controllers/notification_controller.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationController controller = Get.put(NotificationController());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => controller.markAllAsRead(),
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey[700],
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.notifications.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.white.withOpacity(0.1),
          ),
          itemBuilder: (context, index) {
            final notification = controller.notifications[index];
            return _NotificationItem(
              notification: notification,
              onMarkAsRead: () => controller.markAsRead(notification.id),
            );
          },
        );
      }),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final notification;
  final VoidCallback onMarkAsRead;

  const _NotificationItem({
    required this.notification,
    required this.onMarkAsRead,
  });

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'circle_request':
        return Icons.group_add;
      case 'mutual_connection':
        return Icons.people;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'circle_request':
        return Colors.green;
      case 'mutual_connection':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: notification.isRead ? Colors.black : const Color(0xFF1A1A1A),
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: notification.userProfileImage != null
                    ? ClipOval(
                        child: Image.network(
                          notification.userProfileImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          notification.userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: notification.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' ${notification.message}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getNotificationIcon(),
                          size: 14,
                          color: _getIconColor(),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeago.format(notification.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: onMarkAsRead,
                        child: const Text(
                          'Mark as read',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
