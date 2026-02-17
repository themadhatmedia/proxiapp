import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../home/circles_screen.dart';
import '../home/discover_screen.dart';
import '../home/messages_screen.dart';
import '../home/profile_screen.dart';
import '../home/pulse_screen.dart';
import '../../data/services/location_service.dart';
import '../../data/services/api_service.dart';
import '../../controllers/auth_controller.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final LocationService _locationService = Get.put(LocationService());
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();

  void _updateStatusBar() {
    // Set status bar to light icons (white) for Pulse screen (index 1)
    // which has a dark background
    if (_currentIndex == 1) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    } else {
      // Set status bar to dark icons for other screens
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );
    }
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

  @override
  void initState() {
    super.initState();
    _updateStatusBar();
    _updateUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DiscoverScreen(),
          PulseScreen(isVisible: _currentIndex == 1),
          const CirclesScreen(),
          const MessagesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.near_me,
                  label: 'Pulse',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.group,
                  label: 'Circles',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.chat_bubble,
                  label: 'Messages',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  index: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          _updateStatusBar();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A90E2).withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF4A90E2) : Colors.white60,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF4A90E2) : Colors.white60,
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
