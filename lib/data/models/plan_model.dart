class PlanModel {
  final int id;
  final String name;
  final String description;
  final double? monthlyPrice;
  final double? yearlyPrice;
  final int innerLimit;
  final int outerLimit;
  final int pulsesPerDay;
  final bool isFree;
  final bool isDefault;
  final bool availableForPurchase;

  PlanModel({
    required this.id,
    required this.name,
    required this.description,
    this.monthlyPrice,
    this.yearlyPrice,
    required this.innerLimit,
    required this.outerLimit,
    required this.pulsesPerDay,
    required this.isFree,
    this.isDefault = false,
    this.availableForPurchase = false,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final Map<String, dynamic> features = rawFeatures is Map<String, dynamic>
        ? rawFeatures
        : (rawFeatures is Map ? Map<String, dynamic>.from(rawFeatures) : {});

    final priceStr = json['price']?.toString() ?? '0.00';
    final price = double.tryParse(priceStr) ?? 0.0;
    final yearlyRaw = json['yearly_price'];
    final yearlyParsed = yearlyRaw != null && yearlyRaw.toString().isNotEmpty
        ? double.tryParse(yearlyRaw.toString())
        : null;

    final dailyPulse = features['daily_pulse_limit'];
    int parsedPulses;
    if (dailyPulse is int) {
      parsedPulses = dailyPulse;
    } else if (dailyPulse is String && dailyPulse == 'unlimited') {
      parsedPulses = 999999;
    } else {
      parsedPulses = int.tryParse(dailyPulse?.toString() ?? '0') ?? 0;
    }

    return PlanModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      monthlyPrice: price > 0 ? price : null,
      yearlyPrice: yearlyParsed,
      innerLimit: _intFrom(features['inner_circle_limit']),
      outerLimit: _intFrom(features['outer_circle_limit']),
      pulsesPerDay: parsedPulses,
      isFree: price == 0.0,
      isDefault: json['is_default'] == true,
      availableForPurchase: json['available_for_purchase'] == true,
    );
  }

  static int _intFrom(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Initial highlight for onboarding: prefer default tier if it can be purchased,
  /// otherwise first purchasable plan, otherwise the default row (may be non-selectable).
  static PlanModel? initialSelectionForOnboarding(List<PlanModel> plans) {
    if (plans.isEmpty) return null;
    for (final p in plans) {
      if (p.isDefault && p.availableForPurchase) return p;
    }
    for (final p in plans) {
      if (p.availableForPurchase) return p;
    }
    for (final p in plans) {
      if (p.isDefault) return p;
    }
    return plans.first;
  }

  /// When opening upgrade screen without a resolvable current plan id.
  static PlanModel? initialSelectionForUpgrade(List<PlanModel> plans) {
    return initialSelectionForOnboarding(plans);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'monthly_price': monthlyPrice,
      'yearly_price': yearlyPrice,
      'inner_limit': innerLimit,
      'outer_limit': outerLimit,
      'pulses_per_day': pulsesPerDay,
      'is_free': isFree,
      'is_default': isDefault,
      'available_for_purchase': availableForPurchase,
    };
  }

  String get displayPrice {
    if (isFree) return 'Free';
    if (monthlyPrice != null && yearlyPrice != null) {
      return '\$${monthlyPrice!.toStringAsFixed(2)}/mo · \$${yearlyPrice!.toStringAsFixed(0)}/yr';
    }
    if (monthlyPrice != null) {
      return '\$${monthlyPrice!.toStringAsFixed(2)}/month';
    }
    return 'Free';
  }

  String get displayLimits {
    String limits = '$innerLimit inner, $outerLimit outer';
    if (pulsesPerDay > 0) {
      if (pulsesPerDay == 999999) {
        limits += ', unlimited pulses per day';
      } else {
        limits += ', $pulsesPerDay pulse${pulsesPerDay > 1 ? 's' : ''} per day';
      }
    }
    return limits;
  }

  /// Ambassador and Coach tiers use legacy "Coming in 2027" messaging on plan cards.
  bool get isAmbassadorOrCoachTier {
    final n = name.toLowerCase().trim();
    if (n.contains('ambassador')) return true;
    final words = n.split(RegExp(r'\s+'));
    return words.contains('coach');
  }
}
