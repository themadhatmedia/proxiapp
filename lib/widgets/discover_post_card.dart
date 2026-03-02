import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../controllers/discover_controller.dart';
import '../data/models/comment_model.dart';
import '../data/models/post_model.dart';
import '../utils/progress_dialog_helper.dart';
import '../views/posts/media_viewer_screen.dart';
import '../views/pulse/user_profile_detail_screen.dart';
import '../widgets/comment_card.dart';

class DiscoverPostCard extends StatefulWidget {
  final Post post;

  const DiscoverPostCard({
    super.key,
    required this.post,
  });

  @override
  State<DiscoverPostCard> createState() => _DiscoverPostCardState();
}

class _DiscoverPostCardState extends State<DiscoverPostCard> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  int? _replyToCommentId;
  String? _replyToUserName;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DiscoverController>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.post.content.isNotEmpty) _buildContent(),
          if (widget.post.media != null && widget.post.media!.isNotEmpty) _buildMedia(),
          _buildActions(controller),
          Obx(() {
            final showComments = controller.showingComments[widget.post.id] ?? false;
            if (showComments) {
              return _buildCommentsSection(controller);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showUserProfile(),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.post.user?.avatarUrl != null ? NetworkImage(widget.post.user!.avatarUrl!) : null,
              child: widget.post.user?.avatarUrl == null
                  ? Text(
                      (widget.post.user?.name ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showUserProfile(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.user?.name ?? 'Unknown User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeago.format(widget.post.createdAt ?? DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        widget.post.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMedia() {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: widget.post.content.isNotEmpty ? 12 : 0,
      ),
      child: _buildMediaGrid(),
    );
  }

  Widget _buildMediaGrid() {
    final mediaList = widget.post.media!;

    if (mediaList.isEmpty) return const SizedBox.shrink();

    if (mediaList.length == 1) {
      return _buildSingleMediaItem(mediaList[0], 0);
    } else if (mediaList.length == 2) {
      return _buildTwoMediaGrid(mediaList);
    } else if (mediaList.length == 3) {
      return _buildThreeMediaGrid(mediaList);
    } else if (mediaList.length == 4) {
      return _buildFourMediaGrid(mediaList);
    } else {
      return _buildMultiMediaGrid(mediaList);
    }
  }

  Widget _buildSingleMediaItem(MediaItem item, int index) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: widget.post.media!, initialIndex: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: _buildMediaThumbnail(item),
        ),
      ),
    );
  }

  Widget _buildTwoMediaGrid(List<MediaItem> media) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        child: Row(
          children: [
            Expanded(child: _buildMediaGridItem(media[0], 0)),
            const SizedBox(width: 2),
            Expanded(child: _buildMediaGridItem(media[1], 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeMediaGrid(List<MediaItem> media) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 300,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildMediaGridItem(media[0], 0),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildMediaGridItem(media[1], 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildMediaGridItem(media[2], 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFourMediaGrid(List<MediaItem> media) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildMediaGridItem(media[0], 0)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaGridItem(media[1], 1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildMediaGridItem(media[2], 2)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaGridItem(media[3], 3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiMediaGrid(List<MediaItem> media) {
    final displayMedia = media.take(4).toList();
    final remainingCount = media.length - 4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildMediaGridItem(displayMedia[0], 0)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildMediaGridItem(displayMedia[1], 1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildMediaGridItem(displayMedia[2], 2)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: remainingCount > 0 ? _buildMediaGridItemWithOverlay(displayMedia[3], 3, remainingCount) : _buildMediaGridItem(displayMedia[3], 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGridItem(MediaItem item, int index) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: widget.post.media!, initialIndex: index)),
      child: _buildMediaThumbnail(item),
    );
  }

  Widget _buildMediaThumbnail(MediaItem item) {
    if (item.isVideo) {
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
            return _VideoThumbnailWidget(videoUrl: item.fullUrl);
          },
        );
      }
      return _VideoThumbnailWidget(videoUrl: item.fullUrl);
    }

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

  Widget _buildMediaGridItemWithOverlay(MediaItem item, int index, int remainingCount) {
    return GestureDetector(
      onTap: () => Get.to(() => MediaViewerScreen(media: widget.post.media!, initialIndex: index)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildMediaThumbnail(item),
          Container(
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
        ],
      ),
    );
  }

  Widget _buildActions(DiscoverController controller) {
    final canLike = widget.post.permissions?.canLike ?? false;
    final canComment = widget.post.permissions?.canComment ?? false;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats text
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${widget.post.likesCount} ${widget.post.likesCount == 1 ? 'like' : 'likes'} • ${widget.post.commentsCount} ${widget.post.commentsCount == 1 ? 'comment' : 'comments'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: widget.post.liked ? Icons.favorite : Icons.favorite_border,
                  label: 'Like',
                  color: widget.post.liked ? Colors.red : Colors.grey,
                  onTap: canLike ? () => controller.toggleLike(widget.post) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                  color: Colors.grey,
                  onTap: canComment ? () => controller.toggleComments(widget.post.id!) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isEnabled ? color : color.withOpacity(0.3),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isEnabled ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection(DiscoverController controller) {
    final comments = controller.postComments[widget.post.id] ?? [];
    final isLoading = controller.loadingComments[widget.post.id] ?? false;
    final canComment = widget.post.permissions?.canComment ?? false;
    final canReply = widget.post.permissions?.canReply ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => controller.toggleComments(widget.post.id!),
                child: const Text(
                  'Hide',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SpinKitWave(
                  color: Colors.blue,
                  size: 30.0,
                ),
              ),
            )
          else if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No comments yet',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _buildCommentsList(comments, canReply),
            ),
          if (canComment) ...[
            const SizedBox(height: 12),
            if (_replyToCommentId != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'Replying to $_replyToUserName',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        _commentFocusNode.unfocus();
                        setState(() {
                          _replyToCommentId = null;
                          _replyToUserName = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToCommentId != null ? 'Write a reply...' : 'Write a comment...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _submitComment(controller),
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCommentsList(List<CommentModel> comments, bool canReply) {
    final controller = Get.find<DiscoverController>();
    final List<Widget> widgets = [];

    for (var comment in comments) {
      widgets.add(
        CommentCard(
          comment: comment,
          postId: widget.post.id!,
          controller: controller,
          onReply: canReply
              ? (commentId, userName) {
                  setState(() {
                    _replyToCommentId = commentId;
                    _replyToUserName = userName;
                  });
                  _commentController.clear();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _commentFocusNode.requestFocus();
                  });
                }
              : null,
        ),
      );
    }

    return widgets;
  }

  Future<void> _submitComment(DiscoverController controller) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    _commentFocusNode.unfocus();

    ProgressDialogHelper.show(context);
    await controller.addComment(
      widget.post.id!,
      content,
      parentId: _replyToCommentId,
    );
    ProgressDialogHelper.hide();

    _commentController.clear();
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });
  }

  void _showUserProfile() {
    if (widget.post.user == null) return;

    final userData = {
      'id': widget.post.user!.id,
      'name': widget.post.user!.name,
      'user': {
        'id': widget.post.user!.id,
        'name': widget.post.user!.name,
        'profile': {
          'display_name': widget.post.user!.displayName ?? widget.post.user!.name,
          'avatar': widget.post.user!.avatarUrl,
          'bio': widget.post.user!.bio ?? '',
          'profession': widget.post.user!.profession,
          'city': widget.post.user!.city,
          'state': widget.post.user!.state,
          'interests': widget.post.user!.interests ?? [],
          'core_values': widget.post.user!.coreValues ?? [],
          'instagram_url': widget.post.user!.instagramUrl,
          'snapchat_url': widget.post.user!.snapchatUrl,
          'linkedin_url': widget.post.user!.linkedinUrl,
          'facebook_url': widget.post.user!.facebookUrl,
          'x_url': widget.post.user!.xUrl,
          'tiktok_url': widget.post.user!.tiktokUrl,
          'other_url': widget.post.user!.otherUrl,
        },
      },
      'in_inner_circle': false,
      'in_outer_circle': false,
      'inner_request_status': 'not_sent',
      'hide_action_buttons': true,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => UserProfileDetailScreen(
          userData: userData,
          scrollController: scrollController,
        ),
      ),
    );
  }

  // ignore: unused_element
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return timeago.format(date);
  }
}

class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoThumbnailWidget({required this.videoUrl});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.videocam_off,
            color: Colors.white60,
            size: 64,
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}
