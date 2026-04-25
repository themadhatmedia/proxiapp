import 'dart:async' show unawaited;

import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/models/messaging_model.dart';
import '../data/services/api_service.dart';

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
      final list = await _api.getConversations(
        token: c,
        search: _search,
      );
      conversations.assignAll(list);
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
}
