import 'billing_status_model.dart';

/// Immutable fingerprint of [BillingStatusModel] for before/after checkout comparison.
/// If before and after match, the user almost certainly did not complete a new payment.
class BillingStatusSnapshot {
  const BillingStatusSnapshot({
    this.statusNorm,
    this.membershipId,
    this.planTypeNorm,
    this.expiresMs,
  });

  final String? statusNorm;
  final int? membershipId;
  final String? planTypeNorm;
  final int? expiresMs;

  factory BillingStatusSnapshot.fromModel(BillingStatusModel? m) {
    if (m == null) {
      return const BillingStatusSnapshot();
    }
    return BillingStatusSnapshot(
      statusNorm: m.status?.toLowerCase().trim(),
      membershipId: m.membershipId,
      planTypeNorm: m.planType?.toLowerCase().trim(),
      expiresMs: m.expiresAt?.millisecondsSinceEpoch,
    );
  }

  bool matches(BillingStatusSnapshot other) =>
      statusNorm == other.statusNorm &&
      membershipId == other.membershipId &&
      planTypeNorm == other.planTypeNorm &&
      expiresMs == other.expiresMs;
}
