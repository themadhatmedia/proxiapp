import 'package:flutter/material.dart';

/// Optional affiliate code entry for Stripe checkout (paid plans only).
class OptionalAffiliateCodeField extends StatelessWidget {
  const OptionalAffiliateCodeField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.card_giftcard_outlined, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Affiliate code (optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter affiliate code',
            hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.65),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
