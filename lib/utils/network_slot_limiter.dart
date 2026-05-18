import 'dart:async';

/// Limits concurrent heavy network work (video init) so REST calls are not starved.
class NetworkSlotLimiter {
  NetworkSlotLimiter._();
  static final NetworkSlotLimiter instance = NetworkSlotLimiter._();

  /// One decoder at a time avoids Android `pipelineFull: too many frames` on MTK devices.
  static const int maxConcurrent = 1;

  int _inUse = 0;
  final List<Completer<void>> _waitQueue = [];

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_inUse < maxConcurrent) {
      _inUse++;
      return;
    }
    final waiter = Completer<void>();
    _waitQueue.add(waiter);
    await waiter.future;
    _inUse++;
  }

  void _release() {
    _inUse--;
    if (_waitQueue.isEmpty) return;
    if (_inUse >= maxConcurrent) return;
    final next = _waitQueue.removeAt(0);
    if (!next.isCompleted) next.complete();
  }
}
