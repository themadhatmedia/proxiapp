import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/post_like_models.dart';
import '../../data/services/api_service.dart';
import '../../utils/app_vibration.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/safe_avatar.dart';
import '../pulse/user_profile_detail_screen.dart';

/// Opens a themed bottom sheet listing users who liked [postId].
Future<void> showPostLikesBottomSheet(BuildContext context, {required int postId}) async {
  final token = Get.find<AuthController>().token;
  if (token == null) {
    ToastHelper.showError('Please sign in to view likes');
    return;
  }

  AppVibration.likesListOpen();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PostLikesSheetContent(postId: postId, token: token),
  );
}

class _PostLikesSheetContent extends StatefulWidget {
  const _PostLikesSheetContent({
    required this.postId,
    required this.token,
  });

  final int postId;
  final String token;

  @override
  State<_PostLikesSheetContent> createState() => _PostLikesSheetContentState();
}

class _PostLikesSheetContentState extends State<_PostLikesSheetContent> {
  final ApiService _api = ApiService();
  final List<PostLikeUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.getPostLikes(
        token: widget.token,
        postId: widget.postId,
      );
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(result.users);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openUser(PostLikeUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => UserProfileDetailScreen(
          userData: user.toUserProfileDetailData(),
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        gradient: AppTheme.scaffoldGradient(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: cs.onSurface),
                ),
                Expanded(
                  child: Text(
                    'People who liked this',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          if (_users.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_users.length} ${_users.length == 1 ? 'person' : 'people'}',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _load,
                                child: Text('Retry', style: TextStyle(color: cs.primary)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              'No likes yet',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withOpacity(0.15)),
                            itemBuilder: (context, index) {
                              final u = _users[index];
                              final displayName = u.profile['display_name']?.toString() ?? u.name;
                              final avatar = u.profile['avatar']?.toString() ?? u.profile['avatar_url']?.toString();

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openUser(u),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    child: Row(
                                      children: [
                                        SafeAvatar(
                                          imageUrl: avatar,
                                          size: 48,
                                          fallbackText: displayName,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurface,
                                                ),
                                              ),
                                              if (u.likedAt != null)
                                                Text(
                                                  timeago.format(u.likedAt!, allowFromNow: true),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: cs.onSurfaceVariant.withOpacity(0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
