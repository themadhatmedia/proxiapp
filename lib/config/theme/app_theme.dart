import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryAccent = Color(0xFFFFFFFF);
  static const Color secondaryAccent = Color(0xFFE5E5E5);
  static const Color darkAccent = Color(0xFF333333);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryAccent,
    scaffoldBackgroundColor: Colors.black,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      secondary: secondaryAccent,
      surface: Colors.black,
      background: Colors.black,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: primaryAccent,
      selectionColor: Color(0x33FFFFFF),
      selectionHandleColor: primaryAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    // cardTheme: const CardTheme(
    //   color: Color(0xFF1A1A1A),
    //   elevation: 2,
    // ),
    // dialogTheme: const DialogTheme(
    //   backgroundColor: Color(0xFF1A1A1A),
    // ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
      selectedItemColor: primaryAccent,
      unselectedItemColor: Colors.grey,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryAccent,
    scaffoldBackgroundColor: Colors.black,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      secondary: secondaryAccent,
      surface: Colors.black,
      background: Colors.black,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: primaryAccent,
      selectionColor: Color(0x33FFFFFF),
      selectionHandleColor: primaryAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    // cardTheme: const CardTheme(
    //   color: Color(0xFF1A1A1A),
    //   elevation: 2,
    // ),
    // dialogTheme: const DialogTheme(
    //   backgroundColor: Color(0xFF1A1A1A),
    // ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
      selectedItemColor: primaryAccent,
      unselectedItemColor: Colors.grey,
    ),
  );

  static LinearGradient getGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black,
        const Color(0xFF0A0A0A),
      ],
    );
  }
}
