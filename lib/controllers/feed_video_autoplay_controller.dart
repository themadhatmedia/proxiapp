import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';

import '../utils/network_slot_limiter.dart';
import '../utils/video_load_helper.dart';

/// Picks one feed video to play (most visible). Controllers are keyed by URL and
/// kept in a small cache so scrolling back does not reload.
class FeedVideoAutoplayController extends GetxController {
  final RxnString activeSlotId = RxnString();
  final RxInt generation = 0.obs;
  final RxBool isMuted = true.obs;

  final RxString activeFeedScope = 'inner'.obs;

  static final CacheManager _cache = CacheManager(
    Config(
      'proxi_feed_videos',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 40,
    ),
  );

  static final VideoLoadHelper _videoLoader = VideoLoadHelper(_cache);

  final Map<String, double> _visibilityScores = {};
  final Map<String, String> _slotUrls = {};
  final Map<String, VideoPlayerController> _controllersByUrl = {};
  final Map<String, Future<VideoPlayerController>> _initFuturesByUrl = {};
  final Map<String, Timer> _urlEvictTimers = {};
  final RxMap<String, VideoLoadPhase> loadPhaseByUrl = <String, VideoLoadPhase>{}.obs;
  final List<String> _lruUrls = [];

  Timer? _pickTimer;

  static const double _minVisibleToPlay = 0.38;
  static const Duration _evictDelay = Duration(minutes: 3);
  static const Duration _pickDebounce = Duration(milliseconds: 180);
  /// Cached decoders kept paused (scroll-back reuses without reload).
  static const int _maxCachedControllers = 5;

  bool _slotInActiveScope(String slotId) =>
      slotId.startsWith('${activeFeedScope.value}_');

  String? get _activeUrl {
    final id = activeSlotId.value;
    if (id == null) return null;
    return _slotUrls[id];
  }

  VideoLoadPhase phaseForUrl(String? url) {
    if (url == null || url.isEmpty) return VideoLoadPhase.idle;
    return loadPhaseByUrl[url] ?? VideoLoadPhase.idle;
  }

  void _setLoadPhase(String url, VideoLoadPhase phase) {
    if (loadPhaseByUrl[url] == phase) return;
    loadPhaseByUrl[url] = phase;
  }

  void _touchUrl(String url) {
    _lruUrls.remove(url);
    _lruUrls.add(url);
  }

  void switchFeedScope(String scope) {
    if (activeFeedScope.value == scope) {
      _schedulePick();
      return;
    }

    activeFeedScope.value = scope;

    final prevActive = activeSlotId.value;
    if (prevActive != null && !_slotInActiveScope(prevActive)) {
      pauseSlot(prevActive);
      activeSlotId.value = null;
      generation.value++;
    }

    _visibilityScores.removeWhere((id, _) => !_slotInActiveScope(id));

    for (final url in _urlsForScope(activeFeedScope.value == 'inner' ? 'outer' : 'inner')) {
      _pauseUrl(url);
    }

    _schedulePick();
    SchedulerBinding.instance.addPostFrameCallback((_) => _schedulePick());
  }

  Iterable<String> _urlsForScope(String scope) sync* {
    for (final entry in _slotUrls.entries) {
      if (entry.key.startsWith('${scope}_')) yield entry.value;
    }
  }

  void reportVisibility({
    required String slotId,
    required String videoUrl,
    required double visibleFraction,
  }) {
    if (!_slotInActiveScope(slotId)) return;

    _slotUrls[slotId] = videoUrl;
    _urlEvictTimers[videoUrl]?.cancel();
    _urlEvictTimers.remove(videoUrl);

    if (visibleFraction < 0.02) {
      _visibilityScores.remove(slotId);
      _scheduleUrlEvict(videoUrl);
    } else {
      _visibilityScores[slotId] = visibleFraction;
    }
    _schedulePick();
  }

  void unregisterSlot(String slotId) {
    _visibilityScores.remove(slotId);
    _slotUrls.remove(slotId);
    _schedulePick();
  }

  void _scheduleUrlEvict(String url) {
    if (url.isEmpty) return;
    if (_activeUrl == url) return;

    _urlEvictTimers[url]?.cancel();
    _urlEvictTimers[url] = Timer(_evictDelay, () {
      if (_activeUrl == url) return;
      if (_slotUrls.values.contains(url)) return;
      _disposeUrl(url);
    });
  }

  void _schedulePick() {
    _pickTimer?.cancel();
    _pickTimer = Timer(_pickDebounce, _pickActiveSlot);
  }

  void refreshVisibilityDetection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VisibilityDetectorController.instance.notifyNow();
      _schedulePick();
    });
  }

  void primeSlot({required String slotId, required String videoUrl}) {
    if (videoUrl.isEmpty) return;
    reportVisibility(slotId: slotId, videoUrl: videoUrl, visibleFraction: 1.0);
  }

  Future<void> retrySlot(String slotId) async {
    final url = _slotUrls[slotId];
    if (url == null || url.isEmpty) return;

    _initFuturesByUrl.remove(url);
    loadPhaseByUrl.remove(url);
    final existing = _controllersByUrl.remove(url);
    _lruUrls.remove(url);
    if (existing != null) {
      try {
        await existing.dispose();
      } catch (_) {}
    }

    activeSlotId.value = slotId;
    generation.value++;
    await playSlot(slotId);
  }

  void _pickActiveSlot() {
    final previous = activeSlotId.value;

    final scopedScores = Map<String, double>.fromEntries(
      _visibilityScores.entries.where((e) => _slotInActiveScope(e.key)),
    );

    if (scopedScores.isEmpty) {
      if (previous != null) {
        pauseSlot(previous);
        activeSlotId.value = null;
        generation.value++;
      }
      return;
    }

    var bestId = '';
    var bestScore = 0.0;
    for (final entry in scopedScores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestId = entry.key;
      }
    }

    if (bestScore < _minVisibleToPlay) {
      if (previous != null) {
        pauseSlot(previous);
        activeSlotId.value = null;
        generation.value++;
      }
      return;
    }

    if (previous != null && previous != bestId) {
      pauseSlot(previous);
    }

    if (activeSlotId.value != bestId) {
      activeSlotId.value = bestId;
      generation.value++;
    }

    unawaited(playSlot(bestId));
  }

  bool isActive(String slotId) => activeSlotId.value == slotId;

  VideoPlayerController? controllerFor(String slotId) {
    final url = _slotUrls[slotId];
    if (url == null || url.isEmpty) return null;
    return controllerForUrl(url);
  }

  VideoPlayerController? controllerForUrl(String url) {
    final c = _controllersByUrl[url];
    if (c == null) return null;
    if (!_isControllerUsable(c)) {
      _controllersByUrl.remove(url);
      _lruUrls.remove(url);
      return null;
    }
    return c;
  }

  bool isReady(String slotId) {
    final url = _slotUrls[slotId];
    if (url == null) return false;
    return isReadyForUrl(url);
  }

  bool isReadyForUrl(String url) =>
      phaseForUrl(url) == VideoLoadPhase.ready && controllerForUrl(url) != null;

  bool _isControllerUsable(VideoPlayerController c) {
    try {
      // ignore: invalid_use_of_protected_member
      c.value;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<VideoPlayerController> _ensureController(String videoUrl) async {
    final existing = controllerForUrl(videoUrl);
    if (existing != null && existing.value.isInitialized) {
      _setLoadPhase(videoUrl, VideoLoadPhase.ready);
      _touchUrl(videoUrl);
      return existing;
    }

    final pending = _initFuturesByUrl[videoUrl];
    if (pending != null) return pending;

    final future = NetworkSlotLimiter.instance.run(
      () => _videoLoader.load(
        videoUrl,
        mixWithOthers: false,
        onPhase: (phase) => _setLoadPhase(videoUrl, phase),
      ),
    );
    _initFuturesByUrl[videoUrl] = future;
    try {
      final c = await future;
      _controllersByUrl[videoUrl] = c;
      _setLoadPhase(videoUrl, VideoLoadPhase.ready);
      _touchUrl(videoUrl);
      _trimCacheExcept(videoUrl);
      await c.setLooping(true);
      await c.setVolume(isMuted.value ? 0.0 : 1.0);
      return c;
    } catch (e) {
      _setLoadPhase(videoUrl, VideoLoadPhase.failed);
      rethrow;
    } finally {
      _initFuturesByUrl.remove(videoUrl);
    }
  }

  void _trimCacheExcept(String protectUrl) {
    while (_controllersByUrl.length > _maxCachedControllers) {
      String? victim;
      for (final url in _lruUrls) {
        if (url != protectUrl && url != _activeUrl) {
          victim = url;
          break;
        }
      }
      if (victim == null) {
        for (final url in _controllersByUrl.keys) {
          if (url != protectUrl && url != _activeUrl) {
            victim = url;
            break;
          }
        }
      }
      if (victim == null) break;
      _disposeUrl(victim);
    }
  }

  Future<void> playSlot(String slotId) async {
    if (!_slotInActiveScope(slotId)) return;
    final url = _slotUrls[slotId];
    if (url == null || url.isEmpty) return;
    if (activeSlotId.value != slotId) return;

    try {
      final c = await _ensureController(url);
      if (activeSlotId.value != slotId) return;
      if (!_isControllerUsable(c)) return;

      await c.setVolume(isMuted.value ? 0.0 : 1.0);
      if (!c.value.isPlaying) {
        await c.play();
      }
    } catch (e) {
      debugPrint('Feed playSlot failed ($slotId): $e');
      _setLoadPhase(url, VideoLoadPhase.failed);
      generation.value++;
    }
  }

  void pauseSlot(String slotId) {
    final url = _slotUrls[slotId];
    if (url != null) _pauseUrl(url);
  }

  void _pauseUrl(String url) {
    final c = _controllersByUrl[url];
    if (c == null || !_isControllerUsable(c)) return;
    try {
      if (c.value.isInitialized && c.value.isPlaying) {
        c.pause();
      }
    } catch (e) {
      debugPrint('Feed pauseUrl ($url): $e');
    }
  }

  void pauseAll() {
    _pickTimer?.cancel();
    _visibilityScores.clear();
    activeSlotId.value = null;
    generation.value++;
    for (final url in _controllersByUrl.keys.toList()) {
      _pauseUrl(url);
    }
  }

  void toggleMuted() {
    isMuted.value = !isMuted.value;
    final url = _activeUrl;
    if (url == null) return;
    final c = _controllersByUrl[url];
    if (c == null || !_isControllerUsable(c) || !c.value.isInitialized) return;
    try {
      c.setVolume(isMuted.value ? 0.0 : 1.0);
    } catch (_) {}
  }

  void _disposeUrl(String url) {
    _urlEvictTimers[url]?.cancel();
    _urlEvictTimers.remove(url);
    _initFuturesByUrl.remove(url);
    _lruUrls.remove(url);
    final c = _controllersByUrl.remove(url);
    if (c != null) {
      try {
        c.dispose();
      } catch (_) {}
    }
    loadPhaseByUrl.remove(url);
  }

  @override
  void onClose() {
    _pickTimer?.cancel();
    for (final t in _urlEvictTimers.values) {
      t.cancel();
    }
    _urlEvictTimers.clear();
    for (final url in _controllersByUrl.keys.toList()) {
      _disposeUrl(url);
    }
    super.onClose();
  }
}
