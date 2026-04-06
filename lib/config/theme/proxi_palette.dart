import 'package:flutter/material.dart';

/// Client brand colors + theme-specific UI tokens (cards, tabs, nav).
@immutable
class ProxiPalette extends ThemeExtension<ProxiPalette> {
  const ProxiPalette({
    required this.scaffoldGradientTop,
    required this.scaffoldGradientBottom,
    required this.surfaceCard,
    required this.speedDialLabelBackground,
    required this.bottomNavBackground,
    required this.tabBarTrack,
    required this.tabIndicator,
    required this.tabLabelSelected,
    required this.tabLabelUnselected,
    required this.overlayScrim,
  });

  final Color scaffoldGradientTop;
  final Color scaffoldGradientBottom;
  final Color surfaceCard;
  final Color speedDialLabelBackground;
  final Color bottomNavBackground;
  final Color tabBarTrack;
  final Color tabIndicator;
  final Color tabLabelSelected;
  final Color tabLabelUnselected;
  final Color overlayScrim;

  /// Electric Blue #3A86FF
  static const Color electricBlue = Color(0xFF3A86FF);

  /// Deep Indigo #1E2A78
  static const Color deepIndigo = Color(0xFF1E2A78);

  /// Vibrant Purple #8338EC
  static const Color vibrantPurple = Color(0xFF8338EC);

  /// Soft Lavender #E0BBFF
  static const Color softLavender = Color(0xFFE0BBFF);

  /// Sky Blue #A0C4FF
  static const Color skyBlue = Color(0xFFA0C4FF);

  /// Pure White #FFFFFF
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Filled / saved bookmark (icons, speed-dial entry).
  static const Color bookmarkSaved = Color(0xFF43A047);

  /// Outline “add bookmark” icon; also destructive remove actions in bookmark flows.
  static const Color bookmarkAccent = Color(0xFFE53935);

  /// Cool Light Gray #F5F7FB
  static const Color coolLightGray = Color(0xFFF5F7FB);

  static const ProxiPalette light = ProxiPalette(
    scaffoldGradientTop: pureWhite,
    scaffoldGradientBottom: coolLightGray,
    surfaceCard: Color(0xFFF3EDFC),
    speedDialLabelBackground: Color(0xFFE8E4F5),
    bottomNavBackground: deepIndigo,
    tabBarTrack: Color(0x1A3A86FF),
    tabIndicator: Color(0x333A86FF),
    tabLabelSelected: deepIndigo,
    tabLabelUnselected: Color(0xFF5C6B9E),
    overlayScrim: Color(0x80000000),
  );

  static const ProxiPalette dark = ProxiPalette(
    scaffoldGradientTop: Color(0xFF12152E),
    scaffoldGradientBottom: Color(0xFF1E2A78),
    surfaceCard: Color(0xFF252E5C),
    speedDialLabelBackground: Color(0xFF2D3768),
    bottomNavBackground: Color(0xFF0F1433),
    tabBarTrack: Color(0x26FFFFFF),
    tabIndicator: Color(0x40FFFFFF),
    tabLabelSelected: pureWhite,
    tabLabelUnselected: Color(0xB3FFFFFF),
    overlayScrim: Color(0x80000000),
  );

  @override
  ProxiPalette copyWith({
    Color? scaffoldGradientTop,
    Color? scaffoldGradientBottom,
    Color? surfaceCard,
    Color? speedDialLabelBackground,
    Color? bottomNavBackground,
    Color? tabBarTrack,
    Color? tabIndicator,
    Color? tabLabelSelected,
    Color? tabLabelUnselected,
    Color? overlayScrim,
  }) {
    return ProxiPalette(
      scaffoldGradientTop: scaffoldGradientTop ?? this.scaffoldGradientTop,
      scaffoldGradientBottom: scaffoldGradientBottom ?? this.scaffoldGradientBottom,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      speedDialLabelBackground: speedDialLabelBackground ?? this.speedDialLabelBackground,
      bottomNavBackground: bottomNavBackground ?? this.bottomNavBackground,
      tabBarTrack: tabBarTrack ?? this.tabBarTrack,
      tabIndicator: tabIndicator ?? this.tabIndicator,
      tabLabelSelected: tabLabelSelected ?? this.tabLabelSelected,
      tabLabelUnselected: tabLabelUnselected ?? this.tabLabelUnselected,
      overlayScrim: overlayScrim ?? this.overlayScrim,
    );
  }

  @override
  ProxiPalette lerp(ThemeExtension<ProxiPalette>? other, double t) {
    if (other is! ProxiPalette) return this;
    return ProxiPalette(
      scaffoldGradientTop: Color.lerp(scaffoldGradientTop, other.scaffoldGradientTop, t)!,
      scaffoldGradientBottom: Color.lerp(scaffoldGradientBottom, other.scaffoldGradientBottom, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      speedDialLabelBackground:
          Color.lerp(speedDialLabelBackground, other.speedDialLabelBackground, t)!,
      bottomNavBackground: Color.lerp(bottomNavBackground, other.bottomNavBackground, t)!,
      tabBarTrack: Color.lerp(tabBarTrack, other.tabBarTrack, t)!,
      tabIndicator: Color.lerp(tabIndicator, other.tabIndicator, t)!,
      tabLabelSelected: Color.lerp(tabLabelSelected, other.tabLabelSelected, t)!,
      tabLabelUnselected: Color.lerp(tabLabelUnselected, other.tabLabelUnselected, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
    );
  }
}

extension ProxiPaletteContext on BuildContext {
  ProxiPalette get proxi =>
      Theme.of(this).extension<ProxiPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? ProxiPalette.dark : ProxiPalette.light);
}
