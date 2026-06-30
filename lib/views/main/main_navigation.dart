import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/ads_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/circles_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../data/services/api_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/messaging_fcm_listeners.dart';
import '../../utils/location_permission_flow.dart';
import '../../controllers/messages_controller.dart';
import '../home/circles_screen.dart';
import '../home/discover_screen.dart';
import '../home/messages_screen.dart';
import '../home/profile_screen.dart';
import '../home/pulse_screen.dart';
import '../../widgets/proxi_banner_ad.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final NavigationController _navigationController;
  final LocationService _locationService = Get.put(LocationService());
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();
  final GlobalKey<NavigatorState> _circlesKey = GlobalKey<NavigatorState>();

  /// While onboarding routes are on top of the stack, [MainNavigation] can still
  /// be mounted as `GetMaterialApp` `home` — avoid prompting for location until
  /// the user reaches the main app (`/home` after onboarding).
  static bool _isOnboardingRouteActive(String route) {
    final r = route.toLowerCase();
    return r.contains('profile-creation') ||
        r.contains('terms-conditions') ||
        r.contains('select-interests') ||
        r.contains('select-core-values') ||
        r.contains('select-skills') ||
        r.contains('select-ambitions') ||
        r.contains('select-plan') ||
        r.contains('setup-permissions') ||
        r.contains('proxi-circles');
  }

  /// Existing/logged-in users skip onboarding, so location + contacts are
  /// requested directly from the home screen (Walls). Runs once per app session;
  /// the prominent location disclosure is shown before any location request, on
  /// both Android and iOS.
  static bool _homePermissionsPrompted = false;

  Future<void> _ensureHomePermissionsAndLocation() async {
    final token = _authController.token;
    if (token == null) return;

    if (!_homePermissionsPrompted) {
      _homePermissionsPrompted = true;
      await _promptLocationFromHome();
      await _promptContactsFromHome();
    }

    await _pushLocationUpdate(token);
    await _maybeStartBackgroundLocation();
  }

  /// Shows the disclosure (both platforms) then the two-step location request.
  Future<void> _promptLocationFromHome() async {
    if (!mounted) return;
    if (await LocationPermissionFlow.hasBackgroundLocationAccess()) return;
    await LocationPermissionFlow.requestBackgroundLocation(
      context,
      onOpenSettings: ({required title, required body}) =>
          _showPermissionSettingsDialog(title: title, body: body),
    );
  }

  /// Requests contacts from the home screen. Skips when already granted, and
  /// does not nag with a settings dialog when permanently denied.
  Future<void> _promptContactsFromHome() async {
    if (!mounted) return;
    final status = await Permission.contacts.status;
    if (status.isGranted || status.isLimited || status.isPermanentlyDenied) {
      return;
    }
    await Permission.contacts.request();
  }

  /// Pushes a one-off location update — only if foreground access already
  /// exists, so it never triggers a duplicate permission prompt.
  Future<void> _pushLocationUpdate(String token) async {
    try {
      if (!await LocationPermissionFlow.hasForegroundLocationAccess()) return;

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _apiService.queueLocationUpdate(
          token: token,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      debugPrint('MainNavigation location: $e');
    }
  }

  Future<void> _showPermissionSettingsDialog({
    required String title,
    required String body,
  }) async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        content: Text(
          body,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _refreshCirclesData() {
    try {
      if (Get.isRegistered<CirclesController>()) {
        final circlesController = Get.find<CirclesController>();
        circlesController.loadAllData();
      } else {
        // Initialize controller and load data for the first time
        final circlesController = Get.put(CirclesController());
        circlesController.loadAllData();
      }
    } catch (e) {
      // Controller might not be initialized yet
    }
  }

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<NavigationController>()) {
      _navigationController = Get.find<NavigationController>();
      // Reset to home screen after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_navigationController.skipInitialHomeReset.value) {
          _navigationController.navigateToHome();
        }
        _navigationController.skipInitialHomeReset.value = false;
      });
    } else {
      _navigationController = Get.put(NavigationController());
    }
    // Defer so signup → /profile-creation (and Obx switching `home` to this widget)
    // applies first; skip while any onboarding screen is the active route.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      if (_authController.isAuthenticated) {
        if (!Get.isRegistered<MessagesController>()) {
          Get.put(MessagesController(), permanent: true);
        }
        unawaited(Get.find<MessagesController>().loadConversations(showSpinner: false));
        registerMessagingFcmListeners();
      }
      if (_isOnboardingRouteActive(Get.currentRoute)) return;
      unawaited(_ensureHomePermissionsAndLocation());
    });
  }

  /// Background location updates only run when the user has already granted
  /// "Always"/background access (which is only ever requested after the
  /// prominent disclosure in [LocationPermissionFlow.requestBackgroundLocation]).
  /// We never request the permission here — only resume updates if granted.
  Future<void> _maybeStartBackgroundLocation() async {
    if (await LocationPermissionFlow.hasBackgroundLocationAccess()) {
      await _locationService.startBackgroundLocationUpdates();
    }
  }

  Future<bool> _onWillPop() async {
    // If not on home tab (index 0), navigate to home instead of exiting
    if (_navigationController.currentIndex.value != 0) {
      _navigationController.navigateToHome();
      return false; // Don't exit the app
    }
    // If already on home tab, allow the app to exit
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            SystemNavigator.pop();
          }
        }
      },
      child: Obx(() => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemUiOverlayFor(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _navigationController.currentIndex.value,
                  children: [
                    const DiscoverScreen(),
                    PulseScreen(isVisible: _navigationController.currentIndex.value == 1),
                    const CirclesScreen(),
                    const MessagesScreen(),
                    const ProfileScreen(),
                  ],
                ),
              ),
              if (Get.isRegistered<AdsController>())
                Obx(() {
                  final ads = Get.find<AdsController>();
                  if (!ads.shouldShowBanner) {
                    return const SizedBox.shrink();
                  }
                  return const ProxiBannerAd();
                }),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: context.proxi.bottomNavBackground,
              border: Border(
                top: BorderSide(
                  color: ProxiPalette.pureWhite.withOpacity(0.12),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      context: context,
                      icon: Icons.home,
                      label: 'Home',
                      index: 0,
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.near_me,
                      label: 'Pulse',
                      index: 1,
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.group,
                      label: 'Circles',
                      index: 2,
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.chat_bubble,
                      label: 'Messages',
                      index: 3,
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.person,
                      label: 'Profile',
                      index: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _navigationController.currentIndex.value == index;
    final hasUnreadMessages =
        index == 3 &&
        Get.isRegistered<MessagesController>() &&
        Get.find<MessagesController>().unreadConversationsCount.value > 0;
    final selectedBg = ProxiPalette.electricBlue.withOpacity(0.35);
    final unselectedIcon = ProxiPalette.skyBlue.withOpacity(0.85);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _navigationController.navigateToTab(index);

          // Refresh circles data when navigating to circles screen
          if (index == 2) {
            _refreshCirclesData();
          }
          if (index == 3 && Get.isRegistered<MessagesController>()) {
            unawaited(
              Get.find<MessagesController>().loadConversations(showSpinner: false),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? ProxiPalette.pureWhite : unselectedIcon,
                    size: 24,
                  ),
                  if (hasUnreadMessages)
                    Positioned(
                      right: -2,
                      top: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.proxi.bottomNavBackground, width: 1.2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? ProxiPalette.pureWhite : unselectedIcon,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
