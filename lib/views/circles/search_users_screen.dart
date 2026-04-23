import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/circles_controller.dart';
import '../../data/models/user_model.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/safe_avatar.dart';
import '../pulse/user_profile_detail_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final CirclesController controller = Get.find<CirclesController>();
  final RxList<User> searchResults = <User>[].obs;
  final RxBool isSearching = false.obs;
  final RxBool hasSearched = false.obs;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Hide keyboard and remove focus
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    isSearching.value = true;
    hasSearched.value = true;

    try {
      final results = await controller.searchUsers(query);
      searchResults.value = results;
    } finally {
      isSearching.value = false;
    }
  }

  void _handleAddToInner(User user) {
    _sendInnerCircleRequest(user);
  }

  void _handleAddToOuter(User user) {
    _addToOuterCircle(user);
  }

  void _handleViewProfile(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => UserProfileDetailScreen(
          userData: user.toJson(),
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _sendInnerCircleRequest(User user) async {
    final userId = user.id;
    final wasInOuterCircle = user.inOuterCircle ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dialogContext.proxi.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Send Inner Circle Request?',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            wasInOuterCircle
                ? 'This user is currently in your outer circle. They will be removed from outer circle first, then an inner circle request will be sent.'
                : 'This will send a request to add this user to your inner circle. They will need to accept your request.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Send Request', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ProgressDialogHelper.show(context);
    try {
      await controller.sendInnerCircleRequest(
        userId,
        removeOuterConnectionFirst: wasInOuterCircle,
      );
      if (mounted) {
        _patchSearchResultCircleStatus(
          userId,
          inOuterCircle: false,
          innerRequestStatus: 'pending',
        );
      }
    } finally {
      await ProgressDialogHelper.hide();
    }
  }

  Future<void> _addToOuterCircle(User user) async {
    final userId = user.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dialogContext.proxi.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add to Outer Circle?',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will add the user to your outer circle immediately without requiring their approval.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add to Circle', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ProgressDialogHelper.show(context);
    try {
      await controller.addToOuterCircle(userId);
      if (mounted) {
        _patchSearchResultCircleStatus(
          userId,
          inOuterCircle: true,
        );
      }
    } finally {
      await ProgressDialogHelper.hide();
    }
  }

  void _patchSearchResultCircleStatus(
    int userId, {
    bool? inInnerCircle,
    bool? inOuterCircle,
    String? innerRequestStatus,
  }) {
    final idx = searchResults.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final u = searchResults[idx];
    final updated = u.withCircleRelation(
      inInnerCircle: inInnerCircle,
      inOuterCircle: inOuterCircle,
      innerRequestStatus: innerRequestStatus,
    );
    final next = List<User>.from(searchResults);
    next[idx] = updated;
    searchResults.assignAll(next);
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: cs.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Search Users',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
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
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant,
                          ),
                          filled: true,
                          fillColor: context.proxi.surfaceCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          // prefixIcon: const Icon(
                          //   Icons.search,
                          //   color: Colors.white,
                          // ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 16.0,
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
                  if (isSearching.value) {
                    return Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    );
                  }

                  if (!hasSearched.value) {
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
                            'Search for users to connect',
                            style: TextStyle(
                              fontSize: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (searchResults.isEmpty) {
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
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return _buildUserCard(context, user);
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

  Widget _buildUserCard(BuildContext context, User user) {
    final cs = Theme.of(context).colorScheme;
    final name = user.name;
    final bio = user.profile?.bio ?? '';
    final avatarUrl = user.profile?.avatar;

    // Check circle status
    final inInnerCircle = user.inInnerCircle ?? false;
    final inOuterCircle = user.inOuterCircle ?? false;
    final innerRequestStatus = user.innerRequestStatus ?? 'not_sent';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.35),
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
                imageUrl: avatarUrl,
                size: 60,
                fallbackText: name,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status badges
                              if (inInnerCircle)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'In Inner Circle',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4CAF50),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (innerRequestStatus == 'pending')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFA726).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: Color(0xFFFFA726),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Request Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFFA726),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (inOuterCircle)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.group,
                                        size: 14,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'In Outer Circle',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 5),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            ToastHelper.showInfo('Message feature is coming soon');
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.message,
                              size: 20,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 5),
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
          const SizedBox(height: 15),
          // Check if we have both circle buttons to show
          _buildActionButtons(user, inInnerCircle, inOuterCircle, innerRequestStatus),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    User user,
    bool inInnerCircle,
    bool inOuterCircle,
    String innerRequestStatus,
  ) {
    final showInnerButton = !inInnerCircle && innerRequestStatus != 'pending';
    final showOuterButton = !inOuterCircle;
    final showBothCircleButtons = showInnerButton && showOuterButton;

    // If we have both circle buttons, show them in first row, profile button below
    if (showBothCircleButtons) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAddToInner(user),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text(
                    'Add to Inner',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAddToOuter(user),
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text(
                    'Add to Outer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleViewProfile(user),
              icon: const Icon(Icons.person, size: 18),
              label: const Text(
                'See Profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    // Otherwise show buttons in a single row
    return Row(
      children: [
        if (showInnerButton)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleAddToInner(user),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text(
                'Add to Inner',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (showInnerButton && showOuterButton) const SizedBox(width: 12),
        if (showOuterButton)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleAddToOuter(user),
              icon: const Icon(Icons.group_add, size: 18),
              label: const Text(
                'Add to Outer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (showInnerButton || showOuterButton) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleViewProfile(user),
            icon: const Icon(Icons.person, size: 18),
            label: const Text(
              'See Profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
