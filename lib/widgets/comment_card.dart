import 'package:comment_tree/comment_tree.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../controllers/auth_controller.dart';
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
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            backgroundImage: data.user.avatar != null ? NetworkImage(data.user.avatar!) : null,
            child: data.user.avatar == null
                ? Text(
                    data.user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
      ),
      avatarChild: (context, data) => PreferredSize(
        preferredSize: const Size.fromRadius(12),
        child: GestureDetector(
          onTap: () => _showUserProfile(context, data),
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[800],
            backgroundImage: data.user.avatar != null ? NetworkImage(data.user.avatar!) : null,
            child: data.user.avatar == null
                ? Text(
                    data.user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
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
            if (onReply != null) ...[
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
    final userData = {
      'id': data.user.id,
      'name': data.user.name,
      'user': {
        'id': data.user.id,
        'name': data.user.name,
        'profile': {
          'display_name': data.user.name,
          'avatar': data.user.avatar,
          'bio': '',
          'profession': null,
          'city': null,
          'state': null,
          'interests': [],
          'core_values': [],
          'instagram_url': null,
          'snapchat_url': null,
          'linkedin_url': null,
          'facebook_url': null,
          'x_url': null,
          'tiktok_url': null,
          'other_url': null,
        },
      },
      'in_inner_circle': false,
      'in_outer_circle': false,
      'inner_request_status': 'not_sent',
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
