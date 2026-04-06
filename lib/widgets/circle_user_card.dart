import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/bookmarks_controller.dart';
import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
import '../config/theme/proxi_palette.dart';
import '../utils/toast_helper.dart';
import '../views/pulse/user_profile_detail_screen.dart';
import 'safe_avatar.dart';

class CircleUserCard extends StatefulWidget {
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>>? menuItems;
  final Function(String)? onMenuSelected;
  final bool isLoading;
  final User? user;
  final bool showBookmarkButton;
  final bool requireRemoveBookmarkConfirmation;
  /// Space below the card (list density). Default matches circles / search lists.
  final double bottomMargin;

  const CircleUserCard({
    super.key,
    this.name,
    this.bio,
    this.avatarUrl,
    this.onTap,
    this.menuItems,
    this.onMenuSelected,
    this.isLoading = false,
    this.user,
    this.showBookmarkButton = false,
    this.requireRemoveBookmarkConfirmation = false,
    this.bottomMargin = 12,
  });

  @override
  State<CircleUserCard> createState() => _CircleUserCardState();
}

class _CircleUserCardState extends State<CircleUserCard> with SingleTickerProviderStateMixin {
  bool _isTogglingBookmark = false;

  Future<void> _toggleBookmark(BuildContext context) async {
    if (widget.user == null || _isTogglingBookmark) return;

    final authController = Get.find<AuthController>();
    final token = authController.token;
    if (token == null) return;

    setState(() {
      _isTogglingBookmark = true;
    });

    final apiService = ApiService();

    try {
      final isBookmarked = widget.user!.isFavorite ?? false;

      if (isBookmarked) {
        if (widget.requireRemoveBookmarkConfirmation) {
          final confirm = await _showRemoveBookmarkConfirmation(context);
          if (confirm != true) {
            return;
          }
        }
        await apiService.removeBookmark(
          token: token,
          userId: widget.user!.id,
        );

        if (Get.isRegistered<BookmarksController>()) {
          final bmController = Get.find<BookmarksController>();
          bmController.removeBookmarkLocally(widget.user!.id);
        }

        ToastHelper.showSuccess('Bookmark removed');
      } else {
        await apiService.addBookmark(
          token: token,
          userId: widget.user!.id,
        );
        ToastHelper.showSuccess('User bookmarked');
      }
    } catch (e) {
      ToastHelper.showError('Failed to update bookmark');
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingBookmark = false;
        });
      }
    }
  }

  Future<bool?> _showRemoveBookmarkConfirmation(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Remove bookmark?',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Are you sure you want to remove this user from your bookmarks?',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ProxiPalette.bookmarkAccent,
              foregroundColor: ProxiPalette.pureWhite,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openUserProfile(BuildContext context) {
    if (widget.user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => UserProfileDetailScreen(
          userData: widget.user!.toJson(),
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = widget.user?.displayName ?? widget.user?.name ?? widget.name ?? 'Unknown';
    final displayBio = widget.user?.profile?.bio ?? widget.bio;
    final displayAvatar = widget.user?.avatarUrl ?? widget.avatarUrl;

    return Container(
      margin: EdgeInsets.only(bottom: widget.bottomMargin),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.12),
            cs.primary.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.showBookmarkButton && widget.user != null ? () => _openUserProfile(context) : widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withOpacity(0.45),
                      width: 2,
                    ),
                  ),
                  child: SafeAvatar(
                    imageUrl: displayAvatar,
                    size: 50,
                    fallbackText: displayName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displayBio != null && displayBio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          displayBio,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  )
                else if (widget.showBookmarkButton && widget.user != null)
                  IconButton(
                    onPressed: _isTogglingBookmark ? null : () => _toggleBookmark(context),
                    icon: _isTogglingBookmark
                        ? _PulsingBookmark(color: ProxiPalette.bookmarkSaved)
                        : Icon(
                            (widget.user?.isFavorite ?? false) ? Icons.bookmark : Icons.bookmark_border,
                            color: (widget.user?.isFavorite ?? false)
                                ? ProxiPalette.bookmarkSaved
                                : ProxiPalette.bookmarkAccent,
                            size: 24,
                          ),
                  )
                else if (widget.menuItems != null && widget.onMenuSelected != null)
                  PopupMenuButton<String>(
                    onSelected: widget.onMenuSelected!,
                    itemBuilder: (context) => widget.menuItems!,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      color: cs.onSurface,
                      size: 20,
                    ),
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: cs.outline.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    offset: const Offset(0, 40),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingBookmark extends StatefulWidget {
  final Color color;

  const _PulsingBookmark({required this.color});

  @override
  State<_PulsingBookmark> createState() => _PulsingBookmarkState();
}

class _PulsingBookmarkState extends State<_PulsingBookmark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.85, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(
        Icons.bookmark,
        color: widget.color,
        size: 24,
      ),
    );
  }
}
