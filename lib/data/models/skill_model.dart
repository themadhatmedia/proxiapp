class SkillModel {
  final int id;
  final String name;
  final bool isActive;

  SkillModel({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
    );
  }
}
