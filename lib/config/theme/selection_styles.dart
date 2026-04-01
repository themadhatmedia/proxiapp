import 'package:flutter/material.dart';

/// Shared chip styles for interest / core value pickers (light & dark).
class SelectionStyles {
  static BoxDecoration chipBox(BuildContext context, bool selected) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: selected ? cs.primary : cs.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: selected ? cs.primary : cs.outline.withOpacity(0.45),
        width: 2,
      ),
    );
  }

  static TextStyle chipLabel(BuildContext context, bool selected) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: selected ? cs.onPrimary : cs.onSurface,
    );
  }
}
