import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/auth_controller.dart';
import '../../data/services/api_service.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/toast_helper.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final AuthController authController = Get.find<AuthController>();
  final ApiService apiService = ApiService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _mediaFiles = [];
  final List<VideoPlayerController> _videoControllers = [];
  static const int maxMediaSize = 10 * 1024 * 1024; // 10MB

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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                ),
                title: const Text(
                  'Photo',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.gif_box,
                  color: Colors.white,
                ),
                title: const Text(
                  'GIF',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickGif();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.videocam,
                  color: Colors.white,
                ),
                title: const Text(
                  'Video',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),
                title: const Text(
                  'Camera',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
            ],
          ),
        ),
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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _capturePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white),
                title: const Text('Record Video', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _captureVideo();
                },
              ),
            ],
          ),
        ),
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

    if (content.isEmpty && _mediaFiles.isEmpty) {
      ToastHelper.showError('Please add content or media');
      return;
    }

    await ProgressDialogHelper.show(context);

    try {
      final token = authController.token;
      if (token == null) {
        throw Exception('Authentication required');
      }

      await apiService.createPost(
        token: token,
        content: content,
        mediaFiles: _mediaFiles.isNotEmpty ? _mediaFiles : null,
      );

      await ProgressDialogHelper.hide();
      ToastHelper.showSuccess('Post created successfully');
      Get.back(result: true);
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(
            color: Colors.white,
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: const Text(
                'Post',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF0A0A0A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      image: avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white60,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
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
                minLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 20),
              if (_mediaFiles.isNotEmpty) _buildMediaPreview(),
              const SizedBox(height: 20),
              _buildAddMediaButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media (${_mediaFiles.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _pickMedia,
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text(
                  'Add More',
                  style: TextStyle(color: Colors.white),
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

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Container(
                        color: isVideo ? Colors.black : Colors.black45,
                        child: isVideo
                            ? _buildVideoPreview(file)
                            : Image.file(
                                file,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
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
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (isVideo)
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  if (_isGifFile(file))
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'GIF',
                          style: TextStyle(
                            color: Colors.white,
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

  Widget _buildVideoPreview(File file) {
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
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
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
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
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
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.white54,
            size: 40,
          ),
        ),
      );
    }
  }

  Widget _buildAddMediaButton() {
    return InkWell(
      onTap: _pickMedia,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Add Photos/Videos/GIFs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
