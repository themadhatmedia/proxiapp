import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Clears focus so the soft keyboard hides (safe to call anytime).
void unfocusKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

bool _focusIsInEditableTextField(FocusNode focus) {
  final ctx = focus.context;
  if (ctx == null) return false;
  return ctx.findAncestorStateOfType<EditableTextState>() != null;
}

/// Best-effort bounds of the surrounding text field (not just the inner editable).
RenderBox? _textInputRenderBox(FocusNode focus) {
  final ctx = focus.context;
  if (ctx == null) return null;

  RenderBox? found;
  ctx.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is TextField || w is TextFormField || w is CupertinoTextField) {
      found = ancestor.findRenderObject() as RenderBox?;
      return false;
    }
    return true;
  });
  return found ?? ctx.findRenderObject() as RenderBox?;
}

/// Unfocuses the active text field when the user taps outside its bounds.
/// Use from a root [Listener.onPointerDown] with [HitTestBehavior.translucent].
void handlePointerDownDismissKeyboard(PointerDownEvent event) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || !focus.hasFocus) return;
  if (!_focusIsInEditableTextField(focus)) return;

  final box = _textInputRenderBox(focus);
  if (box == null || !box.attached || !box.hasSize) {
    focus.unfocus();
    return;
  }

  final topLeft = box.localToGlobal(Offset.zero);
  final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);
  if (!rect.contains(event.position)) {
    focus.unfocus();
  }
}
