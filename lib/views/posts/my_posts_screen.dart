import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/post_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
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

    try {
      final token = _storageService.getToken();
      if (token == null) return;

      await _apiService.likePost(token, post.id!);

      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          final isLiked = post.liked ?? false;
          _posts[index] = Post(
            id: post.id,
            userId: post.userId,
            content: post.content,
            type: post.type,
            visibility: post.visibility,
            media: post.media,
            likesCount: (post.likesCount ?? 0) + (isLiked ? -1 : 1),
            commentsCount: post.commentsCount,
            liked: !isLiked,
            isModerated: post.isModerated,
            isFlagged: post.isFlagged,
            createdAt: post.createdAt,
            user: post.user,
            permissions: post.permissions,
          );
        }
      });

      ToastHelper.showSuccess(
        (post.liked ?? false) ? 'Post unliked' : 'Post liked',
      );
    } catch (e) {
      ToastHelper.showError('Failed to like post');
    }
  }

  void _handleComment(Post post) {
    ToastHelper.showInfo('Comments feature coming soon');
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
          return PostCard(
            post: post,
            onLike: () => _handleLike(post),
            onComment: () => _handleComment(post),
            onDelete: post.id != null ? () => _deletePost(post.id!) : null,
          );
        },
      ),
    );
  }
}
