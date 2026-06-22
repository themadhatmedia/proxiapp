import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/circles_controller.dart';
import '../../data/models/user_model.dart';
import '../../widgets/safe_avatar.dart';
import 'conversation_screen.dart';

/// Search users to start a new message (same API as Circles search, message-only actions).
class NewMessageSearchScreen extends StatefulWidget {
  const NewMessageSearchScreen({super.key});

  @override
  State<NewMessageSearchScreen> createState() => _NewMessageSearchScreenState();
}

class _NewMessageSearchScreenState extends State<NewMessageSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final CirclesController _circlesController;
  final RxList<User> _searchResults = <User>[].obs;
  final RxBool _isSearching = false.obs;
  final RxBool _hasSearched = false.obs;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<CirclesController>()) {
      _circlesController = Get.put(CirclesController());
    } else {
      _circlesController = Get.find<CirclesController>();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int? get _myUserId {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().currentUser.value?.id;
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    _isSearching.value = true;
    _hasSearched.value = true;

    try {
      final results = await _circlesController.searchUsers(query);
      final myId = _myUserId;
      _searchResults.value = myId == null
          ? results
          : results.where((u) => u.id != myId).toList();
    } finally {
      _isSearching.value = false;
    }
  }

  void _openConversation(User user) {
    final name = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : user.name;
    final avatar = user.avatarUrl ?? user.profile?.avatar;

    Get.off<void>(
      () => ConversationScreen(
        otherUserId: user.id,
        otherDisplayName: name,
        otherAvatarUrl: avatar,
      ),
    );
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: cs.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'New message',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Enter keywords to search...',
                          hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          filled: true,
                          fillColor: context.proxi.surfaceCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Search',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (_isSearching.value) {
                    return Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    );
                  }

                  if (!_hasSearched.value) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 80,
                            color: cs.onSurfaceVariant.withOpacity(0.35),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Search for someone to message',
                            style: TextStyle(
                              fontSize: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (_searchResults.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 80,
                            color: cs.onSurfaceVariant.withOpacity(0.35),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return _UserResultCard(
                        user: user,
                        onSendMessage: () => _openConversation(user),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({
    required this.user,
    required this.onSendMessage,
  });

  final User user;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : user.name;
    final bio = user.profile?.bio ?? '';
    final avatarUrl = user.avatarUrl ?? user.profile?.avatar;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeAvatar(
                imageUrl: avatarUrl,
                size: 56,
                fallbackText: name,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bio,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSendMessage,
              icon: const Icon(Icons.message_outlined, size: 20),
              label: const Text(
                'Send message',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
