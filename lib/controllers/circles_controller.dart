import 'package:get/get.dart';

import '../data/models/circle_connection_model.dart';
import '../data/models/circle_request_model.dart';
import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
import '../utils/toast_helper.dart';
import 'auth_controller.dart';

class CirclesController extends GetxController {
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();

  final RxBool isLoadingInner = false.obs;
  final RxBool isLoadingOuter = false.obs;
  final RxBool isLoadingMutual = false.obs;

  final RxMap<int, bool> actionLoadingStates = <int, bool>{}.obs;

  final RxList<CircleConnectionModel> activeConnections = <CircleConnectionModel>[].obs;
  final RxList<CircleRequestModel> incomingRequests = <CircleRequestModel>[].obs;
  final RxList<CircleRequestModel> sentRequests = <CircleRequestModel>[].obs;
  final RxList<CircleRequestModel> rejectedRequests = <CircleRequestModel>[].obs;

  final RxList<CircleConnectionModel> outerConnections = <CircleConnectionModel>[].obs;
  final RxList<CircleConnectionModel> mutualConnections = <CircleConnectionModel>[].obs;

  final RxString searchQuery = ''.obs;

  List<CircleConnectionModel> get filteredActiveConnections {
    if (searchQuery.value.isEmpty) return activeConnections;
    return activeConnections.where((connection) {
      final name = connection.connectedUser?.name.toLowerCase() ?? '';
      final bio = connection.connectedUser?.profile?.bio?.toLowerCase() ?? '';
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  List<CircleRequestModel> get filteredIncomingRequests {
    if (searchQuery.value.isEmpty) return incomingRequests;
    return incomingRequests.where((request) {
      final name = request.fromUser?.name.toLowerCase() ?? '';
      final bio = request.fromUser?.profile?.bio?.toLowerCase() ?? '';
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  List<CircleRequestModel> get filteredSentRequests {
    if (searchQuery.value.isEmpty) return sentRequests;
    return sentRequests.where((request) {
      final name = request.toUser?.name.toLowerCase() ?? '';
      final bio = request.toUser?.profile?.bio?.toLowerCase() ?? '';
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  List<CircleRequestModel> get filteredRejectedRequests {
    if (searchQuery.value.isEmpty) return rejectedRequests;
    return rejectedRequests.where((request) {
      final name = request.toUser?.name.toLowerCase() ?? '';
      final bio = request.toUser?.profile?.bio?.toLowerCase() ?? '';
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  List<CircleConnectionModel> get filteredOuterConnections {
    if (searchQuery.value.isEmpty) return outerConnections;
    return outerConnections.where((connection) {
      final name = connection.connectedUser?.name.toLowerCase() ?? '';
      final bio = connection.connectedUser?.profile?.bio?.toLowerCase() ?? '';
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  List<CircleConnectionModel> get filteredMutualConnections {
    if (searchQuery.value.isEmpty) return mutualConnections;
    return mutualConnections.where((connection) {
      final name = connection.connectedUser?.name.toLowerCase() ?? '';
      final bio = connection.connectedUser?.profile?.bio?.toLowerCase() ?? '';
      final query = searchQuery.value.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadAllData();
  }

  void setActionLoading(int id, bool isLoading) {
    actionLoadingStates[id] = isLoading;
  }

  bool isActionLoading(int id) {
    return actionLoadingStates[id] ?? false;
  }

  Future<void> loadAllData() async {
    await Future.wait([
      fetchInnerCircle(),
      fetchOuterCircle(),
      fetchMutualCircle(),
    ]);
  }

  Future<void> fetchInnerCircle() async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    isLoadingInner.value = true;

    try {
      final response = await _apiService.getInnerCircle(token: token);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        if (data['active_connections'] != null && data['active_connections']['items'] != null) {
          activeConnections.value = (data['active_connections']['items'] as List).map((item) => CircleConnectionModel.fromJson(item)).toList();
        }

        if (data['pending_requests'] != null && data['pending_requests']['items'] != null) {
          incomingRequests.value = (data['pending_requests']['items'] as List).map((item) => CircleRequestModel.fromJson(item)).toList();
        }

        if (data['sent_requests'] != null && data['sent_requests']['items'] != null) {
          sentRequests.value = (data['sent_requests']['items'] as List).map((item) => CircleRequestModel.fromJson(item)).toList();
        }

        if (data['rejected_requests'] != null && data['rejected_requests']['items'] != null) {
          rejectedRequests.value = (data['rejected_requests']['items'] as List).map((item) => CircleRequestModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      isLoadingInner.value = false;
    }
  }

  Future<void> fetchOuterCircle() async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    isLoadingOuter.value = true;

    try {
      final response = await _apiService.getOuterCircle(token: token);

      if (response['success'] == true && response['connections'] != null) {
        outerConnections.value = (response['connections'] as List).map((item) => CircleConnectionModel.fromJson(item)).toList();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      isLoadingOuter.value = false;
    }
  }

  Future<void> fetchMutualCircle() async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    isLoadingMutual.value = true;

    try {
      final response = await _apiService.getMutualCircle(token: token);

      if (response['success'] == true && response['connections'] != null) {
        mutualConnections.value = (response['connections'] as List).map((item) => CircleConnectionModel.fromJson(item)).toList();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      isLoadingMutual.value = false;
    }
  }

  Future<void> removeConnection(int connectionId, String circleType) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setActionLoading(connectionId, true);
    try {
      await _apiService.removeConnection(
        token: token,
        connectionId: connectionId,
      );

      ToastHelper.showSuccess('Connection removed');

      if (circleType == 'inner') {
        await fetchInnerCircle();
      } else if (circleType == 'outer') {
        await fetchOuterCircle();
      } else if (circleType == 'mutual') {
        await fetchMutualCircle();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      setActionLoading(connectionId, false);
    }
  }

  Future<void> cancelRequest(int requestId) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setActionLoading(requestId, true);
    try {
      await _apiService.cancelCircleRequest(
        token: token,
        requestId: requestId,
      );

      ToastHelper.showSuccess('Request cancelled');
      await fetchInnerCircle();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      setActionLoading(requestId, false);
    }
  }

  Future<void> sendInnerCircleRequest(int userId) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setActionLoading(userId, true);
    try {
      await _apiService.sendCircleRequest(
        token: token,
        toUserId: userId,
      );

      ToastHelper.showSuccess('Inner circle request sent');
      await fetchInnerCircle();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      setActionLoading(userId, false);
    }
  }

  Future<void> addToOuterCircle(int userId) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setActionLoading(userId, true);
    try {
      await _apiService.addToOuterCircle(
        token: token,
        toUserId: userId,
      );

      ToastHelper.showSuccess('Added to outer circle');
      await loadAllData();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      setActionLoading(userId, false);
    }
  }

  Future<void> acceptCircleRequest(int requestId) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setActionLoading(requestId, true);
    try {
      await _apiService.respondToCircleRequest(
        token: token,
        requestId: requestId,
        action: 'accept',
      );

      ToastHelper.showSuccess('Request accepted');
      await fetchInnerCircle();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      setActionLoading(requestId, false);
    }
  }

  Future<void> rejectCircleRequest(int requestId) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    setActionLoading(requestId, true);
    try {
      await _apiService.respondToCircleRequest(
        token: token,
        requestId: requestId,
        action: 'reject',
      );

      ToastHelper.showSuccess('Request rejected');
      await fetchInnerCircle();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      setActionLoading(requestId, false);
    }
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  void clearSearch() {
    searchQuery.value = '';
  }

  Future<List<User>> searchUsers(String query) async {
    final token = _authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return [];
    }

    try {
      final response = await _apiService.searchUsers(
        token: token,
        query: query,
      );

      if (response['success'] == true && response['users'] != null) {
        return (response['users'] as List).map((item) => User.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
      return [];
    }
  }
}
