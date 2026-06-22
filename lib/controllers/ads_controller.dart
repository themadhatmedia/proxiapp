import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_defaults.dart';
import '../data/models/ads_config_model.dart';
import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
import 'auth_controller.dart';

/// Freemium banner ads (AdMob). Admin on/off via remote config when API is ready.
class AdsController extends GetxController {
  static const _storageKey = 'ads_remote_config_v1';

  final ApiService _api = ApiService();
  final GetStorage _box = GetStorage();

  final Rx<AdsConfigModel> config = AdsConfigModel.defaults().obs;
  final RxBool sdkReady = false.obs;
  /// Bumps when GetX route changes so [Obx] re-evaluates [shouldShowBanner].
  final RxInt _routeRevision = 0.obs;

  /// Subscribe in layout widgets that depend on [Get.currentRoute].
  int get bannerLayoutRevision => _routeRevision.value;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static double get reservedBannerHeight => AdsDefaults.bannerHeight;

  @override
  void onInit() {
    super.onInit();
    if (AdsDefaults.fetchRemoteAdsConfig) {
      _loadCachedConfig();
      unawaited(refreshRemoteConfig());
    } else {
      config.value = AdsConfigModel.localActive();
    }
    if (isSupportedPlatform) {
      unawaited(_initSdk());
    }
  }

  /// Called from [GetMaterialApp.routingCallback] when the route changes.
  void notifyRouteChanged() => _scheduleBannerRecheck();

  /// Rebuild banner [Obx] widgets after the current frame (never during build).
  void _scheduleBannerRecheck() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      _routeRevision.value++;
    });
  }

  Future<void> _initSdk() async {
    try {
      final status = await MobileAds.instance.initialize();
      sdkReady.value = true;
      if (kDebugMode) {
        debugPrint('[Ads] AdMob SDK ready (${status.adapterStatuses.length} adapters)');
      }
      _scheduleBannerRecheck();
    } catch (e) {
      debugPrint('[Ads] AdMob init failed: $e');
    }
  }

  void _loadCachedConfig() {
    final raw = _box.read(_storageKey);
    if (raw is Map) {
      config.value = AdsConfigModel.fromStorageMap(
        Map<String, dynamic>.from(raw.map((k, v) => MapEntry('$k', v))),
      );
    }
  }

  Future<void> refreshRemoteConfig() async {
    if (!AdsDefaults.fetchRemoteAdsConfig) {
      config.value = AdsConfigModel.localActive();
      return;
    }

    final token = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().token
        : null;

    try {
      final remote = await _api.getAdsConfig(token: token);
      config.value = remote;
      await _box.write(_storageKey, remote.toJson());
      _scheduleBannerRecheck();
    } catch (e) {
      debugPrint('Ads config fetch failed (using cache): $e');
      _loadCachedConfig();
    }
  }

  bool get _adsEnabledByAdmin =>
      AdsDefaults.effectiveAdsEnabled(config.value.adsEnabled);

  /// True when a freemium user (or debug override) should see the bottom banner.
  bool get shouldShowBanner {
    // Subscribe [Obx] to route + auth changes.
    final _ = _routeRevision.value;
    final route = Get.currentRoute;

    if (!isSupportedPlatform) {
      _debugBannerSkip('unsupported platform');
      return false;
    }
    if (!sdkReady.value) {
      _debugBannerSkip('AdMob SDK not ready');
      return false;
    }
    if (!Get.isRegistered<AuthController>()) {
      _debugBannerSkip('AuthController missing');
      return false;
    }
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated) {
      _debugBannerSkip('not authenticated (route=$route)');
      return false;
    }
    if (!_adsEnabledByAdmin) {
      _debugBannerSkip('ads disabled by admin/config');
      return false;
    }
    if (!AdsDefaults.effectivePlanEligible(_isFreemiumUser(auth.user))) {
      _debugBannerSkip('plan not eligible (freemium-only in release)');
      return false;
    }
    if (_isExcludedRoute(route)) {
      _debugBannerSkip('excluded route: $route');
      return false;
    }
    if (_bannerUnitId == null) {
      _debugBannerSkip('no banner unit id');
      return false;
    }
    _lastSkipReason = null;
    return true;
  }

  void _debugBannerSkip(String reason) {
    if (!kDebugMode) return;
    if (_lastSkipReason == reason) return;
    _lastSkipReason = reason;
    debugPrint('[Ads] banner hidden: $reason');
  }

  String? _lastSkipReason;

  String? get _bannerUnitId {
    final c = config.value;
    if (Platform.isAndroid) {
      return _nonEmpty(c.bannerAndroidUnitId) ?? AdsDefaults.testAndroidBannerUnitId;
    }
    if (Platform.isIOS) {
      return _nonEmpty(c.bannerIosUnitId) ?? AdsDefaults.testIosBannerUnitId;
    }
    return null;
  }

  static String? _nonEmpty(String? id) {
    final s = id?.trim();
    return (s != null && s.isNotEmpty) ? s : null;
  }

  String get bannerAdUnitId => _bannerUnitId ?? '';

  static bool _isFreemiumUser(User? user) {
    if (user == null) return false;
    final plan = user.membership?.membership;
    if (plan == null) {
      // No paid tier on file — treat as freemium until membership loads.
      return true;
    }
    final price = double.tryParse(plan.price) ?? 0;
    if (price <= 0) return true;
    final name = plan.name.toLowerCase();
    return name.contains('freemium') || name.contains('free');
  }

  static bool _isExcludedRoute(String route) {
    final r = route.toLowerCase();
    // `/` is the default when [GetMaterialApp.home] is MainNavigation — allow it.
    // Logged-out AuthScreen is already blocked by [isAuthenticated] in [shouldShowBanner].
    if (r.isEmpty) return true;
    const blocked = [
      '/auth',
      'profile-creation',
      'terms-conditions',
      'select-interests',
      'select-core-values',
      'select-skills',
      'select-ambitions',
      'select-plan',
      'setup-permissions',
      'proxi-circles',
    ];
    return blocked.any(r.contains);
  }
}
