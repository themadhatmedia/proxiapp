import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/services/api_service.dart';
import '../../data/services/location_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/radar_view.dart';
import '../pulse/nearby_users_screen.dart';

class PulseScreen extends StatefulWidget {
  final bool isVisible;

  const PulseScreen({super.key, this.isVisible = false});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();
  final LocationService locationService = Get.put(LocationService());

  final List<int> radiusOptions = [50, 100, 150, 200];
  int selectedRadius = 50;
  int nearbyUserCount = 0;
  bool isSearching = false;
  bool hasSearched = false;
  Position? currentPosition;
  Map<String, dynamic>? nearbyUsersData; // meters

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(PulseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _searchNearbyUsers() async {
    if (isSearching) return;

    final hasPermission = await locationService.checkAndRequestPermission();
    if (!hasPermission) {
      ToastHelper.showError('Location permission is required');
      return;
    }

    setState(() => isSearching = true);

    try {
      final position = await locationService.getCurrentLocation();
      if (position == null) {
        ToastHelper.showError('Unable to get current location');
        setState(() => isSearching = false);
        return;
      }

      setState(() => currentPosition = position);

      final token = authController.token;
      if (token == null) {
        ToastHelper.showError('Authentication required');
        setState(() => isSearching = false);
        return;
      }

      final data = await apiService.getNearbyUsers(
        token: token,
        latitude: position.latitude,
        longitude: position.longitude,
        radius: selectedRadius,
      );

      setState(() {
        nearbyUsersData = data;
        nearbyUserCount = data['count'] ?? 0;
        isSearching = false;
        hasSearched = true;
      });

      await authController.fetchUserProfile();

      if (nearbyUserCount == 0) {
        ToastHelper.showInfo('No nearby users found');
      } else {
        final userText = nearbyUserCount == 1 ? 'user' : 'users';
        ToastHelper.showSuccess('$nearbyUserCount $userText found');
      }
    } catch (e) {
      setState(() => isSearching = false);
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    }
  }

  void _onRadiusChanged(int radius) {
    setState(() {
      selectedRadius = radius;
    });
  }

  void _onRadarTap() {
    if (!isSearching) {
      _searchNearbyUsers();
    }
  }

  void _showNearbyUsersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 400),
      )..forward(),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        snapSizes: const [0.5, 0.95],
        builder: (context, scrollController) => NearbyUsersScreen(
          nearbyUsersData: nearbyUsersData!,
          selectedRadius: selectedRadius,
          currentPosition: currentPosition!,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Pulse',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // const SizedBox(height: 0),
                if (hasSearched)
                  Text(
                    'Nearby Users',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 4),
                if (isSearching)
                  Column(
                    children: [
                      const SpinKitPulse(
                        color: Colors.white,
                        size: 25.0,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Searching...',
                        style: TextStyle(
                          fontSize: 15.0,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (hasSearched)
                  Text(
                    nearbyUserCount.toString(),
                    style: const TextStyle(
                      fontSize: 42,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (!isSearching)
                  Text(
                    'Send pulse to discover people nearby',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 14.0),
                Expanded(
                  child: RadarView(
                    userCount: nearbyUserCount,
                    onTap: _onRadarTap,
                    selectedRadius: selectedRadius,
                    isSearching: isSearching,
                    hasSearched: hasSearched,
                    usersData: nearbyUsersData,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Search Radius',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: radiusOptions.map((radius) {
                      final isSelected = selectedRadius == radius;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onRadiusChanged(radius),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$radius\nYDS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasSearched && nearbyUserCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showNearbyUsersSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                        ),
                        child: const Text(
                          'View Nearby Users',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
