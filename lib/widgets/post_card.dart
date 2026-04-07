import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../config/theme/proxi_palette.dart';
import '../data/models/post_model.dart';
import '../views/posts/media_viewer_screen.dart';
import '../views/posts/user_posts_screen.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onLikesTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isLiking;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onLikesTap,
    this.onEdit,
    this.onDelete,
    this.isLiking = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final proxi = context.proxi;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: proxi.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (post.content.isNotEmpty) _buildContent(context),
          if (post.media != null && post.media!.isNotEmpty) _buildMedia(context),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOwner = post.permissions?.relationType == 'owner';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToUserProfile(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    cs.surfaceContainerHighest.withOpacity(0.9),
                    cs.surfaceContainerHighest.withOpacity(0.5),
                  ],
                ),
              ),
              child: post.user?.avatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: post.user!.avatarUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        maxWidthDiskCache: 96,
                        maxHeightDiskCache: 96,
                        placeholder: (ctx, url) => _buildDefaultAvatar(ctx),
                        errorWidget: (ctx, url, error) => _buildDefaultAvatar(ctx),
                      ),
                    )
                  : _buildDefaultAvatar(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToUserProfile(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.user?.displayName ?? post.user?.name ?? 'Unknown User',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (post.visibility != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          post.visibility == 'public' ? Icons.public : Icons.lock_outline,
                          color: cs.onSurfaceVariant,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isOwner && (onEdit != null || onDelete != null))
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: cs.onSurfaceVariant,
              ),
              color: context.proxi.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Post'),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Delete Post',
                          style: TextStyle(color: Colors.red),
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

  Widget _buildDefaultAvatar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.person,
        color: cs.onSurfaceVariant,
        size: 28,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        post.content,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: post.content.isNotEmpty ? 12 : 0,
      ),
      child: _buildMediaGrid(context),
    );
  }

  Widget _buildMediaGrid(BuildContext context) {
    final mediaList = post.media!;

    if (mediaList.isEmpty) return const SizedBox.shrink();

    if (mediaList.length == 1) {
      return _buildSingleMediaItem(context, mediaList[0], 0);
    } else if (mediaList.length == 2) {
      return _buildTwoMediaGrid(context, mediaList);
    } else if (mediaList.length == 3) {
      return _buildThreeMediaGrid(context, mediaList);
    } else if (mediaList.length == 4) {
      return _buildFourMediaGrid(context, mediaList);
    } else {
      return _buildFiveOrMoreMediaGrid(context, mediaList);
    }
  }

  Widget _buildSingleMediaItem(BuildContext context, MediaItem item, int index) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: post.media!, initialIndex: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildMediaThumbnail(item),
              ),
              if (item.isVideo)
                Positioned.fill(
                  child: Container(
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
                        size: 72,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTwoMediaGrid(BuildContext context, List<MediaItem> mediaList) {
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildMediaGridItem(context, mediaList[0], 0),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: _buildMediaGridItem(context, mediaList[1], 1),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeMediaGrid(BuildContext context, List<MediaItem> mediaList) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[0], 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[1], 1),
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
                child: _buildMediaGridItem(context, mediaList[2], 2),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildFourMediaGrid(BuildContext context, List<MediaItem> mediaList) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[0], 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[1], 1),
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
                child: _buildMediaGridItem(context, mediaList[2], 2),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[3], 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiveOrMoreMediaGrid(BuildContext context, List<MediaItem> mediaList) {
    final remainingCount = mediaList.length > 5 ? mediaList.length - 5 : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[0], 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[1], 1),
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
                child: _buildMediaGridItem(context, mediaList[2], 2),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildMediaGridItem(context, mediaList[3], 3),
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
                child: remainingCount > 0 ? _buildMediaGridItemWithOverlay(context, mediaList[4], 4, remainingCount) : _buildMediaGridItem(context, mediaList[4], 4),
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

  Widget _buildMediaGridItem(BuildContext context, MediaItem item, int index) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: post.media!, initialIndex: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMediaThumbnail(item),
            ),
            if (item.isVideo)
              Positioned.fill(
                child: Container(
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
        return CachedNetworkImage(
          imageUrl: item.thumbnail!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          maxWidthDiskCache: 800,
          maxHeightDiskCache: 800,
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
            return _VideoThumbnailWidget(videoUrl: item.fullUrl);
          },
        );
      }
      // If no thumbnail, generate one from video
      return _VideoThumbnailWidget(videoUrl: item.fullUrl);
    }

    // For images
    return CachedNetworkImage(
      imageUrl: item.fullUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white60,
            size: 64,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGridItemWithOverlay(BuildContext context, MediaItem item, int index, int remainingCount) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: post.media!, initialIndex: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMediaThumbnail(item),
            ),
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

  Widget _buildActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canLike = post.permissions?.canLike ?? true;
    final canComment = post.permissions?.canComment ?? true;
    final statsMeta = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: 13,
      height: 1.25,
      fontWeight: FontWeight.w400,
    );
    final likesMeta = statsMeta.copyWith(fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if ((post.likesCount) > 0 || (post.commentsCount) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if ((post.likesCount) > 0) ...[
                    if (onLikesTap != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onLikesTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Text(
                              '${post.likesCount} ${(post.likesCount) == 1 || (post.likesCount) == 0 ? 'like' : 'likes'}',
                              style: likesMeta,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '${post.likesCount} ${(post.likesCount) == 1 || (post.likesCount) == 0 ? 'like' : 'likes'}',
                        style: statsMeta,
                      ),
                  ],
                  if ((post.likesCount) > 0 && (post.commentsCount) > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '|',
                        style: statsMeta.copyWith(
                          color: cs.onSurfaceVariant.withOpacity(0.62),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  if ((post.commentsCount) > 0) ...[
                    Text(
                      '${post.commentsCount} ${(post.commentsCount) == 1 || (post.commentsCount) == 0 ? 'comment' : 'comments'}',
                      style: statsMeta,
                    ),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: post.liked == true ? Icons.favorite : Icons.favorite_border,
                  label: 'Like',
                  color: post.liked == true ? Colors.red : cs.onSurface,
                  onTap: canLike && !isLiking ? onLike : null,
                  isLoading: isLiking,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                  color: canComment ? cs.onSurface : cs.onSurfaceVariant,
                  onTap: onComment, // Always allow viewing comments
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final isEnabled = onTap != null;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const _BeatingHeart()
              else
                Icon(
                  icon,
                  color: isEnabled ? color.withOpacity(0.9) : color.withOpacity(0.3),
                  size: 20,
                ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isEnabled ? cs.onSurface.withOpacity(0.95) : cs.onSurfaceVariant.withOpacity(0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToUserProfile() {
    if (post.user == null) return;

    Get.to(
      () => UserPostsScreen(
        userId: post.user!.id,
        userName: post.user!.displayName ?? post.user!.name,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoThumbnailWidget({
    required this.videoUrl,
  });

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> with AutomaticKeepAliveClientMixin {
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
            size: 64,
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

class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart();

  @override
  State<_BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<_BeatingHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: const Icon(
        Icons.favorite,
        color: Colors.red,
        size: 20,
      ),
    );
  }
}
