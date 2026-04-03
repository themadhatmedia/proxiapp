import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/theme_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/onboarding_controller.dart';
import 'controllers/profile_controller.dart';
import 'views/auth/auth_screen.dart';
import 'views/main/main_navigation.dart';
import 'views/onboarding/profile_creation_screen.dart';
import 'views/onboarding/terms_conditions_screen.dart';
import 'views/onboarding/select_interests_screen.dart';
import 'views/onboarding/select_core_values_screen.dart';
import 'views/onboarding/select_plan_screen.dart';
import 'views/onboarding/setup_permissions_screen.dart';
import 'views/onboarding/proxi_circles_screen.dart';
import 'views/favorites/favorites_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.put(ThemeController());
    final AuthController authController = Get.put(AuthController());
    Get.put(NavigationController());
    Get.put(OnboardingController());
    Get.put(ProfileController());

    return Obx(
      () => GetMaterialApp(
        title: 'Proxi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        // Full-screen brand gradient behind all routes; fixed text scale.
        builder: (context, child) {
          final data = MediaQuery.of(context);
          final content = MediaQuery(
            data: data.copyWith(textScaler: TextScaler.noScaling),
            child: child ?? const SizedBox.shrink(),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.scaffoldGradient(context),
                ),
                child: const SizedBox.expand(),
              ),
              content,
            ],
          );
        },
        home: authController.isAuthenticated ? const MainNavigation() : const AuthScreen(),
        getPages: [
          GetPage(name: '/auth', page: () => const AuthScreen()),
          GetPage(name: '/home', page: () => const MainNavigation()),
          GetPage(name: '/profile-creation', page: () => const ProfileCreationScreen()),
          GetPage(name: '/terms-conditions', page: () => const TermsConditionsScreen()),
          GetPage(name: '/select-interests', page: () => const SelectInterestsScreen()),
          GetPage(name: '/select-core-values', page: () => const SelectCoreValuesScreen()),
          GetPage(name: '/select-plan', page: () => const SelectPlanScreen()),
          GetPage(name: '/setup-permissions', page: () => const SetupPermissionsScreen()),
          GetPage(name: '/proxi-circles', page: () => const ProxiCirclesScreen()),
          GetPage(name: '/favorites', page: () => const FavoritesScreen()),
        ],
      ),
    );
  }
}
