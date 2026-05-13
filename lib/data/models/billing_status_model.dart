/// Response from `GET /api/v1/billing/status`.
class BillingStatusModel {
  BillingStatusModel({
    required this.success,
    this.status,
    this.planType,
    this.expiresAt,
    this.membershipId,
    this.membershipName,
  });

  final bool success;
  final String? status;
  final String? planType;
  final DateTime? expiresAt;
  final int? membershipId;
  final String? membershipName;

  bool get isActive => status != null && status!.toLowerCase() == 'active';

  factory BillingStatusModel.fromJson(Map<String, dynamic> json) {
    final membership = json['membership'];
    int? mid;
    String? mname;
    if (membership is Map<String, dynamic>) {
      mid = membership['id'] is int ? membership['id'] as int : int.tryParse('${membership['id']}');
      mname = membership['name']?.toString();
    }

    final expiresRaw = json['expires_at']?.toString();
    DateTime? expires;
    if (expiresRaw != null && expiresRaw.isNotEmpty) {
      expires = DateTime.tryParse(expiresRaw);
    }

    return BillingStatusModel(
      success: json['success'] == true,
      status: json['status']?.toString(),
      planType: json['plan_type']?.toString(),
      expiresAt: expires,
      membershipId: mid,
      membershipName: mname,
    );
  }
}
