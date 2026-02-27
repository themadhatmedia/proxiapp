import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    } else {
      return _buildMultipleMedia();
    }
  }

  Widget _buildSingleMedia(MediaItem item) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: media, initialIndex: 0)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 400,
          ),
          child: Stack(
            children: [
              _buildMediaThumbnail(item),
              if (item.isVideo) _buildVideoOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTwoMedia() {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: _buildMediaTile(media[0], 0),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildMediaTile(media[1], 1),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMedia() {
    return SizedBox(
      height: 300,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildMediaTile(media[0], 0),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildMediaTile(media[1], 1),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildMediaTile(media[2], 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleMedia() {
    return SizedBox(
      height: 300,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildMediaTile(media[0], 0),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildMediaTile(media[1], 1),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildMediaTileWithCount(media[2], 2, media.length - 3),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  color: Colors.black.withOpacity(0.6),
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
    String imageUrl;
    if (item.isVideo) {
      if (item.thumbnail != null && item.thumbnail!.isNotEmpty) {
        imageUrl = item.thumbnail!;
        debugPrint('Video thumbnail URL: $imageUrl');
      } else {
        debugPrint('No thumbnail for video: ${item.fullUrl}');
        return Container(
          color: Colors.black,
          width: double.infinity,
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white60,
              size: 64,
            ),
          ),
        );
      }
    } else {
      imageUrl = item.fullUrl;
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      cacheWidth: 800,
      cacheHeight: 600,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading ${item.isVideo ? 'thumbnail' : 'image'}: $error');
        return Container(
          color: Colors.black,
          width: double.infinity,
          child: Center(
            child: Icon(
              item.isVideo ? Icons.videocam_off : Icons.broken_image,
              color: Colors.white60,
              size: 48,
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black,
          width: double.infinity,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
              color: Colors.white,
              strokeWidth: 2,
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
          size: 56,
        ),
      ),
    );
  }
}
