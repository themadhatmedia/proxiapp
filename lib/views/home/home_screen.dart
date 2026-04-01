import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../auth/auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              _buildToggleTabs(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWelcomeTab(context, authController),
                    _buildActivityTab(context),
                    _buildSettingsTab(context, authController),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTabs(BuildContext context) {
    final proxi = context.proxi;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: proxi.tabBarTrack,
          borderRadius: BorderRadius.circular(28.0),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: proxi.tabIndicator,
            borderRadius: BorderRadius.circular(28.0),
            shape: BoxShape.rectangle,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: proxi.tabLabelSelected,
          unselectedLabelColor: proxi.tabLabelUnselected,
          labelStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Welcome'),
            Tab(text: 'Activity'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeTab(BuildContext context, AuthController authController) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.navigation_rounded,
                size: 50,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Welcome to Proxi!',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hello, ${authController.user?.name ?? "User"}',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              authController.user?.email ?? '',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 80,
              color: cs.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Activity Feed Coming Soon',
              style: TextStyle(
                fontSize: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context, AuthController authController) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 60,
              color: cs.onSurface,
            ),
            const SizedBox(height: 30),
            Text(
              'Settings',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  await authController.logout();
                  Get.offAll(() => const AuthScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest,
                  foregroundColor: cs.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  'Logout',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
