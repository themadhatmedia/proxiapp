import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/core_value_model.dart';
import '../models/interest_model.dart';
import '../models/plan_model.dart';
import '../models/user_model.dart';

class ApiService {
  static const String baseUrl = 'https://myproxi.app/index.php/api/v1';
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 30);

  void _logApiCall({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic requestData,
    int? statusCode,
    dynamic responseData,
    String? error,
  }) {
    developer.log(
      '\n${'=' * 80}\n'
      '[$method] $url\n'
      '${'-' * 80}\n'
      // 'Headers: ${headers != null ? jsonEncode(_sanitizeHeaders(headers)) : 'None'}\n'
      'Headers: ${headers != null ? jsonEncode(headers) : 'None'}\n'
      'Request Data: ${requestData != null ? jsonEncode(requestData) : 'None'}\n'
      '${'-' * 80}\n'
      'Status Code: ${statusCode ?? 'N/A'}\n'
      'Response Data: ${responseData != null ? jsonEncode(responseData) : 'None'}\n'
      '${error != null ? 'Error: $error\n' : ''}'
      '${'=' * 80}\n',
      name: 'ApiService',
    );
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      sanitized['Authorization'] = 'Bearer ***';
    }
    return sanitized;
  }

  Future<T> _retryRequest<T>({
    required Future<T> Function() request,
    required String method,
    required String url,
  }) async {
    int attempts = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempts < maxRetries) {
      try {
        attempts++;
        developer.log('Attempt $attempts/$maxRetries for $method $url', name: 'ApiService');
        return await request().timeout(timeout);
      } on TimeoutException catch (e) {
        print(e.message);
        developer.log('Timeout on attempt $attempts for $method $url', name: 'ApiService');
        if (attempts >= maxRetries) {
          _logApiCall(
            method: method,
            url: url,
            error: 'Request timeout after $maxRetries attempts',
          );
          throw Exception('Request timeout after $maxRetries attempts');
        }
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        if (attempts >= maxRetries) {
          _logApiCall(
            method: method,
            url: url,
            error: e.toString(),
          );
          rethrow;
        }
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw Exception('Failed after $maxRetries attempts');
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? displayName,
    String? bio,
    String? dateOfBirth,
    String? gender,
    String? phone,
    List<String>? interests,
    List<String>? preferences,
    File? avatar,
  }) async {
    final url = '$baseUrl/register';

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        http.Response response;

        if (avatar != null) {
          var request = http.MultipartRequest('POST', Uri.parse(url));

          request.fields['name'] = name;
          request.fields['email'] = email;
          request.fields['password'] = password;

          if (displayName != null && displayName.isNotEmpty) {
            request.fields['display_name'] = displayName;
          }
          if (bio != null && bio.isNotEmpty) {
            request.fields['bio'] = bio;
          }
          if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
            request.fields['date_of_birth'] = dateOfBirth;
          }
          if (gender != null && gender.isNotEmpty) {
            request.fields['gender'] = gender;
          }
          if (phone != null && phone.isNotEmpty) {
            request.fields['phone'] = phone;
          }
          if (interests != null && interests.isNotEmpty) {
            request.fields['interests'] = jsonEncode(interests);
          }
          if (preferences != null && preferences.isNotEmpty) {
            request.fields['preferences'] = jsonEncode(preferences);
          }

          request.files.add(
            await http.MultipartFile.fromPath('avatar', avatar.path),
          );

          developer.log('Registering with multipart data', name: 'ApiService');

          final streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
        } else {
          final requestData = {
            'name': name,
            'email': email,
            'password': password,
            if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
            if (bio != null && bio.isNotEmpty) 'bio': bio,
            if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'date_of_birth': dateOfBirth,
            if (gender != null && gender.isNotEmpty) 'gender': gender,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (interests != null && interests.isNotEmpty) 'interests': interests,
            if (preferences != null && preferences.isNotEmpty) 'preferences': preferences,
          };
          final headers = {'Content-Type': 'application/json'};

          _logApiCall(
            method: 'POST',
            url: url,
            headers: headers,
            requestData: requestData,
          );

          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(requestData),
          );
        }

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return AuthResponse.fromJson(responseData);
        } else {
          final errorMessage = responseData?['message'] ?? 'Registration failed';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final url = '$baseUrl/login';
    final requestData = {
      'email': email,
      'password': password,
    };
    final headers = {'Content-Type': 'application/json'};

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
        );

        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(requestData),
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return AuthResponse.fromJson(responseData);
        } else {
          final errorMessage = responseData?['message'] ?? 'Login failed';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<void> logout(String token) async {
    final url = '$baseUrl/logout';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
        );

        final response = await http.post(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200) {
          final errorMessage = responseData?['message'] ?? 'Logout failed';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<User> getProfile(String token) async {
    final url = '$baseUrl/profile';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return User.fromJson(responseData);
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get profile';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<User> updateProfile({
    required String token,
    String? name,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? dateOfBirth,
    String? gender,
    String? city,
    String? state,
    String? profession,
    List<String>? interests,
    List<String>? preferences,
    List<String>? coreValues,
    bool? locationVisible,
    File? avatar,
    String? accountType,
    String? linkedinUrl,
    String? facebookUrl,
    String? instagramUrl,
    String? xUrl,
    String? snapchatUrl,
    String? tiktokUrl,
    String? otherUrl,
    bool? restrictDm,
  }) async {
    final url = '$baseUrl/profile';

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        http.Response response;

        if (avatar != null) {
          var request = http.MultipartRequest('POST', Uri.parse(url));
          request.headers['Authorization'] = 'Bearer $token';

          if (name != null) request.fields['name'] = name;
          if (name != null) request.fields['display_name'] = name;
          if (bio != null) request.fields['bio'] = bio;
          if (avatarUrl != null) request.fields['avatar_url'] = avatarUrl;
          if (dateOfBirth != null) request.fields['date_of_birth'] = dateOfBirth;
          if (gender != null) request.fields['gender'] = gender;
          if (city != null) request.fields['city'] = city;
          if (state != null) request.fields['state'] = state;
          if (profession != null) request.fields['profession'] = profession;
          if (interests != null) request.fields['interests'] = jsonEncode(interests);
          if (preferences != null) request.fields['preferences'] = jsonEncode(preferences);
          if (coreValues != null) request.fields['core_values'] = jsonEncode(coreValues);
          if (locationVisible != null) request.fields['location_visible'] = locationVisible.toString();
          if (accountType != null) request.fields['account_type'] = accountType;
          if (linkedinUrl != null) request.fields['linkedin_url'] = linkedinUrl;
          if (facebookUrl != null) request.fields['facebook_url'] = facebookUrl;
          if (instagramUrl != null) request.fields['instagram_url'] = instagramUrl;
          if (xUrl != null) request.fields['x_url'] = xUrl;
          if (snapchatUrl != null) request.fields['snapchat_url'] = snapchatUrl;
          if (tiktokUrl != null) request.fields['tiktok_url'] = tiktokUrl;
          if (otherUrl != null) request.fields['other_url'] = otherUrl;
          if (restrictDm != null) request.fields['restrict_dm'] = restrictDm.toString();

          request.files.add(
            await http.MultipartFile.fromPath('avatar', avatar.path),
          );

          developer.log('Updating profile with multipart data', name: 'ApiService');

          final streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
        } else {
          final requestData = {
            if (name != null) 'name': name,
            if (displayName != null) 'display_name': displayName,
            if (bio != null) 'bio': bio,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
            if (gender != null) 'gender': gender,
            if (city != null) 'city': city,
            if (state != null) 'state': state,
            if (profession != null) 'profession': profession,
            if (interests != null) 'interests': interests,
            if (preferences != null) 'preferences': preferences,
            if (coreValues != null) 'core_values': coreValues,
            if (locationVisible != null) 'location_visible': locationVisible,
            if (accountType != null) 'account_type': accountType,
            if (linkedinUrl != null) 'linkedin_url': linkedinUrl,
            if (facebookUrl != null) 'facebook_url': facebookUrl,
            if (instagramUrl != null) 'instagram_url': instagramUrl,
            if (xUrl != null) 'x_url': xUrl,
            if (snapchatUrl != null) 'snapchat_url': snapchatUrl,
            if (tiktokUrl != null) 'tiktok_url': tiktokUrl,
            if (otherUrl != null) 'other_url': otherUrl,
            if (restrictDm != null) 'restrict_dm': restrictDm,
          };
          final headers = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          };

          _logApiCall(
            method: 'POST',
            url: url,
            headers: headers,
            requestData: requestData,
          );

          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(requestData),
          );
        }

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          final userData = responseData is Map<String, dynamic> && responseData.containsKey('user') ? responseData['user'] : responseData;
          return User.fromJson(userData);
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to update profile';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<List<InterestModel>> getInterests() async {
    final url = 'https://myproxi.app/index.php/api/v1/master/interests';
    final headers = {'Content-Type': 'application/json'};

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = responseData['data'] ?? responseData ?? [];
          return data.map((json) => InterestModel.fromJson(json)).toList();
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get interests';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<List<dynamic>> getPreferences() async {
    final url = 'https://myproxi.app/index.php/api/v1/master/preferences';
    final headers = {'Content-Type': 'application/json'};

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData['data'] ?? responseData ?? [];
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get preferences';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<List<CoreValueModel>> getCoreValues() async {
    final url = 'https://myproxi.app/index.php/api/v1/master/core-values';
    final headers = {'Content-Type': 'application/json'};

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = responseData['data'] ?? responseData ?? [];
          return data.map((json) => CoreValueModel.fromJson(json)).toList();
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get core values';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> subscribeMembership({
    required String token,
    required int membershipId,
  }) async {
    final url = 'https://myproxi.app/index.php/api/v1/memberships/subscribe';
    final requestData = {
      'membership_id': membershipId,
      'payment_method': 'stripe',
      'transaction_id': 'txn_123',
    };
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
        );

        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(requestData),
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return responseData ?? {};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to subscribe to plan';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<List<PlanModel>> getMemberships(String token) async {
    final url = 'https://myproxi.app/index.php/api/v1/memberships';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          final rawData = responseData['data'] ?? responseData;
          List<dynamic> list;
          if (rawData is List) {
            list = rawData;
          } else if (rawData is Map<String, dynamic>) {
            final nested = rawData.values.firstWhere(
              (v) => v is List,
              orElse: () => <dynamic>[],
            );
            list = nested is List ? nested : <dynamic>[];
          } else {
            list = <dynamic>[];
          }
          return list.map((json) => PlanModel.fromJson(json)).toList();
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get memberships';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<void> updateLocation({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    final url = '$baseUrl/puls/update-location';
    final requestData = {
      'latitude': latitude,
      'longitude': longitude,
    };
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(requestData),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;
          final errorMessage = responseData?['message'] ?? 'Failed to update location';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> getNearbyUsers({
    required String token,
    required double latitude,
    required double longitude,
    required int radius,
  }) async {
    final url = '$baseUrl/puls/nearby?latitude=$latitude&longitude=$longitude&radius=$radius';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData ?? {'success': true, 'count': 0, 'users': []};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get nearby users';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> sendCircleRequest({
    required String token,
    required int toUserId,
  }) async {
    final url = '$baseUrl/circles/request';
    final requestData = {
      'to_user_id': toUserId,
    };
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
        );

        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(requestData),
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return responseData ??
              {
                'success': true,
                'in_inner_circle': false,
                'in_outer_circle': false,
                'inner_request_status': 'pending',
              };
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to send circle request';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> addToOuterCircle({
    required String token,
    required int toUserId,
  }) async {
    final url = '$baseUrl/circles/add-outer';
    final requestData = {
      'to_user_id': toUserId,
    };
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
        );

        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(requestData),
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: requestData,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return responseData ??
              {
                'success': true,
                'in_inner_circle': false,
                'in_outer_circle': true,
                'inner_request_status': 'not_sent',
              };
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to add to outer circle';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> getInnerCircle({
    required String token,
  }) async {
    final url = '$baseUrl/circles/inner';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData ?? {};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to fetch inner circle';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> getOuterCircle({
    required String token,
  }) async {
    final url = '$baseUrl/circles/outer';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData ?? {};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to fetch outer circle';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> getMutualCircle({
    required String token,
  }) async {
    final url = '$baseUrl/circles/mutual';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData ?? {};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to fetch mutual circle';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> removeConnection({
    required String token,
    required int connectionId,
  }) async {
    final url = '$baseUrl/circles/$connectionId';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'DELETE',
      url: url,
      request: () async {
        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
        );

        final response = await http.delete(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return responseData ?? {'success': true};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to remove connection';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> respondToCircleRequest({
    required String token,
    required int requestId,
    required String action,
  }) async {
    final url = '$baseUrl/circles/request/$requestId';
    final requestData = {
      'action': action,
    };
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'PUT',
      url: url,
      request: () async {
        _logApiCall(
          method: 'PUT',
          url: url,
          headers: headers,
          requestData: requestData,
        );

        final response = await http.put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(requestData),
        );

        final responseData = jsonDecode(response.body);

        _logApiCall(
          method: 'PUT',
          url: url,
          headers: headers,
          requestData: requestData,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData;
        } else {
          throw Exception(responseData['message'] ?? 'Failed to respond to request');
        }
      },
    );
  }

  Future<Map<String, dynamic>> cancelCircleRequest({
    required String token,
    required int requestId,
  }) async {
    final url = '$baseUrl/circles/request/$requestId';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'DELETE',
      url: url,
      request: () async {
        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
        );

        final response = await http.delete(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return responseData ?? {'success': true};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to cancel request';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> searchUsers({
    required String token,
    required String query,
  }) async {
    final url = '$baseUrl/users/search?query=$query';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
        );

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData ?? {};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to search users';
          throw Exception(errorMessage);
        }
      },
    );
  }
}
