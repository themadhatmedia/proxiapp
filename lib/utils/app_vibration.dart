import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Motor / haptic feedback used across the app.
class AppVibration {
  AppVibration._();

  /// Strong feedback for like and bookmark add (not unlike / remove).
  static void interactionSuccess() {
    unawaited(_interactionSuccess());
  }

  /// Double pulse when Pulse search finds at least one nearby user.
  static void pulseUsersFound() {
    unawaited(_pulseUsersFound());
  }

  /// When opening the post likes list (tap on likes count).
  static void likesListOpen() {
    unawaited(_likesListOpen());
  }

  static Future<void> _interactionSuccess() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        final amp = await Vibration.hasAmplitudeControl() == true;
        if (amp) {
          await Vibration.vibrate(duration: 200, amplitude: 255);
        } else {
          await Vibration.vibrate(duration: 260);
        }
      } else {
        await _heavyHapticDouble();
      }
    } catch (_) {
      await _heavyHapticDouble();
    }
  }

  static Future<void> _likesListOpen() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        final amp = await Vibration.hasAmplitudeControl() == true;
        if (amp) {
          await Vibration.vibrate(duration: 110, amplitude: 220);
        } else {
          await Vibration.vibrate(duration: 140);
        }
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> _pulseUsersFound() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        final custom = await Vibration.hasCustomVibrationsSupport() == true;
        if (custom) {
          await Vibration.vibrate(pattern: [0, 160, 100, 200]);
        } else {
          await Vibration.vibrate(duration: 280);
        }
      } else {
        await _heavyHapticDouble(longGap: true);
      }
    } catch (_) {
      await _heavyHapticDouble(longGap: true);
    }
  }

  static Future<void> _heavyHapticDouble({bool longGap = false}) async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(Duration(milliseconds: longGap ? 110 : 45));
    await HapticFeedback.heavyImpact();
  }
}
