import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/messaging_model.dart';
import '../data/services/api_service.dart';
import '../utils/app_vibration.dart';

class MessagesController extends GetxController {
  final ApiService _api = ApiService();
  final conversations = <ConversationListItem>[].obs;
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  String? _search;

  void softRefresh() {
    unawaited(_safeSilentRefresh());
  }

  Future<void> _safeSilentRefresh() async {
    try {
      await loadConversations(search: _search, showSpinner: false);
    } catch (_) {}
  }

  Future<void> loadConversations({
    String? search,
    bool showSpinner = true,
  }) async {
    _search = search;
    final c = _auth;
    if (c == null) return;
    if (showSpinner) {
      isLoading.value = true;
    } else {
      isRefreshing.value = true;
    }
    try {
      final before = List<ConversationListItem>.from(conversations);
      final list = await _api.getConversations(
        token: c,
        search: _search,
      );
      conversations.assignAll(list);
      if (showSpinner == false && _hasNewIncoming(before, list)) {
        AppVibration.newMessageSoft();
      }
    } catch (e) {
      if (showSpinner) rethrow;
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  void removeByOtherUserId(int otherUserId) {
    conversations.removeWhere((c) => c.otherUser.id == otherUserId);
  }

  void removeByConversationId(int conversationId) {
    conversations.removeWhere((c) => c.conversationId == conversationId);
  }

  String? get _auth {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().token;
  }

  bool _hasNewIncoming(
    List<ConversationListItem> oldList,
    List<ConversationListItem> newList,
  ) {
    if (!Get.isRegistered<AuthController>()) return false;
    final myId = Get.find<AuthController>().user?.id;
    if (myId == null) return false;
    final oldByConversation = <int, ConversationListItem>{
      for (final c in oldList) c.conversationId: c,
    };
    for (final c in newList) {
      final previous = oldByConversation[c.conversationId];
      final nowUnread = c.unreadCount;
      final prevUnread = previous?.unreadCount ?? 0;
      if (nowUnread > prevUnread) return true;
      final latest = c.lastMessage;
      final prevLatest = previous?.lastMessage;
      if (latest == null) continue;
      final isIncoming = latest.senderId != myId;
      final hasNewMessage = prevLatest == null || latest.id != prevLatest.id;
      if (isIncoming && hasNewMessage) return true;
    }
    return false;
  }
}
