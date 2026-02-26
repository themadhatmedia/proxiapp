import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/circles_controller.dart';
import '../../data/models/circle_connection_model.dart';
import '../../data/models/circle_request_model.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/circle_user_card.dart';
import '../circles/search_users_screen.dart';
import '../pulse/user_profile_detail_screen.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> with SingleTickerProviderStateMixin {
  late CirclesController controller;
  late TabController _tabController;
  final RxBool showIncomingRequests = false.obs;
  final RxBool showSentRequests = false.obs;
  final RxBool showRejectedRequests = false.obs;

  @override
  void initState() {
    super.initState();
    controller = Get.put(CirclesController());
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await controller.loadAllData();
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchUsersScreen()),
    );
  }

  void _handleMenuAction(String action, dynamic data, String circleType) {
    switch (action) {
      case 'view_profile':
        _showUserProfile(data);
        break;
      case 'remove':
        _showRemoveConfirmation(data, circleType);
        break;
      case 'message':
        ToastHelper.showInfo('Messaging feature coming soon');
        break;
      case 'posts':
        ToastHelper.showInfo('Posts feature coming soon');
        break;
      case 'cancel':
        _showCancelRequestConfirmation(data);
        break;
      case 'send_inner':
        _sendInnerCircleRequest(data);
        break;
      case 'add_outer':
        _addToOuterCircle(data);
        break;
    }
  }

  void _handleIncomingRequestAction(String action, CircleRequestModel request) {
    switch (action) {
      case 'view_profile':
        _showUserProfile(request);
        break;
      case 'accept':
        _showAcceptRequestConfirmation(request);
        break;
      case 'reject':
        _showRejectRequestConfirmation(request);
        break;
    }
  }

  void _showUserProfile(dynamic data) {
    dynamic userData;

    if (data is CircleConnectionModel) {
      final user = data.connectedUser;
      final profile = user?.profile;
      userData = {
        'user': {
          'id': user?.id,
          'name': user?.name,
          'profile': profile != null ? profile.toJson() : {},
        },
        'match_score': 0,
        'distance': 0,
        'in_inner_circle': data.circleType == 'inner',
        'in_outer_circle': data.circleType == 'outer',
        'inner_request_status': 'not_sent',
      };
    } else if (data is CircleRequestModel) {
      final user = data.toUser ?? data.fromUser;
      final profile = user?.profile;
      userData = {
        'user': {
          'id': user?.id,
          'name': user?.name,
          'profile': profile != null ? profile.toJson() : {},
        },
        'match_score': 0,
        'distance': 0,
        'in_inner_circle': false,
        'in_outer_circle': false,
        'inner_request_status': data.status,
      };
    } else {
      ToastHelper.showError('Unable to view profile');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => UserProfileDetailScreen(
          userData: userData,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showRemoveConfirmation(dynamic data, String circleType) {
    int connectionId = 0;
    if (data is CircleConnectionModel) {
      connectionId = data.id;
    } else if (data is CircleRequestModel) {
      connectionId = data.id;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_remove, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Remove Connection', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this connection? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ProgressDialogHelper.show(context);
              await controller.removeConnection(connectionId, circleType);
              await ProgressDialogHelper.hide();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remove', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showAcceptRequestConfirmation(CircleRequestModel request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Accept Request', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Accept ${request.fromUser?.name ?? "this user"}\'s inner circle request?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ProgressDialogHelper.show(context);
              await controller.acceptCircleRequest(request.id);
              await ProgressDialogHelper.hide();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Accept', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showRejectRequestConfirmation(CircleRequestModel request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Reject Request', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Reject ${request.fromUser?.name ?? "this user"}\'s inner circle request?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ProgressDialogHelper.show(context);
              await controller.rejectCircleRequest(request.id);
              await ProgressDialogHelper.hide();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showCancelRequestConfirmation(CircleRequestModel request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Cancel Request', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this connection request?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'No',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ProgressDialogHelper.show(context);
              await controller.cancelRequest(request.id);
              await ProgressDialogHelper.hide();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInnerCircleRequest(int userId) async {
    await ProgressDialogHelper.show(context);
    await controller.sendInnerCircleRequest(userId);
    await ProgressDialogHelper.hide();
  }

  Future<void> _addToOuterCircle(int userId) async {
    await ProgressDialogHelper.show(context);
    await controller.addToOuterCircle(userId);
    await ProgressDialogHelper.hide();
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Circles',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildToggleTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInnerCircleTab(),
                    _buildOuterCircleTab(),
                    _buildMutualTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'circles_fab',
        onPressed: _navigateToSearch,
        backgroundColor: Colors.white,
        child: const Icon(
          Icons.search,
          color: Colors.black,
          size: 28.0,
        ),
      ),
    );
  }

  Widget _buildToggleTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(28.0),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(28.0),
            shape: BoxShape.rectangle,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Inner'),
            Tab(text: 'Outer'),
            Tab(text: 'Mutual'),
          ],
        ),
      ),
    );
  }

  Widget _buildInnerCircleTab() {
    return Obx(() {
      if (controller.isLoadingInner.value) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      final activeConnections = controller.activeConnections;
      final incomingRequests = controller.incomingRequests;
      final sentRequests = controller.sentRequests;
      final rejectedRequests = controller.rejectedRequests;

      return RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.white,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Active Connections (${activeConnections.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (activeConnections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 60,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No active connections yet',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...activeConnections.map((connection) => _buildActiveConnectionCard(connection)),
            const SizedBox(height: 8),
            Obx(
              () => InkWell(
                onTap: () => showIncomingRequests.value = !showIncomingRequests.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showIncomingRequests.value ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pending Requests (${incomingRequests.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Obx(() {
              if (showIncomingRequests.value && incomingRequests.isNotEmpty) {
                return Column(
                  children: incomingRequests.map((request) => _buildIncomingRequestCard(request)).toList(),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 4),
            Obx(
              () => InkWell(
                onTap: () => showSentRequests.value = !showSentRequests.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showSentRequests.value ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sent Requests (${sentRequests.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Obx(() {
              if (showSentRequests.value && sentRequests.isNotEmpty) {
                return Column(
                  children: sentRequests.map((request) => _buildSentRequestCard(request)).toList(),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 4),
            Obx(
              () => InkWell(
                onTap: () => showRejectedRequests.value = !showRejectedRequests.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showRejectedRequests.value ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rejected Requests (${rejectedRequests.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Obx(() {
              if (showRejectedRequests.value && rejectedRequests.isNotEmpty) {
                return Column(
                  children: rejectedRequests.map((request) => _buildRejectedRequestCard(request)).toList(),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }

  Widget _buildOuterCircleTab() {
    return Obx(() {
      if (controller.isLoadingOuter.value) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      final connections = controller.outerConnections;

      if (connections.isEmpty) {
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Colors.white,
          child: ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_add,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No outer circle connections yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.white,
        child: ListView(
          children: connections.map((connection) => _buildOuterConnectionCard(connection)).toList(),
        ),
      );
    });
  }

  Widget _buildMutualTab() {
    return Obx(() {
      if (controller.isLoadingMutual.value) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      final connections = controller.mutualConnections;

      if (connections.isEmpty) {
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Colors.white,
          child: ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No mutual connections yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.white,
        child: ListView(
          children: connections.map((connection) => _buildMutualConnectionCard(connection)).toList(),
        ),
      );
    });
  }

  Widget _buildActiveConnectionCard(CircleConnectionModel connection) {
    final user = connection.connectedUser;
    final profile = user?.profile;

    return Obx(
      () => CircleUserCard(
        name: user?.name ?? 'Unknown User',
        bio: profile?.bio,
        avatarUrl: profile?.avatar,
        isLoading: controller.isActionLoading(connection.id),
        menuItems: [
          const PopupMenuItem(
            value: 'view_profile',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'message',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'Send Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'posts',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Posts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.person_remove,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  'Remove Connection',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onMenuSelected: (value) => _handleMenuAction(value, connection, 'inner'),
      ),
    );
  }

  Widget _buildIncomingRequestCard(CircleRequestModel request) {
    final user = request.fromUser;
    final profile = user?.profile;

    return Obx(
      () => CircleUserCard(
        name: user?.name ?? 'Unknown User',
        bio: profile?.bio,
        avatarUrl: profile?.avatar,
        isLoading: controller.isActionLoading(request.id),
        menuItems: [
          const PopupMenuItem(
            value: 'view_profile',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'accept',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Text(
                  'Accept Request',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'reject',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  'Reject Request',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onMenuSelected: (value) => _handleIncomingRequestAction(value, request),
      ),
    );
  }

  Widget _buildSentRequestCard(CircleRequestModel request) {
    final user = request.toUser;
    final profile = user?.profile;

    return Obx(
      () => CircleUserCard(
        name: user?.name ?? 'Unknown User',
        bio: profile?.bio,
        avatarUrl: profile?.avatar,
        isLoading: controller.isActionLoading(request.id),
        menuItems: [
          const PopupMenuItem(
            value: 'view_profile',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'cancel',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 18,
                  color: Colors.orange,
                ),
                const SizedBox(width: 10),
                Text(
                  'Cancel Request',
                  style: TextStyle(
                    color: Colors.orange.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onMenuSelected: (value) => _handleMenuAction(value, request, 'inner'),
      ),
    );
  }

  Widget _buildRejectedRequestCard(CircleRequestModel request) {
    final user = request.toUser;
    final profile = user?.profile;

    return Obx(
      () => CircleUserCard(
        name: user?.name ?? 'Unknown User',
        bio: profile?.bio,
        avatarUrl: profile?.avatar,
        isLoading: controller.isActionLoading(request.id),
        menuItems: const [
          PopupMenuItem(
            value: 'view_profile',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'send_inner',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_add,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'Send Inner Circle Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'add_outer',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.group_add,
                  size: 18,
                  color: Color(0xFF50C878),
                ),
                SizedBox(width: 10),
                Text(
                  'Add to Outer Circle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onMenuSelected: (value) => _handleMenuAction(value, user?.id ?? 0, 'inner'),
      ),
    );
  }

  Widget _buildOuterConnectionCard(CircleConnectionModel connection) {
    final user = connection.connectedUser;
    final profile = user?.profile;

    return Obx(
      () => CircleUserCard(
        name: user?.name ?? 'Unknown User',
        bio: profile?.bio,
        avatarUrl: profile?.avatar,
        isLoading: controller.isActionLoading(connection.id),
        menuItems: [
          const PopupMenuItem(
            value: 'view_profile',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'posts',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Posts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.person_remove,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  'Remove Connection',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onMenuSelected: (value) => _handleMenuAction(value, connection, 'outer'),
      ),
    );
  }

  Widget _buildMutualConnectionCard(CircleConnectionModel connection) {
    final user = connection.connectedUser;
    final profile = user?.profile;

    return Obx(
      () => CircleUserCard(
        name: user?.name ?? 'Unknown User',
        bio: profile?.bio,
        avatarUrl: profile?.avatar,
        isLoading: controller.isActionLoading(connection.id),
        menuItems: [
          const PopupMenuItem(
            value: 'view_profile',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.person_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'posts',
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 10),
                Text(
                  'View Posts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.person_remove,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  'Remove Connection',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onMenuSelected: (value) => _handleMenuAction(value, connection, 'mutual'),
      ),
    );
  }
}
