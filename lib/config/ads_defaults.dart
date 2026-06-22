import 'package:flutter/foundation.dart';

/// Placeholder AdMob IDs for development (Google official test units).
/// Replace with production IDs from the client's AdMob account before release.
class AdsDefaults {
  AdsDefaults._();

  /// Google sample app IDs — swap for production in AndroidManifest / Info.plist.
  static const String testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testIosAppId = 'ca-app-pub-3940256099942544~1458002511';

  // static const String testAndroidBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  // static const String testIosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';

  static const String testAndroidBannerUnitId = 'ca-app-pub-7791764360171099/6160910780';
  static const String testIosBannerUnitId = 'ca-app-pub-7791764360171099/1934430167';

  /// Reserved height so layout does not jump when the ad loads (standard banner).
  static const double bannerHeight = 50;

  // --- Remote config API (GET /settings/ads) ---

  /// Fetches admin ads settings from `GET /api/v1/settings/ads`.
  static const bool fetchRemoteAdsConfig = true;

  /// Fallback when [fetchRemoteAdsConfig] is false (offline / dev without API).
  static const bool localAdsEnabled = true;

  // --- Debug-only toggles (ignored in release/profile bundles) ---

  /// Debug: treat ads as admin-enabled without backend `ads_enabled`.
  static const bool debugForceAdsEnabled = true;

  /// Debug: show banner on paid plans (e.g. Elite) while testing layout.
  static const bool debugShowAdsOnPaidPlans = false;

  static bool get debugOverridesActive => kDebugMode;

  static bool effectiveAdsEnabled(bool remoteAdsEnabled) => remoteAdsEnabled || (!fetchRemoteAdsConfig && localAdsEnabled) || (debugOverridesActive && debugForceAdsEnabled);

  static bool effectivePlanEligible(bool isFreemiumUser) => isFreemiumUser || (debugOverridesActive && debugShowAdsOnPaidPlans);
}
