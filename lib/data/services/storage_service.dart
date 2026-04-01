import 'package:get_storage/get_storage.dart';

class StorageService {
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String createPostHintIndexKey = 'create_post_hint_index';

  final _storage = GetStorage();

  void saveToken(String token) {
    _storage.write(tokenKey, token);
  }

  String? getToken() {
    return _storage.read(tokenKey);
  }

  void saveUserData(String userData) {
    _storage.write(userKey, userData);
  }

  String? getUserData() {
    return _storage.read(userKey);
  }

  void clearAll() {
    _storage.erase();
  }

  /// Next hint to show on create-post (0–9); wraps after each visit.
  int getCreatePostHintIndex() {
    final v = _storage.read(createPostHintIndexKey);
    if (v is int) return v % 10;
    return 0;
  }

  void setCreatePostHintIndex(int index) {
    _storage.write(createPostHintIndexKey, index % 10);
  }
}
