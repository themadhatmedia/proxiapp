import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/invite_config.dart';
import '../config/theme/proxi_palette.dart';
import '../utils/toast_helper.dart';

/// Bottom-sheet invite prompt. Mirrors the affiliate-share flow: copies the
/// message and opens the native share sheet, while also rendering the
/// "MyProxi" word as a tappable link inside the app.
class InviteFriendsSheet extends StatelessWidget {
  const InviteFriendsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InviteFriendsSheet(),
    );
  }

  Future<void> _openInviteLink() async {
    final uri = Uri.parse(InviteConfig.inviteUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareInvite() async {
    final message = InviteConfig.shareMessage();
    await Clipboard.setData(ClipboardData(text: message));
    await Share.share(message, subject: 'Join me on ${InviteConfig.brandWord}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Icon(Icons.group_add_outlined, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Invite friends',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _InviteMessage(onTapBrand: _openInviteLink),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _shareInvite,
            icon: const Icon(Icons.share, size: 20),
            label: const Text('Share invite'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ProxiPalette.electricBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: InviteConfig.shareMessage()),
              );
              ToastHelper.showSuccess('Invite copied');
            },
            icon: Icon(Icons.copy, size: 18, color: cs.onSurfaceVariant),
            label: Text(
              'Copy message',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [InviteConfig.invitePrompt] with the brand word as a tappable link.
class _InviteMessage extends StatefulWidget {
  const _InviteMessage({required this.onTapBrand});

  final Future<void> Function() onTapBrand;

  @override
  State<_InviteMessage> createState() => _InviteMessageState();
}

class _InviteMessageState extends State<_InviteMessage> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = () => widget.onTapBrand();
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const full = InviteConfig.invitePrompt;
    const brand = InviteConfig.brandWord;
    final start = full.indexOf(brand);

    final base = TextStyle(fontSize: 16, height: 1.45, color: cs.onSurface);

    if (start < 0) {
      return Text(full, textAlign: TextAlign.center, style: base);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: full.substring(0, start)),
          TextSpan(
            text: brand,
            style: const TextStyle(
              color: ProxiPalette.electricBlue,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
            recognizer: _recognizer,
          ),
          TextSpan(text: full.substring(start + brand.length)),
        ],
      ),
    );
  }
}
