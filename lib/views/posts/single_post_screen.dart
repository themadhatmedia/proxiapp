import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/post_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import '../../utils/app_vibration.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/comment_card.dart';
import '../../widgets/post_card.dart';
import 'post_likes_bottom_sheet.dart';

class SinglePostScreen extends StatefulWidget {
  final int postId;
  final bool openCommentsOnLoad;
  final bool openLikesOnLoad;

  const SinglePostScreen({
    super.key,
    required this.postId,
    this.openCommentsOnLoad = false,
    this.openLikesOnLoad = false,
  });

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final AuthController _authController = Get.find<AuthController>();

  bool _isLoading = true;
  bool _isLiking = false;
  bool _showComments = false;
  bool _loadingComments = false;
  Post? _post;
  String? _errorMessage;
  List<CommentModel> _comments = <CommentModel>[];

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  int? _replyToCommentId;
  String? _replyToUserName;
  bool _replyToCommentCanReply = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await _apiService.getPostDetail(
        token: token,
        postId: widget.postId,
      );

      final postJson = response['post'];
      if (response['success'] == true && postJson is Map<String, dynamic>) {
        final parsedPost = Post.fromJson(postJson);
        setState(() {
          _post = parsedPost;
          _isLoading = false;
        });

        if (widget.openCommentsOnLoad) {
          await _toggleComments(forceOpen: true);
        }
        if (widget.openLikesOnLoad && parsedPost.id != null && parsedPost.likesCount > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showPostLikesBottomSheet(context, postId: parsedPost.id!);
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to load post');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLike() async {
    final post = _post;
    if (post?.id == null || _isLiking) return;
    if (!(post!.permissions?.canLike ?? false)) return;

    setState(() => _isLiking = true);
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      if (post.liked) {
        await _apiService.unlikePost(token, post.id!);
        setState(() {
          post.liked = false;
          post.likesCount = (post.likesCount - 1).clamp(0, 1 << 30);
        });
      } else {
        await _apiService.likePost(token, post.id!);
        AppVibration.interactionSuccess();
        setState(() {
          post.liked = true;
          post.likesCount = post.likesCount + 1;
        });
      }
    } catch (e) {
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', 'Failed to like post: '));
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _toggleComments({bool forceOpen = false}) async {
    final post = _post;
    if (post?.id == null) return;

    if (!_showComments || forceOpen) {
      await _fetchComments(post!.id!);
      if (!mounted) return;
      setState(() => _showComments = true);
      return;
    }
    setState(() => _showComments = false);
  }

  Future<void> _fetchComments(int postId) async {
    setState(() => _loadingComments = true);
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final response = await _apiService.getPostComments(token, postId);
      if (response['success'] != true) return;

      final commentsList = response['comments'] as List? ?? [];
      final comments = commentsList.map((json) => CommentModel.fromJson(Map<String, dynamic>.from(json))).toList();
      final Map<int, CommentModel> commentMap = {};
      final List<CommentModel> rootComments = [];

      for (final comment in comments) {
        commentMap[comment.id] = comment;
        if (comment.parentId == null) rootComments.add(comment);
      }

      for (final comment in comments) {
        if (comment.parentId == null) continue;
        final parent = commentMap[comment.parentId];
        if (parent == null) continue;

        String? replyingToName;
        if (parent.parentId != null) replyingToName = parent.user.name;

        final commentWithReplyName = CommentModel(
          id: comment.id,
          postId: comment.postId,
          userId: comment.userId,
          content: comment.content,
          parentId: comment.parentId,
          createdAt: comment.createdAt,
          user: comment.user,
          replies: comment.replies,
          replyingToName: replyingToName,
          canReply: comment.canReply,
        );

        CommentModel rootParent = parent;
        while (rootParent.parentId != null && commentMap[rootParent.parentId!] != null) {
          rootParent = commentMap[rootParent.parentId!]!;
        }
        rootParent.replies = [...rootParent.replies, commentWithReplyName];
      }

      int totalComments = rootComments.length;
      for (final c in rootComments) {
        totalComments += c.replies.length;
      }

      setState(() {
        _comments = rootComments;
        if (_post != null) _post!.commentsCount = totalComments;
      });
    } catch (e) {
      ToastHelper.showError('Failed to load comments: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final post = _post;
    if (post?.id == null) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final canComment = post!.permissions?.canComment ?? false;
    if (_replyToCommentId == null && !canComment) {
      ToastHelper.showInfo('You cannot comment on this post');
      return;
    }
    if (_replyToCommentId != null && !_replyToCommentCanReply) {
      ToastHelper.showInfo('You cannot reply to comments on this post');
      return;
    }

    _commentFocusNode.unfocus();
    ProgressDialogHelper.show(context);
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.addComment(
        token,
        post.id!,
        content,
        parentId: _replyToCommentId,
      );
      if (response['success'] != true) return;

      _commentController.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToUserName = null;
        _replyToCommentCanReply = false;
        _post?.commentsCount = response['comments_count'] ?? ((_post?.commentsCount ?? 0) + 1);
      });
      await _fetchComments(post.id!);
    } catch (e) {
      ToastHelper.showError('Failed to add comment: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) ProgressDialogHelper.hide();
    }
  }

  Future<void> _deleteComment(int commentId, int postId) async {
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.deleteComment(token, commentId);
      if (response['success'] != true) return;

      setState(() {
        _post?.commentsCount = response['comments_count'] ?? ((_post?.commentsCount ?? 1) - 1);
      });
      await _fetchComments(postId);
    } catch (e) {
      ToastHelper.showError('Failed to delete comment: ${e.toString().replaceFirst('Exception: ', '')}');
    }
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
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: cs.primary))
                    : _errorMessage != null
                        ? _buildError(context)
                        : _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.proxi.surfaceCard,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
          ),
          Expanded(
            child: Text(
              'Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: cs.onSurfaceVariant.withOpacity(0.5), size: 64),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPost, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final post = _post;
    if (post == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadPost,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [
          PostCard(
            post: post,
            onLike: _handleLike,
            onComment: () {
              AppVibration.likesListOpen();
              _toggleComments();
            },
            onLikesTap: post.id != null && post.likesCount > 0 ? () => showPostLikesBottomSheet(context, postId: post.id!) : null,
            onCommentCountTap: post.id != null && post.commentsCount > 0 ? () => _toggleComments(forceOpen: true) : null,
            onDelete: null,
            isLiking: _isLiking,
          ),
          if (_showComments) _buildCommentsSection(context, post),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context, Post post) {
    final cs = Theme.of(context).colorScheme;
    final canComment = post.permissions?.canComment ?? false;
    final canReply = post.permissions?.canReply ?? false;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Comments', style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => _toggleComments(), child: Text('Hide', style: TextStyle(color: cs.primary))),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingComments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: SpinKitWave(color: cs.primary, size: 30)),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No comments yet', style: TextStyle(color: cs.onSurfaceVariant))),
            )
          else
            Column(children: _buildCommentsList(post.id!, _comments, canReply)),
          const SizedBox(height: 12),
          if (canComment || (_replyToCommentId != null && _replyToCommentCanReply))
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _replyToCommentId != null ? 'Write a reply...' : 'Write a comment...',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _submitComment, icon: const Icon(Icons.send), color: cs.primary),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCommentsList(int postId, List<CommentModel> comments, bool canReply) {
    final List<Widget> widgets = [];
    for (final comment in comments) {
      widgets.add(
        CommentCard(
          comment: comment,
          postId: postId,
          onReply: comment.canReply && canReply
              ? (commentId, userName) {
                  setState(() {
                    _replyToCommentId = commentId;
                    _replyToUserName = userName;
                    _replyToCommentCanReply = true;
                  });
                  _commentController.clear();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _commentFocusNode.requestFocus();
                  });
                }
              : null,
          currentUserId: _authController.currentUser.value?.id,
          controller: _SinglePostCommentController(deleteComment: _deleteComment),
        ),
      );
    }
    return widgets;
  }
}

class _SinglePostCommentController {
  final Future<void> Function(int commentId, int postId) deleteComment;
  final bool canDeleteAnyComment = false;

  _SinglePostCommentController({
    required this.deleteComment,
  });
}
