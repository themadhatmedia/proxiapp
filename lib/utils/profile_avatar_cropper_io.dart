import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:image_cropping/image_cropping.dart';
import 'package:path_provider/path_provider.dart';

import '../config/theme/proxi_palette.dart';

/// Opens [image_cropping] with a 1:1 ratio, writes JPG bytes to a temp file.
/// Returns the temp file path, or `null` if the user cancels or cropping fails.
Future<String?> cropProfilePictureFromPath(
  BuildContext context,
  String sourcePath,
) async {
  if (!context.mounted) return null;

  final bytes = await XFile(sourcePath).readAsBytes();
  if (!context.mounted) return null;

  Uint8List? fromListener;
  final dynamic popResult = await ImageCropping.cropImage(
    context: context,
    imageBytes: bytes,
    onImageStartLoading: () {},
    onImageEndLoading: () {},
    onImageDoneListener: (dynamic data) {
      if (data is Uint8List) fromListener = data;
    },
    selectedImageRatio: CropAspectRatio.fromRation(ImageRatio.RATIO_1_1),
    visibleOtherAspectRatios: false,
    squareBorderWidth: 2,
    squareCircleColor: ProxiPalette.electricBlue,
    defaultTextColor: Colors.white70,
    selectedTextColor: ProxiPalette.electricBlue,
    colorForWhiteSpace: ProxiPalette.deepIndigo,
    encodingQuality: 90,
    outputImageFormat: OutputImageFormat.jpg,
  );

  final Uint8List? out =
      fromListener ?? (popResult is Uint8List ? popResult : null);
  if (out == null || out.isEmpty) return null;

  try {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/proxi_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(out);
    return file.path;
  } catch (_) {
    return null;
  }
}
