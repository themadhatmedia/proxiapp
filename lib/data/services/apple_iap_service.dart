import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_service.dart';

class AppleIapResult {
  const AppleIapResult({required this.success, this.error});

  final bool success;
  final String? error;
}

/// Handles App Store subscription purchases on iOS and verifies them with the Proxi API.
class AppleIapService {
  AppleIapService._();

  static final AppleIapService instance = AppleIapService._();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Completer<PurchaseDetails>? _purchaseCompleter;
  String? _pendingProductId;

  String? _flushProductId;
  Completer<void>? _flushCompleter;

  Future<void> init() async {
    if (!isSupported) return;
    await _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        if (kDebugMode) debugPrint('[IAP] purchaseStream error: $e');
      },
    );
    // Deliver any unfinished transactions so we can complete them on cold start.
    unawaited(_drainOutstandingTransactions());
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  Future<AppleIapResult> purchaseAndVerify({
    required String productId,
    required String token,
    required int membershipId,
    required String planType,
    String? affiliateCode,
  }) async {
    if (!isSupported) {
      return const AppleIapResult(success: false, error: 'In-App Purchase is only available on iOS.');
    }

    final available = await _iap.isAvailable();
    if (!available) {
      return const AppleIapResult(success: false, error: 'In-App Purchase is not available on this device.');
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.contains(productId) || response.productDetails.isEmpty) {
      return AppleIapResult(
        success: false,
        error: 'Product "$productId" was not found in App Store Connect. '
            'Create this subscription and submit it for review before testing.',
      );
    }

    final product = response.productDetails.first;

    // Clear any stale StoreKit queue entry for this product before buying again.
    await _flushPendingTransactions(productId: productId);

    _pendingProductId = productId;
    _purchaseCompleter = Completer<PurchaseDetails>();

    PurchaseDetails? purchase;
    try {
      final started = await _startPurchase(product);
      if (!started) {
        return const AppleIapResult(success: false, error: 'Could not start In-App Purchase.');
      }

      purchase = await _purchaseCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException('Purchase timed out');
        },
      );

      final transactionId = purchase.purchaseID?.trim() ?? '';
      final receiptData = purchase.verificationData.serverVerificationData.trim();
      if (transactionId.isEmpty) {
        throw Exception('Missing Apple transaction id. Try again or contact support.');
      }
      if (receiptData.isEmpty) {
        throw Exception('Missing Apple receipt data. Try again or contact support.');
      }

      await _verifyWithRetry(
        token: token,
        membershipId: membershipId,
        planType: planType,
        productId: productId,
        transactionId: transactionId,
        receiptData: receiptData,
        affiliateCode: affiliateCode,
      );

      return const AppleIapResult(success: true);
    } on TimeoutException {
      return const AppleIapResult(success: false, error: 'Purchase timed out. Try again.');
    } on PlatformException catch (e) {
      if (_isDuplicatePendingProductError(e)) {
        return AppleIapResult(
          success: false,
          error: 'A previous App Store purchase for this plan is still pending. '
              'Close and reopen the app, then try again. If it persists, use Stripe checkout.',
        );
      }
      return AppleIapResult(success: false, error: _friendlyError(e));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('cancel')) {
        return const AppleIapResult(success: false, error: 'Purchase canceled.');
      }
      return AppleIapResult(success: false, error: message);
    } finally {
      if (purchase != null && purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
          if (kDebugMode) {
            debugPrint('[IAP] Finished transaction ${purchase.productID}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[IAP] completePurchase failed: $e');
        }
      }
      _clearPending();
    }
  }

  Future<bool> _startPurchase(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: param);
    } on PlatformException catch (e) {
      if (!_isDuplicatePendingProductError(e)) rethrow;

      if (kDebugMode) {
        debugPrint('[IAP] Duplicate pending product — flushing ${product.id}');
      }
      await _flushPendingTransactions(productId: product.id);
      return _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> _verifyWithRetry({
    required String token,
    required int membershipId,
    required String planType,
    required String productId,
    required String transactionId,
    required String receiptData,
    String? affiliateCode,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await ApiService().verifyAppleInAppPurchase(
          token: token,
          membershipId: membershipId,
          planType: planType,
          productId: productId,
          transactionId: transactionId,
          receiptData: receiptData,
          affiliateCode: affiliateCode,
        );
        return;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
    }
    throw lastError ?? Exception('Could not verify purchase with server');
  }

  Future<void> _drainOutstandingTransactions() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] restorePurchases on init: $e');
    }
  }

  Future<void> _flushPendingTransactions({required String productId}) async {
    _flushProductId = productId;
    _flushCompleter = Completer<void>();
    try {
      await _iap.restorePurchases();
      await _flushCompleter!.future.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // No matching pending transaction surfaced — queue may already be clear.
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] flush pending: $e');
    } finally {
      _flushProductId = null;
      _flushCompleter = null;
    }
  }

  bool _isDuplicatePendingProductError(PlatformException e) {
    return e.code == 'storekit_duplicate_product_object' ||
        e.message?.toLowerCase().contains('pending transaction') == true;
  }

  String _friendlyError(PlatformException e) {
    if (_isDuplicatePendingProductError(e)) {
      return 'A previous App Store purchase for this plan is still pending. '
          'Close and reopen the app, then try again.';
    }
    return e.message ?? e.toString();
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      unawaited(_handlePurchaseUpdate(purchase));
    }
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    if (_flushProductId != null &&
        purchase.pendingCompletePurchase &&
        purchase.productID == _flushProductId) {
      try {
        await _iap.completePurchase(purchase);
        if (kDebugMode) {
          debugPrint('[IAP] Flushed pending ${purchase.productID}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[IAP] flush completePurchase failed: $e');
      }
      if (_flushCompleter != null && !_flushCompleter!.isCompleted) {
        _flushCompleter!.complete();
      }
      return;
    }

    final pendingId = _pendingProductId;
    final completer = _purchaseCompleter;

    if (pendingId != null && completer != null && !completer.isCompleted) {
      if (purchase.productID != pendingId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          completer.completeError(
            Exception(
              'You already have an active App Store subscription (${purchase.productID}). '
              'Open iPhone Settings → Apple ID → Subscriptions to manage it, '
              'or choose Stripe checkout.',
            ),
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
        return;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          return;
        case PurchaseStatus.canceled:
          completer.completeError(Exception('Purchase canceled'));
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          return;
        case PurchaseStatus.error:
          completer.completeError(
            Exception(purchase.error?.message ?? 'In-App Purchase failed'),
          );
          return;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (kDebugMode) {
            debugPrint('[IAP] Purchase ready for ${purchase.productID} (${purchase.status.name})');
          }
          completer.complete(purchase);
          return;
      }
    }

    // Orphaned / stale transaction — finish it so StoreKit does not block future buys.
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
        if (kDebugMode) {
          debugPrint('[IAP] Completed orphaned transaction ${purchase.productID}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[IAP] orphaned completePurchase failed: $e');
      }
    }
  }

  void _clearPending() {
    _pendingProductId = null;
    _purchaseCompleter = null;
  }
}
