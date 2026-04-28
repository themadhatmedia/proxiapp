import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/messages_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../data/services/api_service.dart';
import '../../data/models/messaging_model.dart';
import '../messages/conversation_screen.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/safe_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _search = TextEditingController();
  final _api = ApiService();
  Timer? _debounce;
  Timer? _autoRefreshTimer;
  late final MessagesController _controller;
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<MessagesController>()) {
      _controller = Get.find<MessagesController>();
    } else {
      _controller = Get.put(MessagesController());
    }
    if (Get.isRegistered<AuthController>() && Get.find<AuthController>().token != null) {
      unawaited(_resetAndReload(showSpinner: true));
    }
    if (Get.isRegistered<NavigationController>()) {
      final nav = Get.find<NavigationController>();
      _tabWorker = ever<int>(nav.currentIndex, (idx) {
        if (idx == 3 && mounted) {
          unawaited(_resetAndReload(showSpinner: true));
        }
      });
    }
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      if (Get.isRegistered<NavigationController>() &&
          Get.find<NavigationController>().currentIndex.value == 3) {
        unawaited(_load(showSpinner: false));
      }
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _autoRefreshTimer?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    try {
      await _controller.loadConversations(
        search: _search.text.trim(),
        showSpinner: showSpinner,
      );
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _resetAndReload({required bool showSpinner}) async {
    _debounce?.cancel();
    if (_search.text.isNotEmpty) {
      _search.clear();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _load(showSpinner: showSpinner);
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_load(showSpinner: false));
    });
  }

  String? get _token =>
      Get.isRegistered<AuthController>() ? Get.find<AuthController>().token : null;

  Future<void> _confirmDeleteConversation(ConversationListItem item) async {
    if (item.conversationId <= 0 || _token == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.proxi.surfaceCard,
        title: const Text('Delete conversation?'),
        content: const Text('This will remove all messages in this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteConversationWithUser(
        token: _token!,
        conversationId: item.conversationId,
      );
      _controller.removeByConversationId(item.conversationId);
      if (mounted) ToastHelper.showInfo('Conversation deleted');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmUnreadConversation(ConversationListItem item) async {
    if (item.conversationId <= 0 || _token == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.proxi.surfaceCard,
        title: const Text('Mark conversation unread?'),
        content: const Text('This will mark this conversation as unread.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark unread'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.markConversationAsUnread(
        token: _token!,
        conversationId: item.conversationId,
      );
    } catch (_) {
      // Fallback when API only supports message-level unread.
      final messageId = item.lastMessage?.id;
      if (messageId == null || messageId <= 0) rethrow;
      await _api.markMessageAsUnread(
        token: _token!,
        messageId: messageId,
      );
    }
    await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: SafeArea(
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      filled: true,
                      fillColor: context.proxi.surfaceCard,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_controller.isRefreshing.value && _controller.conversations.isNotEmpty)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: ProxiPalette.electricBlue,
                  ),
                Expanded(
                  child: _controller.isLoading.value && _controller.conversations.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: cs.primary,
                          ),
                        )
                      : RefreshIndicator(
                          color: cs.primary,
                          onRefresh: () => _load(showSpinner: false),
                          child: _controller.conversations.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.sizeOf(context).height * 0.35,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chat_bubble_outline,
                                              size: 72,
                                              color: cs.onSurfaceVariant.withOpacity(0.45),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No conversations yet',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 40),
                                              child: Text(
                                                'Reach out from Circles, Pulse, or your profile to start chatting.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: cs.onSurfaceVariant.withOpacity(0.8),
                                                  fontSize: 13,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  itemCount: _controller.conversations.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (c, i) {
                                    final it = _controller.conversations[i];
                                    return Slidable(
                                      key: ValueKey<int>(it.conversationId),
                                      startActionPane: ActionPane(
                                        motion: const BehindMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) => unawaited(_confirmUnreadConversation(it)),
                                            backgroundColor: const Color(0xFFC48000),
                                            foregroundColor: Colors.white,
                                            icon: Icons.mark_chat_unread_outlined,
                                            label: 'Unread',
                                          ),
                                        ],
                                      ),
                                      endActionPane: ActionPane(
                                        motion: const BehindMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) => unawaited(_confirmDeleteConversation(it)),
                                            backgroundColor: const Color(0xFFB00020),
                                            foregroundColor: Colors.white,
                                            icon: Icons.delete_outline,
                                            label: 'Delete',
                                          ),
                                        ],
                                      ),
                                      child: _ThreadTile(
                                        c: it,
                                        onTap: () async {
                                          await Get.to(
                                            () => ConversationScreen(
                                              otherUserId: it.otherUser.id,
                                              conversationId: it.conversationId > 0 ? it.conversationId : null,
                                              otherDisplayName: it.otherUser.displayName,
                                              otherAvatarUrl: it.otherUser.profilePicture,
                                            ),
                                          );
                                          if (c.mounted) {
                                            await _resetAndReload(showSpinner: true);
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.c,
    required this.onTap,
  });

  final ConversationListItem c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = c.lastMessage;
    final u = c.otherUser;
    final preview = (c.lastMessageText?.trim().isNotEmpty == true)
        ? c.lastMessageText!.trim()
        : (last?.message.trim().isNotEmpty == true ? last!.message.trim() : 'No messages yet');
    final messageAt = c.lastMessageAt ?? last?.createdAt;
    final hasUnread = c.unreadCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: hasUnread ? ProxiPalette.electricBlue.withOpacity(0.12) : context.proxi.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outline.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SafeAvatar(
                  imageUrl: u.profilePicture,
                  size: 50,
                  fallbackText: u.displayName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: hasUnread
                              ? cs.onSurface.withOpacity(0.9)
                              : cs.onSurfaceVariant,
                          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                      if (messageAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(messageAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ProxiPalette.electricBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
