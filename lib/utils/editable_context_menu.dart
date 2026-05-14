import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clipboard_rich_paste.dart';

/// Pastes plain text using the same clipboard path as the in-app Paste buttons
/// (`Pasteboard` + fallback to [Clipboard]), then inserts at the current
/// selection. [EditableTextState.pasteText] uses [Clipboard.getData] only, which
/// often returns null on iOS and exits before changing the field.
Future<void> proxiToolbarPaste(EditableTextState state) async {
  if (!state.mounted || state.widget.readOnly) return;
  final controller = state.widget.controller;

  // Snapshot before awaiting clipboard: the menu closing can unfocus and
  // reset [controller.selection] while we wait.
  final textBefore = controller.text;
  final sel = controller.selection;
  int start;
  int end;
  if (sel.isValid &&
      sel.start >= 0 &&
      sel.end >= 0 &&
      sel.start <= textBefore.length &&
      sel.end <= textBefore.length) {
    start = sel.start;
    end = sel.end;
  } else {
    start = end = textBefore.length;
  }

  String? insertion = await ClipboardRichPaste.clipboardPlainText();
  if (insertion == null || insertion.isEmpty) {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    insertion = data?.text;
  }
  if (insertion == null || insertion.isEmpty) return;

  if (!state.mounted) return;
  final newText = textBefore.replaceRange(start, end, insertion);
  final offset = (start + insertion.length).clamp(0, newText.length);
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: offset),
  );

  if (!state.mounted) return;
  state.widget.focusNode.requestFocus();
  state.hideToolbar(false);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (state.mounted) {
      state.widget.focusNode.requestFocus();
    }
  });
}

List<ContextMenuButtonItem> _withProxiPasteHandlers(
  List<ContextMenuButtonItem> items,
  EditableTextState editableTextState,
) {
  return items
      .map((item) {
        if (item.type != ContextMenuButtonType.paste) return item;
        return ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () => unawaited(proxiToolbarPaste(editableTextState)),
        );
      })
      .toList(growable: true);
}

/// Context menu for post/message composers: keeps default items (including
/// Live Text / "Scan Text" on iOS) and ensures **Paste** is present when the
/// platform has not yet marked the clipboard as pasteable.
///
/// Paste always uses [proxiToolbarPaste] so iOS clipboard text matches the
/// working toolbar / paste-button behavior.
Widget buildProxiEditableTextContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final readOnly = editableTextState.widget.readOnly;
  final items = _withProxiPasteHandlers(
    List<ContextMenuButtonItem>.from(editableTextState.contextMenuButtonItems),
    editableTextState,
  );
  if (!readOnly && !items.any((e) => e.type == ContextMenuButtonType.paste)) {
    items.add(
      ContextMenuButtonItem(
        onPressed: () => unawaited(proxiToolbarPaste(editableTextState)),
        type: ContextMenuButtonType.paste,
      ),
    );
  }
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}
