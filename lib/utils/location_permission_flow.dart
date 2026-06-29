import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../views/permissions/background_location_disclosure_screen.dart';

/// Google Play–compliant background location flow:
/// 1. Prominent disclosure screen (explicit Accept)
/// 2. Foreground / while-in-use permission (Android 11+ step 1)
/// 3. Background / Always permission (Android "Allow all the time", iOS Always)
class LocationPermissionFlow {
  LocationPermissionFlow._();

  static const _disclosureAcceptedKey = 'background_location_disclosure_accepted_v1';
  static final GetStorage _box = GetStorage();

  static bool get hasAcceptedDisclosure => _box.read(_disclosureAcceptedKey) == true;

  static Future<void> markDisclosureAccepted() async {
    await _box.write(_disclosureAcceptedKey, true);
  }

  static bool _isAuthorized(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static Future<bool> hasBackgroundLocationAccess() async {
    final always = await Permission.locationAlways.status;
    return _isAuthorized(always);
  }

  static Future<bool> hasForegroundLocationAccess() async {
    final whenInUse = await Permission.locationWhenInUse.status;
    return _isAuthorized(whenInUse);
  }

  /// Returns true when background (Always) location is granted.
  static Future<bool> requestBackgroundLocation(
    BuildContext context, {
    Future<void> Function({
      required String title,
      required String body,
    })? onOpenSettings,
  }) async {
    if (await hasBackgroundLocationAccess()) return true;

    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    if (!hasAcceptedDisclosure) {
      final accepted = await Get.to<bool>(
        () => const BackgroundLocationDisclosureScreen(),
      );
      if (accepted != true) return false;
      await markDisclosureAccepted();
    }

    // Step 1 — foreground / while using the app (Android 11+ requirement).
    final whenInUsePre = await Permission.locationWhenInUse.status;
    if (whenInUsePre.isPermanentlyDenied) {
      await onOpenSettings?.call(
        title: 'Location is turned off',
        body: 'Please enable location for Proxi in Settings → Privacy → Location.',
      );
      return false;
    }

    if (!_isAuthorized(whenInUsePre)) {
      final whenInUse = await Permission.locationWhenInUse.request();
      if (!_isAuthorized(whenInUse)) {
        if (whenInUse.isPermanentlyDenied) {
          await onOpenSettings?.call(
            title: 'Location is turned off',
            body: 'Location was blocked. Enable it from Settings to use Pulse.',
          );
        }
        return false;
      }
    }

    // Step 2 — background / Always (separate system prompt).
    final alwaysPre = await Permission.locationAlways.status;
    if (_isAuthorized(alwaysPre)) return true;

    if (alwaysPre.isPermanentlyDenied) {
      await onOpenSettings?.call(
        title: 'Background location needed',
        body:
            'Open Settings → Proxi → Location and choose Always (or Allow all the time on Android) for Pulse proximity.',
      );
      return false;
    }

    if (context.mounted) {
      await _showBackgroundPermissionEducation(context);
    }

    final always = await Permission.locationAlways.request();
    if (_isAuthorized(always)) return true;

    if (always.isPermanentlyDenied) {
      await onOpenSettings?.call(
        title: 'Background location needed',
        body:
            'Choose Always / Allow all the time in Settings so Pulse can update when the app is closed.',
      );
    }
    return false;
  }

  static Future<void> _showBackgroundPermissionEducation(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Next: allow all the time',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        content: Text(
          'On the next system screen, choose Allow all the time (Android) or Always Allow (iPhone).\n\n'
          'This is required for Pulse proximity when Proxi is closed or not in use.',
          style: TextStyle(fontSize: 14, height: 1.35, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Continue', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }
}
