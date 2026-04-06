// ignore_for_file: unnecessary_underscores

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/post_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/safe_avatar.dart';
import 'my_posts_screen.dart';

enum _ShareFeed {
  inner,
  outer,
  mutual,
}

extension on _ShareFeed {
  String get apiKey => name;

  String get chipHint => switch (this) {
    _ShareFeed.inner => 'Inner connection',
    _ShareFeed.outer => 'Outer connection',
    _ShareFeed.mutual => 'Mutual connection',
  };

  IconData get chipIcon => switch (this) {
    _ShareFeed.inner => Icons.bolt_rounded,
    _ShareFeed.outer => Icons.hub_outlined,
    _ShareFeed.mutual => Icons.handshake_outlined,
  };
}

class CreatePostScreen extends StatefulWidget {
  /// When set, screen updates this post via [ApiService.updatePost].
  final Post? postToEdit;

  const CreatePostScreen({super.key, this.postToEdit});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();
  final StorageService _storageService = StorageService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _mediaFiles = [];
  final List<VideoPlayerController> _videoControllers = [];
  List<MediaItem> _serverMedia = [];
  final Set<int> _removedMediaIds = {};
  static const List<_ShareFeed> _shareFeedOrder = [
    _ShareFeed.inner,
    _ShareFeed.outer,
    _ShareFeed.mutual,
  ];
  final Set<_ShareFeed> _selectedShareFeeds = {
    _ShareFeed.inner,
    _ShareFeed.outer,
    _ShareFeed.mutual,
  };
  static const int maxMediaSize = 10 * 1024 * 1024; // 10MB per file
  static const int maxTotalSize = 50 * 1024 * 1024; // 50MB total

  static const List<String> _createPostHints = [
    "What's the good news?",
    "What's your win today?",
    "What are you thankful for?",
    "Where did you level up?",
    "What's a win - big or small - you're celebrating today?",
    "Where did you show up strong this week?",
    "What are you improving this week?",
    "What lifted your energy?",
    "Who helped you win?",
    "What are you building?",
  ];

  late String _composeHint;

  bool get _isEditing => widget.postToEdit != null && widget.postToEdit!.id != null;

  /// API rule: post must have caption text and/or at least one media item.
  bool get _hasCaptionOrMedia {
    final hasText = _contentController.text.trim().isNotEmpty;
    if (_isEditing) {
      return hasText || _visibleServerMedia.isNotEmpty || _mediaFiles.isNotEmpty;
    }
    return hasText || _mediaFiles.isNotEmpty;
  }

  List<MediaItem> get _visibleServerMedia {
    return _serverMedia
        .where((m) => m.id != null && !_removedMediaIds.contains(m.id!))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final edit = widget.postToEdit;
    if (edit != null) {
      _contentController.text = edit.content;
      _serverMedia = List<MediaItem>.from(edit.media ?? []);
      final aud = edit.connectionAudiences;
      if (aud != null && aud.isNotEmpty) {
        _selectedShareFeeds.clear();
        for (final k in aud) {
          switch (k) {
            case 'inner':
              _selectedShareFeeds.add(_ShareFeed.inner);
              break;
            case 'outer':
              _selectedShareFeeds.add(_ShareFeed.outer);
              break;
            case 'mutual':
              _selectedShareFeeds.add(_ShareFeed.mutual);
              break;
          }
        }
        if (_selectedShareFeeds.isEmpty) {
          _selectedShareFeeds.addAll({
            _ShareFeed.inner,
            _ShareFeed.outer,
            _ShareFeed.mutual,
          });
        }
      }
      _composeHint = "Edit your post…";
    } else {
      final idx = _storageService.getCreatePostHintIndex();
      _composeHint = _createPostHints[idx];
      _storageService.setCreatePostHintIndex(idx + 1);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library, color: cs.primary),
                  title: Text('Photo', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.gif_box, color: cs.primary),
                  title: Text('GIF', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickGif();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.videocam, color: cs.primary),
                  title: Text('Video', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: cs.primary),
                  title: Text('Camera', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromCamera();
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ToastHelper.showError('Failed to pick media');
    }
  }

  Future<void> _pickImage() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        for (final image in images) {
          await _addMedia(File(image.path), false);
        }
      }
    } catch (e) {
      ToastHelper.showError('Failed to pick images');
    }
  }

  Future<void> _pickVideo() async {
    try {
      await ProgressDialogHelper.show(context);

      // Note: pickVideo doesn't support multiple selection, so we use pickMultipleMedia
      final List<XFile> media = await _picker.pickMultipleMedia();

      if (media.isNotEmpty) {
        for (final file in media) {
          final isVideo = _isVideoFile(File(file.path));
          if (isVideo) {
            await _addMedia(File(file.path), true);
          }
        }
      }

      await ProgressDialogHelper.hide();
    } catch (e) {
      await ProgressDialogHelper.hide();
      ToastHelper.showError('Failed to pick videos');
    }
  }

  Future<void> _pickGif() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        int gifCount = 0;
        for (final image in images) {
          final file = File(image.path);
          if (_isGifFile(file)) {
            await _addMedia(file, false);
            gifCount++;
          }
        }
        if (gifCount == 0) {
          ToastHelper.showError('No GIF files were selected');
        }
      }
    } catch (e) {
      ToastHelper.showError('Failed to pick GIFs');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: cs.primary),
                  title: Text('Take Photo', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturePhoto();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.videocam, color: cs.primary),
                  title: Text('Record Video', style: TextStyle(color: cs.onSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureVideo();
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ToastHelper.showError('Failed to open camera options');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _addMedia(File(image.path), false);
      }
    } catch (e) {
      ToastHelper.showError('Failed to capture photo');
    }
  }

  Future<void> _captureVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
      if (video != null) {
        await ProgressDialogHelper.show(context);
        await _addMedia(File(video.path), true);
        await ProgressDialogHelper.hide();
      }
    } catch (e) {
      await ProgressDialogHelper.hide();
      ToastHelper.showError('Failed to record video');
    }
  }

  Future<void> _addMedia(File file, bool isVideo) async {
    VideoPlayerController? controller;
    try {
      final fileSize = await file.length();
      if (fileSize > maxMediaSize) {
        ToastHelper.showError('File size must be less than 10MB');
        return;
      }

      // Check total size of all media files
      int currentTotalSize = 0;
      for (var existingFile in _mediaFiles) {
        currentTotalSize += await existingFile.length();
      }

      if (currentTotalSize + fileSize > maxTotalSize) {
        ToastHelper.showError('Total media size cannot exceed 50MB. Please remove some files.');
        return;
      }

      if (isVideo) {
        controller = VideoPlayerController.file(file);

        if (mounted) {
          setState(() {
            _videoControllers.add(controller!);
            _mediaFiles.add(file);
          });
        }

        // Initialize after adding to state
        await controller.initialize();

        // Pause immediately after initialization
        await controller.pause();

        // Seek to 1 millisecond (some platforms have issues with Duration.zero)
        await controller.seekTo(const Duration(milliseconds: 1));

        // Force a UI update to show the frame
        if (mounted) {
          setState(() {});
        }
      } else {
        setState(() {
          _mediaFiles.add(file);
        });
      }
    } catch (e) {
      ToastHelper.showError('Failed to process media file');
      // Clean up if video controller was created
      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      final file = _mediaFiles[index];
      _mediaFiles.removeAt(index);

      // Find and dispose corresponding video controller if it's a video
      final videoIndex = _videoControllers.indexWhere((controller) => controller.dataSource == file.path);
      if (videoIndex != -1) {
        _videoControllers[videoIndex].dispose();
        _videoControllers.removeAt(videoIndex);
      }
    });
  }

  bool _isVideoFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
  }

  bool _isGifFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return extension == 'gif';
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();

    if (!_hasCaptionOrMedia) {
      ToastHelper.showError(
        'Add a caption or choose at least one photo, video, or GIF before you post.',
      );
      return;
    }

    if (_selectedShareFeeds.isEmpty) {
      ToastHelper.showError('Choose at least one connection to share with');
      return;
    }

    await ProgressDialogHelper.show(context);

    try {
      final token = authController.token;
      if (token == null) {
        throw Exception('Authentication required');
      }

      final audiences = _shareFeedOrder.where((f) => _selectedShareFeeds.contains(f)).map((f) => f.apiKey).toList();

      if (_isEditing) {
        final postId = widget.postToEdit!.id!;
        await apiService.updatePost(
          token: token,
          postId: postId,
          content: content,
          connectionAudiences: audiences,
          deleteMediaIds: _removedMediaIds.isNotEmpty ? _removedMediaIds.toList() : null,
          newMediaFiles: _mediaFiles.isNotEmpty ? _mediaFiles : null,
        );

        await ProgressDialogHelper.hide();
        ToastHelper.showSuccess('Post updated');
        if (mounted) Get.back(result: true);
        return;
      }

      await apiService.createPost(
        token: token,
        content: content,
        mediaFiles: _mediaFiles.isNotEmpty ? _mediaFiles : null,
        connectionAudiences: audiences,
      );

      await ProgressDialogHelper.hide();
      ToastHelper.showSuccess('Post created successfully');

      Get.back();
      Get.to(() => const MyPostsScreen());
    } catch (e) {
      await ProgressDialogHelper.hide();
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ToastHelper.showError(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authController.currentUser.value;
    final displayName = user?.displayName ?? user?.name ?? 'User';
    final avatarUrl = user?.avatarUrl;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.proxi.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Text(
          _isEditing ? 'Edit Post' : 'Create Post',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                _isEditing ? 'Save' : 'Post',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SafeAvatar(
                      imageUrl: avatarUrl,
                      size: 50,
                      fallbackText: displayName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _contentController,
                  maxLines: null,
                  minLines: 5,
                  maxLength: 280,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    hintText: _composeHint,
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant.withOpacity(0.85),
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 15),
                _buildShareWithSection(),
                const SizedBox(height: 15),
                if (_isEditing && (_visibleServerMedia.isNotEmpty || _mediaFiles.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildEditMediaPreview(),
                  )
                else if (!_isEditing && _mediaFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildMediaPreview(),
                  ),
                _buildAddMediaButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleShareFeed(_ShareFeed feed) {
    setState(() {
      if (_selectedShareFeeds.contains(feed)) {
        if (_selectedShareFeeds.length > 1) {
          _selectedShareFeeds.remove(feed);
        }
      } else {
        _selectedShareFeeds.add(feed);
      }
    });
  }

  Widget _buildShareWithSection() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Share with',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' · ',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              Expanded(
                child: Text(
                  'Tap to add or remove',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _shareFeedOrder.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildShareFeedCell(_shareFeedOrder[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareFeedCell(_ShareFeed feed) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedShareFeeds.contains(feed);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleShareFeed(feed),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected ? cs.primary.withOpacity(0.12) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                feed.chipIcon,
                size: 18,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                feed.chipHint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 15,
                color: selected ? cs.primary : cs.onSurfaceVariant.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<int> _getTotalMediaSize() async {
    int totalSize = 0;
    for (var file in _mediaFiles) {
      totalSize += await file.length();
    }
    return totalSize;
  }

  void _removeServerMedia(int mediaId) {
    setState(() {
      _removedMediaIds.add(mediaId);
    });
  }

  Widget _buildEditMediaPreview() {
    final cs = Theme.of(context).colorScheme;
    final server = _visibleServerMedia;
    final totalSlots = server.length + _mediaFiles.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media ($totalSlots)',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FutureBuilder<int>(
                      future: _getTotalMediaSize(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == 0) {
                          return const SizedBox.shrink();
                        }
                        final totalSize = snapshot.data!;
                        final percentage = (totalSize / maxTotalSize * 100).clamp(0, 100);
                        final isNearLimit = percentage > 80;
                        return Text(
                          'New uploads: ${_formatFileSize(totalSize)} / ${_formatFileSize(maxTotalSize)}',
                          style: TextStyle(
                            color: isNearLimit ? Colors.orange : cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickMedia,
                icon: Icon(Icons.add, color: cs.primary, size: 20),
                label: Text(
                  'Add More',
                  style: TextStyle(color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: totalSlots,
            itemBuilder: (context, index) {
              if (index < server.length) {
                final m = server[index];
                final thumb = m.fullUrl.isNotEmpty ? m.fullUrl : m.url;
                final isVideo = m.isVideo;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: isVideo
                            ? ColoredBox(
                                color: cs.surfaceContainerHighest,
                                child: Icon(Icons.videocam, color: cs.onSurfaceVariant, size: 36),
                              )
                            : CachedNetworkImage(
                                imageUrl: thumb,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (_, __) => ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                                ),
                              ),
                      ),
                    ),
                    if (m.id != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeServerMedia(m.id!),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cs.inverseSurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: cs.onInverseSurface,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    if (isVideo)
                      Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: cs.onPrimary,
                          size: 40,
                        ),
                      ),
                    if (m.isGif)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.inverseSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GIF',
                            style: TextStyle(
                              color: cs.onInverseSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }

              final fileIndex = index - server.length;
              final file = _mediaFiles[fileIndex];
              final isVideo = _isVideoFile(file);
              return Stack(
                children: [
                  GestureDetector(
                    onTap: isVideo ? () => _showVideoReview(file) : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Container(
                          color: isVideo ? cs.scrim : cs.surfaceContainerHighest,
                          child: isVideo
                              ? _buildVideoPreview(context, file)
                              : Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeMedia(fileIndex),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.inverseSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: cs.onInverseSurface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (isVideo)
                    GestureDetector(
                      onTap: () => _showVideoReview(file),
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: cs.onPrimary,
                          size: 40,
                        ),
                      ),
                    ),
                  if (_isGifFile(file))
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.inverseSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'GIF',
                          style: TextStyle(
                            color: cs.onInverseSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media (${_mediaFiles.length})',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FutureBuilder<int>(
                      future: _getTotalMediaSize(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final totalSize = snapshot.data!;
                          final percentage = (totalSize / maxTotalSize * 100).clamp(0, 100);
                          final isNearLimit = percentage > 80;
                          return Text(
                            '${_formatFileSize(totalSize)} / ${_formatFileSize(maxTotalSize)}',
                            style: TextStyle(
                              color: isNearLimit ? Colors.orange : cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickMedia,
                icon: Icon(Icons.add, color: cs.primary, size: 20),
                label: Text(
                  'Add More',
                  style: TextStyle(color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _mediaFiles.length,
            itemBuilder: (context, index) {
              final file = _mediaFiles[index];
              final isVideo = _isVideoFile(file);
              final cs = Theme.of(context).colorScheme;

              return Stack(
                children: [
                  GestureDetector(
                    onTap: isVideo ? () => _showVideoReview(file) : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Container(
                          color: isVideo ? cs.scrim : cs.surfaceContainerHighest,
                          child: isVideo
                              ? _buildVideoPreview(context, file)
                              : Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeMedia(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.inverseSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: cs.onInverseSurface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (isVideo)
                    GestureDetector(
                      onTap: isVideo ? () => _showVideoReview(file) : null,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: cs.onPrimary,
                          size: 40,
                        ),
                      ),
                    ),
                  if (_isGifFile(file))
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.inverseSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'GIF',
                          style: TextStyle(
                            color: cs.onInverseSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(BuildContext context, File file) {
    final cs = Theme.of(context).colorScheme;
    try {
      // Find the controller by matching the file index
      final fileIndex = _mediaFiles.indexOf(file);

      // Count how many videos come before this file
      int videoIndex = 0;
      for (int i = 0; i < fileIndex; i++) {
        if (_isVideoFile(_mediaFiles[i])) {
          videoIndex++;
        }
      }

      if (videoIndex >= _videoControllers.length) {
        return Container(
          color: cs.scrim,
          child: Center(
            child: CircularProgressIndicator(
              color: cs.primary,
              strokeWidth: 2,
            ),
          ),
        );
      }

      final controller = _videoControllers[videoIndex];

      return ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, VideoPlayerValue value, child) {
          if (!value.isInitialized) {
            return Center(
              child: CircularProgressIndicator(
                color: cs.primary,
                strokeWidth: 2,
              ),
            );
          }

          // Use FittedBox to fill the entire grid cell while cropping as needed
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: value.size.width,
              height: value.size.height,
              child: VideoPlayer(controller),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        color: cs.scrim,
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: cs.onSurfaceVariant,
            size: 40,
          ),
        ),
      );
    }
  }

  void _showVideoReview(File file) {
    final fileIndex = _mediaFiles.indexOf(file);
    int videoIndex = 0;
    for (int i = 0; i < fileIndex; i++) {
      if (_isVideoFile(_mediaFiles[i])) {
        videoIndex++;
      }
    }

    if (videoIndex >= _videoControllers.length) return;

    final controller = _videoControllers[videoIndex];

    showDialog(
      context: context,
      barrierColor: Theme.of(context).colorScheme.scrim,
      builder: (context) => VideoReviewDialog(
        controller: controller,
      ),
    );
  }

  Widget _buildAddMediaButton() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _pickMedia,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.photo_library,
                color: cs.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Add Photos/Videos/GIFs',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: cs.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoReviewDialog extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoReviewDialog({
    super.key,
    required this.controller,
  });

  @override
  State<VideoReviewDialog> createState() => _VideoReviewDialogState();
}

class _VideoReviewDialogState extends State<VideoReviewDialog> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 120,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Video Preview',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_isPlaying) {
                            widget.controller.pause();
                          }
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.close, color: cs.onSurface, size: 24),
                      ),
                    ],
                  ),
                ),
                // Video player
                AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ColoredBox(
                        color: cs.scrim,
                        child: VideoPlayer(widget.controller),
                      ),
                      // Play/Pause overlay
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cs.scrim.withOpacity(0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: cs.onPrimary,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Video controls
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      VideoProgressIndicator(
                        widget.controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: cs.primary,
                          bufferedColor: cs.primary.withOpacity(0.35),
                          backgroundColor: cs.outlineVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Time and controls
                      Row(
                        children: [
                          IconButton(
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder(
                            valueListenable: widget.controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return Text(
                                '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
