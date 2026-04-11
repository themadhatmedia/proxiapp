import 'package:flutter/material.dart';

import '../config/theme/proxi_palette.dart';
import '../data/models/plan_model.dart';

/// Plan row used on onboarding and upgrade flows.
class PlanOptionCard extends StatelessWidget {
  final PlanModel plan;
  final bool isSelected;
  final VoidCallback? onTap;

  const PlanOptionCard({
    super.key,
    required this.plan,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final comingSoon = plan.isComingSoonPlan;
    final effectiveOnTap = comingSoon ? null : onTap;

    final priceLabel = plan.isFree ? 'Free' : plan.displayPrice.split(' ').first;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected ? cs.primary : context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? cs.primary : cs.outline.withOpacity(0.45),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ),
              Text(
                priceLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.description,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? cs.onPrimary.withOpacity(0.85) : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            plan.displayLimits,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? cs.onPrimary.withOpacity(0.95) : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          GestureDetector(
            onTap: effectiveOnTap,
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: comingSoon ? 0.48 : 1,
              child: card,
            ),
          ),
          if (comingSoon)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.black.withOpacity(0.38),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outline.withOpacity(0.4)),
                      ),
                      child: Text(
                        'Coming in 2027',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
