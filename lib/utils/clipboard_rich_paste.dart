import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
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
    if (sel.isValid && sel.start >= 0 && sel.end >= 0 && sel.start <= text.length && sel.end <= text.length) {
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
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
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

  static String _extensionFromUrlPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.mp4')) return 'mp4';
    if (lower.endsWith('.mov')) return 'mov';
    if (lower.endsWith('.m4v')) return 'm4v';
    if (lower.endsWith('.webm')) return 'webm';
    return '';
  }

  static String _inferExtension(Uint8List bytes, String? mime, Uri uri) {
    final byHeader = _extensionForBytes(bytes);
    if (byHeader != 'png') return byHeader;
    if (mime != null && mime.isNotEmpty) {
      final fromMime = _extensionFromMime(mime);
      if (fromMime != 'png') return fromMime;
    }
    final fromPath = _extensionFromUrlPath(uri.path);
    if (fromPath.isNotEmpty) return fromPath;
    return byHeader;
  }

  static bool _looksLikeMediaUrl(Uri uri) {
    final ext = _extensionFromUrlPath(uri.path);
    if (ext.isNotEmpty) return true;
    final host = uri.host.toLowerCase();
    return host.contains('giphy.') || host.contains('tenor.') || host.contains('imgur.') || host.contains('media.');
  }

  static Future<String?> _giphyPageToGifUrl(String pageUrl) async {
    try {
      final oembed = Uri.parse(
        'https://giphy.com/services/oembed?url=${Uri.encodeComponent(pageUrl)}',
      );
      final res = await http.get(oembed);
      if (res.statusCode < 200 || res.statusCode >= 300 || res.body.isEmpty) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      final img = decoded['image_url'] ?? decoded['url'];
      if (img is String && img.isNotEmpty && img.toLowerCase().contains('.gif')) {
        return img;
      }
      if (img is String && img.isNotEmpty) {
        return img;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> _downloadHttpToFile(Uri uri) async {
    try {
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300 || res.bodyBytes.isEmpty) {
        return null;
      }
      final mime = res.headers['content-type']?.split(';').first.trim().toLowerCase();
      if (mime != null && mime.isNotEmpty && !(mime.startsWith('image/') || mime.startsWith('video/'))) {
        return null;
      }
      final ext = _inferExtension(res.bodyBytes, mime, uri);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/clipboard_url_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final f = File(path);
      await f.writeAsBytes(res.bodyBytes);
      return f;
    } catch (_) {
      return null;
    }
  }

  /// Resolves GIPHY/Tenor-style page URLs and direct media URLs from clipboard text (try before raw image bytes).
  static Future<File?> clipboardResolvedUrlMediaToTempFile() async {
    final text = await clipboardPlainText();
    if (text == null || text.trim().isEmpty) return null;
    final trimmed = text.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;

    final host = uri.host.toLowerCase();
    if (host.contains('giphy.com') && uri.path.contains('/gifs/')) {
      final gifUrl = await _giphyPageToGifUrl(trimmed);
      if (gifUrl != null) {
        final u = Uri.tryParse(gifUrl);
        if (u != null) {
          final f = await _downloadHttpToFile(u);
          if (f != null) return f;
        }
      }
    }

    if (_looksLikeMediaUrl(uri)) {
      return _downloadHttpToFile(uri);
    }
    return null;
  }

  /// Bitmap / GIF / PNG bytes from the system clipboard as a temp file (GIF magic bytes → `.gif`).
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

  /// Prefer URL/GIF resolution (GIPHY page links) over bitmap clipboard — matches other apps that copy link + PNG preview.
  static Future<File?> clipboardPasteImageGifOrResolvedUrl() async {
    final fromUrl = await clipboardResolvedUrlMediaToTempFile();
    if (fromUrl != null) return fromUrl;
    return clipboardImageToTempFile();
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

  /// If clipboard text is an image/video URL (e.g. direct `.gif`), download to temp file.
  static Future<File?> clipboardMediaUrlToTempFile() async {
    final text = await clipboardPlainText();
    if (text == null || text.trim().isEmpty) return null;
    final uri = Uri.tryParse(text.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;
    if (!_looksLikeMediaUrl(uri)) return null;
    return _downloadHttpToFile(uri);
  }
}
