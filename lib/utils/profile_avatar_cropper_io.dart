import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../config/theme/proxi_palette.dart';

/// Opens the cropper locked to a 1:1 **circular** selection and returns the
/// cropped JPG file path, or `null` if the user cancels or cropping fails.
Future<String?> cropProfilePictureFromPath(
  BuildContext context,
  String sourcePath,
) async {
  if (!context.mounted) return null;

  final CroppedFile? cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop photo',
        toolbarColor: ProxiPalette.deepIndigo,
        toolbarWidgetColor: Colors.white,
        backgroundColor: ProxiPalette.deepIndigo,
        activeControlsWidgetColor: ProxiPalette.electricBlue,
        cropStyle: CropStyle.circle,
        lockAspectRatio: true,
        hideBottomControls: true,
        initAspectRatio: CropAspectRatioPreset.square,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Crop photo',
        cropStyle: CropStyle.circle,
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
    ],
  );

  if (cropped == null) return null;
  return cropped.path;
}
