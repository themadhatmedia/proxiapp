import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/post_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/comment_card.dart';
import '../../widgets/post_card.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final AuthController _authController = Get.find<AuthController>();

  bool _isLoading = true;
  List<Post> _posts = [];
  String? _errorMessage;
  final Map<int, List<CommentModel>> _postComments = {};
  final Map<int, bool> _showingComments = {};
  final Map<int, bool> _loadingComments = {};
  final Map<int, bool> _likingPosts = {};
  final Map<int, TextEditingController> _commentControllers = {};
  final Map<int, FocusNode> _commentFocusNodes = {};
  final Map<int, int?> _replyToCommentIds = {};
  final Map<int, String?> _replyToUserNames = {};

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _commentFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCommentController(int postId) {
    if (!_commentControllers.containsKey(postId)) {
      _commentControllers[postId] = TextEditingController();
    }
    return _commentControllers[postId]!;
  }

  FocusNode _getCommentFocusNode(int postId) {
    if (!_commentFocusNodes.containsKey(postId)) {
      _commentFocusNodes[postId] = FocusNode();
    }
    return _commentFocusNodes[postId]!;
  }

  Future<void> _loadMyPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = _storageService.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'Authentication required';
          _isLoading = false;
        });
        return;
      }

      final posts = await _apiService.getMyPosts(token);

      final currentUser = _authController.currentUser.value;

      final postsWithUser = posts.map((post) {
        if (post.user == null && currentUser != null) {
          return Post(
            id: post.id,
            userId: post.userId,
            content: post.content,
            type: post.type,
            visibility: post.visibility,
            media: post.media,
            likesCount: post.likesCount,
            commentsCount: post.commentsCount,
            liked: post.liked,
            isModerated: post.isModerated,
            isFlagged: post.isFlagged,
            createdAt: post.createdAt,
            user: PostUser(
              id: currentUser.id,
              name: currentUser.name,
              displayName: currentUser.displayName,
              avatarUrl: currentUser.avatarUrl,
            ),
            permissions: post.permissions,
          );
        }
        return post;
      }).toList();

      setState(() {
        _posts = postsWithUser;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      ToastHelper.showError('Failed to load posts: ${e.toString()}');
    }
  }

  Future<void> _handleRefresh() async {
    _postComments.clear();
    _showingComments.clear();
    _loadingComments.clear();
    await _loadMyPosts();
  }

  Future<void> _deletePost(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ProgressDialogHelper.show(context);

      try {
        final token = _storageService.getToken();
        if (token == null) {
          ProgressDialogHelper.hide();
          return;
        }

        await _apiService.deletePost(token, postId);

        if (mounted) {
          ProgressDialogHelper.hide();
          ToastHelper.showSuccess('Post deleted successfully');
          _loadMyPosts();
        }
      } catch (e) {
        if (mounted) {
          ProgressDialogHelper.hide();
          ToastHelper.showError('Failed to delete post: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _handleLike(Post post) async {
    if (post.id == null) return;
    if (_likingPosts[post.id] == true) return;

    setState(() {
      _likingPosts[post.id!] = true;
    });

    try {
      final token = _storageService.getToken();
      if (token == null) {
        setState(() {
          _likingPosts[post.id!] = false;
        });
        return;
      }

      final isLiked = post.liked;

      if (isLiked) {
        await _apiService.unlikePost(token, post.id!);
      } else {
        await _apiService.likePost(token, post.id!);
      }

      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = Post(
            id: post.id,
            userId: post.userId,
            content: post.content,
            type: post.type,
            visibility: post.visibility,
            media: post.media,
            likesCount: (post.likesCount) + (isLiked ? -1 : 1),
            commentsCount: post.commentsCount,
            liked: !isLiked,
            isModerated: post.isModerated,
            isFlagged: post.isFlagged,
            createdAt: post.createdAt,
            user: post.user,
            permissions: post.permissions,
          );
        }
        _likingPosts[post.id!] = false;
      });
    } catch (e) {
      setState(() {
        _likingPosts[post.id!] = false;
      });
      ToastHelper.showError('Failed to like post');
    }
  }

  void _handleComment(Post post) {
    if (post.id == null) return;
    setState(() {
      final isShowing = _showingComments[post.id] ?? false;
      if (!isShowing) {
        _fetchComments(post.id!);
      }
      _showingComments[post.id!] = !isShowing;
    });
  }

  Future<void> _fetchComments(int postId) async {
    setState(() {
      _loadingComments[postId] = true;
    });

    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.getPostComments(token, postId);

      if (response['success'] == true) {
        final commentsList = response['comments'] as List? ?? [];
        final comments = commentsList.map((json) => CommentModel.fromJson(json)).toList();

        final Map<int, CommentModel> commentMap = {};
        final List<CommentModel> rootComments = [];

        for (var comment in comments) {
          commentMap[comment.id] = comment;
          if (comment.parentId == null) {
            rootComments.add(comment);
          }
        }

        for (var comment in comments) {
          if (comment.parentId != null) {
            final parent = commentMap[comment.parentId];
            if (parent != null) {
              String? replyingToName;
              if (parent.parentId != null) {
                replyingToName = parent.user.name;
              }

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
              );

              CommentModel rootParent = parent;
              while (rootParent.parentId != null && commentMap[rootParent.parentId!] != null) {
                rootParent = commentMap[rootParent.parentId!]!;
              }

              rootParent.replies = [...rootParent.replies, commentWithReplyName];
            }
          }
        }

        setState(() {
          _postComments[postId] = rootComments;

          // Update the comment count in the post
          final postIndex = _posts.indexWhere((p) => p.id == postId);
          if (postIndex != -1) {
            // Calculate total comments (root + all replies)
            int totalComments = rootComments.length;
            for (var comment in rootComments) {
              totalComments += comment.replies.length;
            }
            _posts[postIndex].commentsCount = totalComments;
          }
        });
      }
    } catch (e) {
      ToastHelper.showError('Failed to load comments: ${e.toString()}');
    } finally {
      setState(() {
        _loadingComments[postId] = false;
      });
    }
  }

  Future<void> _submitComment(int postId) async {
    final controller = _getCommentController(postId);
    final content = controller.text.trim();
    if (content.isEmpty) return;

    final focusNode = _getCommentFocusNode(postId);
    focusNode.unfocus();

    ProgressDialogHelper.show(context);

    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.addComment(
        token,
        postId,
        content,
        parentId: _replyToCommentIds[postId],
      );

      if (response['success'] == true) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          setState(() {
            _posts[index] = Post(
              id: _posts[index].id,
              userId: _posts[index].userId,
              content: _posts[index].content,
              type: _posts[index].type,
              visibility: _posts[index].visibility,
              media: _posts[index].media,
              likesCount: _posts[index].likesCount,
              commentsCount: response['comments_count'] ?? _posts[index].commentsCount + 1,
              liked: _posts[index].liked,
              isModerated: _posts[index].isModerated,
              isFlagged: _posts[index].isFlagged,
              createdAt: _posts[index].createdAt,
              user: _posts[index].user,
              permissions: _posts[index].permissions,
            );
          });
        }

        controller.clear();
        setState(() {
          _replyToCommentIds[postId] = null;
          _replyToUserNames[postId] = null;
        });

        await _fetchComments(postId);
      }
    } catch (e) {
      ToastHelper.showError('Failed to add comment: ${e.toString()}');
    } finally {
      if (mounted) {
        ProgressDialogHelper.hide();
      }
    }
  }

  Future<void> _deleteComment(int commentId, int postId) async {
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.deleteComment(token, commentId);

      if (response['success'] == true) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          setState(() {
            _posts[index] = Post(
              id: _posts[index].id,
              userId: _posts[index].userId,
              content: _posts[index].content,
              type: _posts[index].type,
              visibility: _posts[index].visibility,
              media: _posts[index].media,
              likesCount: _posts[index].likesCount,
              commentsCount: response['comments_count'] ?? _posts[index].commentsCount - 1,
              liked: _posts[index].liked,
              isModerated: _posts[index].isModerated,
              isFlagged: _posts[index].isFlagged,
              createdAt: _posts[index].createdAt,
              user: _posts[index].user,
              permissions: _posts[index].permissions,
            );
          });
        }

        await _fetchComments(postId);
      }
    } catch (e) {
      ToastHelper.showError('Failed to delete comment: ${e.toString()}');
    }
  }

  Widget _buildCommentsSection(Post post) {
    final postId = post.id!;
    final comments = _postComments[postId] ?? [];
    final isLoading = _loadingComments[postId] ?? false;
    final canComment = post.permissions?.canComment ?? false;
    final canReply = post.permissions?.canReply ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _handleComment(post),
                child: const Text(
                  'Hide',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SpinKitWave(
                  color: Colors.blue,
                  size: 30.0,
                ),
              ),
            )
          else if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No comments yet',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _buildCommentsList(postId, comments, canReply),
            ),
          if (canComment) ...[
            const SizedBox(height: 12),
            if (_replyToCommentIds[postId] != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'Replying to ${_replyToUserNames[postId]}',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        _getCommentFocusNode(postId).unfocus();
                        setState(() {
                          _replyToCommentIds[postId] = null;
                          _replyToUserNames[postId] = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _getCommentController(postId),
                    focusNode: _getCommentFocusNode(postId),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToCommentIds[postId] != null ? 'Write a reply...' : 'Write a comment...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _submitComment(postId),
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCommentsList(int postId, List<CommentModel> comments, bool canReply) {
    final List<Widget> widgets = [];

    for (var comment in comments) {
      widgets.add(
        CommentCard(
          comment: comment,
          postId: postId,
          onReply: canReply
              ? (commentId, userName) {
                  setState(() {
                    _replyToCommentIds[postId] = commentId;
                    _replyToUserNames[postId] = userName;
                  });
                  _getCommentController(postId).clear();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _getCommentFocusNode(postId).requestFocus();
                  });
                }
              : null,
          currentUserId: _authController.currentUser.value?.id,
          controller: _MyPostsCommentController(
            deleteComment: _deleteComment,
            canDeleteAnyComment: true,
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF0A0A0A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'My Posts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (!_isLoading)
            Text(
              '${_posts.length} ${_posts.length == 1 ? 'post' : 'posts'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withOpacity(0.4),
              size: 64,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMyPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              color: Colors.white.withOpacity(0.2),
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first post to get started',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Column(
            children: [
              PostCard(
                post: post,
                onLike: () => _handleLike(post),
                onComment: () => _handleComment(post),
                onDelete: post.id != null ? () => _deletePost(post.id!) : null,
                isLiking: _likingPosts[post.id] ?? false,
              ),
              if (_showingComments[post.id] == true) _buildCommentsSection(post),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

// Controller wrapper for comment deletion
class _MyPostsCommentController {
  final Future<void> Function(int commentId, int postId) deleteComment;
  final bool canDeleteAnyComment;

  _MyPostsCommentController({
    required this.deleteComment,
    this.canDeleteAnyComment = false,
  });
}
