import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

/// Paste helpers for text and images copied from other apps (GIFs/memes use the image path).
class ClipboardRichPaste {
  ClipboardRichPaste._();

  static Future<String?> clipboardPlainText() => Pasteboard.text;

  static void insertTextAtSelection(TextEditingController controller, String insertion) {
    final text = controller.text;
    final sel = controller.selection;
    int start;
    int end;
    if (sel.isValid &&
        sel.start >= 0 &&
        sel.end >= 0 &&
        sel.start <= text.length &&
        sel.end <= text.length) {
      start = sel.start;
      end = sel.end;
    } else {
      start = end = text.length;
    }
    final newText = text.replaceRange(start, end, insertion);
    final offset = (start + insertion.length).clamp(0, newText.length);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static String _extensionForBytes(Uint8List bytes) {
    if (bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'gif';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'webp';
    }
    return 'png';
  }

  static String _extensionFromMime(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('gif')) return 'gif';
    if (m.contains('jpeg') || m.contains('jpg')) return 'jpg';
    if (m.contains('webp')) return 'webp';
    if (m.contains('png')) return 'png';
    return 'png';
  }

  /// Bitmap / GIF / PNG bytes from the system clipboard as a temp file.
  static Future<File?> clipboardImageToTempFile() async {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final ext = _extensionForBytes(bytes);
    final path = '${dir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final f = File(path);
    await f.writeAsBytes(bytes);
    return f;
  }

  /// Android keyboard “content insertion” (GIF/sticker keyboards).
  static Future<File?> keyboardInsertedContentToTempFile(KeyboardInsertedContent content) async {
    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final ext = _extensionFromMime(content.mimeType);
    final path = '${dir.path}/keyboard_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final f = File(path);
    await f.writeAsBytes(bytes);
    return f;
  }
}
