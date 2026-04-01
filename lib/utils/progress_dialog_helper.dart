import 'package:flutter/material.dart';
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';

class ProgressDialogHelper {
  static ProgressDialog? _progressDialog;
  static BuildContext? _currentContext;

  static ProgressDialog create(BuildContext context) {
    _currentContext = context;
    final cs = Theme.of(context).colorScheme;

    _progressDialog = ProgressDialog(
      context,
      type: ProgressDialogType.normal,
      isDismissible: false,
    );

    _progressDialog!.style(
      message: 'Please wait...',
      borderRadius: 10.0,
      backgroundColor: cs.surfaceContainerHighest,
      progressWidget: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      ),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
      messageTextStyle: TextStyle(
        color: cs.onSurface,
        fontSize: 16.0,
        fontWeight: FontWeight.w500,
      ),
    );

    return _progressDialog!;
  }

  static Future<void> show(BuildContext context) async {
    if (_progressDialog == null || _currentContext != context) {
      create(context);
    }
    await _progressDialog!.show();
  }

  static Future<void> hide() async {
    if (_progressDialog != null && _progressDialog!.isShowing()) {
      await _progressDialog!.hide();
    }
  }

  static bool isShowing() {
    return _progressDialog != null && _progressDialog!.isShowing();
  }
}
