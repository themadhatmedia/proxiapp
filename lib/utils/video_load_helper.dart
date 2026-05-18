import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Phases reported while opening a remote video.
enum VideoLoadPhase {
  idle,
  loadingCache,
  streaming,
  downloading,
  ready,
  failed,
}

/// Opens remote videos reliably: cache → short stream attempt → full download → file play.
///
/// Large iPhone `.mov` files (100MB+) often cannot stream within ExoPlayer's default
/// timeouts; downloading first is required.
class VideoLoadHelper {
  VideoLoadHelper(this.cacheManager);

  final CacheManager cacheManager;

  static const Duration streamTimeout = Duration(seconds: 25);
  static const Duration downloadTimeout = Duration(minutes: 10);
  static const Duration fileInitTimeout = Duration(seconds: 60);

  Future<VideoPlayerController> load(
    String url, {
    ValueChanged<VideoLoadPhase>? onPhase,
    bool mixWithOthers = false,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Video URL is empty');
    }

    onPhase?.call(VideoLoadPhase.loadingCache);
    try {
      final cached = await cacheManager.getFileFromCache(trimmed);
      if (cached != null && await cached.file.exists()) {
        final c = await _initFile(cached.file, mixWithOthers: mixWithOthers);
        onPhase?.call(VideoLoadPhase.ready);
        return c;
      }
    } catch (e) {
      debugPrint('VideoLoadHelper cache read ($trimmed): $e');
    }

    onPhase?.call(VideoLoadPhase.streaming);
    VideoPlayerController? streamController;
    try {
      streamController = VideoPlayerController.networkUrl(
        Uri.parse(trimmed),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: mixWithOthers),
      );
      await streamController.initialize().timeout(streamTimeout);
      onPhase?.call(VideoLoadPhase.ready);
      unawaited(_cacheInBackground(trimmed));
      return streamController;
    } catch (e) {
      debugPrint('VideoLoadHelper stream ($trimmed): $e');
      await _safeDispose(streamController);
    }

    onPhase?.call(VideoLoadPhase.downloading);
    try {
      final file = await cacheManager.getSingleFile(trimmed).timeout(downloadTimeout);
      if (!await file.exists()) {
        throw StateError('Downloaded video missing on disk');
      }
      final c = await _initFile(file, mixWithOthers: mixWithOthers);
      onPhase?.call(VideoLoadPhase.ready);
      return c;
    } catch (e) {
      onPhase?.call(VideoLoadPhase.failed);
      debugPrint('VideoLoadHelper download ($trimmed): $e');
      rethrow;
    }
  }

  Future<void> _cacheInBackground(String url) async {
    try {
      final hit = await cacheManager.getFileFromCache(url);
      if (hit != null && await hit.file.exists()) return;
      await cacheManager.downloadFile(url).timeout(downloadTimeout);
    } catch (e) {
      debugPrint('VideoLoadHelper background cache ($url): $e');
    }
  }

  Future<VideoPlayerController> _initFile(
    File file, {
    required bool mixWithOthers,
  }) async {
    final c = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: mixWithOthers),
    );
    await c.initialize().timeout(fileInitTimeout);
    return c;
  }

  static Future<void> _safeDispose(VideoPlayerController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {}
  }
}
