import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
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
    final whenInUse = await Permission.locationWhenInUse.status;
    final always = await Permission.locationAlways.status;
    final contactsStatus = await Permission.contacts.status;

    if (!mounted) return;
    setState(() {
      _locationGranted = _isLocationAuthorized(whenInUse) || _isLocationAuthorized(always);
      _contactsGranted = contactsStatus.isGranted;
    });
  }

  Future<void> _requestLocationPermission() async {
    if (_locationGranted) return;
    // Prefer when-in-use so it matches iOS Settings → "While Using the App".
    var status = await Permission.locationWhenInUse.request();
    if (!_isLocationAuthorized(status)) {
      status = await Permission.location.request();
    }
    // if (!mounted) return;
    setState(() {
      _locationGranted = _isLocationAuthorized(status);
    });
    await _checkPermissions();
  }

  Future<void> _requestContactsPermission() async {
    if (_contactsGranted) return;
    final status = await Permission.contacts.request();
    setState(() {
      _contactsGranted = status.isGranted;
    });
  }

  bool get _canContinue => _locationGranted && _contactsGranted;

  void _handleContinue() {
    if (_canContinue) {
      Get.toNamed('/proxi-circles');
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
                      const SizedBox(height: 40),
                      _PermissionCard(
                        icon: Icons.location_on,
                        title: 'Location Access',
                        description: 'While using the app or always — to detect nearby users and proximity alerts',
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
                        onPressed: _canContinue ? _handleContinue : () {},
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
