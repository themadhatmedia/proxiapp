import 'package:flutter/material.dart';

enum IosPaymentMethod { inAppPurchase, stripe }

/// iOS-only: choose between App Store In-App Purchase and Stripe checkout.
Future<IosPaymentMethod?> showIosPaymentMethodSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  return showModalBottomSheet<IosPaymentMethod>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              'Choose payment method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subscribe through the App Store or continue with Stripe in your browser.',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(sheetContext).pop(IosPaymentMethod.inAppPurchase),
              icon: const Icon(Icons.apple),
              label: const Text('In-App Purchase'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(sheetContext).pop(IosPaymentMethod.stripe),
              icon: const Icon(Icons.credit_card_outlined),
              label: const Text('Stripe Purchase'),
            ),
          ],
        ),
      );
    },
  );
}
