import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../config/theme/proxi_palette.dart';

class ToastHelper {
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF2E7D32),
      textColor: ProxiPalette.pureWhite,
      fontSize: 16.0,
    );
  }

  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFFC62828),
      textColor: ProxiPalette.pureWhite,
      fontSize: 16.0,
    );
  }

  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: ProxiPalette.electricBlue,
      textColor: ProxiPalette.pureWhite,
      fontSize: 16.0,
    );
  }
}
