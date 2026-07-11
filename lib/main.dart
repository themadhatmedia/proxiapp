import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:get_storage/get_storage.dart';

import 'data/services/app_badge_service.dart';
import 'data/services/apple_iap_service.dart';
import 'data/services/billing_link_service.dart';
import 'data/services/fcm_service.dart';
import 'data/services/messaging_fcm_listeners.dart';
import 'firebase_options.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/theme_controller.dart';
import 'controllers/ads_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/onboarding_controller.dart';
import 'controllers/profile_controller.dart';
import 'views/auth/auth_screen.dart';
import 'views/main/main_navigation.dart';
import 'views/onboarding/profile_creation_screen.dart';
import 'views/onboarding/terms_conditions_screen.dart';
import 'views/onboarding/select_interests_screen.dart';
import 'views/onboarding/select_ambitions_screen.dart';
import 'views/onboarding/select_core_values_screen.dart';
import 'views/onboarding/select_skills_screen.dart';
import 'views/onboarding/select_plan_screen.dart';
import 'views/onboarding/setup_permissions_screen.dart';
import 'views/onboarding/proxi_circles_screen.dart';
import 'utils/app_keyboard_dismiss.dart';
import 'utils/us_date_format.dart';
import 'widgets/proxi_ads_host.dart';
import 'views/bookmarks/bookmarks_screen.dart';

Future<void> _initializeFirebaseSafe() async {
  // Prefer native platform config files (GoogleService-Info.plist / google-services.json).
  // Fallback to explicit options to keep development builds resilient.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  await _initializeFirebaseSafe();
  await AppBadgeService.applyBadgeFromRemoteMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15 (SDK 35) draws edge-to-edge by default. Enable it explicitly so
  // it renders consistently for all users, with transparent system bars so the
  // app content shows behind them. Screens use SafeArea to avoid overlap.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await GetStorage.init();
  Intl.defaultLocale = 'en_US';
  await initializeDateFormatting('en_US');

  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    await _initializeFirebaseSafe();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    if (!Get.isRegistered<BillingLinkService>()) {
      Get.put(BillingLinkService(), permanent: true);
    }
    if (AppleIapService.isSupported) {
      await AppleIapService.instance.init();
    }
  }

  runApp(const MyApp());

  // Run FCM listener setup after the first frame so iOS native swizzling / notification
  // plumbing is less likely to race the Dart isolate during cold start.
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FcmService.instance.install();
      handleInitialMessagingFcm();
    });
  }
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
    if (AdsController.isSupportedPlatform) {
      Get.put(AdsController(), permanent: true);
    }

    return Obx(
      () => GetMaterialApp(
        title: 'Proxi',
        debugShowCheckedModeBanner: false,
        locale: UsDateFormat.locale,
        supportedLocales: const [UsDateFormat.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        routingCallback: (routing) {
          if (Get.isRegistered<AdsController>()) {
            Get.find<AdsController>().notifyRouteChanged();
          }
        },
        // Full-screen brand gradient behind all routes; fixed text scale.
        builder: (context, child) {
          final data = MediaQuery.of(context);
          final content = MediaQuery(
            data: data.copyWith(textScaler: TextScaler.noScaling),
            child: child ?? const SizedBox.shrink(),
          );
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: handlePointerDownDismissKeyboard,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Decorative layer must not participate in hit testing — on iOS taps can
                // otherwise fall through transparent scaffold regions and never reach targets.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.scaffoldGradient(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                ProxiAdsHost(child: content),
              ],
            ),
          );
        },
        home: authController.isAuthenticated ? const MainNavigation() : const AuthScreen(),
        getPages: [
          GetPage(name: '/auth', page: () => const AuthScreen()),
          GetPage(name: '/home', page: () => const MainNavigation()),
          GetPage(
            name: '/profile-creation',
            page: () => const ProfileCreationScreen(),
          ),
          GetPage(
            name: '/terms-conditions',
            page: () => const TermsConditionsScreen(),
          ),
          GetPage(
            name: '/select-interests',
            page: () => const SelectInterestsScreen(),
          ),
          GetPage(
            name: '/select-core-values',
            page: () => const SelectCoreValuesScreen(),
          ),
          GetPage(
            name: '/select-skills',
            page: () => const SelectSkillsScreen(),
          ),
          GetPage(
            name: '/select-ambitions',
            page: () => const SelectAmbitionsScreen(),
          ),
          GetPage(name: '/select-plan', page: () => const SelectPlanScreen()),
          GetPage(
            name: '/setup-permissions',
            page: () => const SetupPermissionsScreen(),
          ),
          GetPage(
            name: '/proxi-circles',
            page: () => const ProxiCirclesScreen(),
          ),
          GetPage(name: '/bookmarks', page: () => const BookmarksScreen()),
          GetPage(name: '/favorites', page: () => const BookmarksScreen()),
        ],
      ),
    );
  }
}
