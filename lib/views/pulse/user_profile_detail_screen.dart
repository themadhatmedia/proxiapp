import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';

class UserProfileDetailScreen extends StatefulWidget {
  final dynamic userData;
  final ScrollController? scrollController;

  const UserProfileDetailScreen({
    super.key,
    required this.userData,
    this.scrollController,
  });

  @override
  State<UserProfileDetailScreen> createState() => _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();

  bool inInnerCircle = false;
  bool inOuterCircle = false;
  String innerRequestStatus = 'not_sent';
  int? pendingRequestId;

  @override
  void initState() {
    super.initState();
    inInnerCircle = widget.userData['in_inner_circle'] ?? false;
    inOuterCircle = widget.userData['in_outer_circle'] ?? false;
    innerRequestStatus = widget.userData['inner_request_status'] ?? 'not_sent';

    if (widget.userData['inner_request_id'] != null) {
      pendingRequestId = widget.userData['inner_request_id'];
    } else if (widget.userData['pending_request'] != null) {
      pendingRequestId = widget.userData['pending_request']['id'];
    }
  }

  Future<void> _sendInnerCircleRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Send Inner Circle Request?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'This will send a request to add this user to your inner circle. They will need to accept your request.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final userData = widget.userData['user'] ?? widget.userData;
    final userId = userData['id'];

    if (userId == null) {
      ToastHelper.showError('User ID not found');
      return;
    }

    await ProgressDialogHelper.show(context);

    try {
      final token = authController.token;
      if (token == null) {
        ToastHelper.showError('Authentication required');
        await ProgressDialogHelper.hide();
        return;
      }

      final response = await apiService.sendCircleRequest(
        token: token,
        toUserId: userId,
      );

      final requestData = response['request'];
      final requestId = requestData != null ? requestData['id'] : null;
      final innerRequestId = response['inner_request_id'];

      setState(() {
        inInnerCircle = response['in_inner_circle'] ?? false;
        inOuterCircle = response['in_outer_circle'] ?? false;
        innerRequestStatus = response['inner_request_status'] ?? 'pending';
        pendingRequestId = innerRequestId ?? requestId;
      });

      widget.userData['in_inner_circle'] = inInnerCircle;
      widget.userData['in_outer_circle'] = inOuterCircle;
      widget.userData['inner_request_status'] = innerRequestStatus;
      widget.userData['inner_request_id'] = pendingRequestId;

      await ProgressDialogHelper.hide();
      ToastHelper.showSuccess('Inner circle request sent');
    } catch (e) {
      await ProgressDialogHelper.hide();
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    }
  }

  Future<void> _addToOuterCircle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add to Outer Circle?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            innerRequestStatus == 'pending' ? 'Your inner circle request will be cancelled and this user will be added to your outer circle instead.' : 'This will add the user to your outer circle immediately without requiring their approval.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add to Circle'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final userData = widget.userData['user'] ?? widget.userData;
    final userId = userData['id'];

    if (userId == null) {
      ToastHelper.showError('User ID not found');
      return;
    }

    await ProgressDialogHelper.show(context);

    try {
      final token = authController.token;
      if (token == null) {
        ToastHelper.showError('Authentication required');
        await ProgressDialogHelper.hide();
        return;
      }

      if (pendingRequestId != null) {
        await apiService.cancelCircleRequest(
          token: token,
          requestId: pendingRequestId!,
        );
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final response = await apiService.addToOuterCircle(
        token: token,
        toUserId: userId,
      );

      setState(() {
        inInnerCircle = response['in_inner_circle'] ?? false;
        inOuterCircle = response['in_outer_circle'] ?? true;
        innerRequestStatus = response['inner_request_status'] ?? 'not_sent';
        pendingRequestId = null;
      });

      widget.userData['in_inner_circle'] = inInnerCircle;
      widget.userData['in_outer_circle'] = inOuterCircle;
      widget.userData['inner_request_status'] = innerRequestStatus;
      widget.userData['inner_request_id'] = null;

      await ProgressDialogHelper.hide();
      ToastHelper.showSuccess('Added to outer circle');
    } catch (e) {
      await ProgressDialogHelper.hide();
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = widget.userData['user'] ?? widget.userData;
    final profile = userData['profile'] ?? {};

    final name = userData['name'] ?? profile['display_name'] ?? 'Unknown User';
    final bio = profile['bio'] ?? '';
    final avatarUrl = profile['avatar'];
    final profession = profile['profession'];
    final city = profile['city'];
    final state = profile['state'];
    final matchScore = widget.userData['match_score'] ?? 0;
    final distance = widget.userData['distance'] != null ? (widget.userData['distance']).toDouble() : null;
    final interests = profile['interests'] as List<dynamic>? ?? [];
    final coreValues = profile['core_values'] as List<dynamic>? ?? [];

    return Container(
      decoration: const BoxDecoration(
        // gradient: LinearGradient(
        //   colors: [Colors.white, Color(0xFF3D5A80)],
        //   begin: Alignment.topCenter,
        //   end: Alignment.bottomCenter,
        // ),
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      image: avatarUrl != null && avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white60,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (matchScore != null && matchScore > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            // color: Colors.white.withOpacity(0.95),
                            color: _getMatchColor(matchScore).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              // color: Colors.white,
                              color: _getMatchColor(matchScore),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: _getMatchColor(matchScore),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$matchScore% Match',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getMatchColor(matchScore),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (distance != null && distance > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distance.toStringAsFixed(0)} yds',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    if (matchScore != null && matchScore > 0 && distance != null && distance > 0) SizedBox(height: 16),
                    Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (profession != null || city != null || state != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (profession != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.work,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  profession,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if ((city != null || state != null) && profession != null) ...[
                            const SizedBox(height: 12),
                          ],
                          if (city != null || state != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_city,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatLocation(city, state),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Interests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.home,
                                  // color: Colors.white,
                                  color: Colors.white,
                                  size: 16.0,
                                ),
                                const SizedBox(width: 5.0),
                                Text(
                                  interest,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (coreValues.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Core Values',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: coreValues.map((value) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              value.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (_hasSocialLinks(profile)) ...[
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Social & Service Links',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSocialLinks(profile),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (inInnerCircle) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Inner Circle Connection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    if (inOuterCircle) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Outer Circle Connection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (innerRequestStatus == 'pending') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Inner Circle Request Sent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addToOuterCircle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add, size: 20),
                  SizedBox(width: 8),
                  Text('Add to Outer Circle'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (innerRequestStatus == 'accepted') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Inner Circle Connection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _sendInnerCircleRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text('Inner Circle'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _addToOuterCircle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_add, size: 20),
                    SizedBox(width: 8),
                    Text('Outer Circle'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getMatchColor(int score) {
    if (score > 80) {
      return const Color(0xFF4CAF50);
    } else if (score >= 50) {
      return const Color(0xFFFFA726);
    } else {
      return const Color(0xFFE74C3C);
    }
  }

  String _formatLocation(String? city, String? state) {
    if ((city == null || city.isEmpty) && (state == null || state.isEmpty)) {
      return '';
    } else if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
      return '$city, $state';
    } else if (city != null && city.isNotEmpty) {
      return city;
    } else {
      return state ?? '';
    }
  }

  bool _hasSocialLinks(Map<String, dynamic> profile) {
    return (profile['instagram_url'] != null && profile['instagram_url'].toString().isNotEmpty) || (profile['snapchat_url'] != null && profile['snapchat_url'].toString().isNotEmpty) || (profile['linkedin_url'] != null && profile['linkedin_url'].toString().isNotEmpty) || (profile['facebook_url'] != null && profile['facebook_url'].toString().isNotEmpty) || (profile['x_url'] != null && profile['x_url'].toString().isNotEmpty) || (profile['tiktok_url'] != null && profile['tiktok_url'].toString().isNotEmpty) || (profile['other_url'] != null && profile['other_url'].toString().isNotEmpty);
  }

  Widget _buildSocialLinks(Map<String, dynamic> profile) {
    final links = <Map<String, String>>[];

    print('profile: $profile');

    if (profile['instagram_url'] != null && profile['instagram_url'].toString().isNotEmpty) {
      links.add({'title': 'Instagram', 'url': profile['instagram_url'].toString()});
    }
    if (profile['snapchat_url'] != null && profile['snapchat_url'].toString().isNotEmpty) {
      links.add({'title': 'Snapchat', 'url': profile['snapchat_url'].toString()});
    }
    if (profile['linkedin_url'] != null && profile['linkedin_url'].toString().isNotEmpty) {
      links.add({'title': 'LinkedIn', 'url': profile['linkedin_url'].toString()});
    }
    if (profile['facebook_url'] != null && profile['facebook_url'].toString().isNotEmpty) {
      links.add({'title': 'Facebook', 'url': profile['facebook_url'].toString()});
    }
    if (profile['x_url'] != null && profile['x_url'].toString().isNotEmpty) {
      links.add({'title': 'X (Twitter)', 'url': profile['x_url'].toString()});
    }
    if (profile['tiktok_url'] != null && profile['tiktok_url'].toString().isNotEmpty) {
      links.add({'title': 'TikTok', 'url': profile['tiktok_url'].toString()});
    }
    if (profile['other_url'] != null && profile['other_url'].toString().isNotEmpty) {
      links.add({'title': 'Other', 'url': profile['other_url'].toString()});
    }

    print('links: $links');
    return Column(
      children: links.map((link) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchUrl(link['url']!),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSocialIcon(link['title']!),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        link['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      color: Colors.white.withOpacity(0.5),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getSocialIcon(String title) {
    switch (title.toLowerCase()) {
      case 'instagram':
        return Icons.camera_alt;
      case 'snapchat':
        return Icons.camera;
      case 'linkedin':
        return Icons.business;
      case 'facebook':
        return Icons.facebook;
      case 'x (twitter)':
        return Icons.message;
      case 'tiktok':
        return Icons.music_note;
      default:
        return Icons.link;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      String validUrl = urlString.trim();

      if (!validUrl.startsWith('http://') && !validUrl.startsWith('https://')) {
        validUrl = 'https://$validUrl';
      }

      print('validUrl: $validUrl');

      final uri = Uri.parse(validUrl);

      // final canLaunch = await canLaunchUrl(uri);
      // if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // } else {
      //   if (mounted) {
      //     ToastHelper.showError('Could not open link');
      //   }
      // }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError('Invalid link');
      }
    }
  }
}
