import 'package:get/get.dart';
import '../data/models/notification_model.dart';

class NotificationController extends GetxController {
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadStaticNotifications();
  }

  void _loadStaticNotifications() {
    notifications.value = [
      NotificationModel(
        id: '1',
        type: 'like',
        message: 'liked your post',
        userName: 'Jay Tarpara',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        type: 'comment',
        message: 'commented on your post',
        userName: 'Pritesh Bhanderi',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: '3',
        type: 'circle_request',
        message: 'sent you an inner circle request',
        userName: 'John Doe',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: false,
      ),
      NotificationModel(
        id: '4',
        type: 'mutual_connection',
        message: 'is your mutual connection now',
        userName: 'Jay Tarpara',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: false,
      ),
    ];
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void markAsRead(String notificationId) {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifications.refresh();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
    notifications.refresh();
  }
}
