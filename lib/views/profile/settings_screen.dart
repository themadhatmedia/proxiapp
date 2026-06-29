import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../config/theme/theme_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import 'edit_basic_profile_screen.dart';
import 'edit_social_links_screen.dart';
import 'upgrade_plan_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ThemeController themeController = Get.find<ThemeController>();
  final ApiService apiService = ApiService();
  bool restrictDm = false;

  @override
  void initState() {
    super.initState();
    final user = authController.currentUser.value;
    if (user?.profile != null) {
      restrictDm = user!.profile!.restrictDm ?? false;
    }
  }

  Future<void> _updateRestrictDm(bool value) async {
    await ProgressDialogHelper.show(context);

    try {
      final token = authController.token;
      if (token == null) {
        ToastHelper.showError('Authentication required');
        await ProgressDialogHelper.hide();
        return;
      }

      final updatedUser = await apiService.updateProfile(
        token: token,
        restrictDm: value,
      );

      authController.updateUser(updatedUser);

      setState(() {
        restrictDm = value;
      });

      await ProgressDialogHelper.hide();
      ToastHelper.showSuccess('Privacy settings updated');
    } catch (e) {
      await ProgressDialogHelper.hide();
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    }
  }

  /// GDPR data export: POST to start, poll GET until `completed`, then open the
  /// public download link in the browser.
  Future<void> _downloadMyData() async {
    final token = authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    final progress = ValueNotifier<Map<String, dynamic>>(<String, dynamic>{
      'status': 'pending',
      'message': 'Starting your data export...',
      'progress': 0,
      'step': 'Queued',
    });

    bool dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ExportProgressDialog(progress: progress),
      ).then((_) => dialogOpen = false),
    );

    void closeDialog() {
      if (dialogOpen && mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
    }

    try {
      final started = await apiService.requestDataExport(token);
      progress.value = started;

      String status = (started['status'] ?? '').toString();
      String? downloadUrl = started['download_url'] as String?;

      const pollInterval = Duration(seconds: 4);
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      const terminal = {'completed', 'expired', 'failed', 'error', 'none'};

      while (!terminal.contains(status) && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
        if (!mounted) return;
        final statusResp = await apiService.getDataExportStatus(token);
        progress.value = statusResp;
        status = (statusResp['status'] ?? '').toString();
        downloadUrl = statusResp['download_url'] as String?;
      }

      closeDialog();
      if (!mounted) return;

      if (status == 'completed' && downloadUrl != null && downloadUrl.isNotEmpty) {
        final launched = await launchUrl(
          Uri.parse(downloadUrl),
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          ToastHelper.showSuccess('Opening your data download...');
        } else {
          ToastHelper.showError('Could not open the download link');
        }
      } else if (status == 'expired' || status == 'none') {
        ToastHelper.showError('Export link unavailable. Please try again.');
      } else {
        ToastHelper.showInfo(
          'Your export is still being prepared. Please try again in a few minutes.',
        );
      }
    } catch (e) {
      closeDialog();
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(msg);
    } finally {
      progress.dispose();
    }
  }

  /// Soft-delete the account: confirm with password, call the API behind a
  /// loader, then sign out (server has revoked all tokens).
  Future<void> _deleteMyAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty) return;
    if (!mounted) return;

    final token = authController.token;
    if (token == null) {
      ToastHelper.showError('Authentication required');
      return;
    }

    await ProgressDialogHelper.show(context);
    try {
      final result = await apiService.deleteAccount(
        token: token,
        password: password,
      );
      await ProgressDialogHelper.hide();

      final msg = (result['message'] ?? '').toString();
      ToastHelper.showSuccess(
        msg.isNotEmpty ? msg : 'Your account has been temporarily deleted.',
      );

      // Tokens are revoked server-side; clear local session and route to /auth.
      await authController.logout();
    } catch (e) {
      await ProgressDialogHelper.hide();
      ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
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
                      icon: Icon(
                        Icons.arrow_back,
                        color: cs.onSurface,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Settings',
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preference',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dark mode',
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Turn off to use light theme',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: themeController.isDarkMode,
                                onChanged: (_) => themeController.toggleTheme(),
                                activeThumbColor: ProxiPalette.electricBlue,
                                activeTrackColor:
                                    ProxiPalette.electricBlue.withOpacity(0.45),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Privacy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Restrict DMs from the opposite gender',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Only receive messages from same gender',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: restrictDm,
                              onChanged: _updateRestrictDm,
                              activeThumbColor: ProxiPalette.electricBlue,
                              activeTrackColor: ProxiPalette.electricBlue.withOpacity(0.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Get.to(() => const EditBasicProfileScreen()),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Get.to(() => const EditSocialLinksScreen()),
                          icon: const Icon(Icons.link),
                          label: const Text('Social & Service Links'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Subscription',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Get.to(() => const UpgradePlanScreen()),
                          icon: const Icon(Icons.arrow_upward),
                          label: const Text('Upgrade Subscription'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Your Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _downloadMyData,
                          icon: const Icon(Icons.download),
                          label: const Text('Download My Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _deleteMyAccount,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete My Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProxiPalette.bookmarkAccent,
                            foregroundColor: ProxiPalette.pureWhite,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

/// Confirmation dialog for account deletion. Requires the current password and
/// returns it via `Navigator.pop` when confirmed.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _confirm() {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    Navigator.pop(context, pwd);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Delete my account',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This temporarily deletes your account and signs you out of all '
            'devices. Your data is kept during a retention period and then '
            'permanently removed. You can request to restore it by logging in '
            'again before then.\n\nEnter your password to confirm.',
            style: TextStyle(fontSize: 14, height: 1.4, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Password',
              errorText: _error,
              filled: true,
              fillColor: cs.surface.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _confirm(),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: ProxiPalette.bookmarkAccent,
            foregroundColor: ProxiPalette.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Live progress dialog for the data export. Rebuilds from [progress] as each
/// poll updates the status / step / percentage.
class _ExportProgressDialog extends StatelessWidget {
  const _ExportProgressDialog({required this.progress});

  final ValueNotifier<Map<String, dynamic>> progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: progress,
          builder: (context, data, _) {
            final status = (data['status'] ?? '').toString();
            final step = (data['step'] ?? '').toString();
            final message =
                (data['message'] ?? 'Preparing your data...').toString();

            final rawProgress = data['progress'];
            double? fraction;
            if (rawProgress is num) {
              final p = rawProgress.toDouble();
              fraction = (p < 0 ? 0.0 : (p > 100 ? 100.0 : p)) / 100.0;
            }
            final showPct =
                fraction != null && fraction > 0 && status == 'processing';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: showPct ? fraction : null,
                          strokeWidth: 5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cs.primary),
                          backgroundColor: cs.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      if (showPct)
                        Text(
                          '${(fraction * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Preparing your data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.isNotEmpty ? step : message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  'This may take a moment. Please keep the app open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
