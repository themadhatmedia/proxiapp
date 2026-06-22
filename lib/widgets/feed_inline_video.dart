import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';

import '../controllers/feed_video_autoplay_controller.dart';
import '../utils/video_load_helper.dart';
import 'video_thumbnail_preview.dart';

/// In-feed autoplay video (Wins wall): plays when most visible, muted by default.
class FeedInlineVideo extends StatefulWidget {
  const FeedInlineVideo({
    super.key,
    required this.slotId,
    required this.videoUrl,
    this.posterUrl,
    this.onOpenFullscreen,
    this.borderRadius = BorderRadius.zero,
  });

  final String slotId;
  final String videoUrl;
  final String? posterUrl;
  final VoidCallback? onOpenFullscreen;
  final BorderRadius borderRadius;

  @override
  State<FeedInlineVideo> createState() => _FeedInlineVideoState();
}

class _FeedInlineVideoState extends State<FeedInlineVideo> {
  FeedVideoAutoplayController get _coordinator => Get.find<FeedVideoAutoplayController>();

  Worker? _activeWorker;
  Worker? _generationWorker;
  Worker? _muteWorker;
  Worker? _scopeWorker;
  Worker? _phaseWorker;

  double _lastVisibleFraction = 0;
  VideoLoadPhase _phase = VideoLoadPhase.idle;
  bool _wasActive = false;

  bool get _inActiveScope {
    final scope = _coordinator.activeFeedScope.value;
    return widget.slotId.startsWith('${scope}_');
  }

  @override
  void initState() {
    super.initState();
    _phase = _coordinator.phaseForUrl(widget.videoUrl);

    _activeWorker = ever<String?>(_coordinator.activeSlotId, (_) => _syncFromCoordinator());
    _generationWorker = ever<int>(_coordinator.generation, (_) => _syncFromCoordinator());
    _muteWorker = ever<bool>(_coordinator.isMuted, (_) {
      if (mounted) setState(() {});
    });
    _scopeWorker = ever<String>(_coordinator.activeFeedScope, (_) {
      _rereportVisibility();
      _syncFromCoordinator();
    });
    _phaseWorker = ever(_coordinator.loadPhaseByUrl, (_) {
      if (!mounted) return;
      final next = _coordinator.phaseForUrl(widget.videoUrl);
      if (next == _phase) return;
      _phase = next;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _activeWorker?.dispose();
    _generationWorker?.dispose();
    _muteWorker?.dispose();
    _scopeWorker?.dispose();
    _phaseWorker?.dispose();
    _coordinator.unregisterSlot(widget.slotId);
    super.dispose();
  }

  void _rereportVisibility() {
    if (!mounted || !_inActiveScope) return;
    if (_lastVisibleFraction < 0.02) return;
    _coordinator.reportVisibility(
      slotId: widget.slotId,
      videoUrl: widget.videoUrl,
      visibleFraction: _lastVisibleFraction,
    );
  }

  void _syncFromCoordinator() {
    if (!mounted) return;
    final nextPhase = _coordinator.phaseForUrl(widget.videoUrl);
    final nowActive = _coordinator.isActive(widget.slotId);
    final shouldRebuild =
        nextPhase != _phase || nowActive != _wasActive;
    _phase = nextPhase;
    _wasActive = nowActive;

    if (nowActive) {
      unawaited(_coordinator.playSlot(widget.slotId));
    } else {
      _coordinator.pauseSlot(widget.slotId);
    }

    if (shouldRebuild) setState(() {});
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    _lastVisibleFraction = info.visibleFraction;
    if (!_inActiveScope) return;
    _coordinator.reportVisibility(
      slotId: widget.slotId,
      videoUrl: widget.videoUrl,
      visibleFraction: info.visibleFraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _coordinator.isActive(widget.slotId) && _inActiveScope;
    final controller =
        _coordinator.controllerForUrl(widget.videoUrl) ?? _coordinator.controllerFor(widget.slotId);
    final ready = controller != null && controller.value.isInitialized;
    final loading = active && !ready && _phase != VideoLoadPhase.failed;
    final failed = active && _phase == VideoLoadPhase.failed;
    final downloading = _phase == VideoLoadPhase.downloading;

    return RepaintBoundary(
      child: VisibilityDetector(
        key: Key('feed_video_${widget.slotId}'),
        onVisibilityChanged: _onVisibilityChanged,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: GestureDetector(
            onTap: () {
              if (failed) {
                unawaited(_coordinator.retrySlot(widget.slotId));
                return;
              }
              _coordinator.pauseAll();
              widget.onOpenFullscreen?.call();
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (ready)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                else
                  VideoThumbnailPreview(
                    videoUrl: widget.videoUrl,
                    posterUrl: widget.posterUrl,
                    showIconOnPlaceholder: false,
                    maxThumbnailWidth: 720,
                  ),
                if (loading)
                  ColoredBox(
                    color: const Color(0x66000000),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2,
                            ),
                          ),
                          if (downloading) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Downloading video…',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (failed)
                  ColoredBox(
                    color: const Color(0x88000000),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Video could not load',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to retry',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (active && ready)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Obx(
                      () => GestureDetector(
                        onTap: _coordinator.toggleMuted,
                        behavior: HitTestBehavior.opaque,
                        child: _MuteButton(muted: _coordinator.isMuted.value),
                      ),
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

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
