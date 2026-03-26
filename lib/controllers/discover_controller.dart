import 'package:get/get.dart';

import '../data/models/comment_model.dart';
import '../data/models/post_model.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';
import '../utils/toast_helper.dart';

class DiscoverController extends GetxController {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  final RxList<Post> innerProxyPosts = <Post>[].obs;
  final RxList<Post> outerProxyPosts = <Post>[].obs;
  final RxBool isLoadingInner = false.obs;
  final RxBool isLoadingOuter = false.obs;
  final RxMap<int, List<CommentModel>> postComments = <int, List<CommentModel>>{}.obs;
  final RxMap<int, bool> showingComments = <int, bool>{}.obs;
  final RxMap<int, bool> loadingComments = <int, bool>{}.obs;
  final RxMap<int, bool> likingPosts = <int, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPosts();
  }

  void reset() {
    innerProxyPosts.clear();
    outerProxyPosts.clear();
    postComments.clear();
    showingComments.clear();
    loadingComments.clear();
    likingPosts.clear();
    isLoadingInner.value = false;
    isLoadingOuter.value = false;
  }

  Future<void> fetchPosts() async {
    isLoadingInner.value = true;
    isLoadingOuter.value = true;

    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.getDiscoverPosts(token);

      final innerList = response['inner_proxy'] as List? ?? [];
      final outerList = response['outer_proxy'] as List? ?? [];

      innerProxyPosts.value = innerList.map((json) => Post.fromJson(json)).toList();
      outerProxyPosts.value = outerList.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      ToastHelper.showError('Failed to load posts: ${e.toString()}');
    } finally {
      isLoadingInner.value = false;
      isLoadingOuter.value = false;
    }
  }

  Future<void> refreshInnerPosts() async {
    showingComments.clear();
    postComments.clear();
    loadingComments.clear();
    await fetchPosts();
  }

  Future<void> refreshOuterPosts() async {
    showingComments.clear();
    postComments.clear();
    loadingComments.clear();
    await fetchPosts();
  }

  Future<void> likePost(Post post) async {
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      await _apiService.likePost(token, post.id!);

      post.liked = true;
      post.likesCount = post.likesCount + 1;
      _updatePostInLists(post);
    } catch (e) {
      ToastHelper.showError('Failed to like post: ${e.toString()}');
    }
  }

  Future<void> unlikePost(Post post) async {
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      await _apiService.unlikePost(token, post.id!);

      post.liked = false;
      post.likesCount = post.likesCount - 1;
      _updatePostInLists(post);
    } catch (e) {
      ToastHelper.showError('Failed to unlike post: ${e.toString()}');
    }
  }

  Future<void> toggleLike(Post post) async {
    if (likingPosts[post.id] == true) return;

    likingPosts[post.id!] = true;
    likingPosts.refresh();

    try {
      if (post.liked) {
        await unlikePost(post);
      } else {
        await likePost(post);
      }
    } catch (e) {
      ToastHelper.showError('Failed to update like: ${e.toString()}');
    } finally {
      likingPosts[post.id!] = false;
      likingPosts.refresh();
    }
  }

  Future<void> fetchComments(int postId) async {
    loadingComments[postId] = true;
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

        postComments[postId] = rootComments;

        // Update the comment count in the post
        final post = _findPostById(postId);
        if (post != null) {
          // Calculate total comments (root + all replies)
          int totalComments = rootComments.length;
          for (var comment in rootComments) {
            totalComments += comment.replies.length;
          }
          post.commentsCount = totalComments;
          _updatePostInLists(post);
        }
      }
    } catch (e) {
      ToastHelper.showError('Failed to load comments: ${e.toString()}');
    } finally {
      loadingComments[postId] = false;
    }
  }

  Future<void> addComment(int postId, String content, {int? parentId}) async {
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.addComment(
        token,
        postId,
        content,
        parentId: parentId,
      );

      if (response['success'] == true) {
        final post = _findPostById(postId);
        if (post != null) {
          post.commentsCount = response['comments_count'] ?? post.commentsCount + 1;
          _updatePostInLists(post);
        }

        await fetchComments(postId);
      }
    } catch (e) {
      ToastHelper.showError('Failed to add comment: ${e.toString()}');
    }
  }

  Future<void> deleteComment(int commentId, int postId) async {
    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.deleteComment(token, commentId);

      if (response['success'] == true) {
        final post = _findPostById(postId);
        if (post != null) {
          post.commentsCount = response['comments_count'] ?? post.commentsCount - 1;
          _updatePostInLists(post);
        }

        await fetchComments(postId);
      }
    } catch (e) {
      ToastHelper.showError('Failed to delete comment: ${e.toString()}');
    }
  }

  void toggleComments(int postId) {
    final isShowing = showingComments[postId] ?? false;
    if (!isShowing) {
      fetchComments(postId);
    }
    showingComments[postId] = !isShowing;
  }

  Post? _findPostById(int postId) {
    try {
      return innerProxyPosts.firstWhere((p) => p.id == postId);
    } catch (e) {
      try {
        return outerProxyPosts.firstWhere((p) => p.id == postId);
      } catch (e) {
        return null;
      }
    }
  }

  void _updatePostInLists(Post post) {
    final innerIndex = innerProxyPosts.indexWhere((p) => p.id == post.id);
    if (innerIndex != -1) {
      innerProxyPosts[innerIndex] = post;
      innerProxyPosts.refresh();
      return;
    }

    final outerIndex = outerProxyPosts.indexWhere((p) => p.id == post.id);
    if (outerIndex != -1) {
      outerProxyPosts[outerIndex] = post;
      outerProxyPosts.refresh();
    }
  }
}
