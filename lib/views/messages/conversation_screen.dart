import 'dart:async' show Timer, unawaited;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme/app_theme.dart';
import '../../config/theme/proxi_palette.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/messages_controller.dart';
import '../../data/models/messaging_model.dart';
import '../../data/services/api_service.dart';
import '../../utils/app_vibration.dart';
import '../../utils/toast_helper.dart';
import '../../widgets/safe_avatar.dart';

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

  Future<void> _onSend() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty && _selectedAttachment == null) return;
    if (_myId == null) return;
    if (_token == null) return;
    setState(() {
      _sending = true;
    });
    try {
      final sent = await _api.sendMessage(
        token: _token!,
        messageTo: widget.otherUserId,
        text: text.isEmpty ? null : text,
        file: _selectedAttachment,
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _selectedAttachment = null;
        _selectedAttachmentName = null;
        _selectedAttachmentKind = null;
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
      _selectedAttachmentKind = _AttachmentKind.photo;
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
    setState(() {
      _selectedAttachment = file;
      _selectedAttachmentName = x.name;
      _selectedAttachmentKind = _AttachmentKind.video;
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
    try {
      final length = await file.length();
      const tenMb = 10 * 1024 * 1024;
      if (length > tenMb) {
        ToastHelper.showError('Document must be 10MB or less');
        return;
      }
    } catch (_) {}
    setState(() {
      _selectedAttachment = file;
      _selectedAttachmentName = p.name;
      _selectedAttachmentKind = _AttachmentKind.document;
    });
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
      _AttachmentKind.video => Icons.videocam_outlined,
      _AttachmentKind.document => Icons.insert_drive_file_outlined,
    };

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
          if (kind == _AttachmentKind.photo)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
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
                  kind == _AttachmentKind.document ? ext.toUpperCase() : kind.name.toUpperCase(),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
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
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _Bubble(
                                  m: m,
                                  mine: my,
                                  onOpenAttachment: m.fileUrl != null && m.fileUrl!.isNotEmpty
                                      ? () => unawaited(_openAttachment(m))
                                      : null,
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
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
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
    if (t == 'image') return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.png') || u.endsWith('.gif') || u.endsWith('.webp');
  }

  static bool _isVideo(ChatMessageModel m) {
    final t = m.type.toLowerCase();
    if (t == 'video') return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.avi') || u.endsWith('.mkv') || u.endsWith('.webm');
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
  });

  final ChatMessageModel m;
  final bool mine;
  final VoidCallback? onOpenAttachment;

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
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: DecoratedBox(
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        ),
      ),
    );
  }
}

enum _AttachmentKind {
  photo,
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
    if (t == 'image') return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.png') || u.endsWith('.gif') || u.endsWith('.webp');
  }

  bool get _isVideo {
    final t = m.type.toLowerCase();
    if (t == 'video') return true;
    final u = m.fileUrl?.toLowerCase() ?? '';
    return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.avi') || u.endsWith('.mkv') || u.endsWith('.webm');
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

class _InlineVideoThumb extends StatefulWidget {
  const _InlineVideoThumb({required this.url});
  final String url;

  @override
  State<_InlineVideoThumb> createState() => _InlineVideoThumbState();
}

class _InlineVideoThumbState extends State<_InlineVideoThumb> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    unawaited(c.initialize().then((_) {
      if (mounted) setState(() {});
    }));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Container(color: Colors.black12);
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
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

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _video = c;
      unawaited(c.initialize().then((_) {
        if (mounted) setState(() {});
      }));
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
            ? (_video == null || !_video!.value.isInitialized)
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () {
                      if (_video!.value.isPlaying) {
                        _video!.pause();
                      } else {
                        _video!.play();
                      }
                      setState(() {});
                    },
                    child: AspectRatio(
                      aspectRatio: _video!.value.aspectRatio,
                      child: VideoPlayer(_video!),
                    ),
                  )
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                ),
              ),
      ),
      floatingActionButton: widget.isVideo
          ? FloatingActionButton.small(
              onPressed: () {
                if (_video == null) return;
                if (_video!.value.isPlaying) {
                  _video!.pause();
                } else {
                  _video!.play();
                }
                setState(() {});
              },
              child: Icon(_video?.value.isPlaying == true ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}
