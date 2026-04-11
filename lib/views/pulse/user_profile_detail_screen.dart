import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/bookmarks_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/app_vibration.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/safe_avatar.dart';

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

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> with SingleTickerProviderStateMixin {
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();

  /// True when this sheet shows the signed-in user's profile (hide bookmark & circle UI).
  bool get _isOwnProfile {
    final me = authController.user?.id;
    if (me == null) return false;
    final raw = widget.userData['user'] ?? widget.userData;
    final other = raw['id'];
    if (other == null) return false;
    final otherId = other is int ? other : int.tryParse('$other');
    return otherId != null && otherId == me;
  }

  bool inInnerCircle = false;
  bool inOuterCircle = false;
  String innerRequestStatus = 'not_sent';
  int? pendingRequestId;
  bool isBookmarked = false;
  bool _isTogglingBookmark = false;

  @override
  void initState() {
    super.initState();
    inInnerCircle = widget.userData['in_inner_circle'] ?? false;
    inOuterCircle = widget.userData['in_outer_circle'] ?? false;
    innerRequestStatus = widget.userData['inner_request_status'] ?? 'not_sent';

    final userData = widget.userData['user'] ?? widget.userData;
    isBookmarked = userData['isFavorite'] ?? false;

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
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Send Inner Circle Request?',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will send a request to add this user to your inner circle. They will need to accept your request.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
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
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add to Outer Circle?',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            innerRequestStatus == 'pending' ? 'Your inner circle request will be cancelled and this user will be added to your outer circle instead.' : 'This will add the user to your outer circle immediately without requiring their approval.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
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

  void _setBookmarkOnUserData(bool value) {
    final nested = widget.userData['user'];
    if (nested is Map) {
      nested['isFavorite'] = value;
    } else {
      widget.userData['isFavorite'] = value;
    }
  }

  Future<bool?> _showRemoveBookmarkConfirmation() {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Remove bookmark?',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Are you sure you want to remove this user from your bookmarks?',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ProxiPalette.bookmarkAccent,
              foregroundColor: ProxiPalette.pureWhite,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_isTogglingBookmark) return;

    final userData = widget.userData['user'] ?? widget.userData;
    final userId = userData['id'];

    if (userId == null) return;

    final token = authController.token;
    if (token == null) return;

    if (isBookmarked) {
      final confirm = await _showRemoveBookmarkConfirmation();
      if (!mounted || confirm != true) return;
    }

    setState(() {
      _isTogglingBookmark = true;
    });

    try {
      if (isBookmarked) {
        await apiService.removeBookmark(
          token: token,
          userId: userId,
        );
        if (Get.isRegistered<BookmarksController>()) {
          Get.find<BookmarksController>().removeBookmarkLocally(userId);
        }
        setState(() {
          isBookmarked = false;
        });
        _setBookmarkOnUserData(false);
        ToastHelper.showSuccess('Bookmark removed');
      } else {
        await apiService.addBookmark(
          token: token,
          userId: userId,
        );
        AppVibration.interactionSuccess();
        setState(() {
          isBookmarked = true;
        });
        _setBookmarkOnUserData(true);
        ToastHelper.showSuccess('User bookmarked');
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingBookmark = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userData = widget.userData['user'] ?? widget.userData;
    final profile = userData['profile'] ?? {};

    final name = profile['display_name'] ?? userData['name'] ?? 'Unknown User';
    final bio = profile['bio'] ?? '';
    final avatarUrl = profile['avatar'];
    final rawProfession = profile['profession'] ?? userData['profession'];
    final professionText = rawProfession != null && rawProfession.toString().trim().isNotEmpty
        ? rawProfession.toString().trim()
        : null;
    final city = profile['city'];
    final state = profile['state'];
    final matchScore = widget.userData['match_score'] ?? 0;
    final distance = widget.userData['distance'] != null ? (widget.userData['distance']).toDouble() : null;
    final interests = profile['interests'] as List<dynamic>? ?? [];
    final coreValues = profile['core_values'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.scaffoldGradient(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.4),
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
                  icon: Icon(Icons.close, color: cs.onSurface),
                ),
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                if (_isOwnProfile)
                  const SizedBox(width: 48)
                else
                  IconButton(
                    onPressed: _isTogglingBookmark ? null : _toggleBookmark,
                    icon: _isTogglingBookmark
                        ? _PulsingBookmark(color: ProxiPalette.bookmarkSaved)
                        : Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: isBookmarked
                                ? ProxiPalette.bookmarkSaved
                                : ProxiPalette.bookmarkAccent,
                          ),
                  ),
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
                      border: Border.all(
                        color: cs.primary,
                        width: 3,
                      ),
                    ),
                    child: SafeAvatar(
                      imageUrl: avatarUrl,
                      size: 120,
                      fallbackText: name,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (professionText != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            professionText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.45),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distance.toStringAsFixed(0)} yds',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
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
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (city != null || state != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outline.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: cs.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatLocation(city, state),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Interests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
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
                              color: ProxiPalette.skyBlue.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.home,
                                  color: cs.primary,
                                  size: 16.0,
                                ),
                                const SizedBox(width: 5.0),
                                Text(
                                  interest,
                                  style: TextStyle(
                                    color: cs.onSurface,
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Core Values',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
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
                              color: ProxiPalette.vibrantPurple.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              value.toString(),
                              style: TextStyle(
                                color: cs.onSurface,
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Social & Service Links',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSocialLinks(context, profile),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (widget.userData['hide_action_buttons'] != true && !_isOwnProfile)
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.9),
                border: Border(
                  top: BorderSide(
                    color: cs.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: _buildActionButtons(context),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            const Icon(
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
                color: Colors.green.shade700,
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
          color: cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group,
              color: cs.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Outer Circle Connection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
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
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outline.withOpacity(0.45),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Inner Circle Request Sent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _addToOuterCircle,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary),
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
            const Icon(
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
                color: Colors.green.shade700,
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
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
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
              child: OutlinedButton(
                onPressed: _addToOuterCircle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary),
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

  Widget _buildSocialLinks(BuildContext context, Map<String, dynamic> profile) {
    final cs = Theme.of(context).colorScheme;
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
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outline.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSocialIcon(link['title']!),
                      color: cs.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        link['title']!,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      color: cs.onSurfaceVariant,
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

class _PulsingBookmark extends StatefulWidget {
  final Color color;

  const _PulsingBookmark({required this.color});

  @override
  State<_PulsingBookmark> createState() => _PulsingBookmarkState();
}

class _PulsingBookmarkState extends State<_PulsingBookmark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.85, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(
        Icons.bookmark,
        color: widget.color,
        size: 24,
      ),
    );
  }
}
