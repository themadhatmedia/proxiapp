import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'proxi_palette.dart';

class AppTheme {
  static LinearGradient scaffoldGradient(BuildContext context) {
    final p = context.proxi;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [p.scaffoldGradientTop, p.scaffoldGradientBottom],
    );
  }

  /// Used where only a bool is available (e.g. legacy callbacks).
  static LinearGradient getGradient(bool isDark) {
    final p = isDark ? ProxiPalette.dark : ProxiPalette.light;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [p.scaffoldGradientTop, p.scaffoldGradientBottom],
    );
  }

  static SystemUiOverlayStyle systemUiOverlayFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );
  }

  static final ThemeData lightTheme = _buildTheme(brightness: Brightness.light);

  static final ThemeData darkTheme = _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isLight = brightness == Brightness.light;
    final palette = isLight ? ProxiPalette.light : ProxiPalette.dark;

    final colorScheme = isLight
        ? ColorScheme.light(
            primary: ProxiPalette.electricBlue,
            onPrimary: ProxiPalette.pureWhite,
            secondary: ProxiPalette.vibrantPurple,
            onSecondary: ProxiPalette.pureWhite,
            tertiary: ProxiPalette.skyBlue,
            onTertiary: ProxiPalette.deepIndigo,
            surface: ProxiPalette.pureWhite,
            onSurface: ProxiPalette.deepIndigo,
            onSurfaceVariant: const Color(0xFF5C6B9E),
            surfaceContainerHighest: ProxiPalette.coolLightGray,
            error: const Color(0xFFB3261E),
            onError: ProxiPalette.pureWhite,
            outline: ProxiPalette.skyBlue.withOpacity(0.55),
          )
        : ColorScheme.dark(
            primary: ProxiPalette.electricBlue,
            onPrimary: ProxiPalette.pureWhite,
            secondary: ProxiPalette.vibrantPurple,
            onSecondary: ProxiPalette.pureWhite,
            tertiary: ProxiPalette.skyBlue,
            onTertiary: ProxiPalette.deepIndigo,
            surface: const Color(0xFF161C3D),
            onSurface: ProxiPalette.pureWhite,
            onSurfaceVariant: const Color(0xFFB8C0E8),
            surfaceContainerHighest: const Color(0xFF252E5C),
            error: const Color(0xFFF2B8B5),
            onError: const Color(0xFF601410),
            outline: ProxiPalette.skyBlue.withOpacity(0.4),
          );

    final baseText = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onPrimary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.scaffoldGradientTop,
      primaryColor: colorScheme.primary,
      extensions: [palette],
      textTheme: baseText,
      primaryTextTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.scaffoldGradientTop,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.bottomNavBackground,
        selectedItemColor: ProxiPalette.pureWhite,
        unselectedItemColor: ProxiPalette.skyBlue.withOpacity(isLight ? 0.85 : 0.7),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? ProxiPalette.pureWhite : palette.surfaceCard,
      ),
      cardTheme: CardThemeData(
        color: palette.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? ProxiPalette.coolLightGray
            : ProxiPalette.pureWhite.withOpacity(0.08),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withOpacity(0.35),
        selectionHandleColor: colorScheme.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outline.withOpacity(0.35)),
      popupMenuTheme: PopupMenuThemeData(
        color: isLight ? ProxiPalette.pureWhite : palette.surfaceCard,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? ProxiPalette.pureWhite : palette.surfaceCard,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
