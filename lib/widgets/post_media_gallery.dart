import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../data/models/post_model.dart';
import '../views/posts/media_viewer_screen.dart';

class PostMediaGallery extends StatelessWidget {
  final List<MediaItem> media;

  const PostMediaGallery({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    if (media.length == 1) {
      return _buildSingleMedia(media[0]);
    } else if (media.length == 2) {
      return _buildTwoMedia();
    } else if (media.length == 3) {
      return _buildThreeMedia();
    } else if (media.length == 4) {
      return _buildFourMedia();
    } else {
      return _buildFiveOrMoreMedia();
    }
  }

  Widget _buildSingleMedia(MediaItem item) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: media, initialIndex: 0)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildSingleMediaThumbnail(item),
              ),
              if (item.isVideo) _buildVideoOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTwoMedia() {
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildMediaTile(media[0], 0),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildMediaTile(media[1], 1),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeMedia() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[0], 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[1], 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[2], 2),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildFourMedia() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[0], 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[1], 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[2], 2),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[3], 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiveOrMoreMedia() {
    final remainingCount = media.length > 5 ? media.length - 5 : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[0], 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[1], 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[2], 2),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaTile(media[3], 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: remainingCount > 0 ? _buildMediaTileWithCount(media[4], 4, remainingCount) : _buildMediaTile(media[4], 4),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaTile(MediaItem item, int index) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: media, initialIndex: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMediaThumbnail(item),
            ),
            if (item.isVideo)
              Positioned.fill(
                child: _buildVideoOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTileWithCount(MediaItem item, int index, int remainingCount) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: media, initialIndex: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMediaThumbnail(item),
            ),
            if (item.isVideo)
              Positioned.fill(
                child: _buildVideoOverlay(),
              ),
            if (remainingCount > 0)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(MediaItem item) {
    if (item.isVideo) {
      // If video has a thumbnail URL, use it
      if (item.thumbnail != null) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CachedNetworkImage(
            imageUrl: item.thumbnail!,
            fit: BoxFit.cover,
            memCacheWidth: 800,
            memCacheHeight: 800,
            placeholder: (context, url) => Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              debugPrint('Error loading video thumbnail: $error');
              return VideoThumbnailWidget(videoUrl: item.fullUrl);
            },
          ),
        );
      }
      // If no thumbnail, generate one from video
      return VideoThumbnailWidget(videoUrl: item.fullUrl);
    }

    // For images
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CachedNetworkImage(
        imageUrl: item.fullUrl,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        memCacheHeight: 800,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('Error loading image: $error');
          return Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white60,
                size: 64,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleMediaThumbnail(MediaItem item) {
    if (item.isVideo) {
      // If video has a thumbnail URL, use it
      if (item.thumbnail != null) {
        return CachedNetworkImage(
          imageUrl: item.thumbnail!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('Error loading video thumbnail: $error');
            return VideoThumbnailWidget(videoUrl: item.fullUrl);
          },
        );
      }
      // If no thumbnail, generate one from video
      return VideoThumbnailWidget(videoUrl: item.fullUrl);
    }

    // For images
    return CachedNetworkImage(
      imageUrl: item.fullUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('Error loading image: $error');
        return Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.white60,
              size: 80,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white,
          size: 64,
        ),
      ),
    );
  }
}

class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> with AutomaticKeepAliveClientMixin {
  static final Map<String, VideoPlayerController> _controllerCache = {};
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (_controllerCache.containsKey(widget.videoUrl)) {
        _controller = _controllerCache[widget.videoUrl];
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
        return;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      await _controller!.seekTo(const Duration(milliseconds: 100));

      _controllerCache[widget.videoUrl] = _controller!;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasError) {
      return Container(
        color: Colors.black,
        width: double.infinity,
        child: const Center(
          child: Icon(
            Icons.videocam_off,
            color: Colors.white60,
            size: 48,
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        width: double.infinity,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
