// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:flutter/material.dart';

import 'profile_avatar_cropper_io.dart'
    if (dart.library.html) 'profile_avatar_cropper_web.dart' as _impl;

/// Opens [image_cropping] with a 1:1 ratio, writes JPG bytes to a temp file.
/// Returns the absolute path to the temp `.jpg`, or `null` if cancelled / failed.
///
/// On **web**, cropping to a temp file is not supported; this always returns `null`.
Future<String?> cropProfilePictureFromPath(
  BuildContext context,
  String sourcePath,
) =>
    _impl.cropProfilePictureFromPath(context, sourcePath);
