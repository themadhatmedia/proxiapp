import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_theme.dart';
import '../../controllers/profile_controller.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/custom_button.dart';

class EditSocialLinksScreen extends StatefulWidget {
  const EditSocialLinksScreen({super.key});

  @override
  State<EditSocialLinksScreen> createState() => _EditSocialLinksScreenState();
}

class _EditSocialLinksScreenState extends State<EditSocialLinksScreen> {
  final ProfileController controller = Get.find<ProfileController>();
  final TextEditingController affiliateCodeController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController xController = TextEditingController();
  final TextEditingController snapchatController = TextEditingController();
  final TextEditingController tiktokController = TextEditingController();
  final TextEditingController otherController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      await controller.loadSocialLinks();
      if (!mounted) return;
      affiliateCodeController.text = controller.affiliateCode.value;
      linkedinController.text = controller.linkedinUrl.value;
      facebookController.text = controller.facebookUrl.value;
      instagramController.text = controller.instagramUrl.value;
      xController.text = controller.xUrl.value;
      snapchatController.text = controller.snapchatUrl.value;
      tiktokController.text = controller.tiktokUrl.value;
      otherController.text = controller.otherUrl.value;
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    affiliateCodeController.dispose();
    linkedinController.dispose();
    facebookController.dispose();
    instagramController.dispose();
    xController.dispose();
    snapchatController.dispose();
    tiktokController.dispose();
    otherController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value, String platform) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final urlPattern = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
      caseSensitive: false,
    );

    if (!urlPattern.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      controller.linkedinUrl.value = linkedinController.text.trim();
      controller.facebookUrl.value = facebookController.text.trim();
      controller.instagramUrl.value = instagramController.text.trim();
      controller.xUrl.value = xController.text.trim();
      controller.snapchatUrl.value = snapchatController.text.trim();
      controller.tiktokUrl.value = tiktokController.text.trim();
      controller.otherUrl.value = otherController.text.trim();

      final success = await controller.saveSocialLinks();
      if (success) {
        Get.back();
      }
    }
  }

  String _affiliateShareMessage(String code) {
    return 'I\'m on Proxi and wanted to share my affiliate code with you. '
        'When you sign up for a membership plan, enter this code during checkout.\n\n'
        'Affiliate code: $code';
  }

  Future<void> _copyAndShareAffiliateCode() async {
    final code = affiliateCodeController.text.trim();
    if (code.isEmpty) {
      ToastHelper.showInfo('No affiliate code to share');
      return;
    }
    final message = _affiliateShareMessage(code);
    await Clipboard.setData(ClipboardData(text: message));
    await Share.share(
      message,
      subject: 'Proxi affiliate code',
    );
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
                        'Social & Service Links',
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
                child: _isLoadingData
                    ? Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add your social media profiles to connect with others',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildReadOnlyAffiliateCodeField(),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: linkedinController,
                          label: 'LinkedIn',
                          hint: 'https://linkedin.com/in/yourprofile',
                          icon: Icons.business,
                        ),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: facebookController,
                          label: 'Facebook',
                          hint: 'https://facebook.com/yourprofile',
                          icon: Icons.facebook,
                        ),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: instagramController,
                          label: 'Instagram',
                          hint: 'https://instagram.com/yourprofile',
                          icon: Icons.camera_alt,
                        ),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: xController,
                          label: 'X (Twitter)',
                          hint: 'https://x.com/yourprofile',
                          icon: Icons.tag,
                        ),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: snapchatController,
                          label: 'Snapchat',
                          hint: 'https://snapchat.com/add/yourprofile',
                          icon: Icons.camera,
                        ),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: tiktokController,
                          label: 'TikTok',
                          hint: 'https://tiktok.com/@yourprofile',
                          icon: Icons.music_note,
                        ),
                        const SizedBox(height: 20),
                        _buildSocialLinkField(
                          controller: otherController,
                          label: 'Other',
                          hint: 'https://yourwebsite.com',
                          icon: Icons.link,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isLoadingData)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Obx(
                    () => CustomButton(
                      text: controller.isLoading.value ? 'Saving...' : 'Save',
                      isEnabled: !controller.isLoading.value,
                      onPressed: _handleSave,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyAffiliateCodeField() {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final hasCode = affiliateCodeController.text.trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Affiliate Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: affiliateCodeController,
              readOnly: true,
              enableInteractiveSelection: true,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'No affiliate code assigned',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: hasCode
                    ? IconButton(
                        tooltip: 'Copy and share',
                        onPressed: _copyAndShareAffiliateCode,
                        icon: Icon(Icons.copy_outlined, color: cs.primary),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialLinkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              textCapitalization: TextCapitalization.none,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.8)),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) => _validateUrl(value, label),
              keyboardType: TextInputType.url,
            ),
          ],
        );
      },
    );
  }
}
