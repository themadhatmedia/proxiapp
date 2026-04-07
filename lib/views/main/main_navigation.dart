import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/circles_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../data/services/api_service.dart';
import '../../data/services/location_service.dart';
import '../home/circles_screen.dart';
import '../home/discover_screen.dart';
import '../home/messages_screen.dart';
import '../home/profile_screen.dart';
import '../home/pulse_screen.dart';

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

  Future<void> _updateUserLocation() async {
    try {
      final token = _authController.token;
      if (token == null) return;

      final hasPermission = await _locationService.checkAndRequestPermission();
      if (!hasPermission) return;

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        await _apiService.updateLocation(
          token: token,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      // Silently fail - location update is not critical for navigation
    }
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
        _navigationController.navigateToHome();
      });
    } else {
      _navigationController = Get.put(NavigationController());
    }
    // Defer so signup → /profile-creation (and Obx switching `home` to this widget)
    // applies first; skip while any onboarding screen is the active route.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      if (_isOnboardingRouteActive(Get.currentRoute)) return;
      await _updateUserLocation();
    });
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
          body: IndexedStack(
            index: _navigationController.currentIndex.value,
            children: [
              const DiscoverScreen(),
              PulseScreen(isVisible: _navigationController.currentIndex.value == 1),
              const CirclesScreen(),
              const MessagesScreen(),
              const ProfileScreen(),
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
              Icon(
                icon,
                color: isSelected ? ProxiPalette.pureWhite : unselectedIcon,
                size: 24,
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
