import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/profile_controller.dart';
import '../../widgets/custom_button.dart';

class EditSocialLinksScreen extends StatefulWidget {
  const EditSocialLinksScreen({super.key});

  @override
  State<EditSocialLinksScreen> createState() => _EditSocialLinksScreenState();
}

class _EditSocialLinksScreenState extends State<EditSocialLinksScreen> {
  final ProfileController controller = Get.find<ProfileController>();
  final TextEditingController linkedinController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController xController = TextEditingController();
  final TextEditingController snapchatController = TextEditingController();
  final TextEditingController tiktokController = TextEditingController();
  final TextEditingController otherController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await controller.loadSocialLinks();
    linkedinController.text = controller.linkedinUrl.value;
    facebookController.text = controller.facebookUrl.value;
    instagramController.text = controller.instagramUrl.value;
    xController.text = controller.xUrl.value;
    snapchatController.text = controller.snapchatUrl.value;
    tiktokController.text = controller.tiktokUrl.value;
    otherController.text = controller.otherUrl.value;
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF0A0A0A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Social & Service Links',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Add your social media profiles to connect with others',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 32),
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Obx(
                  () => CustomButton(
                    text: controller.isLoading.value ? 'Saving...' : 'Save',
                    onPressed: controller.isLoading.value ? () {} : _handleSave,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.2),
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
  }
}
