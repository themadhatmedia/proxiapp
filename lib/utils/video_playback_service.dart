import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import 'network_slot_limiter.dart';
import 'video_load_helper.dart';

/// Shared network video loading: disk cache when available, stream otherwise,
/// with in-memory controller reuse for the same URL.
class VideoPlaybackService {
  VideoPlaybackService._();
  static final VideoPlaybackService instance = VideoPlaybackService._();

  static final CacheManager _cache = CacheManager(
    Config(
      'proxi_videos',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 48,
    ),
  );

  static final VideoLoadHelper _videoLoader = VideoLoadHelper(_cache);

  final Map<String, Future<VideoPlayerController>> _inFlight = {};
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, VideoLoadPhase> _phaseByUrl = {};
  final Map<String, int> _obtainGeneration = {};

  VideoLoadPhase phaseFor(String url) => _phaseByUrl[url] ?? VideoLoadPhase.idle;

  void preload(String url) {
    if (url.isEmpty) return;
    unawaited(
      obtain(url).then((_) {}).catchError((Object e) {
        if (e is StateError && e.message == 'Video load cancelled') return;
        debugPrint('Video preload failed ($url): $e');
      }),
    );
  }

  /// Cancels in-flight loads and disposes any cached controller for [url].
  void cancelPending(String url) {
    if (url.isEmpty) return;
    _obtainGeneration[url] = (_obtainGeneration[url] ?? 0) + 1;
    _inFlight.remove(url);

    final c = _controllers.remove(url);
    if (c != null) {
      try {
        if (c.value.isInitialized && c.value.isPlaying) {
          c.pause();
        }
        c.dispose();
      } catch (_) {}
    }
    _phaseByUrl.remove(url);
  }

  Future<VideoPlayerController> obtain(
    String url, {
    void Function(VideoLoadPhase phase)? onPhase,
  }) async {
    if (url.isEmpty) {
      throw ArgumentError('Video URL is empty');
    }

    final gen = (_obtainGeneration[url] ?? 0) + 1;
    _obtainGeneration[url] = gen;

    final cached = _controllers[url];
    if (cached != null && cached.value.isInitialized) {
      try {
        if (cached.value.isPlaying) {
          await cached.pause();
        }
      } catch (_) {}
      _phaseByUrl[url] = VideoLoadPhase.ready;
      onPhase?.call(VideoLoadPhase.ready);
      return cached;
    }

    final pending = _inFlight[url];
    if (pending != null) return pending;

    void reportPhase(VideoLoadPhase phase) {
      _phaseByUrl[url] = phase;
      onPhase?.call(phase);
    }

    final future = NetworkSlotLimiter.instance.run(
      () => _videoLoader.load(
        url,
        mixWithOthers: true,
        onPhase: reportPhase,
      ),
    );
    _inFlight[url] = future;
    try {
      final controller = await future;
      if (_obtainGeneration[url] != gen) {
        try {
          await controller.pause();
          await controller.dispose();
        } catch (_) {}
        throw StateError('Video load cancelled');
      }
      _controllers[url] = controller;
      reportPhase(VideoLoadPhase.ready);
      return controller;
    } catch (e) {
      if (_obtainGeneration[url] == gen) {
        reportPhase(VideoLoadPhase.failed);
      }
      rethrow;
    } finally {
      if (identical(_inFlight[url], future)) {
        _inFlight.remove(url);
      }
    }
  }

  void release(String url, VideoPlayerController controller) {
    final current = _controllers[url];
    if (identical(current, controller)) {
      _controllers.remove(url);
    }
    _phaseByUrl.remove(url);
    try {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
      controller.dispose();
    } catch (_) {}
  }

  void releaseAll(Iterable<VideoPlayerController> controllers) {
    for (final c in controllers) {
      c.dispose();
    }
    _controllers.removeWhere((_, v) => controllers.contains(v));
  }
}
