import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

/// Prominent disclosure shown before any background location permission request.
/// Required by Google Play — must not be buried in privacy policy or settings.
class BackgroundLocationDisclosureScreen extends StatelessWidget {
  const BackgroundLocationDisclosureScreen({super.key});

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(result: false),
                      icon: Icon(Icons.close, color: cs.onSurface),
                    ),
                    Expanded(
                      child: Text(
                        'Location disclosure',
                        style: TextStyle(
                          fontSize: 20,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.location_on_outlined, size: 56, color: cs.primary),
                      const SizedBox(height: 20),
                      Text(
                        'How Proxi uses your location',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please read this before continuing. You must accept to enable background location.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _DisclosureBlock(
                        icon: Icons.my_location_outlined,
                        title: 'We collect your location',
                        body:
                            'Proxi collects your device\'s location to power proximity features in the app.',
                      ),
                      const SizedBox(height: 16),
                      _DisclosureBlock(
                        icon: Icons.nightlight_round_outlined,
                        title: 'Background access',
                        body:
                            'We access your location in the background — including when the app is closed or not in use.',
                      ),
                      const SizedBox(height: 16),
                      _DisclosureBlock(
                        icon: Icons.radar_outlined,
                        title: 'Pulse proximity',
                        body:
                            'This powers Pulse: finding people nearby, proximity alerts, and keeping your map up to date.',
                      ),
                      const SizedBox(height: 16),
                      _DisclosureBlock(
                        icon: Icons.info_outline,
                        title: 'Why background access is needed',
                        body:
                            'Background location lets Proxi refresh nearby contacts and send proximity alerts when you move, even if you are not actively using the app. Without it, Pulse cannot stay accurate when Proxi is in the background.',
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'On Android you will first allow location while using the app, then separately choose Allow all the time. On iPhone, choose Always Allow on the second prompt.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      text: 'I understand & accept',
                      onPressed: () => Get.back(result: true),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: Text(
                        'Not now',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclosureBlock extends StatelessWidget {
  const _DisclosureBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
