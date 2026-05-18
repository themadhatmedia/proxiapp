import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'feed_video_autoplay_controller.dart';

import '../config/post_reaction_emojis.dart';
import '../data/models/comment_model.dart';
import '../data/models/feed_wall_page.dart';
import '../data/models/post_model.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';
import '../utils/toast_helper.dart';

class DiscoverController extends GetxController {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  static const int postsPerPage = 12;

  final RxList<Post> innerProxyPosts = <Post>[].obs;
  final RxList<Post> outerProxyPosts = <Post>[].obs;
  final RxBool isLoadingInner = false.obs;
  final RxBool isLoadingOuter = false.obs;
  final RxBool isLoadingMoreInner = false.obs;
  final RxBool isLoadingMoreOuter = false.obs;
  final RxBool hasMoreInner = false.obs;
  final RxBool hasMoreOuter = false.obs;

  String? _innerNextCursor;
  String? _outerNextCursor;

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
    isLoadingMoreInner.value = false;
    isLoadingMoreOuter.value = false;
    hasMoreInner.value = false;
    hasMoreOuter.value = false;
    _innerNextCursor = null;
    _outerNextCursor = null;
  }

  Future<void> fetchPosts() async {
    if (Get.isRegistered<FeedVideoAutoplayController>()) {
      Get.find<FeedVideoAutoplayController>().pauseAll();
    }

    _innerNextCursor = null;
    _outerNextCursor = null;
    isLoadingInner.value = true;
    isLoadingOuter.value = true;

    try {
      final token = _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await _apiService.getDiscoverPosts(
        token,
        perPage: postsPerPage,
        innerPerPage: postsPerPage,
        outerPerPage: postsPerPage,
      );

      final payload = unwrapDiscoverFeedPayload(response);
      final innerPage = FeedWallPage.fromSection(payload['inner_proxy'], _parsePosts);
      final outerPage = FeedWallPage.fromSection(payload['outer_proxy'], _parsePosts);

      innerProxyPosts
        ..clear()
        ..addAll(innerPage.posts);
      outerProxyPosts
        ..clear()
        ..addAll(outerPage.posts);

      _innerNextCursor = innerPage.nextCursor;
      _outerNextCursor = outerPage.nextCursor;
      hasMoreInner.value = innerPage.hasMore;
      hasMoreOuter.value = outerPage.hasMore;

      innerProxyPosts.refresh();
      outerProxyPosts.refresh();

      _refreshFeedVideoAfterLoad();
    } catch (e) {
      ToastHelper.showError('Failed to load posts: ${e.toString()}');
    } finally {
      isLoadingInner.value = false;
      isLoadingOuter.value = false;
    }
  }

  Future<void> loadMoreInner() async {
    if (!hasMoreInner.value || isLoadingMoreInner.value || isLoadingInner.value) return;
    final cursor = _innerNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    final token = _storageService.getToken();
    if (token == null) return;

    isLoadingMoreInner.value = true;
    try {
      final response = await _apiService.getDiscoverPosts(
        token,
        innerCursor: cursor,
      );

      final payload = unwrapDiscoverFeedPayload(response);
      final page = FeedWallPage.fromSection(payload['inner_proxy'], _parsePosts);
      if (page.posts.isEmpty) {
        hasMoreInner.value = false;
        _innerNextCursor = null;
        return;
      }

      innerProxyPosts.addAll(page.posts);
      _innerNextCursor = page.nextCursor;
      hasMoreInner.value = page.hasMore;
      innerProxyPosts.refresh();
    } catch (e) {
      debugPrint('loadMoreInner: $e');
    } finally {
      isLoadingMoreInner.value = false;
    }
  }

  Future<void> loadMoreOuter() async {
    if (!hasMoreOuter.value || isLoadingMoreOuter.value || isLoadingOuter.value) return;
    final cursor = _outerNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    final token = _storageService.getToken();
    if (token == null) return;

    isLoadingMoreOuter.value = true;
    try {
      final response = await _apiService.getDiscoverPosts(
        token,
        outerCursor: cursor,
      );

      final payload = unwrapDiscoverFeedPayload(response);
      final page = FeedWallPage.fromSection(payload['outer_proxy'], _parsePosts);
      if (page.posts.isEmpty) {
        hasMoreOuter.value = false;
        _outerNextCursor = null;
        return;
      }

      outerProxyPosts.addAll(page.posts);
      _outerNextCursor = page.nextCursor;
      hasMoreOuter.value = page.hasMore;
      outerProxyPosts.refresh();
    } catch (e) {
      debugPrint('loadMoreOuter: $e');
    } finally {
      isLoadingMoreOuter.value = false;
    }
  }

  void _refreshFeedVideoAfterLoad() {
    if (!Get.isRegistered<FeedVideoAutoplayController>()) return;
    Get.find<FeedVideoAutoplayController>().refreshVisibilityDetection();
  }

  List<Post> _parsePosts(List<dynamic> raw) {
    final out = <Post>[];
    for (final item in raw) {
      try {
        if (item is Map<String, dynamic>) {
          out.add(Post.fromJson(item));
        } else if (item is Map) {
          out.add(Post.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        debugPrint('DiscoverController: skipped post: $e');
      }
    }
    return out;
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

  Future<void> _setReactionImpl(Post post, String emoji) async {
    final token = _storageService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final res = await _apiService.reactToPost(token: token, postId: post.id!, emoji: emoji);
    post.mergeReactionResponse(res);
    _updatePostInLists(post);
  }

  Future<void> _removeReactionImpl(Post post) async {
    final token = _storageService.getToken();
    if (token == null) throw Exception('Not authenticated');
    final res = await _apiService.removePostReaction(token: token, postId: post.id!);
    post.mergeReactionResponse(res);
    _updatePostInLists(post);
  }

  /// Quick tap: 👍🏻 toggle (Facebook-style default).
  Future<void> toggleReactionQuick(Post post) async {
    if (post.id == null || likingPosts[post.id] == true) return;
    if (!(post.permissions?.canLike ?? false)) return;

    likingPosts[post.id!] = true;
    likingPosts.refresh();

    try {
      final thumb = PostReactionEmojis.thumbsUp;
      if (post.reactions?.myEmoji == thumb) {
        await _removeReactionImpl(post);
      } else {
        await _setReactionImpl(post, thumb);
      }
    } catch (e) {
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      likingPosts[post.id!] = false;
      likingPosts.refresh();
    }
  }

  /// Long-press picker selection (same emoji removes).
  Future<void> chooseReaction(Post post, String emoji) async {
    if (post.id == null || likingPosts[post.id] == true) return;
    if (!(post.permissions?.canLike ?? false)) return;
    if (!PostReactionEmojis.isAllowed(emoji)) return;

    likingPosts[post.id!] = true;
    likingPosts.refresh();

    try {
      if (post.reactions?.myEmoji == emoji) {
        await _removeReactionImpl(post);
      } else {
        await _setReactionImpl(post, emoji);
      }
    } catch (e) {
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
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

        final post = _findPostById(postId);
        if (post != null) {
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
