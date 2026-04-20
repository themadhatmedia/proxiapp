import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

class SetupPermissionsScreen extends StatefulWidget {
  const SetupPermissionsScreen({super.key});

  @override
  State<SetupPermissionsScreen> createState() => _SetupPermissionsScreenState();
}

class _SetupPermissionsScreenState extends State<SetupPermissionsScreen> with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _contactsGranted = false;

  /// iOS: "Allow While Using the App" satisfies [locationWhenInUse] but often not [Permission.location]
  /// (which targets Always). Treat when-in-use, always, and limited as OK.
  static bool _isLocationAuthorized(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final always = await Permission.locationAlways.status;
    final contactsStatus = await Permission.contacts.status;

    if (!mounted) return;
    setState(() {
      // Nearby / proximity while Proxi is not open requires background ("Always") location.
      _locationGranted = _isLocationAuthorized(always);
      _contactsGranted = contactsStatus.isGranted;
    });
  }

  Future<void> _openSettingsGuideDialog({
    required String title,
    required String body,
  }) async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        content: Text(
          body,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Not now',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlwaysAllowEducation() async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Allow location in the background',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        content: Text(
          'Proxi uses your location to send proximity alerts and refresh nearby contacts even when the app is not open.\n\n'
          'On the next system screen, choose Always Allow — not only while using the app — so your location stays up to date.',
          style: TextStyle(fontSize: 14, height: 1.35, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Not now',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    if (_locationGranted) return;

    final whenInUsePre = await Permission.locationWhenInUse.status;

    if (whenInUsePre.isPermanentlyDenied) {
      await _openSettingsGuideDialog(
        title: 'Location is turned off',
        body: 'Please enable location for Proxi in Settings → Privacy → Location.',
      );
      return;
    }

    if (!whenInUsePre.isGranted && !whenInUsePre.isLimited) {
      final status = await Permission.locationWhenInUse.request();
      await _checkPermissions();
      if (!mounted) return;
      if (!status.isGranted && !status.isLimited) {
        if (status.isPermanentlyDenied) {
          await _openSettingsGuideDialog(
            title: 'Location is turned off',
            body: 'Location was blocked. Enable it from Settings.',
          );
        }
        return;
      }
    }

    final alwaysPre = await Permission.locationAlways.status;
    if (alwaysPre.isGranted || alwaysPre.isLimited) {
      await _checkPermissions();
      return;
    }

    if (alwaysPre.isPermanentlyDenied) {
      await _openSettingsGuideDialog(
        title: 'Background location needed',
        body:
            'To update nearby contacts when Proxi is closed, open Settings → Proxi → Location and choose Always (or Allow all the time on Android).',
      );
      return;
    }

    await _showAlwaysAllowEducation();
    if (!mounted) return;

    await Permission.locationAlways.request();
    await _checkPermissions();

    if (!_locationGranted && mounted) {
      final s = await Permission.locationAlways.status;
      if (s.isPermanentlyDenied) {
        await _openSettingsGuideDialog(
          title: 'Background location needed',
          body:
              'Open Settings → Proxi → Location and choose Always so we can refresh your proximity when you move.',
        );
      }
    }
  }

  Future<void> _requestContactsPermission() async {
    if (_contactsGranted) return;

    final pre = await Permission.contacts.status;
    if (pre.isPermanentlyDenied) {
      await _openSettingsGuideDialog(
        title: 'Contacts are turned off',
        body: 'Proxi needs contacts to find friends on the app. Open Settings → Proxi → Contacts and turn them on, then return here.',
      );
      return;
    }

    await Permission.contacts.request();
    await _checkPermissions();

    if (!_contactsGranted && mounted) {
      final s = await Permission.contacts.status;
      if (s.isPermanentlyDenied) {
        await _openSettingsGuideDialog(
          title: 'Contacts are turned off',
          body: 'Contacts were blocked for Proxi. Open Settings → Proxi → Contacts and allow access, then come back.',
        );
      } else {
        await _openSettingsGuideDialog(
          title: 'Allow contacts',
          body: 'Contacts are still off for Proxi. Open Settings and enable Contacts for Proxi, then return — Continue unlocks when Location and Contacts are both allowed.',
        );
      }
    }
  }

  bool get _canContinue => _locationGranted && _contactsGranted;

  void _handleContinue() {
    Get.toNamed('/proxi-circles');
  }

  void _onContinuePressed() {
    if (_canContinue) {
      _handleContinue();
    } else {
      ToastHelper.showInfo(
        'Allow Location and Contacts above to continue. If you tapped Don’t Allow before, tap each card and use Open Settings, then return here.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.arrow_back, color: cs.onSurface),
                    ),
                    Expanded(
                      child: Text(
                        'Setup Permissions',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proxi needs these permissions to work properly',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'If you denied access earlier, tap the card and choose Open Settings, turn the permission on for Proxi, then return — we refresh when you come back.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: cs.onSurfaceVariant.withOpacity(0.95),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PermissionCard(
                        icon: Icons.location_on,
                        title: 'Location (Always)',
                        description:
                            'Always Allow — needed for proximity alerts and nearby contacts when the app is closed',
                        isGranted: _locationGranted,
                        onTap: _requestLocationPermission,
                      ),
                      const SizedBox(height: 16),
                      _PermissionCard(
                        icon: Icons.contacts,
                        title: 'Contacts Access',
                        description: 'Always - To find friends who also use Proxi',
                        isGranted: _contactsGranted,
                        onTap: _requestContactsPermission,
                      ),
                      const Spacer(),
                      CustomButton(
                        text: 'Continue',
                        onPressed: _onContinuePressed,
                        backgroundColor: _canContinue ? null : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = context.proxi.surfaceCard;
    // Material + InkWell gives a reliable hit target on iOS; GestureDetector alone
    // can fail when combined with transparent ancestors / Stack backdrops.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // onTap: isGranted ? null : onTap,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isGranted ? Colors.green : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isGranted ? Colors.white : cs.onSurface,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (!isGranted) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap to allow. If you chose Don’t Allow, use Open Settings in the dialog.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: cs.primary.withOpacity(0.95),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isGranted)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
