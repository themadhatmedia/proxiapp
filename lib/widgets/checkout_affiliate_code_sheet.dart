import 'package:flutter/material.dart';

import 'optional_affiliate_code_field.dart';

/// Prompts for an optional affiliate code before Stripe checkout.
/// Returns trimmed code (may be empty), or `null` if the user dismissed the sheet.
Future<String?> showCheckoutAffiliateCodeSheet(BuildContext context) {
  final controller = TextEditingController();
  final cs = Theme.of(context).colorScheme;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Before checkout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an affiliate code if you have one. You can leave it blank and continue.',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OptionalAffiliateCodeField(controller: controller),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('Continue to secure checkout'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(''),
              child: const Text('Skip'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
