import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/post_model.dart';
import '../../utils/video_load_helper.dart';
import '../../utils/video_playback_service.dart';

class MediaViewerScreen extends StatefulWidget {
  final List<MediaItem> media;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, Object> _videoLoadTokens = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _prepareVideo(_currentIndex);
    _preloadAdjacentVideos(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    final playback = VideoPlaybackService.instance;
    for (final entry in _videoControllers.entries) {
      playback.release(widget.media[entry.key].fullUrl, entry.value);
    }
    _videoControllers.clear();
    super.dispose();
  }

  void _preloadAdjacentVideos(int index) {
    final playback = VideoPlaybackService.instance;
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.media.length && widget.media[i].isVideo) {
        playback.preload(widget.media[i].fullUrl);
      }
    }
  }

  Future<void> _prepareVideo(int index) async {
    if (!widget.media[index].isVideo) return;

    final url = widget.media[index].fullUrl;
    final token = Object();
    _videoLoadTokens[index] = token;

    final existing = _videoControllers[index];
    if (existing != null) {
      VideoPlaybackService.instance.release(url, existing);
      _videoControllers.remove(index);
    }

    if (mounted) setState(() {});

    try {
      final controller = await VideoPlaybackService.instance.obtain(url);
      if (!mounted || _videoLoadTokens[index] != token) return;
      _videoControllers[index] = controller;
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) setState(() {});
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    for (final entry in _videoControllers.entries) {
      if (entry.key != index) {
        entry.value.pause();
      }
    }

    if (widget.media[index].isVideo) {
      unawaited(_prepareVideo(index));
    }
    _preloadAdjacentVideos(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.media.length,
            itemBuilder: (context, index) {
              final mediaItem = widget.media[index];
              return _buildMediaView(mediaItem, index);
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                if (widget.media.length > 1) _buildIndicators(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            '${_currentIndex + 1} / ${widget.media.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIndicators() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.media.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentIndex == index ? Colors.white : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaView(MediaItem mediaItem, int index) {
    if (mediaItem.isVideo) {
      return _buildVideoView(mediaItem, index);
    }
    return _buildImageView(mediaItem);
  }

  Widget _buildImageView(MediaItem mediaItem) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: mediaItem.fullUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white60, size: 64),
                SizedBox(height: 16),
                Text('Failed to load image', style: TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView(MediaItem mediaItem, int index) {
    final controller = _videoControllers[index];
    final ready = controller != null && controller.value.isInitialized;
    final phase = VideoPlaybackService.instance.phaseFor(mediaItem.fullUrl);
    final failed = phase == VideoLoadPhase.failed;
    final downloading = phase == VideoLoadPhase.downloading;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (mediaItem.posterUrl != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: mediaItem.posterUrl!,
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
            ),
          ),
        if (!ready && !failed)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                if (downloading) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Downloading video…',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          )
        else if (failed)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Video could not load',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => unawaited(_prepareVideo(index)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (ready && controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  Positioned.fill(
                    child: _VideoControls(controller: controller),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_showControls)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              if (_showControls)
                Center(
                  child: IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      widget.controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              const Spacer(),
              if (_showControls)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        widget.controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(widget.controller.value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            _formatDuration(widget.controller.value.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
