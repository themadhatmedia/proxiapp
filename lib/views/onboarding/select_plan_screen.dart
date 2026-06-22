import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../data/models/billing_status_model.dart';
import '../../data/models/billing_status_snapshot.dart';
import '../../data/services/api_service.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/checkout_affiliate_code_sheet.dart';
import '../../widgets/plan_option_card.dart';

class SelectPlanScreen extends StatefulWidget {
  const SelectPlanScreen({super.key});

  @override
  State<SelectPlanScreen> createState() => _SelectPlanScreenState();
}

class _SelectPlanScreenState extends State<SelectPlanScreen> with WidgetsBindingObserver {
  final OnboardingController onboardingController = Get.find<OnboardingController>();
  final AuthController authController = Get.find<AuthController>();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _awaitingCheckoutReturn) {
      _syncAfterCheckoutReturn();
    }
  }

  Future<void> _loadPlans() async {
    if (authController.token != null) {
      await onboardingController.fetchPlans(authController.token!);
    }
  }

  bool _isSaving = false;
  bool _awaitingCheckoutReturn = false;
  String _billingCycle = 'monthly';
  BillingStatusSnapshot? _billingSnapshotBeforeCheckout;

  Future<void> _syncAfterCheckoutReturn() async {
    final token = authController.token;
    if (token == null) return;
    final before = _billingSnapshotBeforeCheckout;
    await authController.fetchUserProfile();
    try {
      final status = await _apiService.getBillingStatus(token);
      if (!mounted) return;
      setState(() {
        _awaitingCheckoutReturn = false;
        _billingSnapshotBeforeCheckout = null;
      });

      final selected = onboardingController.selectedPlan.value;
      if (before == null || selected == null) {
        return;
      }

      BillingStatusModel? effective = status;
      var afterSnap = BillingStatusSnapshot.fromModel(effective);
      if (before.matches(afterSnap)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        effective = await _apiService.getBillingStatus(token);
        afterSnap = BillingStatusSnapshot.fromModel(effective);
      }
      if (before.matches(afterSnap)) {
        ToastHelper.showInfo('Checkout canceled. Your plan was not changed.');
        return;
      }

      if (effective != null &&
          effective.isActive &&
          selected.id == effective.membershipId) {
        Get.toNamed('/setup-permissions');
        return;
      }

      ToastHelper.showInfo(
        'If you completed payment, your plan may take a moment to activate.',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _awaitingCheckoutReturn = false;
          _billingSnapshotBeforeCheckout = null;
        });
        ToastHelper.showInfo('Could not verify billing yet — try again shortly.');
      }
    }
  }

  Future<void> _handleContinue() async {
    final selected = onboardingController.selectedPlan.value;
    if (selected == null) {
      ToastHelper.showError('Please select a plan');
      return;
    }
    if (!selected.availableForPurchase) {
      ToastHelper.showError('This plan is not available for purchase');
      return;
    }
    if (authController.token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    if (selected.isFree) {
      setState(() => _isSaving = true);
      final success = await onboardingController.subscribeMembershipToApi(authController.token!);
      setState(() => _isSaving = false);
      if (success) {
        Get.toNamed('/setup-permissions');
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

      BillingStatusSnapshot snapshotBefore;
      try {
        final prior = await _apiService.getBillingStatus(authController.token!);
        snapshotBefore = BillingStatusSnapshot.fromModel(prior);
      } catch (_) {
        snapshotBefore = const BillingStatusSnapshot();
      }

      await onboardingController.openStripeCheckoutForSelectedPlan(
        token: authController.token!,
        planType: _billingCycle,
        affiliateCode: affiliateCode,
      );
      setState(() {
        _isSaving = false;
        _awaitingCheckoutReturn = true;
        _billingSnapshotBeforeCheckout = snapshotBefore;
      });
      ToastHelper.showInfo('Complete payment in the browser, then return to Proxi.');
    } catch (e) {
      setState(() => _isSaving = false);
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
    }
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
                        'Choose Your Plan',
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
                        if (onboardingController.isLoading.value) {
                          return const SizedBox.shrink();
                        }
                        final plans = onboardingController.availablePlans;
                        if (plans.isEmpty || !plans.any((p) => !p.isFree)) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'monthly', label: Text('Monthly')),
                                ButtonSegment(value: 'yearly', label: Text('Yearly')),
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
                        if (onboardingController.isLoading.value) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: CircularProgressIndicator(color: cs.primary),
                            ),
                          );
                        }

                        if (onboardingController.availablePlans.isEmpty) {
                          return Center(
                            child: Text(
                              'No plans available',
                              style: TextStyle(color: cs.onSurface),
                            ),
                          );
                        }

                        return Column(
                          children: onboardingController.availablePlans.map((plan) {
                            final isSelected = onboardingController.selectedPlan.value?.id == plan.id;
                            return PlanOptionCard(
                              plan: plan,
                              isSelected: isSelected,
                              billingCycle: _billingCycle,
                              onTap: plan.availableForPurchase
                                  ? () => onboardingController.selectPlan(plan)
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
                padding: const EdgeInsets.all(20.0),
                child: Obx(() {
                  final selectedPlan = onboardingController.selectedPlan.value;
                  final canContinue = selectedPlan != null &&
                      selectedPlan.availableForPurchase &&
                      !_isSaving &&
                      !_awaitingCheckoutReturn;
                  String buttonText;
                  if (_isSaving) {
                    buttonText = 'Please wait...';
                  } else if (selectedPlan != null && selectedPlan.isFree) {
                    buttonText = 'Continue with Free';
                  } else {
                    buttonText = 'Continue to secure checkout';
                  }
                  return CustomButton(
                    text: buttonText,
                    isEnabled: canContinue,
                    onPressed: _handleContinue,
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
