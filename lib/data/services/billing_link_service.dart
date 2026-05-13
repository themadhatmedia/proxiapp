import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import '../../config/billing_links.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/toast_helper.dart';
import 'api_service.dart';

/// Listens for `proxiapp://billing/...` after Stripe Checkout in the external browser.
class BillingLinkService extends GetxService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void onInit() {
    super.onInit();
    unawaited(_attach());
  }

  Future<void> _attach() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleUri(initial);
      }
    } catch (_) {}
    _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != BillingLinks.scheme || uri.host != BillingLinks.host) {
      return;
    }
    final normalized = uri.path.toLowerCase();
    if (normalized.endsWith('/success') || normalized == '/success') {
      unawaited(_refreshMembershipAfterReturn(fromDeepLink: true));
      return;
    }
    if (normalized.endsWith('/cancel') || normalized == '/cancel') {
      ToastHelper.showInfo('Checkout canceled');
    }
  }

  /// Called when user returns from Stripe (deep link or app resume).
  Future<void> _refreshMembershipAfterReturn({bool fromDeepLink = false}) async {
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated || auth.token == null) return;

    await auth.fetchUserProfile();

    try {
      await ApiService().getBillingStatus(auth.token!);
      // No success/cancel toasts here — plan screens compare billing snapshots on resume.
    } catch (_) {
      if (fromDeepLink) {
        ToastHelper.showInfo('Returning from checkout — refreshing your profile.');
      }
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
