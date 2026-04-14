class PulseDistanceOptions {
  final String distanceUnit;
  final List<int> distanceOptions;

  const PulseDistanceOptions({
    required this.distanceUnit,
    required this.distanceOptions,
  });

  factory PulseDistanceOptions.fromJson(Map<String, dynamic> json) {
    final raw = json['distance_options'];
    final List<int> options;
    if (raw is List) {
      options = raw
          .map((e) {
            if (e is int) return e;
            return int.tryParse('$e') ?? 0;
          })
          .where((e) => e > 0)
          .toList();
    } else {
      options = [];
    }
    final unit = json['distance_unit']?.toString().trim();
    return PulseDistanceOptions(
      distanceUnit: (unit != null && unit.isNotEmpty) ? unit : 'yards',
      distanceOptions: options,
    );
  }

  /// Default when API is unavailable (matches common backend example).
  static PulseDistanceOptions fallback() {
    return const PulseDistanceOptions(
      distanceUnit: 'yards',
      distanceOptions: [50, 100, 250, 500],
    );
  }
}
