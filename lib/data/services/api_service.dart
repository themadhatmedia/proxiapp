import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import '../models/ambition_model.dart';
import '../models/core_value_model.dart';
import '../models/interest_model.dart';
import '../models/skill_model.dart';
import '../models/plan_model.dart';
import '../models/post_like_models.dart';
import '../models/post_model.dart';
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

  // ignore: unused_element
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

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final url = '$baseUrl/forgot-password';
    final requestData = {'email': email};
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
          return responseData as Map<String, dynamic>;
        } else {
          return responseData as Map<String, dynamic>;
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
    List<String>? skills,
    List<String>? ambitions,
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
          if (skills != null) request.fields['skills'] = jsonEncode(skills);
          if (ambitions != null) request.fields['ambitions'] = jsonEncode(ambitions);
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
            if (skills != null) 'skills': skills,
            if (ambitions != null) 'ambitions': ambitions,
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

  Future<List<SkillModel>> getSkills() async {
    final url = '$baseUrl/master/skills';
    final headers = {'Content-Type': 'application/json'};

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(method: 'GET', url: url, headers: headers);

        final response = await http.get(Uri.parse(url), headers: headers);
        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = responseData['data'] ?? responseData ?? [];
          return data
              .map((json) => SkillModel.fromJson(json as Map<String, dynamic>))
              .where((s) => s.isActive && s.name.isNotEmpty)
              .toList();
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get skills';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<List<AmbitionModel>> getAmbitions() async {
    final url = '$baseUrl/master/ambitions';
    final headers = {'Content-Type': 'application/json'};

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(method: 'GET', url: url, headers: headers);

        final response = await http.get(Uri.parse(url), headers: headers);
        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = responseData['data'] ?? responseData ?? [];
          return data
              .map((json) => AmbitionModel.fromJson(json as Map<String, dynamic>))
              .where((a) => a.isActive && a.name.isNotEmpty)
              .toList();
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get ambitions';
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

  Future<Post> createPost({
    required String token,
    required String content,
    List<File>? mediaFiles,
    List<String>? connectionAudiences,
  }) async {
    final url = '$baseUrl/posts/create';
    final headers = {
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        final request = http.MultipartRequest('POST', Uri.parse(url));
        request.headers.addAll(headers);
        request.fields['content'] = content;

        if (connectionAudiences != null && connectionAudiences.isNotEmpty) {
          request.fields['connection_audiences'] = jsonEncode(connectionAudiences);
        }

        if (mediaFiles != null && mediaFiles.isNotEmpty) {
          for (var file in mediaFiles) {
            final extension = file.path.split('.').last.toLowerCase();
            String? mimeType;

            // Determine MIME type based on extension
            if (['jpg', 'jpeg'].contains(extension)) {
              mimeType = 'image/jpeg';
            } else if (extension == 'png') {
              mimeType = 'image/png';
            } else if (extension == 'webp') {
              mimeType = 'image/webp';
            } else if (extension == 'gif') {
              mimeType = 'image/gif';
            } else if (extension == 'mp4') {
              mimeType = 'video/mp4';
            } else if (extension == 'mov') {
              mimeType = 'video/quicktime';
            } else if (extension == 'avi') {
              mimeType = 'video/x-msvideo';
            }

            final stream = http.ByteStream(file.openRead());
            final length = await file.length();
            final multipartFile = http.MultipartFile(
              'media[]',
              stream,
              length,
              filename: file.path.split('/').last,
              contentType: mimeType != null ? http_parser.MediaType.parse(mimeType) : null,
            );
            request.files.add(multipartFile);
          }
        }

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: {
            'content': content,
            if (connectionAudiences != null && connectionAudiences.isNotEmpty)
              'connection_audiences': connectionAudiences,
          },
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        dynamic responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          _logApiCall(
            method: 'POST',
            url: url,
            headers: headers,
            requestData: {
              'content': content,
              if (connectionAudiences != null && connectionAudiences.isNotEmpty)
                'connection_audiences': connectionAudiences,
            },
            statusCode: response.statusCode,
            responseData: {'raw_response': response.body.substring(0, 500)},
          );
          throw Exception('Invalid response format from server');
        }

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: {
            'content': content,
            if (connectionAudiences != null && connectionAudiences.isNotEmpty)
              'connection_audiences': connectionAudiences,
          },
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // API returns { "success": true, "post": {...} }
          if (responseData['post'] != null) {
            return Post.fromJson(responseData['post']);
          } else if (responseData['data'] != null) {
            return Post.fromJson(responseData['data']);
          } else {
            return Post.fromJson(responseData);
          }
        } else if (response.statusCode == 413) {
          throw Exception('Files are too large. Total size must be less than 50MB');
        } else {
          throw Exception(responseData['message'] ?? 'Failed to create post');
        }
      },
    );
  }

  Future<Post> updatePost({
    required String token,
    required int postId,
    required String content,
    List<String>? connectionAudiences,
    List<int>? deleteMediaIds,
    List<File>? newMediaFiles,
  }) async {
    final url = '$baseUrl/posts/$postId/update';
    final headers = {
      'Authorization': 'Bearer $token',
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        final request = http.MultipartRequest('POST', Uri.parse(url));
        request.headers.addAll(headers);
        request.fields['content'] = content;

        if (connectionAudiences != null && connectionAudiences.isNotEmpty) {
          request.fields['connection_audiences'] = jsonEncode(connectionAudiences);
        }

        // Multipart form maps each key to a string; Laravel expects a real array, not a JSON string.
        // Use delete_media_ids[0], delete_media_ids[1], … (Map cannot repeat delete_media_ids[]).
        if (deleteMediaIds != null && deleteMediaIds.isNotEmpty) {
          for (var i = 0; i < deleteMediaIds.length; i++) {
            request.fields['delete_media_ids[$i]'] = deleteMediaIds[i].toString();
          }
        }

        if (newMediaFiles != null && newMediaFiles.isNotEmpty) {
          for (var file in newMediaFiles) {
            final extension = file.path.split('.').last.toLowerCase();
            String? mimeType;

            if (['jpg', 'jpeg'].contains(extension)) {
              mimeType = 'image/jpeg';
            } else if (extension == 'png') {
              mimeType = 'image/png';
            } else if (extension == 'webp') {
              mimeType = 'image/webp';
            } else if (extension == 'gif') {
              mimeType = 'image/gif';
            } else if (extension == 'mp4') {
              mimeType = 'video/mp4';
            } else if (extension == 'mov') {
              mimeType = 'video/quicktime';
            } else if (extension == 'avi') {
              mimeType = 'video/x-msvideo';
            }

            final stream = http.ByteStream(file.openRead());
            final length = await file.length();
            final multipartFile = http.MultipartFile(
              'media[]',
              stream,
              length,
              filename: file.path.split('/').last,
              contentType: mimeType != null ? http_parser.MediaType.parse(mimeType) : null,
            );
            request.files.add(multipartFile);
          }
        }

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: {
            'content': content,
            if (connectionAudiences != null && connectionAudiences.isNotEmpty)
              'connection_audiences': connectionAudiences,
            if (deleteMediaIds != null && deleteMediaIds.isNotEmpty) 'delete_media_ids': deleteMediaIds,
          },
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        dynamic responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          _logApiCall(
            method: 'POST',
            url: url,
            headers: headers,
            statusCode: response.statusCode,
            responseData: {
              'raw_response': response.body.length > 500 ? response.body.substring(0, 500) : response.body,
            },
          );
          throw Exception('Invalid response format from server');
        }

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (responseData['post'] != null) {
            return Post.fromJson(responseData['post'] as Map<String, dynamic>);
          }
          if (responseData['data'] != null) {
            return Post.fromJson(responseData['data'] as Map<String, dynamic>);
          }
          return Post.fromJson(responseData as Map<String, dynamic>);
        } else if (response.statusCode == 413) {
          throw Exception('Files are too large. Each file must be 10MB or less');
        } else {
          throw Exception(responseData['message'] ?? 'Failed to update post');
        }
      },
    );
  }

  Future<List<Post>> getMyPosts(String token) async {
    final url = '$baseUrl/my-posts';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          // Handle both array and object responses
          List<dynamic> postsData;
          if (responseData is List) {
            postsData = responseData;
          } else if (responseData is Map) {
            // Check for posts array directly (e.g., {success: true, posts: [...]})
            postsData = responseData['posts'] ?? responseData['data'] ?? [];
          } else {
            postsData = [];
          }
          return postsData.map((json) => Post.fromJson(json)).toList();
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get posts';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> getUserPosts(String token, int userId) async {
    final url = '$baseUrl/users/$userId/posts';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData;
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to get user posts';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<void> deletePost(String token, int postId) async {
    final url = '$baseUrl/posts/$postId';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .delete(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200 && response.statusCode != 204) {
          final errorMessage = responseData?['message'] ?? 'Failed to delete post';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<void> likePost(String token, int postId) async {
    final url = '$baseUrl/posts/$postId/like';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .post(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          final errorMessage = responseData?['message'] ?? 'Failed to like post';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<void> unlikePost(String token, int postId) async {
    final url = '$baseUrl/posts/$postId/unlike';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .delete(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200 && response.statusCode != 204) {
          final errorMessage = responseData?['message'] ?? 'Failed to unlike post';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<PostLikesResult> getPostLikes({
    required String token,
    required int postId,
  }) async {
    final url = '$baseUrl/posts/$postId/likes';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    return _retryRequest(
      method: 'GET',
      url: url,
      request: () async {
        _logApiCall(method: 'GET', url: url, headers: headers);

        final response = await http.get(Uri.parse(url), headers: headers).timeout(timeout);
        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic> : <String, dynamic>{};

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200) {
          final errorMessage = responseData['message'] ?? 'Failed to load likes';
          throw Exception(errorMessage);
        }

        return PostLikesResult.fromJson(responseData);
      },
    );
  }

  Future<Map<String, dynamic>> getDiscoverPosts(String token) async {
    final url = '$baseUrl/posts';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = jsonDecode(response.body);

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200) {
          final errorMessage = responseData['message'] ?? 'Failed to fetch posts';
          throw Exception(errorMessage);
        }

        return responseData;
      },
    );
  }

  Future<Map<String, dynamic>> getPostComments(String token, int postId) async {
    final url = '$baseUrl/posts/$postId/comments';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = jsonDecode(response.body);

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200) {
          final errorMessage = responseData['message'] ?? 'Failed to fetch comments';
          throw Exception(errorMessage);
        }

        return responseData;
      },
    );
  }

  Future<Map<String, dynamic>> addComment(
    String token,
    int postId,
    String content, {
    int? parentId,
  }) async {
    final url = '$baseUrl/posts/$postId/comment';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final body = {
      'content': content,
      if (parentId != null) 'parent_id': parentId,
    };

    return _retryRequest(
      method: 'POST',
      url: url,
      request: () async {
        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: body,
        );

        final response = await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(timeout);

        final responseData = jsonDecode(response.body);

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          requestData: body,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          final errorMessage = responseData['message'] ?? 'Failed to add comment';
          throw Exception(errorMessage);
        }

        return responseData;
      },
    );
  }

  Future<Map<String, dynamic>> deleteComment(String token, int commentId) async {
    final url = '$baseUrl/posts/$commentId/comment';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
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

        final response = await http
            .delete(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : {};

        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode != 200 && response.statusCode != 204) {
          final errorMessage = responseData['message'] ?? 'Failed to delete comment';
          throw Exception(errorMessage);
        }

        return responseData;
      },
    );
  }

  Future<Map<String, dynamic>> addBookmark({
    required String token,
    required int userId,
  }) async {
    final url = '$baseUrl/users/$userId/favorite';
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

        final response = await http
            .post(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'POST',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return responseData ?? {'success': true, 'isFavorite': true};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to bookmark user';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> removeBookmark({
    required String token,
    required int userId,
  }) async {
    final url = '$baseUrl/users/$userId/unfavorite';
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

        final response = await http
            .delete(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'DELETE',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          return responseData ?? {'success': true, 'isFavorite': false};
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to remove bookmark';
          throw Exception(errorMessage);
        }
      },
    );
  }

  Future<Map<String, dynamic>> getBookmarks({
    required String token,
    int page = 1,
  }) async {
    // final url = '$baseUrl/favorites?page=$page';
    final url = '$baseUrl/favorites';
    final headers = {
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

        final response = await http
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(timeout);

        final responseData = response.body.isNotEmpty ? jsonDecode(response.body) : null;

        _logApiCall(
          method: 'GET',
          url: url,
          headers: headers,
          statusCode: response.statusCode,
          responseData: responseData,
        );

        if (response.statusCode == 200) {
          return responseData ??
              {
                'success': true,
                'data': {'favorites': [], 'pagination': {}},
              };
        } else {
          final errorMessage = responseData?['message'] ?? 'Failed to load bookmarks';
          throw Exception(errorMessage);
        }
      },
    );
  }
}
