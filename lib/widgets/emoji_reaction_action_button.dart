import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../utils/app_vibration.dart';

/// Single active picker overlay (posts + messages share one slot).
OverlayEntry? _floatingReactionOverlayEntry;

final List<VoidCallback> _floatingReactionPickerClearRefsCallbacks = [];

void _registerFloatingReactionPickerClearRefs(VoidCallback cb) {
  _floatingReactionPickerClearRefsCallbacks.add(cb);
}

void _unregisterFloatingReactionPickerClearRefs(VoidCallback cb) {
  _floatingReactionPickerClearRefsCallbacks.remove(cb);
}

const double _kReactionPillEmojiSize = 22;
const double _kReactionPillRadius = 22;
const double _kReactionPillViewportPadding = 10;

/// Shared overlay pill (posts button + message long-press).
OverlayEntry buildReactionPickerOverlayEntry({
  required LayerLink layerLink,
  required VoidCallback removeOverlay,
  required Future<void> Function(String emoji) onEmojiChosen,
  required List<String> reactionEmojis,
  required String? pickerSelectionEmoji,
  required Brightness brightness,
  Widget? bottomMenuChild,
}) {
  final isDark = brightness == Brightness.dark;
  final selected = pickerSelectionEmoji;

  Future<void> onPick(String emoji) async {
    removeOverlay();
    await onEmojiChosen(emoji);
  }

  return OverlayEntry(
    builder: (overlayContext) {
      final mqOverlay = MediaQuery.of(overlayContext);
      final maxBarWidth = (mqOverlay.size.width -
              mqOverlay.padding.horizontal -
              2 * _kReactionPillViewportPadding)
          .clamp(120.0, double.infinity);

      final selectedReactionFill =
          isDark ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.52);
      final selectedReactionOutline =
          isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.06);
      final selectedReactionShadow = Colors.black.withOpacity(isDark ? 0.14 : 0.06);

      return Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => removeOverlay(),
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.35),
                ),
              ),
            ),
          ),
          CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.bottomCenter,
            targetAnchor: Alignment.topCenter,
            offset: const Offset(0, -8),
            child: _ViewportClampTransform(
              mediaQueryContext: overlayContext,
              edgePadding: _kReactionPillViewportPadding,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kReactionPillRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxBarWidth),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xD9141418)
                            : Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(_kReactionPillRadius),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final emoji in reactionEmojis)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => onPick(emoji),
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected == emoji ? selectedReactionFill : null,
                                        border: selected == emoji
                                            ? Border.all(color: selectedReactionOutline, width: 1)
                                            : null,
                                        boxShadow: selected == emoji
                                            ? [
                                                BoxShadow(
                                                  color: selectedReactionShadow,
                                                  blurRadius: 6,
                                                  spreadRadius: -2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(
                                            fontSize: _kReactionPillEmojiSize,
                                            height: 1.05,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (bottomMenuChild != null)
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.topCenter,
              targetAnchor: Alignment.bottomCenter,
              offset: const Offset(0, 10),
              child: _ViewportClampTransform(
                mediaQueryContext: overlayContext,
                edgePadding: _kReactionPillViewportPadding,
                child: Material(
                  color: Colors.transparent,
                  child: bottomMenuChild,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Long-press anywhere on [child] to show the same floating emoji row as posts (no visible React chip).
class ReactionPickerLongPress extends StatefulWidget {
  const ReactionPickerLongPress({
    super.key,
    required this.child,
    required this.reactionEmojis,
    required this.pickerSelectionEmoji,
    required this.onEmojiChosen,
    this.enabled = true,
    this.bottomMenuBuilder,
  });

  final Widget child;
  final List<String> reactionEmojis;
  final String? pickerSelectionEmoji;
  final Future<void> Function(String emoji) onEmojiChosen;
  final bool enabled;
  final Widget Function(VoidCallback closeOverlay)? bottomMenuBuilder;

  @override
  State<ReactionPickerLongPress> createState() => _ReactionPickerLongPressState();
}

class _ReactionPickerLongPressState extends State<ReactionPickerLongPress> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _clearOverlayReferenceOnly() {
    _overlayEntry = null;
  }

  @override
  void initState() {
    super.initState();
    _registerFloatingReactionPickerClearRefs(_clearOverlayReferenceOnly);
  }

  @override
  void dispose() {
    _unregisterFloatingReactionPickerClearRefs(_clearOverlayReferenceOnly);
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    if (_floatingReactionOverlayEntry == entry) {
      _floatingReactionOverlayEntry = null;
    }
    entry.remove();
    entry.dispose();
  }

  void _showPicker() {
    if (!mounted || !widget.enabled) return;
    EmojiReactionActionButton.dismissFloatingReactionPicker();

    AppVibration.reactionPickerOpen();

    _overlayEntry = buildReactionPickerOverlayEntry(
      layerLink: _layerLink,
      removeOverlay: _removeOverlay,
      onEmojiChosen: widget.onEmojiChosen,
      reactionEmojis: widget.reactionEmojis,
      pickerSelectionEmoji: widget.pickerSelectionEmoji,
      brightness: Theme.of(context).brightness,
      bottomMenuChild: widget.bottomMenuBuilder?.call(_removeOverlay),
    );

    _floatingReactionOverlayEntry = _overlayEntry;
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onLongPress: _showPicker,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}

/// Tap = quick reaction toggle (caller chooses emoji); long-press = floating pill above the chip.
class EmojiReactionActionButton extends StatefulWidget {
  const EmojiReactionActionButton({
    super.key,
    required this.reactionEmojis,
    required this.displayEmoji,
    required this.pickerSelectionEmoji,
    required this.hasMine,
    required this.enabled,
    required this.isLoading,
    required this.onQuickTap,
    required this.onEmojiChosen,
    this.compact = false,
  });

  final List<String> reactionEmojis;
  /// Leading glyph on the chip (may differ from [pickerSelectionEmoji] for legacy “liked” UI).
  final String? displayEmoji;
  /// Highlight ring in the long-press picker (typically `reactions?.myEmoji` only).
  final String? pickerSelectionEmoji;
  final bool hasMine;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onQuickTap;
  final Future<void> Function(String emoji) onEmojiChosen;
  final bool compact;

  /// Closes any open long-press reaction bar (feed posts, messages, sheets).
  static void dismissFloatingReactionPicker() {
    final entry = _floatingReactionOverlayEntry;
    _floatingReactionOverlayEntry = null;
    entry?.remove();
    entry?.dispose();
    for (final cb in List<VoidCallback>.from(_floatingReactionPickerClearRefsCallbacks)) {
      cb();
    }
  }

  @override
  State<EmojiReactionActionButton> createState() => _EmojiReactionActionButtonState();
}

/// After layout, shifts [child] so it stays inside the viewport.
class _ViewportClampTransform extends StatefulWidget {
  const _ViewportClampTransform({
    required this.mediaQueryContext,
    required this.edgePadding,
    required this.child,
  });

  final BuildContext mediaQueryContext;
  final double edgePadding;
  final Widget child;

  @override
  State<_ViewportClampTransform> createState() => _ViewportClampTransformState();
}

class _ViewportClampTransformState extends State<_ViewportClampTransform> {
  final GlobalKey _measureKey = GlobalKey();
  Offset _nudge = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _clamp());
  }

  void _clamp() {
    final ctx = _measureKey.currentContext;
    if (ctx == null || !mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final mq = MediaQuery.of(widget.mediaQueryContext);
    final pad = widget.edgePadding;
    final leftBound = mq.padding.left + pad;
    final rightBound = mq.size.width - mq.padding.right - pad;
    final topBound = mq.padding.top + pad;
    final bottomBound = mq.size.height - mq.padding.bottom - pad;

    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    final rect = topLeft & size;

    double correctionDx = 0;
    double correctionDy = 0;
    if (rect.left < leftBound) correctionDx += leftBound - rect.left;
    if (rect.right > rightBound) correctionDx += rightBound - rect.right;
    if (rect.top < topBound) correctionDy += topBound - rect.top;
    if (rect.bottom > bottomBound) correctionDy += bottomBound - rect.bottom;

    if (correctionDx.abs() < 0.01 && correctionDy.abs() < 0.01) return;

    final next = _nudge + Offset(correctionDx, correctionDy);
    setState(() => _nudge = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _clamp());
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _nudge,
      child: KeyedSubtree(
        key: _measureKey,
        child: widget.child,
      ),
    );
  }
}

class _EmojiReactionActionButtonState extends State<EmojiReactionActionButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _clearOverlayReferenceOnly() {
    _overlayEntry = null;
  }

  @override
  void initState() {
    super.initState();
    _registerFloatingReactionPickerClearRefs(_clearOverlayReferenceOnly);
  }

  @override
  void dispose() {
    _unregisterFloatingReactionPickerClearRefs(_clearOverlayReferenceOnly);
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    if (_floatingReactionOverlayEntry == entry) {
      _floatingReactionOverlayEntry = null;
    }
    entry.remove();
    entry.dispose();
  }

  void _showFloatingReactionBar() {
    if (!mounted) return;
    EmojiReactionActionButton.dismissFloatingReactionPicker();

    AppVibration.reactionPickerOpen();

    _overlayEntry = buildReactionPickerOverlayEntry(
      layerLink: _layerLink,
      removeOverlay: _removeOverlay,
      onEmojiChosen: widget.onEmojiChosen,
      reactionEmojis: widget.reactionEmojis,
      pickerSelectionEmoji: widget.pickerSelectionEmoji,
      brightness: Theme.of(context).brightness,
    );

    _floatingReactionOverlayEntry = _overlayEntry;
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compact = widget.compact;
    final hPad = compact ? 10.0 : 16.0;
    final vPad = compact ? 6.0 : 12.0;
    final leading = compact ? 15.0 : 18.0;
    final labelSize = compact ? 12.0 : 14.0;
    final gap = compact ? 6.0 : 8.0;
    final emoji = widget.displayEmoji;
    final canPress = widget.enabled && !widget.isLoading;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canPress
              ? () {
                  EmojiReactionActionButton.dismissFloatingReactionPicker();
                  widget.onQuickTap();
                }
              : null,
          onLongPress: canPress ? _showFloatingReactionBar : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outline.withOpacity(0.35), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: leading,
                    height: leading,
                    child: CircularProgressIndicator(
                      strokeWidth: compact ? 1.5 : 1.75,
                      color: cs.primary,
                    ),
                  )
                else if (emoji != null && emoji.isNotEmpty)
                  Text(
                    emoji,
                    style: TextStyle(
                      fontSize: leading,
                      height: 1,
                    ),
                  )
                else
                  Icon(
                    Icons.add_reaction_outlined,
                    color: canPress ? cs.onSurfaceVariant : cs.onSurfaceVariant.withOpacity(0.3),
                    size: leading,
                  ),
                SizedBox(width: gap),
                Text(
                  'React',
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                    color: !canPress
                        ? cs.onSurface.withOpacity(0.35)
                        : (widget.hasMine ? cs.primary : cs.onSurface.withOpacity(0.95)),
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
