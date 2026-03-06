import 'package:cached_network_image/cached_network_image.dart';
import 'package:comment_tree/comment_tree.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../data/models/comment_model.dart';
import '../utils/progress_dialog_helper.dart';
import '../views/pulse/user_profile_detail_screen.dart';

class CommentCard extends StatelessWidget {
  final CommentModel comment;
  final int postId;
  final Function(int commentId, String userName)? onReply;
  final int? currentUserId;
  final dynamic controller;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postId,
    this.onReply,
    this.currentUserId,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final userId = currentUserId ?? authController.currentUser.value?.id;
    final isOwnComment = userId == comment.userId;

    return CommentTreeWidget<CommentModel, dynamic>(
      comment,
      _flattenReplies(comment),
      treeThemeData: TreeThemeData(
        lineColor: Colors.grey[700]!,
        lineWidth: 2,
      ),
      avatarRoot: (context, data) => PreferredSize(
        preferredSize: const Size.fromRadius(16),
        child: GestureDetector(
          onTap: () => _showUserProfile(context, data),
          child: data.user.avatar != null
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: data.user.avatar!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      maxWidthDiskCache: 64,
                      maxHeightDiskCache: 64,
                      placeholder: (context, url) => CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          data.user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          data.user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    data.user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
      avatarChild: (context, data) => PreferredSize(
        preferredSize: const Size.fromRadius(12),
        child: GestureDetector(
          onTap: () => _showUserProfile(context, data),
          child: data.user.avatar != null
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: data.user.avatar!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      maxWidthDiskCache: 48,
                      maxHeightDiskCache: 48,
                      placeholder: (context, url) => CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          data.user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          data.user.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    data.user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
      contentRoot: (context, data) {
        return _buildCommentContent(context, data, isOwnComment, isRoot: true);
      },
      contentChild: (context, data) {
        final isOwnChildComment = userId == data.userId;
        return _buildCommentContent(context, data, isOwnChildComment, isRoot: false);
      },
    );
  }

  List<CommentModel> _flattenReplies(CommentModel comment) {
    List<CommentModel> flattened = [];
    for (var reply in comment.replies) {
      flattened.add(
        CommentModel(
          id: reply.id,
          postId: reply.postId,
          userId: reply.userId,
          content: reply.content,
          parentId: reply.parentId,
          createdAt: reply.createdAt,
          user: reply.user,
          replies: _flattenReplies(reply),
          replyingToName: reply.replyingToName,
          canReply: reply.canReply,
        ),
      );
    }
    return flattened;
  }

  Widget _buildCommentContent(BuildContext context, CommentModel data, bool isOwn, {required bool isRoot}) {
    // Check if user can delete this comment
    // Either they own the comment, or controller allows deleting any comment (post owner)
    bool canDeleteAnyComment = false;
    try {
      canDeleteAnyComment = (controller as dynamic).canDeleteAnyComment ?? false;
    } catch (e) {
      canDeleteAnyComment = false;
    }
    final canDelete = controller != null && (isOwn || canDeleteAnyComment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showUserProfile(context, data),
                      child: Text(
                        data.user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (canDelete)
                    InkWell(
                      onTap: () => _deleteComment(context, controller!),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (data.replyingToName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '@${data.replyingToName} ',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Text(
                data.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              timeago.format(data.createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            if (onReply != null && data.canReply) ...[
              const SizedBox(width: 16),
              InkWell(
                onTap: () => onReply!(data.id, data.user.name),
                child: Text(
                  'Reply',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _deleteComment(BuildContext context, dynamic controller) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Comment',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ProgressDialogHelper.show(context);
      await controller.deleteComment(comment.id, postId);
      ProgressDialogHelper.hide();
    }
  }

  void _showUserProfile(BuildContext context, CommentModel data) {
    final authController = Get.find<AuthController>();
    final loggedInUserId = currentUserId ?? authController.currentUser.value?.id;

    // If it's the logged-in user's comment, navigate to profile page
    if (loggedInUserId == data.user.id) {
      // Navigate to profile tab using NavigationController
      if (Get.isRegistered<NavigationController>()) {
        Get.find<NavigationController>().navigateToProfile();
      }
      // Close any open modal sheets
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final profile = data.user.profile ?? {};

    final userData = {
      'id': data.user.id,
      'name': data.user.name,
      'user': {
        'id': data.user.id,
        'name': data.user.name,
        'profile': {
          'display_name': profile['display_name'] ?? data.user.name,
          'avatar': data.user.avatar,
          'bio': profile['bio'] ?? '',
          'profession': profile['profession'],
          'city': profile['city'],
          'state': profile['state'],
          'interests': profile['interests'] ?? [],
          'core_values': profile['core_values'] ?? [],
          'instagram_url': profile['instagram_url'],
          'snapchat_url': profile['snapchat_url'],
          'linkedin_url': profile['linkedin_url'],
          'facebook_url': profile['facebook_url'],
          'x_url': profile['x_url'],
          'tiktok_url': profile['tiktok_url'],
          'other_url': profile['other_url'],
        },
      },
      'in_inner_circle': false,
      'in_outer_circle': false,
      'inner_request_status': 'not_sent',
      'hide_action_buttons': true,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => UserProfileDetailScreen(
          userData: userData,
          scrollController: scrollController,
        ),
      ),
    );
  }
}
