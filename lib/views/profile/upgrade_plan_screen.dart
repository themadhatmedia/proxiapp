import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/apple_iap_products.dart';
import '../../config/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../data/models/billing_status_model.dart';
import '../../data/models/billing_status_snapshot.dart';
import '../../data/models/plan_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/apple_iap_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/checkout_affiliate_code_sheet.dart';
import '../../widgets/ios_payment_method_sheet.dart';
import '../../widgets/plan_option_card.dart';

class UpgradePlanScreen extends StatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> with WidgetsBindingObserver {
  final ProfileController controller = Get.put(ProfileController());
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();
  int? selectedPlanId;
  bool _isSaving = false;
  bool _awaitingStripeReturn = false;

  /// Captured immediately before opening Stripe; used to detect cancel/back without paying.
  BillingStatusSnapshot? _billingSnapshotBeforeCheckout;

  /// Must match API: `monthly` | `yearly`.
  String _billingCycle = 'monthly';

  int? get _currentMembershipPlanId => authController.currentUser.value?.membership?.membershipId;

  bool get _isSameAsCurrentPlan =>
      selectedPlanId != null && _currentMembershipPlanId != null && selectedPlanId == _currentMembershipPlanId;

  PlanModel? get _selectedPlanModel {
    if (selectedPlanId == null) return null;
    for (final p in controller.availablePlans) {
      if (p.id == selectedPlanId) return p;
    }
    return null;
  }

  bool get _canStartCheckout {
    if (_isSaving || selectedPlanId == null || _isSameAsCurrentPlan) return false;
    return _selectedPlanModel?.availableForPurchase == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final currentUser = authController.currentUser.value;
    if (currentUser?.membership?.membershipId != null) {
      selectedPlanId = currentUser!.membership!.membershipId;
    }
    controller.loadPlans().then((_) {
      if (!mounted) return;
      final plans = controller.availablePlans;
      if (plans.isEmpty) return;

      var found = false;
      if (selectedPlanId != null) {
        for (final p in plans) {
          if (p.id == selectedPlanId) {
            found = true;
            break;
          }
        }
      }
      setState(() {
        if (!found) {
          selectedPlanId = PlanModel.initialSelectionForUpgrade(plans)?.id;
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _awaitingStripeReturn) {
      _syncAfterStripeReturn();
    }
  }

  Future<void> _syncAfterStripeReturn() async {
    final token = authController.token;
    if (token == null) return;
    final before = _billingSnapshotBeforeCheckout;
    await authController.fetchUserProfile();
    try {
      final status = await apiService.getBillingStatus(token);
      if (!mounted) return;
      setState(() {
        _awaitingStripeReturn = false;
        _billingSnapshotBeforeCheckout = null;
      });

      if (before == null) {
        return;
      }

      BillingStatusModel? effective = status;
      var afterSnap = BillingStatusSnapshot.fromModel(effective);
      if (before.matches(afterSnap)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        effective = await apiService.getBillingStatus(token);
        afterSnap = BillingStatusSnapshot.fromModel(effective);
      }
      if (before.matches(afterSnap)) {
        ToastHelper.showInfo('Checkout canceled. Your plan was not changed.');
        return;
      }

      final targetId = selectedPlanId;
      final targetCycle = _billingCycle.toLowerCase().trim();
      if (effective != null &&
          effective.isActive &&
          targetId != null &&
          effective.membershipId == targetId &&
          (effective.planType?.toLowerCase().trim() == targetCycle)) {
        ToastHelper.showSuccess('Subscription active.');
        Get.back(result: true);
        return;
      }

      if (effective != null &&
          effective.isActive &&
          targetId != null &&
          effective.membershipId == targetId) {
        ToastHelper.showSuccess('Subscription active.');
        Get.back(result: true);
        return;
      }

      ToastHelper.showInfo(
        'If you completed payment, your plan may take a moment to activate.',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _awaitingStripeReturn = false;
          _billingSnapshotBeforeCheckout = null;
        });
        ToastHelper.showInfo('Could not verify billing yet — try again shortly.');
      }
    }
  }

  Future<bool> _confirmMembershipUpdated({
    required String token,
    required int expectedMembershipId,
    String? expectedPlanType,
  }) async {
    final normalizedPlanType = expectedPlanType?.toLowerCase().trim();
    for (var attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: attempt <= 2 ? 1 : 2));
      }
      await authController.fetchUserProfile();
      try {
        final status = await apiService.getBillingStatus(token);
        final planTypeOk = normalizedPlanType == null ||
            normalizedPlanType.isEmpty ||
            status?.planType?.toLowerCase().trim() == normalizedPlanType;
        if (status != null &&
            status.isActive &&
            status.membershipId == expectedMembershipId &&
            planTypeOk) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> _handleSubscribe() async {
    if (selectedPlanId == null) {
      ToastHelper.showError('Please select a plan');
      return;
    }
    if (_isSameAsCurrentPlan) {
      ToastHelper.showError('You are already on this plan');
      return;
    }

    final selectedPlan = _selectedPlanModel;
    if (selectedPlan?.availableForPurchase != true) {
      ToastHelper.showError('This plan is not available for purchase');
      return;
    }

    final token = authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    if (selectedPlan!.isFree) {
      setState(() => _isSaving = true);
      try {
        await apiService.subscribeMembership(token: token, membershipId: selectedPlanId!);
        await authController.fetchUserProfile();
        ToastHelper.showSuccess('Subscription updated successfully');
        Get.back(result: true);
      } catch (e) {
        ToastHelper.showError('Failed to update subscription');
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final affiliateCode = await showCheckoutAffiliateCodeSheet(context);
      if (!mounted || affiliateCode == null) {
        setState(() => _isSaving = false);
        return;
      }

      if (AppleIapService.isSupported) {
        final method = await showIosPaymentMethodSheet(context);
        if (!mounted || method == null) {
          setState(() => _isSaving = false);
          return;
        }
        if (method == IosPaymentMethod.inAppPurchase) {
          await _startAppleInAppPurchase(
            token: token,
            affiliateCode: affiliateCode,
          );
          return;
        }
      }

      await _startStripeCheckout(
        token: token,
        affiliateCode: affiliateCode,
      );
    } catch (e) {
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && !_awaitingStripeReturn) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _startStripeCheckout({
    required String token,
    required String affiliateCode,
  }) async {
    final res = await apiService.createBillingCheckoutSession(
      token: token,
      membershipId: selectedPlanId!,
      planType: _billingCycle,
      affiliateCode: affiliateCode,
    );
    final checkoutUrl = res['checkout_url']?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('Missing checkout URL');
    }
    final uri = Uri.parse(checkoutUrl);
    BillingStatusSnapshot snapshotBefore;
    try {
      final prior = await apiService.getBillingStatus(token);
      snapshotBefore = BillingStatusSnapshot.fromModel(prior);
    } catch (_) {
      snapshotBefore = const BillingStatusSnapshot();
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Could not open checkout');
    }
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _awaitingStripeReturn = true;
      _billingSnapshotBeforeCheckout = snapshotBefore;
    });
    ToastHelper.showInfo('Complete payment in the browser, then return to Proxi.');
  }

  Future<void> _startAppleInAppPurchase({
    required String token,
    required String affiliateCode,
  }) async {
    final selectedPlan = _selectedPlanModel;
    if (selectedPlan == null) {
      setState(() => _isSaving = false);
      return;
    }

    final productId = AppleIapProducts.productIdForPlan(selectedPlan, _billingCycle);
    if (productId == null) {
      setState(() => _isSaving = false);
      ToastHelper.showError('This plan is not available via In-App Purchase.');
      return;
    }

    final result = await AppleIapService.instance.purchaseAndVerify(
      productId: productId,
      token: token,
      membershipId: selectedPlanId!,
      planType: _billingCycle,
      affiliateCode: affiliateCode.isEmpty ? null : affiliateCode,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.success) {
      if (result.error != null && result.error!.isNotEmpty) {
        ToastHelper.showError(result.error!);
      } else {
        ToastHelper.showError('Purchase could not be completed.');
      }
      return;
    }

    final activated = await _confirmMembershipUpdated(
      token: token,
      expectedMembershipId: selectedPlanId!,
      expectedPlanType: _billingCycle,
    );
    if (!mounted) return;

    if (activated) {
      ToastHelper.showSuccess('Subscription active.');
      Get.back(result: true);
      return;
    }

    ToastHelper.showInfo(
      'Purchase received. Your plan may take a moment to activate — pull to refresh your profile.',
    );
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.arrow_back, color: cs.onSurface),
                    ),
                    Expanded(
                      child: Text(
                        'Upgrade Plan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Select the subscription that works best for you',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return const SizedBox.shrink();
                        }
                        final plans = controller.availablePlans;
                        if (plans.isEmpty || !plans.any((p) => !p.isFree)) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'monthly',
                                  label: Text('Monthly'),
                                  icon: Icon(Icons.calendar_month_outlined, size: 18),
                                ),
                                ButtonSegment(
                                  value: 'yearly',
                                  label: Text('Yearly'),
                                  icon: Icon(Icons.event_repeat_outlined, size: 18),
                                ),
                              ],
                              selected: {_billingCycle},
                              onSelectionChanged: (Set<String> next) {
                                setState(() => _billingCycle = next.first);
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: CircularProgressIndicator(color: cs.primary),
                            ),
                          );
                        }

                        if (controller.availablePlans.isEmpty) {
                          return Center(
                            child: Text(
                              'No plans available',
                              style: TextStyle(color: cs.onSurface),
                            ),
                          );
                        }

                        return Column(
                          children: controller.availablePlans.map((plan) {
                            return PlanOptionCard(
                              plan: plan,
                              isSelected: selectedPlanId == plan.id,
                              billingCycle: _billingCycle,
                              currentMembershipPlanId: _currentMembershipPlanId,
                              onTap: plan.availableForPurchase
                                  ? () {
                                      setState(() {
                                        selectedPlanId = plan.id;
                                      });
                                    }
                                  : null,
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Obx(() {
                  controller.availablePlans.length;
                  final sel = _selectedPlanModel;
                  final label = sel == null
                      ? 'Select a plan'
                      : sel.isFree
                          ? (_isSaving ? 'Updating...' : 'Update subscription')
                          : (_isSaving ? 'Please wait...' : 'Continue to secure checkout');
                  return CustomButton(
                    text: label,
                    isEnabled: _canStartCheckout,
                    onPressed: _handleSubscribe,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
