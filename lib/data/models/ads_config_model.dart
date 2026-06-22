import '../../config/ads_defaults.dart';

/// Remote ads settings (admin enable/disable + unit IDs). Backend wiring is optional.
class AdsConfigModel {
  const AdsConfigModel({
    required this.adsEnabled,
    this.bannerAndroidUnitId,
    this.bannerIosUnitId,
  });

  final bool adsEnabled;
  final String? bannerAndroidUnitId;
  final String? bannerIosUnitId;

  factory AdsConfigModel.defaults() => AdsConfigModel.localActive();

  /// In-app defaults until admin API is available.
  factory AdsConfigModel.localActive() => AdsConfigModel(
        adsEnabled: AdsDefaults.localAdsEnabled,
        bannerAndroidUnitId: AdsDefaults.testAndroidBannerUnitId,
        bannerIosUnitId: AdsDefaults.testIosBannerUnitId,
      );

  factory AdsConfigModel.fromJson(Map<String, dynamic> json) {
    final remoteEnabled = json['ads_enabled'] == true || json['adsEnabled'] == true;
    final enabled = AdsDefaults.effectiveAdsEnabled(remoteEnabled);

    return AdsConfigModel(
      adsEnabled: enabled,
      bannerAndroidUnitId: _resolveBannerUnitId(
        json['banner_android_unit_id'] ?? json['bannerAndroidUnitId'],
        fallback: AdsDefaults.testAndroidBannerUnitId,
      ),
      bannerIosUnitId: _resolveBannerUnitId(
        json['banner_ios_unit_id'] ?? json['bannerIosUnitId'],
        fallback: AdsDefaults.testIosBannerUnitId,
      ),
    );
  }

  /// Uses [fallback] (from [AdsDefaults]) when the API omits or sends blank unit IDs.
  static String _resolveBannerUnitId(dynamic value, {required String fallback}) {
    final s = value?.toString().trim();
    return (s != null && s.isNotEmpty) ? s : fallback;
  }

  Map<String, dynamic> toJson() => {
        'ads_enabled': adsEnabled,
        if (bannerAndroidUnitId != null) 'banner_android_unit_id': bannerAndroidUnitId,
        if (bannerIosUnitId != null) 'banner_ios_unit_id': bannerIosUnitId,
      };

  factory AdsConfigModel.fromStorageMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return AdsConfigModel.defaults();
    return AdsConfigModel.fromJson(map);
  }
}
