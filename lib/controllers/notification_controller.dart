import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/circles_controller.dart';
import '../data/models/notification_model.dart';
import '../data/services/api_service.dart';
import '../utils/toast_helper.dart';

class NotificationController extends GetxController {
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isMarkingAllRead = false.obs;
  final RxInt unreadCount = 0.obs;
  final RxMap<String, bool> requestActionLoading = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  void reset() {
    notifications.clear();
    unreadCount.value = 0;
    isLoading.value = false;
    isMarkingAllRead.value = false;
    requestActionLoading.clear();
  }

  Future<void> fetchNotifications({bool showLoader = true}) async {
    final token = _authController.token;
    if (token == null) return;

    if (showLoader) isLoading.value = true;
    try {
      final response = await _apiService.getNotifications(token: token);
      final rawNotifications = response['notifications'];
      final listData = rawNotifications is Map ? rawNotifications['data'] : null;
      final items = (listData is List)
          ? listData
              .whereType<Map>()
              .map((item) => NotificationModel.fromApi(Map<String, dynamic>.from(item)))
              .toList()
          : <NotificationModel>[];

      notifications.assignAll(items);

      final unread = response['unread_count'];
      if (unread is int) {
        unreadCount.value = unread;
      } else {
        unreadCount.value = items.where((n) => !n.isRead).length;
      }
    } catch (e) {
      if (showLoader) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (showLoader) isLoading.value = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1 || notifications[index].isRead) return;

    final token = _authController.token;
    if (token == null) return;

    try {
      await _apiService.markNotificationAsRead(
        token: token,
        notificationId: notificationId,
      );
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifications.refresh();
      if (unreadCount.value > 0) unreadCount.value--;
    } catch (e) {
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> markAllAsRead() async {
    if (notifications.isEmpty || unreadCount.value == 0 || isMarkingAllRead.value) return;

    final token = _authController.token;
    if (token == null) return;

    isMarkingAllRead.value = true;
    try {
      await _apiService.markAllNotificationsAsRead(token: token);
      for (int i = 0; i < notifications.length; i++) {
        notifications[i] = notifications[i].copyWith(isRead: true);
      }
      notifications.refresh();
      unreadCount.value = 0;
    } catch (e) {
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      isMarkingAllRead.value = false;
    }
  }

  bool isRequestActionLoading(String notificationId) {
    return requestActionLoading[notificationId] ?? false;
  }

  Future<void> respondToInnerCircleRequest({
    required NotificationModel notification,
    required String action,
  }) async {
    final requestId = notification.circleRequestId;
    if (requestId == null) {
      ToastHelper.showError('Circle request id not available');
      return;
    }
    if (isRequestActionLoading(notification.id)) return;

    if (!Get.isRegistered<CirclesController>()) {
      Get.put(CirclesController());
    }
    final circlesController = Get.find<CirclesController>();

    requestActionLoading[notification.id] = true;
    requestActionLoading.refresh();
    try {
      if (action == 'accept') {
        await circlesController.acceptCircleRequest(requestId);
      } else {
        await circlesController.rejectCircleRequest(requestId);
      }
      await markAsRead(notification.id);
    } finally {
      requestActionLoading[notification.id] = false;
      requestActionLoading.refresh();
    }
  }
}
