import 'dart:async' show Timer, unawaited;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../config/message_reaction_emojis.dart';
import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/messages_controller.dart';
import '../../data/models/messaging_model.dart';
import '../../data/models/post_reaction_models.dart';
import '../../data/services/api_service.dart';
import '../../utils/app_vibration.dart';
import '../../utils/clipboard_rich_paste.dart';
import '../../utils/editable_context_menu.dart';
import '../../utils/progress_dialog_helper.dart';
import '../../utils/video_trim_helper.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/emoji_reaction_action_button.dart';
import '../../widgets/safe_avatar.dart';
import '../posts/post_reactions_bottom_sheet.dart';

/// Emoji keys for bubble badges: highest counts first (max 4), stable tie-break.
List<String> _orderedMessageReactionEmojis(PostReactionSummary? rx) {
  if (rx == null || rx.total <= 0) return [];

  if (rx.counts.isNotEmpty) {
    final sorted = rx.counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return sorted.map((e) => e.key).take(4).toList();
  }

  final tally = <String, int>{};
  for (final row in rx.users) {
    if (row.emoji.isEmpty) continue;
    tally[row.emoji] = (tally[row.emoji] ?? 0) + 1;
  }
  if (tally.isEmpty) return [];
  final sorted = tally.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return sorted.map((e) => e.key).take(4).toList();
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.otherUserId,
    this.conversationId,
    this.otherDisplayName = 'User',
    this.otherAvatarUrl,
  });

  final int otherUserId;
  final int? conversationId;
  final String otherDisplayName;
  final String? otherAvatarUrl;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _picker = ImagePicker();
  File? _selectedAttachment;
  String? _selectedAttachmentName;
  _AttachmentKind? _selectedAttachmentKind;

  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  int _page = 1;
  int? _nextPage;
  bool _loadMoreInFlight = false;
  bool _initialScrollPending = false;
  late String _title;
  String? _avatar;
  String? _token;
  int? _myId;
  int? _conversationId;
  Timer? _poll;
  bool _disposed = false;
  final Map<int, bool> _messageReacting = {};
  final Map<int, bool> _messageDeleting = {};
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _title = widget.otherDisplayName;
    _avatar = widget.otherAvatarUrl;
    _conversationId = widget.conversationId;
    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    _token = auth?.token;
    _myId = auth?.user?.id;
    if (_token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ToastHelper.showError('Not signed in');
        Get.back<void>();
      });
      return;
    }
    unawaited(_loadInitial());
    _scroll.addListener(_onScroll);
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      _poll = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          unawaited(_syncLatest());
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_readAll());
    _disposed = true;
    _poll?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_loadMoreInFlight || _nextPage == null) return;
    if (_scroll.position.pixels < 100) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _readAll() async {
    if (_disposed) return;
    if (_token == null || _conversationId == null) return;
    try {
      await _api.markMessagesAsReadForUser(
        token: _token!,
        conversationId: _conversationId!,
      );
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().softRefresh();
      }
    } catch (_) {
      // Non-fatal: thread still usable.
    }
  }

  Future<int?> _resolveConversationId() async {
    if (_conversationId != null && _conversationId! > 0) return _conversationId;
    if (_token == null) return null;

    if (Get.isRegistered<MessagesController>()) {
      final cached = Get.find<MessagesController>()
          .conversations
          .where((c) => c.otherUser.id == widget.otherUserId && c.conversationId > 0)
          .toList();
      if (cached.isNotEmpty) {
        _conversationId = cached.first.conversationId;
        return _conversationId;
      }
    }

    final list = await _api.getConversations(token: _token!);
    for (final c in list) {
      if (c.otherUser.id == widget.otherUserId && c.conversationId > 0) {
        _conversationId = c.conversationId;
        return _conversationId;
      }
    }
    return null;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
    });
    try {
      final convId = await _resolveConversationId();
      if (convId == null) {
        if (mounted) {
          setState(() {
            _messages = <ChatMessageModel>[];
            _page = 1;
            _nextPage = null;
          });
        }
        return;
      }
      final r = await _api.getConversationThread(
        token: _token!,
        conversationId: convId,
        page: 1,
      );
      await _readAll();
      if (mounted) {
        setState(() {
          _messages = r.items;
          _page = 1;
          _nextPage = r.nextPage;
          _initialScrollPending = r.items.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        if (_initialScrollPending) {
          _initialScrollPending = false;
          _scrollToEnd(animate: false);
        }
      }
    }
  }

  Future<void> _loadOlder() async {
    final np = _nextPage;
    if (np == null || _loadMoreInFlight) return;
    _loadMoreInFlight = true;
    try {
      final convId = _conversationId ?? await _resolveConversationId();
      if (convId == null) return;
      final r = await _api.getConversationThread(
        token: _token!,
        conversationId: convId,
        page: np,
      );
      if (!mounted) return;
      final wasAtTop = _scroll.hasClients && _scroll.position.pixels < 8;
      final h = _scroll.hasClients ? _scroll.position.pixels : 0.0;
      setState(() {
        _messages = [...r.items, ..._messages];
        _page = np;
        _nextPage = r.nextPage;
      });
      if (_scroll.hasClients && r.items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final newMax = _scroll.position.maxScrollExtent;
          if (wasAtTop) {
            _scroll.jumpTo((newMax - h).clamp(0.0, newMax));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _loadMoreInFlight = false;
    }
  }

  Future<void> _syncLatest() async {
    if (_token == null) return;
    try {
      final convId = _conversationId ?? await _resolveConversationId();
      if (convId == null) return;
      final prevCount = _messages.length;
      final r = await _api.getConversationThread(
        token: _token!,
        conversationId: convId,
        page: 1,
      );
      if (!mounted) return;
      final by = <int, ChatMessageModel>{for (final m in _messages) m.id: m};
      for (final m in r.items) {
        by[m.id] = m;
      }
      final next = by.values.toList()..sort((a, b) {
            final t = a.createdAt;
            final u = b.createdAt;
            if (t == null && u == null) return a.id.compareTo(b.id);
            if (t == null) return -1;
            if (u == null) return 1;
            return t.compareTo(u);
          });
      setState(() {
        _messages = next;
        _nextPage = _page == 1 ? r.nextPage : _nextPage;
      });
      if (next.length > prevCount) {
        final hasIncoming = next.any(
          (m) => !m.isMine(_myId ?? -1) && !m.isRead,
        );
        if (hasIncoming) {
          AppVibration.newMessageSoft();
        }
        _scrollToEnd();
      }
      await _readAll();
    } catch (_) {
      // Silent: polling
    }
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final t = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          t,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(t);
      }
    });
  }

  void _patchMessage(ChatMessageModel updated) {
    final i = _messages.indexWhere((m) => m.id == updated.id);
    if (i < 0) return;
    setState(() => _messages[i] = updated);
  }

  Future<void> _handleMessageReactionEmoji(ChatMessageModel m, String emoji) async {
    if (_token == null || m.id <= 0) return;
    if (!MessageReactionEmojis.isAllowed(emoji)) return;
    setState(() => _messageReacting[m.id] = true);
    try {
      final mine = m.reactions?.myEmoji;
      final Map<String, dynamic> res;
      if (mine == emoji) {
        res = await _api.removeMessageReaction(token: _token!, messageId: m.id);
      } else {
        res = await _api.reactToMessage(token: _token!, messageId: m.id, emoji: emoji);
      }
      if (!mounted) return;
      _patchMessage(m.withReactionResponse(res));
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _messageReacting[m.id] = false);
      }
    }
  }

  Future<void> _openMessageReactions(ChatMessageModel m) async {
    final rx = m.reactions;
    if (rx == null || rx.users.isEmpty) return;
    await showReactionParticipantsBottomSheet(context, users: rx.users);
  }

  Future<void> _copyMessageText(ChatMessageModel m) async {
    final text = m.message.trim();
    if (text.isEmpty) {
      ToastHelper.showError('No text to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ToastHelper.showInfo('Message copied');
    }
  }

  Future<void> _confirmAndDeleteMessage(ChatMessageModel m) async {
    if (_token == null || m.id <= 0) return;
    if (_messageDeleting[m.id] == true) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.proxi.surfaceCard,
        title: const Text('Delete message?'),
        content: const Text('This message will be deleted for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB00020)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _messageDeleting[m.id] = true);
    try {
      await ProgressDialogHelper.show(context);
      await _api.deleteMessageById(token: _token!, messageId: m.id);
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((x) => x.id == m.id);
        _messageReacting.remove(m.id);
      });
      ToastHelper.showInfo('Message deleted');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      await ProgressDialogHelper.hide();
      if (mounted) {
        setState(() => _messageDeleting.remove(m.id));
      }
    }
  }

  Future<void> _pasteIntoComposer() async {
    final mediaFile = await ClipboardRichPaste.clipboardPasteImageGifOrResolvedUrl();
    if (mediaFile != null) {
      final isVideo = _isVideoPath(mediaFile.path);
      setState(() {
        _selectedAttachment = mediaFile;
        _selectedAttachmentName = mediaFile.path.split(Platform.pathSeparator).last;
        _selectedAttachmentKind =
            isVideo ? _AttachmentKind.video : _attachmentKindForLocalMedia(mediaFile.path);
      });
      _onInputChanged();
      return;
    }
    final text = await ClipboardRichPaste.clipboardPlainText();
    if (text != null && text.trim().isNotEmpty) {
      ClipboardRichPaste.insertTextAtSelection(_input, text);
      _onInputChanged();
      return;
    }
    ToastHelper.showError('Nothing to paste');
  }

  Future<void> _onKeyboardInsertedMessage(KeyboardInsertedContent content) async {
    final file = await ClipboardRichPaste.keyboardInsertedContentToTempFile(content);
    if (file != null) {
      setState(() {
        _selectedAttachment = file;
        _selectedAttachmentName = file.path.split(Platform.pathSeparator).last;
        _selectedAttachmentKind = _attachmentKindForLocalMedia(file.path);
      });
      _onInputChanged();
      return;
    }
    ToastHelper.showError('Could not read pasted image');
  }

  Future<void> _onSend() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty && _selectedAttachment == null) return;
    if (_myId == null) return;
    if (_token == null) return;
    setState(() {
      _sending = true;
      _uploadProgress = _selectedAttachment != null ? 0 : null;
    });
    try {
      final sent = await _api.sendMessage(
        token: _token!,
        messageTo: widget.otherUserId,
        text: text.isEmpty ? null : text,
        file: _selectedAttachment,
        onUploadProgress: (sentBytes, totalBytes) {
          if (!mounted || totalBytes <= 0) return;
          final next = (sentBytes / totalBytes).clamp(0.0, 1.0);
          if (_uploadProgress == null || (next - _uploadProgress!).abs() >= 0.01 || next == 1.0) {
            setState(() {
              _uploadProgress = next;
            });
          }
        },
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _selectedAttachment = null;
        _selectedAttachmentName = null;
        _selectedAttachmentKind = null;
        _uploadProgress = null;
      });
      if (!_messages.any((e) => e.id == sent.id)) {
        setState(() {
          _messages = [..._messages, sent]..sort((a, b) {
                final t = a.createdAt;
                final u = b.createdAt;
                if (t == null && u == null) return a.id.compareTo(b.id);
                if (t == null) return -1;
                if (u == null) return 1;
                return t.compareTo(u);
              });
        });
        _scrollToEnd();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _showAttachmentPicker() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.proxi.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_outlined, color: cs.primary),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickPhoto());
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam_outlined, color: cs.primary),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickVideo());
                },
              ),
              ListTile(
                leading: Icon(Icons.gif_box_outlined, color: cs.primary),
                title: const Text('GIF'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickGif());
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file_outlined, color: cs.primary),
                title: const Text('Document'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickDocument());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (x == null || !mounted) return;
    final file = File(x.path);
    if (!file.existsSync()) {
      ToastHelper.showError('Could not read selected photo');
      return;
    }
    setState(() {
      _selectedAttachment = file;
      _selectedAttachmentName = x.name;
      _selectedAttachmentKind = _attachmentKindForLocalMedia(file.path);
    });
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (x == null || !mounted) return;
    final file = File(x.path);
    if (!file.existsSync()) {
      ToastHelper.showError('Could not read selected video');
      return;
    }
    if (!_isVideoPath(x.path, mimeType: x.mimeType)) {
      setState(() {
        _selectedAttachment = file;
        _selectedAttachmentName = x.name;
        _selectedAttachmentKind = _attachmentKindForLocalMedia(file.path);
      });
      _onInputChanged();
      return;
    }
    final trimmed = await VideoTrimHelper.enforceMaxDuration(context, file);
    if (trimmed == null) return;
    setState(() {
      _selectedAttachment = trimmed;
      _selectedAttachmentName = x.name;
      _selectedAttachmentKind = _AttachmentKind.video;
    });
  }

  Future<void> _pickGif() async {
    final picks = await _picker.pickMultiImage();
    if (picks.isEmpty || !mounted) return;
    XFile? gifPick;
    var hasNonGif = false;
    for (final p in picks) {
      final ext = p.path.split('.').last.toLowerCase();
      if (ext == 'gif') {
        gifPick ??= p;
      } else {
        hasNonGif = true;
      }
    }
    if (gifPick == null) {
      ToastHelper.showError('Please select a GIF file');
      unawaited(_pickGif());
      return;
    }
    if (hasNonGif) {
      ToastHelper.showError('Only GIF files can be selected here');
      unawaited(_pickGif());
      return;
    }
    final file = File(gifPick.path);
    if (!file.existsSync()) {
      ToastHelper.showError('Could not read selected GIF');
      return;
    }
    setState(() {
      _selectedAttachment = file;
      _selectedAttachmentName = gifPick!.name;
      _selectedAttachmentKind = _AttachmentKind.gif;
    });
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>[
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
      ],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final p = result.files.single;
    final path = p.path;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) {
      ToastHelper.showError('Could not read selected document');
      return;
    }
    setState(() {
      _selectedAttachment = file;
      _selectedAttachmentName = p.name;
      _selectedAttachmentKind = _AttachmentKind.document;
    });
  }

  /// GIF vs still image for composer preview label (upload behavior is still image upload).
  static bool _isGifPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.gif') || p.contains('.gif?');
  }

  static _AttachmentKind _attachmentKindForLocalMedia(String path) {
    if (_isGifPath(path)) return _AttachmentKind.gif;
    return _AttachmentKind.photo;
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    final file = _selectedAttachment;
    if (file == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final kind = _selectedAttachmentKind ?? _AttachmentKind.document;
    final ext = file.path.split('.').last.toLowerCase();
    final name = _selectedAttachmentName ?? file.path.split(Platform.pathSeparator).last;
    final icon = switch (kind) {
      _AttachmentKind.photo => Icons.photo_outlined,
      _AttachmentKind.gif => Icons.gif_box_outlined,
      _AttachmentKind.video => Icons.videocam_outlined,
      _AttachmentKind.document => Icons.insert_drive_file_outlined,
    };
    final progress = _uploadProgress;
    final progressPct = progress == null ? null : (progress * 100).round().clamp(0, 100);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.proxi.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          if (kind == _AttachmentKind.photo || kind == _AttachmentKind.gif)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            )
          else if (kind == _AttachmentKind.video)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.42),
                    cs.primary.withOpacity(0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: cs.onPrimary, size: 26),
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Icon(Icons.videocam_rounded, color: cs.onPrimary.withOpacity(0.92), size: 12),
                  ),
                ],
              ),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: cs.primary),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  switch (kind) {
                    _AttachmentKind.document => ext.toUpperCase(),
                    _AttachmentKind.gif => 'GIF',
                    _ => kind.name.toUpperCase(),
                  },
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (_sending && progressPct != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: progress,
                            color: cs.primary,
                            backgroundColor: cs.primary.withOpacity(0.18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progressPct%',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _sending
                ? null
                : () {
                    setState(() {
                      _selectedAttachment = null;
                      _selectedAttachmentName = null;
                      _selectedAttachmentKind = null;
                    });
                  },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  bool get _canSend {
    return _input.text.trim().isNotEmpty || _selectedAttachment != null;
  }

  void _onInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }


  Future<void> _confirmAndDeleteThread() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.proxi.surfaceCard,
        title: const Text('Delete conversation?'),
        content: const Text(
          'The entire history with this person will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true || _token == null) return;
    try {
      final convId = _conversationId ?? await _resolveConversationId();
      if (convId == null) {
        ToastHelper.showError('Conversation id not found');
        return;
      }
      await _api.deleteConversationWithUser(
        token: _token!,
        conversationId: convId,
      );
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().removeByOtherUserId(widget.otherUserId);
      }
      if (mounted) {
        Get.back<void>();
        ToastHelper.showInfo('Conversation deleted');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          backgroundColor: context.proxi.surfaceCard,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Get.back<void>(),
          ),
          title: Row(
            children: [
              SafeAvatar(
                size: 38,
                imageUrl: _avatar,
                fallbackText: _title,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onSurface),
              color: context.proxi.surfaceCard,
              onSelected: (v) {
                if (v == 'delete') {
                  unawaited(_confirmAndDeleteThread());
                }
              },
              itemBuilder: (c) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete conversation'),
                ),
              ],
            ),
          ],
        ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.scaffoldGradient(context),
        ),
        child: Column(
          children: [
              if (_page > 1 && _nextPage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'Pull to load older, or scroll up',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet.\nSay hi!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final my = m.isMine(_myId ?? -1);
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: 4,
                                  bottom: m.reactionTotal > 0 ? 14 : 4,
                                ),
                                child: _Bubble(
                                  m: m,
                                  mine: my,
                                  onOpenAttachment: m.fileUrl != null && m.fileUrl!.isNotEmpty
                                      ? () => unawaited(_openAttachment(m))
                                      : null,
                                  showReactions: m.id > 0 && _token != null,
                                  reactionBusy: _messageReacting[m.id] == true,
                                  deleteBusy: _messageDeleting[m.id] == true,
                                  canDelete: my,
                                  onReactEmoji: m.id > 0 && _token != null
                                      ? (emoji) async => _handleMessageReactionEmoji(m, emoji)
                                      : null,
                                  onReactionsSummaryTap: m.reactionTotal > 0 &&
                                          m.reactions != null &&
                                          m.reactions!.users.isNotEmpty
                                      ? () => unawaited(_openMessageReactions(m))
                                      : null,
                                  onCopyTap: (m.fileUrl == null || m.fileUrl!.isEmpty)
                                      ? () => unawaited(_copyMessageText(m))
                                      : null,
                                  onDeleteTap: my ? () => unawaited(_confirmAndDeleteMessage(m)) : null,
                                ),
                              );
                            },
                          ),
              ),
              const Divider(height: 1),
              _buildAttachmentPreview(context),
              SafeArea(
                top: false,
                child: Material(
                  color: context.proxi.bottomNavBackground.withOpacity(0.75),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: _sending ? null : () => unawaited(_showAttachmentPicker()),
                          icon: const Icon(Icons.attach_file),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary.withOpacity(0.15),
                            foregroundColor: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          onPressed: _sending ? null : () => unawaited(_pasteIntoComposer()),
                          icon: const Icon(Icons.content_paste),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary.withOpacity(0.15),
                            foregroundColor: cs.primary,
                          ),
                          tooltip: 'Paste text or image',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            contextMenuBuilder: buildProxiEditableTextContextMenu,
                            contentInsertionConfiguration: ContentInsertionConfiguration(
                              allowedMimeTypes: const [
                                'image/png',
                                'image/gif',
                                'image/jpeg',
                                'image/jpg',
                                'image/webp',
                              ],
                              onContentInserted: (KeyboardInsertedContent value) {
                                unawaited(_onKeyboardInsertedMessage(value));
                              },
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              filled: true,
                              fillColor: context.proxi.surfaceCard,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                              ),
                            ),
                            onChanged: (_) => _onInputChanged(),
                            onSubmitted: (_) => unawaited(_onSend()),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          onPressed: _sending || !_canSend ? null : _onSend,
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                          icon: _sending
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openUrl(String u) async {
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ToastHelper.showError('Could not open this link');
    }
  }

  static bool _isImage(ChatMessageModel m) {
    final t = m.type.toLowerCase();
    if (t == 'image' || t.startsWith('image/') || t.contains('image')) return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.gif') ||
        u.endsWith('.webp') ||
        u.contains('.jpg?') ||
        u.contains('.jpeg?') ||
        u.contains('.png?') ||
        u.contains('.gif?') ||
        u.contains('.webp?');
  }

  static bool _isVideo(ChatMessageModel m) {
    final t = m.type.toLowerCase();
    if (t == 'video' || t.startsWith('video/') || t.contains('video') || t.contains('mp4')) return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.avi') ||
        u.endsWith('.mkv') ||
        u.endsWith('.webm') ||
        u.contains('.mp4?') ||
        u.contains('.mov?') ||
        u.contains('.avi?') ||
        u.contains('.mkv?') ||
        u.contains('.webm?');
  }

  static bool _isVideoPath(String path, {String? mimeType}) {
    final mime = mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;
    if (mime.startsWith('image/')) return false;
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm') ||
        p.endsWith('.m4v') ||
        p.endsWith('.3gp') ||
        p.contains('.mp4?') ||
        p.contains('.mov?') ||
        p.contains('.avi?') ||
        p.contains('.mkv?') ||
        p.contains('.webm?') ||
        p.contains('.m4v?') ||
        p.contains('.3gp?');
  }

  static Future<void> _openAttachment(ChatMessageModel m) async {
    final url = m.fileUrl;
    if (url == null || url.isEmpty) return;
    if (_isImage(m) || _isVideo(m)) {
      await Get.to<void>(() => _ChatMediaViewerScreen(url: url, isVideo: _isVideo(m)));
      return;
    }
    await _openUrl(url);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.m,
    required this.mine,
    this.onOpenAttachment,
    this.showReactions = false,
    this.reactionBusy = false,
    this.deleteBusy = false,
    this.canDelete = false,
    this.onReactEmoji,
    this.onReactionsSummaryTap,
    this.onCopyTap,
    this.onDeleteTap,
  });

  final ChatMessageModel m;
  final bool mine;
  final VoidCallback? onOpenAttachment;
  final bool showReactions;
  final bool reactionBusy;
  final bool deleteBusy;
  final bool canDelete;
  final Future<void> Function(String emoji)? onReactEmoji;
  final VoidCallback? onReactionsSummaryTap;
  final VoidCallback? onCopyTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = mine
        ? ProxiPalette.electricBlue
        : context.proxi.surfaceCard;
    final fg = mine ? ProxiPalette.pureWhite : cs.onSurface;
    final at = m.createdAt;
    final timeLabel = at == null
        ? null
        : (DateTime.now().difference(at.toLocal()) < const Duration(days: 6)
            ? timeago.format(at.toLocal())
            : DateFormat('MMM d, h:mm a').format(at.toLocal()));

    final reactionEmojiKeys = _orderedMessageReactionEmojis(m.reactions);
    final showReactionBadges =
        reactionEmojiKeys.isNotEmpty && onReactionsSummaryTap != null;

    // Corner badges overlap the bubble bottom (~28px intrusion + glow); keep time / read above them.
    final footerPadBottom = showReactionBadges ? 36.0 : 10.0;

    final bubbleCard = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: mine ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight: mine ? const Radius.circular(4) : const Radius.circular(16),
        ),
        border: !mine
            ? Border.all(color: cs.outline.withOpacity(0.18))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, footerPadBottom),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.message.trim().isNotEmpty)
              Text(
                m.message,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            if (m.fileUrl != null && m.fileUrl!.isNotEmpty) ...[
              if (m.message.trim().isNotEmpty) const SizedBox(height: 8),
              _AttachmentPreviewInBubble(
                m: m,
                onTap: onOpenAttachment,
                foreground: fg,
              ),
            ],
            const SizedBox(height: 6),
            if (timeLabel != null)
              Text(
                timeLabel,
                style: TextStyle(
                  color: fg.withOpacity(0.7),
                  fontSize: 11,
                ),
              )
            else
              const SizedBox.shrink(),
            if (mine) ...[
              const SizedBox(height: 2),
              Text(
                m.isRead ? 'Read' : 'Sent',
                style: TextStyle(
                  color: fg.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ] else if (!m.isRead) ...[
              const SizedBox(height: 2),
              Text(
                'New',
                style: TextStyle(
                  color: fg.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final layered = Stack(
      clipBehavior: Clip.none,
      children: [
        bubbleCard,
        if (showReactionBadges)
          Positioned(
            bottom: -6,
            left: mine ? null : -2,
            right: mine ? -2 : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                EmojiReactionActionButton.dismissFloatingReactionPicker();
                onReactionsSummaryTap!();
              },
              child: _MessageReactionBadgeCluster(
                emojis: reactionEmojiKeys,
                alignEnd: mine,
              ),
            ),
          ),
      ],
    );

    final Widget bubbleWithPicker = showReactions && onReactEmoji != null
        ? ReactionPickerLongPress(
            enabled: !reactionBusy && !deleteBusy,
            reactionEmojis: MessageReactionEmojis.all,
            pickerSelectionEmoji: m.reactions?.myEmoji,
            onEmojiChosen: onReactEmoji!,
            bottomMenuBuilder: (closeOverlay) => _MessageLongPressActions(
              canDelete: canDelete,
              onCopy: () {
                closeOverlay();
                onCopyTap?.call();
              },
              onDelete: onDeleteTap == null
                  ? null
                  : () {
                      closeOverlay();
                      onDeleteTap!.call();
                    },
            ),
            child: layered,
          )
        : layered;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: bubbleWithPicker,
      ),
    );
  }
}

class _MessageLongPressActions extends StatelessWidget {
  const _MessageLongPressActions({
    required this.canDelete,
    required this.onCopy,
    required this.onDelete,
  });

  final bool canDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 188,
      decoration: BoxDecoration(
        color: const Color(0xE61A1A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCopy != null)
            _ActionRow(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              color: Colors.white.withOpacity(0.92),
              onTap: onCopy!,
            ),
          if (onCopy != null && canDelete && onDelete != null)
            Divider(height: 1, color: Colors.white.withOpacity(0.14)),
          if (canDelete && onDelete != null) ...[
            _ActionRow(
              label: 'Delete',
              icon: Icons.delete_forever_outlined,
              color: cs.error,
              onTap: onDelete!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(icon, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// Overlapping circular emoji badges with soft halo (reference: system message apps).
class _MessageReactionBadgeCluster extends StatelessWidget {
  const _MessageReactionBadgeCluster({
    required this.emojis,
    required this.alignEnd,
  });

  final List<String> emojis;
  final bool alignEnd;

  static const double _d = 30;
  static const double _overlap = 13;

  @override
  Widget build(BuildContext context) {
    final n = emojis.length;
    if (n == 0) return const SizedBox.shrink();
    final step = _d - _overlap;
    final w = _d + (n - 1) * step;

    return SizedBox(
      width: w,
      height: _d + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = n - 1; i >= 0; i--)
            Positioned(
              left: alignEnd ? null : i * step,
              right: alignEnd ? i * step : null,
              bottom: 0,
              child: _SingleReactionGlowBadge(emoji: emojis[i]),
            ),
        ],
      ),
    );
  }
}

class _SingleReactionGlowBadge extends StatelessWidget {
  const _SingleReactionGlowBadge({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _MessageReactionBadgeCluster._d,
      height: _MessageReactionBadgeCluster._d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.42),
            blurRadius: 14,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: _MessageReactionBadgeCluster._d - 2,
        height: _MessageReactionBadgeCluster._d - 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF25252C),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 15.5, height: 1.05),
        ),
      ),
    );
  }
}

enum _AttachmentKind {
  photo,
  gif,
  video,
  document,
}

class _AttachmentPreviewInBubble extends StatelessWidget {
  const _AttachmentPreviewInBubble({
    required this.m,
    required this.onTap,
    required this.foreground,
  });

  final ChatMessageModel m;
  final VoidCallback? onTap;
  final Color foreground;

  bool get _isImage {
    final t = m.type.toLowerCase();
    if (t == 'image' || t.startsWith('image/') || t.contains('image')) return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.gif') ||
        u.endsWith('.webp') ||
        u.contains('.jpg?') ||
        u.contains('.jpeg?') ||
        u.contains('.png?') ||
        u.contains('.gif?') ||
        u.contains('.webp?');
  }

  bool get _isVideo {
    final t = m.type.toLowerCase();
    if (t == 'video' || t.startsWith('video/') || t.contains('video') || t.contains('mp4')) return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.avi') ||
        u.endsWith('.mkv') ||
        u.endsWith('.webm') ||
        u.contains('.mp4?') ||
        u.contains('.mov?') ||
        u.contains('.avi?') ||
        u.contains('.mkv?') ||
        u.contains('.webm?');
  }

  @override
  Widget build(BuildContext context) {
    final url = m.fileUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (_isImage) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _docTile(context, 'Image unavailable'),
          ),
        ),
      );
    }
    if (_isVideo) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 220,
                height: 220,
                child: _InlineVideoThumb(url: url),
              ),
            ),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
            ),
          ],
        ),
      );
    }
    return _docTile(context, 'Open attachment');
  }

  Widget _docTile(BuildContext context, String caption) {
    final ext = (m.fileUrl?.split('.').last.toUpperCase() ?? 'FILE');
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: foreground.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file_outlined, color: foreground.withOpacity(0.95)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$ext • $caption',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground.withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same strategy as post cards: initialize once, seek first frame, cache controller by URL.
class _InlineVideoThumb extends StatefulWidget {
  const _InlineVideoThumb({required this.url});
  final String url;

  @override
  State<_InlineVideoThumb> createState() => _InlineVideoThumbState();
}

class _InlineVideoThumbState extends State<_InlineVideoThumb> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Avoid heavy controller fan-out in long message lists.
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller!.initialize().timeout(const Duration(seconds: 18));
      await _controller!.seekTo(const Duration(milliseconds: 100));
      await _controller!.pause();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing message video thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasError) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF38304F), Color(0xFF1D1E2A)],
          ),
        ),
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.movie_creation_outlined,
                color: Colors.white.withOpacity(0.75),
                size: 34,
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to open video',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2F3150), Color(0xFF1A1F3A)],
          ),
        ),
        width: double.infinity,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

class _ChatMediaViewerScreen extends StatefulWidget {
  const _ChatMediaViewerScreen({required this.url, required this.isVideo});
  final String url;
  final bool isVideo;

  @override
  State<_ChatMediaViewerScreen> createState() => _ChatMediaViewerScreenState();
}

class _ChatMediaViewerScreenState extends State<_ChatMediaViewerScreen> {
  VideoPlayerController? _video;
  bool _videoInitFailed = false;
  bool _videoInitializing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      unawaited(_initVideo());
    }
  }

  Future<void> _initVideo() async {
    _videoInitFailed = false;
    _videoInitializing = true;
    if (mounted) setState(() {});
    await _video?.dispose();
    _video = null;
    VideoPlayerController? c;
    try {
      // Retry a couple times for flaky CDN/socket timeouts.
      for (var attempt = 1; attempt <= 3; attempt++) {
        c?.dispose();
        c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        try {
          await c.initialize();
          await c.setLooping(false);
          _video = c;
          await c.play();
          _videoInitFailed = false;
          break;
        } catch (_) {
          if (attempt == 3) {
            _videoInitFailed = true;
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        }
      }
    } finally {
      _videoInitializing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: widget.isVideo
            ? (_videoInitFailed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white70, size: 36),
                      const SizedBox(height: 10),
                      const Text(
                        'Video failed to load',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _initVideo,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : ((_video == null || !_video!.value.isInitialized)
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            _videoInitializing ? 'Loading video...' : 'Preparing player...',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      )
                    : AspectRatio(
                        aspectRatio: _video!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_video!),
                            Positioned.fill(
                              child: _ChatVideoControls(controller: _video!),
                            ),
                          ],
                        ),
                      )))
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }
}

class _ChatVideoControls extends StatefulWidget {
  const _ChatVideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_ChatVideoControls> createState() => _ChatVideoControlsState();
}

class _ChatVideoControlsState extends State<_ChatVideoControls> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_showControls)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              if (_showControls)
                Center(
                  child: IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      widget.controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              const Spacer(),
              if (_showControls)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        widget.controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(widget.controller.value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(widget.controller.value.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
