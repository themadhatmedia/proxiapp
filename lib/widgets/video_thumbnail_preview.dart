import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/network_slot_limiter.dart';

/// Poster URL and/or disk-cached video frame (no [VideoPlayer]).
class VideoThumbnailPreview extends StatefulWidget {
  const VideoThumbnailPreview({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 48,
    this.maxThumbnailWidth = 720,
    this.showIconOnPlaceholder = true,
  });

  final String videoUrl;
  final String? posterUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;
  final int maxThumbnailWidth;
  final bool showIconOnPlaceholder;

  @override
  State<VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<VideoThumbnailPreview> {
  static final Map<String, Future<File?>> _inFlight = {};

  File? _cachedFile;
  bool _loading = false;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadThumbnail());
  }

  @override
  void didUpdateWidget(VideoThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.posterUrl != widget.posterUrl) {
      _loadGeneration++;
      _cachedFile = null;
      _failed = false;
      _loading = false;
      unawaited(_loadThumbnail());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    final poster = widget.posterUrl?.trim();
    if (poster != null && poster.isNotEmpty) return;

    final trimmed = widget.videoUrl.trim();
    if (trimmed.isEmpty) return;

    final dir = await _cacheDir();
    final cached = File('${dir.path}/${_cacheKey(trimmed)}.jpg');
    if (await cached.exists() && await cached.length() > 0) {
      if (mounted) {
        setState(() {
          _cachedFile = cached;
          _failed = false;
        });
      }
      return;
    }

    await _resolveThumbnail();
  }

  static String _cacheKey(String url) =>
      sha256.convert(utf8.encode(url.trim())).toString();

  static Future<Directory> _cacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/video_thumbs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File?> thumbnailFileForUrl(
    String url, {
    int maxThumbnailWidth = 720,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final dir = await _cacheDir();
    final file = File('${dir.path}/${_cacheKey(trimmed)}.jpg');
    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    final pending = _inFlight[trimmed];
    if (pending != null) return pending;

    final future = NetworkSlotLimiter.instance.run(() async {
      try {
        final generated = await VideoThumbnail.thumbnailFile(
          video: trimmed,
          thumbnailPath: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: maxThumbnailWidth,
          timeMs: 500,
          quality: 72,
        );
        final out = File(generated.path);
        if (await out.exists() && await out.length() > 0) {
          return out;
        }
      } catch (e) {
        final msg = e.toString();
        // Common when scrolling away: native HTTP read races with dispose.
        if (!msg.contains('Socket is closed') &&
            !msg.contains('SocketException')) {
          debugPrint('Video thumbnail failed ($trimmed): $e');
        }
      }
      return null;
    });

    _inFlight[trimmed] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(trimmed);
    }
  }

  Future<void> _resolveThumbnail() async {
    if (!mounted || _loading) return;
    final generation = ++_loadGeneration;
    _loading = true;
    if (mounted) setState(() {});

    try {
      final file = await thumbnailFileForUrl(
        widget.videoUrl,
        maxThumbnailWidth: widget.maxThumbnailWidth,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _cachedFile = file;
        _failed = file == null;
      });
    } finally {
      if (generation == _loadGeneration) {
        _loading = false;
        if (mounted) setState(() {});
      }
    }
  }

  Widget _wrapSized(Widget child) {
    final w = widget.width;
    final h = widget.height;
    if (w != null && h != null) {
      return SizedBox(width: w, height: h, child: child);
    }
    return SizedBox.expand(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.posterUrl?.trim();
    if (poster != null && poster.isNotEmpty) {
      return _wrapSized(
        CachedNetworkImage(
          imageUrl: poster,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          maxWidthDiskCache: 1200,
          maxHeightDiskCache: 1200,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => _placeholder(showSpinner: true),
          errorWidget: (_, __, ___) => _buildGeneratedOrPlaceholder(),
        ),
      );
    }
    return _wrapSized(_buildGeneratedOrPlaceholder());
  }

  Widget _buildGeneratedOrPlaceholder() {
    final file = _cachedFile;
    if (file != null) {
      return Image.file(
        file,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (_loading) {
      return _placeholder(showSpinner: true);
    }
    if (_failed) {
      return _placeholder();
    }
    return _placeholder(showSpinner: true);
  }

  Widget _placeholder({bool showSpinner = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F3150), Color(0xFF1A1F3A)],
        ),
      ),
      child: Center(
        child: showSpinner
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2,
                ),
              )
            : (widget.showIconOnPlaceholder
                ? Icon(
                    Icons.movie_creation_outlined,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: widget.iconSize * 0.65,
                  )
                : const SizedBox.shrink()),
      ),
    );
  }
}

/// @deprecated Use [VideoThumbnailPreview].
class ChatVideoThumbnail extends StatelessWidget {
  const ChatVideoThumbnail({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    this.width = 220,
    this.height = 220,
    this.iconSize = 48,
  });

  final String videoUrl;
  final String? posterUrl;
  final double width;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return VideoThumbnailPreview(
      videoUrl: videoUrl,
      posterUrl: posterUrl,
      width: width,
      height: height,
      iconSize: iconSize,
      maxThumbnailWidth: 480,
      showIconOnPlaceholder: true,
    );
  }
}
