import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/network_slot_limiter.dart';

/// Video tile for feeds: server poster when available, otherwise one cached
/// video frame (unless [allowVideoFrameFallback] is false).
class VideoPostPreview extends StatelessWidget {
  const VideoPostPreview({
    super.key,
    this.posterUrl,
    this.videoUrl,
    this.fit = BoxFit.cover,
    this.iconSize = 56,
    this.allowVideoFrameFallback = true,
  });

  final String? posterUrl;
  final String? videoUrl;
  final BoxFit fit;
  final double iconSize;
  final bool allowVideoFrameFallback;

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl?.trim();
    if (poster != null && poster.isNotEmpty) {
      return _PosterWithVideoFallback(
        posterUrl: poster,
        videoUrl: videoUrl ?? '',
        fit: fit,
        iconSize: iconSize,
        allowVideoFrameFallback: allowVideoFrameFallback,
      );
    }
    final url = videoUrl?.trim();
    if (allowVideoFrameFallback && url != null && url.isNotEmpty) {
      return _VideoFrameThumbnail(
        videoUrl: url,
        fit: fit,
        iconSize: iconSize,
      );
    }
    return _VideoPosterPlaceholder(iconSize: iconSize);
  }
}

/// @deprecated Use [VideoPostPreview] with [videoUrl].
typedef VideoPostPoster = VideoPostPreview;

class _PosterWithVideoFallback extends StatefulWidget {
  const _PosterWithVideoFallback({
    required this.posterUrl,
    required this.videoUrl,
    required this.fit,
    required this.iconSize,
    required this.allowVideoFrameFallback,
  });

  final String posterUrl;
  final String videoUrl;
  final BoxFit fit;
  final double iconSize;
  final bool allowVideoFrameFallback;

  @override
  State<_PosterWithVideoFallback> createState() => _PosterWithVideoFallbackState();
}

class _PosterWithVideoFallbackState extends State<_PosterWithVideoFallback> {
  bool _useVideoFrame = false;

  @override
  Widget build(BuildContext context) {
    if (_useVideoFrame && widget.allowVideoFrameFallback) {
      return _VideoFrameThumbnail(
        videoUrl: widget.videoUrl,
        fit: widget.fit,
        iconSize: widget.iconSize,
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.posterUrl,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => const _VideoPosterPlaceholder(showSpinner: true),
      errorWidget: (_, __, ___) {
        if (!widget.allowVideoFrameFallback || widget.videoUrl.isEmpty) {
          return _VideoPosterPlaceholder(iconSize: widget.iconSize);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_useVideoFrame) {
            setState(() => _useVideoFrame = true);
          }
        });
        return const _VideoPosterPlaceholder(showSpinner: true);
      },
    );
  }
}

/// First-frame preview from [videoUrl]; shared controller cache per URL.
class _VideoFrameThumbnail extends StatefulWidget {
  const _VideoFrameThumbnail({
    required this.videoUrl,
    required this.fit,
    required this.iconSize,
  });

  final String videoUrl;
  final BoxFit fit;
  final double iconSize;

  @override
  State<_VideoFrameThumbnail> createState() => _VideoFrameThumbnailState();
}

class _VideoFrameThumbnailState extends State<_VideoFrameThumbnail> {
  static final Map<String, VideoPlayerController> _controllerCache = {};
  static const int _maxCachedControllers = 6;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  static void _evictOldControllersIfNeeded() {
    while (_controllerCache.length > _maxCachedControllers) {
      final key = _controllerCache.keys.first;
      _controllerCache.remove(key)?.dispose();
    }
  }

  Future<void> _initialize() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      if (_controllerCache.containsKey(url)) {
        _controller = _controllerCache[url];
        if (_controller!.value.isInitialized) {
          if (mounted) setState(() => _isInitialized = true);
          return;
        }
      }

      await NetworkSlotLimiter.instance.run(() async {
        _controller ??= VideoPlayerController.networkUrl(Uri.parse(url));
        if (!_controllerCache.containsKey(url)) {
          _evictOldControllersIfNeeded();
          _controllerCache[url] = _controller!;
        }
        if (!_controller!.value.isInitialized) {
          await _controller!.initialize().timeout(const Duration(seconds: 20));
          await _controller!.seekTo(const Duration(milliseconds: 100));
          await _controller!.pause();
        }
      });

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Video frame thumbnail failed ($url): $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _VideoPosterPlaceholder(iconSize: widget.iconSize);
    }

    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return const _VideoPosterPlaceholder(showSpinner: true);
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

class _VideoPosterPlaceholder extends StatelessWidget {
  const _VideoPosterPlaceholder({
    this.iconSize = 56,
    this.showSpinner = false,
  });

  final double iconSize;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
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
            : Icon(
                Icons.movie_creation_outlined,
                color: Colors.white.withValues(alpha: 0.55),
                size: iconSize * 0.65,
              ),
      ),
    );
  }
}
