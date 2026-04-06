import 'package:get/get.dart';

import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
import '../utils/toast_helper.dart';

class BookmarksController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxList<User> bookmarkedUsers = <User>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentPage = 1.obs;

  String? _token;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _token = args['token'] as String?;
    }
    if (_token != null) {
      loadBookmarks();
    }
  }

  Future<void> loadBookmarks({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      bookmarkedUsers.clear();
      hasMore.value = true;
    }

    if (isLoading.value || !hasMore.value) return;
    if (_token == null) return;

    try {
      isLoading.value = true;

      final response = await _apiService.getBookmarks(
        token: _token!,
        page: currentPage.value,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final List<dynamic> favorites = data['favorites'] ?? [];

        final users = favorites.map((json) => User.fromJson(json)).toList();

        if (refresh) {
          bookmarkedUsers.value = users;
        } else {
          bookmarkedUsers.addAll(users);
        }

        final pagination = data['pagination'];
        if (pagination != null) {
          hasMore.value = pagination['has_more'] == true;
          if (hasMore.value) {
            currentPage.value++;
          }
        } else {
          hasMore.value = false;
        }
      }
    } catch (e) {
      ToastHelper.showError('Failed to load bookmarks: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> toggleBookmark(int userId, bool isCurrentlyBookmarked) async {
    if (_token == null) return false;

    try {
      if (isCurrentlyBookmarked) {
        final response = await _apiService.removeBookmark(
          token: _token!,
          userId: userId,
        );

        if (response['success'] == true) {
          bookmarkedUsers.removeWhere((user) => user.id == userId);
          ToastHelper.showSuccess('Bookmark removed');
          return false;
        }
      } else {
        final response = await _apiService.addBookmark(
          token: _token!,
          userId: userId,
        );

        if (response['success'] == true) {
          ToastHelper.showSuccess('User bookmarked');
          return true;
        }
      }
    } catch (e) {
      ToastHelper.showError('Failed to update bookmark: ${e.toString()}');
    }

    return isCurrentlyBookmarked;
  }

  void removeBookmarkLocally(int userId) {
    bookmarkedUsers.removeWhere((user) => user.id == userId);
  }

  void reset() {
    bookmarkedUsers.clear();
    currentPage.value = 1;
    hasMore.value = true;
    isLoading.value = false;
  }
}
