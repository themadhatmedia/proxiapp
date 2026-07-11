import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ads_controller.dart';
import 'proxi_banner_ad.dart';

/// Wraps pushed routes with a bottom banner. [MainNavigation] handles its own slot
/// above the bottom nav bar on `/` and `/home`.
class ProxiAdsHost extends StatelessWidget {
  const ProxiAdsHost({super.key, required this.child});

  final Widget? child;

  /// Main tab shell already renders the banner above [Scaffold.bottomNavigationBar].
  static bool _isMainShellRoute(String route) {
    final r = route.toLowerCase();
    if (r == '/' || r == '/home') return true;
    // Fallback for legacy anonymous routes from Get.off(() => MainNavigation()).
    if (r.contains('mainnavigation')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();

    if (!Get.isRegistered<AdsController>()) {
      return content;
    }

    final ads = Get.find<AdsController>();
    return Obx(() {
      final _ = ads.bannerLayoutRevision;
      if (_isMainShellRoute(Get.currentRoute)) {
        return content;
      }
      if (!ads.shouldShowBanner) {
        return content;
      }
      return Column(
        children: [
          Expanded(child: content),
          const ProxiBannerAd(),
        ],
      );
    });
  }
}
