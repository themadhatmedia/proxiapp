class AmbitionModel {
  final int id;
  final String name;
  final bool isActive;

  AmbitionModel({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory AmbitionModel.fromJson(Map<String, dynamic> json) {
    return AmbitionModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
    );
  }
}
