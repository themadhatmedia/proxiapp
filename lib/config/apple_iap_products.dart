import '../data/models/plan_model.dart';

/// App Store subscription product IDs configured in App Store Connect.
class AppleIapProducts {
  AppleIapProducts._();

  static const Set<String> allProductIds = {
    'com.myproxiapp.basic.monthly',
    'com.myproxiapp.basic.yearly',
    'com.myproxiapp.professional.monthly',
    'com.myproxiapp.professional.yearly',
    'com.myproxiapp.elite.monthly',
    'com.myproxiapp.elite.yearly',
    'com.myproxiapp.ambassador.monthly',
    'com.myproxiapp.ambassador.yearly',
    'com.myproxiapp.coach.monthly',
    'com.myproxiapp.coach.yearly',
  };

  static const Map<String, Map<String, String>> _productIdsByTier = {
    'basic': {
      'monthly': 'com.myproxiapp.basic.monthly',
      'yearly': 'com.myproxiapp.basic.yearly',
    },
    'professional': {
      'monthly': 'com.myproxiapp.professional.monthly',
      'yearly': 'com.myproxiapp.professional.yearly',
    },
    'elite': {
      'monthly': 'com.myproxiapp.elite.monthly',
      'yearly': 'com.myproxiapp.elite.yearly',
    },
    'ambassador': {
      'monthly': 'com.myproxiapp.ambassador.monthly',
      'yearly': 'com.myproxiapp.ambassador.yearly',
    },
    'coach': {
      'monthly': 'com.myproxiapp.coach.monthly',
      'yearly': 'com.myproxiapp.coach.yearly',
    },
  };

  /// Resolves the App Store product id for a membership tier and billing cycle.
  static String? productIdForPlan(PlanModel plan, String billingCycle) {
    if (plan.isFree) return null;
    final slug = _slugForPlanName(plan.name);
    if (slug == null) return null;
    final cycle = billingCycle.toLowerCase().trim() == 'yearly' ? 'yearly' : 'monthly';
    return _productIdsByTier[slug]?[cycle];
  }

  static String? _slugForPlanName(String name) {
    final normalized = name.toLowerCase().trim();
    if (normalized.contains('basic')) return 'basic';
    if (normalized.contains('professional') || normalized.contains(' pro')) return 'professional';
    if (normalized.contains('elite')) return 'elite';
    if (normalized.contains('ambassador')) return 'ambassador';
    if (normalized.contains('coach')) return 'coach';
    return null;
  }
}
