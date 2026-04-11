import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final VoidCallback? onToggleVisibility;
  final bool? isPassword;
  /// When null, uses [defaultTextCapitalization] from other props.
  final TextCapitalization? textCapitalization;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.onToggleVisibility,
    this.isPassword = false,
    this.textCapitalization,
  });

  static TextCapitalization defaultTextCapitalization({
    required bool obscureText,
    required bool isPassword,
    TextInputType? keyboardType,
  }) {
    if (obscureText || isPassword) return TextCapitalization.none;
    final kt = keyboardType;
    if (kt == TextInputType.emailAddress ||
        kt == TextInputType.url ||
        kt == TextInputType.visiblePassword) {
      return TextCapitalization.none;
    }
    if (kt == TextInputType.phone) return TextCapitalization.none;
    return TextCapitalization.sentences;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withOpacity(0.45),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization ??
            defaultTextCapitalization(
              obscureText: obscureText,
              isPassword: isPassword == true,
              keyboardType: keyboardType,
            ),
        cursorColor: cs.primary,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withOpacity(0.85),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 12.0,
          ),
          suffixIcon: isPassword == true
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: cs.onSurfaceVariant,
                    size: 22.0,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
        ),
      ),
    );
  }
}
