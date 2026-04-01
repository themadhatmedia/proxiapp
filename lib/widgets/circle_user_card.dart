import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/favorites_controller.dart';
import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
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
  final bool showFavoriteButton;
  final bool requireUnfavoriteConfirmation;

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
    this.showFavoriteButton = false,
    this.requireUnfavoriteConfirmation = false,
  });

  @override
  State<CircleUserCard> createState() => _CircleUserCardState();
}

class _CircleUserCardState extends State<CircleUserCard> with SingleTickerProviderStateMixin {
  bool _isTogglingFavorite = false;

  Future<void> _toggleFavorite(BuildContext context) async {
    if (widget.user == null || _isTogglingFavorite) return;

    final authController = Get.find<AuthController>();
    final token = authController.token;
    if (token == null) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    final apiService = ApiService();

    try {
      final currentlyisFavorite = widget.user!.isFavorite ?? false;

      if (currentlyisFavorite) {
        if (widget.requireUnfavoriteConfirmation) {
          final confirm = await _showUnfavoriteConfirmation(context);
          if (confirm != true) {
            return;
          }
        }
        await apiService.removeFromFavorites(
          token: token,
          userId: widget.user!.id,
        );

        if (Get.isRegistered<FavoritesController>()) {
          final favController = Get.find<FavoritesController>();
          favController.removeFavoriteLocally(widget.user!.id);
        }

        ToastHelper.showSuccess('Removed from favorites');
      } else {
        await apiService.addToFavorites(
          token: token,
          userId: widget.user!.id,
        );
        ToastHelper.showSuccess('Added to favorites');
      }
    } catch (e) {
      ToastHelper.showError('Failed to update favorites');
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  Future<bool?> _showUnfavoriteConfirmation(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Remove favorite?',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Are you sure you want to remove this user from favorites?',
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
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
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
      margin: const EdgeInsets.only(bottom: 12),
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
          onTap: widget.showFavoriteButton && widget.user != null ? () => _openUserProfile(context) : widget.onTap,
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
                else if (widget.showFavoriteButton && widget.user != null)
                  IconButton(
                    onPressed: _isTogglingFavorite ? null : () => _toggleFavorite(context),
                    icon: _isTogglingFavorite
                        ? const _BeatingHeart()
                        : Icon(
                            (widget.user?.isFavorite ?? false) ? Icons.favorite : Icons.favorite_border,
                            color: (widget.user?.isFavorite ?? false) ? Colors.red : cs.onSurface,
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

class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart();

  @override
  State<_BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<_BeatingHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
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
      child: const Icon(
        Icons.favorite,
        color: Colors.red,
        size: 24,
      ),
    );
  }
}
