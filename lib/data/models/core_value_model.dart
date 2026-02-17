class CoreValueModel {
  final int id;
  final String name;
  final String? icon;

  CoreValueModel({
    required this.id,
    required this.name,
    this.icon,
  });

  factory CoreValueModel.fromJson(Map<String, dynamic> json) {
    return CoreValueModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }
}
