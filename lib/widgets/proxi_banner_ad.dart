import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_defaults.dart';
import '../controllers/ads_controller.dart';

/// Fixed-height bottom banner so surrounding layout does not shift.
class ProxiBannerAd extends StatefulWidget {
  const ProxiBannerAd({super.key});

  @override
  State<ProxiBannerAd> createState() => _ProxiBannerAdState();
}

class _ProxiBannerAdState extends State<ProxiBannerAd> {
  BannerAd? _banner;
  bool _loaded = false;
  String? _loadingUnitId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdIfNeeded());
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  void _disposeBanner() {
    _banner?.dispose();
    _banner = null;
    _loaded = false;
    _loadingUnitId = null;
  }

  void _loadAdIfNeeded() {
    if (!mounted) return;
    final ads = Get.find<AdsController>();
    if (!ads.shouldShowBanner) return;
    final unitId = ads.bannerAdUnitId;
    if (unitId.isEmpty) return;
    _loadAd(unitId);
  }

  Future<void> _loadAd(String unitId) async {
    if (_loadingUnitId == unitId && (_loaded || _banner != null)) return;
    _disposeBanner();
    _loadingUnitId = unitId;

    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) return;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) {
      if (kDebugMode) debugPrint('[Ads] banner size unavailable (width=$width)');
      return;
    }

    final banner = BannerAd(
      adUnitId: unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
          if (kDebugMode) debugPrint('[Ads] banner loaded ($unitId)');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[Ads] banner failed ($unitId): $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _loaded = false;
              _banner = null;
              _loadingUnitId = null;
            });
          }
        },
      ),
    );

    _banner = banner;
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    final height = _loaded && _banner != null
        ? _banner!.size.height.toDouble()
        : AdsDefaults.bannerHeight;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: _loaded && _banner != null
          ? ColoredBox(
              color: Colors.black.withValues(alpha: 0.04),
              child: Center(
                child: AdWidget(ad: _banner!),
              ),
            )
          : ColoredBox(
              color: Colors.black.withValues(alpha: 0.02),
              child: kDebugMode
                  ? const Center(
                      child: Text(
                        'Loading ad…',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    )
                  : null,
            ),
    );
  }
}
