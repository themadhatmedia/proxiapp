import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../data/models/user_model.dart';
import '../../widgets/safe_avatar.dart';
import '../profile/edit_core_values_screen.dart';
import '../profile/edit_interests_screen.dart';
import '../profile/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ProfileController profileController = Get.put(ProfileController());
  bool _isRefreshing = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    // Load profile after build completes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    await authController.fetchUserProfile();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadProfile();
    setState(() => _isRefreshing = false);
  }

  Future<void> _handleLogout() async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Logout',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Are you sure you want to logout?',
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
              backgroundColor: Colors.red,
              foregroundColor: ProxiPalette.pureWhite,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoggingOut = true);
      await authController.logout();
      setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: cs.primary,
            child: Obx(() {
              final user = authController.currentUser.value;
              if (user == null) {
                return Center(
                  child: CircularProgressIndicator(
                    color: cs.primary,
                  ),
                );
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Expanded(child: SizedBox()),
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: () => Get.to(() => const SettingsScreen()),
                                icon: Icon(
                                  Icons.settings,
                                  color: cs.onSurface,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15.0),
                    GestureDetector(
                      onTap: () {
                        profileController.showImageSourceDialog((source) {
                          profileController.pickAndUploadProfileImage(source);
                        });
                      },
                      child: Stack(
                        children: [
                          SafeAvatar(
                            imageUrl: user.avatarUrl,
                            size: 100,
                            fallbackText: user.name,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                color: cs.onPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      user.displayName ?? user.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user.profile?.bio != null && user.profile!.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          user.profile!.bio!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _getMemberSinceText(user.createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 25.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          GestureDetector(
                            onTap: () => Get.to(() => const EditInterestsScreen()),
                            child: _buildStatItem(
                              count: user.interests?.length ?? 0,
                              label: 'Interests',
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Get.to(() => const EditCoreValuesScreen()),
                            child: _buildStatItem(
                              count: user.coreValues?.length ?? 0,
                              label: 'Core Values',
                            ),
                          ),
                          _buildStatItem(
                            // count: user.membership?.membership?.features?.dailyPulseLimit ?? 0,
                            count: _getRemainingPulses(user),
                            label: 'Pulses',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30.0),
                    if (user.interests != null && user.interests!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Your Interests',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                SizedBox(
                                  width: 10.0,
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(() => const EditInterestsScreen()),
                                  child: Icon(
                                    Icons.edit,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10.0,
                              runSpacing: 10.0,
                              children: user.interests!.map((interest) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ProxiPalette.skyBlue.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.home,
                                        color: cs.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        interest,
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    if (user.coreValues != null && user.coreValues!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Your Core Values',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                SizedBox(
                                  width: 10.0,
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(() => const EditCoreValuesScreen()),
                                  child: Icon(
                                    Icons.edit,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: user.coreValues!.map((value) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ProxiPalette.vibrantPurple.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: ProxiPalette.vibrantPurple,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        value,
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Delete Account'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.surfaceContainerHighest,
                                foregroundColor: cs.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoggingOut ? null : _handleLogout,
                              icon: _isLoggingOut
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ProxiPalette.pureWhite,
                                      ),
                                    )
                                  : const Icon(Icons.logout),
                              label: Text(
                                _isLoggingOut ? 'Logging out...' : 'Logout',
                                style: const TextStyle(
                                  color: ProxiPalette.pureWhite,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.85),
                                foregroundColor: ProxiPalette.pureWhite,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Proxi v.0.1.0.1205.2',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({required int count, required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 30.0,
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _getMemberSinceText(DateTime? createdAt) {
    if (createdAt == null) return 'Member since recently';
    final formatter = DateFormat('dd MMM yyyy');
    return 'Member since ${formatter.format(createdAt)}';
  }

  int _getRemainingPulses(User user) {
    final dailyPulseLimit = user.membership?.membership?.features?.dailyPulseLimit ?? 0;
    final dailyPulsesUsed = user.membership?.dailyPulsesUsed ?? 0;
    return dailyPulseLimit - dailyPulsesUsed;
  }
}
