import 'package:get_storage/get_storage.dart';

class StorageService {
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

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
}
