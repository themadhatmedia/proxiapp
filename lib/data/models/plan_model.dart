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
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    final features = json['features'] as Map<String, dynamic>? ?? {};
    final priceStr = json['price']?.toString() ?? '0.00';
    final price = double.tryParse(priceStr) ?? 0.0;
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
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      monthlyPrice: price > 0 ? price : null,
      // yearlyPrice: json['yearly_price'] != null ? double.tryParse(json['yearly_price'].toString()) : null,
      yearlyPrice: null,
      innerLimit: json['features']['inner_circle_limit'] ?? 0,
      outerLimit: json['features']['outer_circle_limit'] ?? 0,
      pulsesPerDay: parsedPulses,
      isFree: double.tryParse(json['price'].toString()) == 0.0 ? true : false,
    );
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
    };
  }

  String get displayPrice {
    if (isFree) return 'Free';
    // if (monthlyPrice != null && yearlyPrice != null) {
    //   return '\$${monthlyPrice!.toStringAsFixed(2)}/month or \$${yearlyPrice!.toStringAsFixed(0)}/year';
    // }
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
}
