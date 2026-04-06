import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';

import '../config/theme/proxi_palette.dart';

/// Opens native crop UI (square / circle overlay) for profile photos.
/// Returns `null` if the user cancels.
Future<File?> cropProfileAvatarFile(String sourcePath, {BuildContext? context}) async {
  final ctx = context ?? Get.context;
  final brightness = ctx != null ? Theme.of(ctx).brightness : Brightness.dark;
  final isLight = brightness == Brightness.light;

  final toolbarColor = isLight ? ProxiPalette.deepIndigo : const Color(0xFF252E5C);
  const toolbarFg = ProxiPalette.pureWhite;
  final dimColor = Colors.black.withOpacity(0.72);

  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    maxWidth: 1024,
    maxHeight: 1024,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Adjust photo',
        toolbarColor: toolbarColor,
        toolbarWidgetColor: toolbarFg,
        backgroundColor: isLight ? ProxiPalette.coolLightGray : const Color(0xFF12152E),
        activeControlsWidgetColor: ProxiPalette.electricBlue,
        dimmedLayerColor: dimColor,
        cropFrameColor: ProxiPalette.electricBlue,
        cropGridColor: ProxiPalette.pureWhite.withOpacity(0.35),
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
        cropStyle: CropStyle.circle,
      ),
      IOSUiSettings(
        title: 'Adjust photo',
        doneButtonTitle: 'Done',
        cancelButtonTitle: 'Cancel',
        // Without a visible navigation bar, Done/Cancel can be missing or clipped on iOS
        // (especially with circle crop / safe areas). Embed and show the bar explicitly.
        embedInNavigationController: true,
        hidesNavigationBar: false,
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        rotateButtonsHidden: false,
        cropStyle: CropStyle.circle,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
      if (kIsWeb && ctx != null && ctx.mounted) WebUiSettings(context: ctx),
    ],
  );

  if (cropped == null) return null;
  return File(cropped.path);
}
