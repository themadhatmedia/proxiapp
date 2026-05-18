import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoTrimHelper {
  VideoTrimHelper._();

  static const Duration maxDuration = Duration(seconds: 15);

  /// Short clips under this length skip the trim UI only when the file is small enough to upload.
  static const int maxBytesWithoutTranscode = 14 * 1024 * 1024;

  /// Opens the trim screen for every video. It loads [Trimmer] after [TrimViewer] is in the
  /// tree so `TrimmerEvent.initialized` is not missed (otherwise the filmstrip stays blank).
  /// If the file is already ≤15s, the screen pops itself with the same path so we only pay
  /// for **one** decode, not a separate duration probe plus trimmer.
  static Future<File?> enforceMaxDuration(BuildContext context, File source) async {
    final outPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _VideoTrimScreen(
          source: source,
          maxDuration: maxDuration,
        ),
      ),
    );
    if (outPath == null || outPath.isEmpty) return null;
    final file = File(outPath);
    if (!file.existsSync()) return null;
    return file;
  }
}

class _VideoTrimScreen extends StatefulWidget {
  const _VideoTrimScreen({
    required this.source,
    required this.maxDuration,
  });

  final File source;
  final Duration maxDuration;

  @override
  State<_VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<_VideoTrimScreen> {
  final Trimmer _trimmer = Trimmer();

  /// True after [Trimmer.loadVideo] completes (preview + filmstrip are usable).
  bool _ready = false;

  bool _saving = false;
  bool _autoCompressing = false;
  bool _isPlaying = false;
  String? _loadError;

  /// Start/end positions from [TrimViewer] (milliseconds).
  double _startMs = 0;
  double _endMs = 0;

  /// Total video length in milliseconds.
  double _totalMs = 0;

  @override
  void initState() {
    super.initState();
    // Build [TrimViewer] on the first frame so it subscribes to [eventStream] before
    // `loadVideo` emits [TrimmerEvent.initialized].
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadVideo());
    });
  }

  Future<void> _loadVideo() async {
    setState(() {
      _loadError = null;
      _ready = false;
    });
    try {
      await _trimmer.loadVideo(videoFile: widget.source);
      final c = _trimmer.videoPlayerController;
      if (c == null || !c.value.isInitialized) {
        throw StateError('Video failed to load');
      }
      _totalMs = c.value.duration.inMilliseconds.toDouble();
      final bytes = await widget.source.length();

      if (c.value.duration <= widget.maxDuration &&
          bytes <= VideoTrimHelper.maxBytesWithoutTranscode) {
        if (mounted) Navigator.of(context).pop(widget.source.path);
        return;
      }

      if (c.value.duration <= widget.maxDuration &&
          bytes > VideoTrimHelper.maxBytesWithoutTranscode) {
        await _autoCompressShortClip();
        return;
      }

      await c.pause();
      await c.seekTo(Duration.zero);
      final cap = widget.maxDuration.inMilliseconds.toDouble();
      _startMs = 0;
      _endMs = math.min(_totalMs, cap);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Could not open video';
          _ready = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _disposePlayback() async {
    final c = _trimmer.videoPlayerController;
    if (c != null) {
      try {
        await c.pause();
      } catch (_) {}
      try {
        await c.dispose();
      } catch (_) {}
    }
    try {
      _trimmer.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _trimmer.videoPlayerController?.pause();
    } catch (_) {}
    super.dispose();
    // Let [TrimViewer] / [VideoViewer] dispose first; then drop native video + trimmer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_disposePlayback());
    });
  }

  Future<void> _autoCompressShortClip() async {
    if (!mounted) return;
    setState(() {
      _autoCompressing = true;
      _loadError = null;
    });
    try {
      final maxMs = widget.maxDuration.inMilliseconds.toDouble();
      final endMs = math.min(_totalMs > 0 ? _totalMs : maxMs, maxMs);
      final completer = Completer<String?>();
      await _trimmer.saveTrimmedVideo(
        startValue: 0,
        endValue: endMs,
        onSave: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );
      final out = await completer.future.timeout(const Duration(minutes: 5));
      if (!mounted) return;
      if (out != null && out.isNotEmpty) {
        Navigator.of(context).pop(out);
        return;
      }
      setState(() {
        _autoCompressing = false;
        _loadError = 'Could not compress video';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoCompressing = false;
        _loadError = 'Could not compress video';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_ready) return;
    setState(() => _saving = true);
    try {
      final maxMs = widget.maxDuration.inMilliseconds.toDouble();
      final span = _endMs - _startMs;
      final safeEndMs = span > maxMs ? _startMs + maxMs : _endMs;

      final completer = Completer<String?>();
      await _trimmer.saveTrimmedVideo(
        startValue: _startMs,
        endValue: safeEndMs,
        onSave: (path) => completer.complete(path),
      );
      final out = await completer.future;
      if (!mounted) return;
      // Do not setState after pop — the route can be defunct while `mounted` is still true.
      Navigator.of(context).pop(out);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePreview() async {
    if (!_ready) return;
    final end = _endMs <= 0 ? _totalMs : _endMs;
    await _trimmer.videoPlaybackControl(
      startValue: _startMs,
      endValue: end,
    );
    if (mounted) {
      setState(() {
        _isPlaying = _trimmer.videoPlayerController?.value.isPlaying ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxSec = widget.maxDuration.inSeconds;
    final viewerW = MediaQuery.of(context).size.width - 32;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          final c = _trimmer.videoPlayerController;
          try {
            await c?.pause();
          } catch (_) {}
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trim Video'),
          actions: [
            TextButton(
              onPressed: _saving || !_ready ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : const Text('Use clip'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'The whole video is shown on one strip. Drag the highlighted '
                  'window (or its edges) to pick up to $maxSec seconds from anywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoViewer(trimmer: _trimmer),
                      if ((!_ready || _autoCompressing) && _loadError == null)
                        ColoredBox(
                          color: cs.surface.withOpacity(0.65),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                if (_autoCompressing) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Compressing video for upload…',
                                    style: TextStyle(color: cs.onSurface),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (_loadError != null)
                        ColoredBox(
                          color: cs.surface.withOpacity(0.85),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, color: cs.error),
                                const SizedBox(height: 8),
                                Text(_loadError!, style: TextStyle(color: cs.onSurface)),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _loadVideo,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 104),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_ready && _loadError == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Preparing filmstrip…',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 72,
                      viewerWidth: viewerW,
                      // Fixed = full timeline on one filmstrip; scrollable only shows ~15s+padding
                      // in the viewport and is easy to mistake for “the whole video”.
                      type: ViewerType.fixed,
                      maxVideoLength: widget.maxDuration,
                      durationStyle: DurationStyle.FORMAT_HH_MM_SS,
                      areaProperties: const TrimAreaProperties(
                        thumbnailQuality: 45,
                        borderRadius: 6,
                      ),
                      onChangeStart: (v) => _startMs = v,
                      onChangeEnd: (v) => _endMs = v,
                      onChangePlaybackState: (playing) {
                        if (!mounted || _saving) return;
                        setState(() => _isPlaying = playing);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (!_ready) || _saving ? null : _togglePreview,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlaying ? 'Pause preview' : 'Preview'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving || !_ready ? null : _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
