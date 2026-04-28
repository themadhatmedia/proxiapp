import 'package:flutter/foundation.dart';

/// A row in the conversations list.
@immutable
class ConversationListItem {
  const ConversationListItem({
    required this.conversationId,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final int conversationId;
  final ConversationOtherUser otherUser;
  final ConversationLastMessage? lastMessage;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory ConversationListItem.fromJson(Map<String, dynamic> json) {
    final otherRaw = json['other_user'] ?? json['otherUser'];
    final otherMap = otherRaw is Map
        ? Map<String, dynamic>.from(otherRaw.map((k, v) => MapEntry('$k', v)))
        : <String, dynamic>{};
    final lastRaw =
        json['last_message'] ?? json['lastMessage'] ?? json['latest_message'] ?? json['recent_message'];
    final lastMessageText = (lastRaw is String)
        ? lastRaw
        : (json['last_message_text'] ?? json['last_message'] ?? json['latest_message_text'])?.toString();
    final lastAtRaw = json['last_message_at'] ?? json['lastMessageAt'];
    final unreadRaw = json['unread_count'] ?? json['unreadCount'] ?? 0;
    final conversationRaw = json['conversation_id'] ?? json['id'];
    return ConversationListItem(
      conversationId: conversationRaw is int ? conversationRaw : int.tryParse('$conversationRaw') ?? 0,
      otherUser: ConversationOtherUser.fromJson(otherMap),
      lastMessage: lastRaw is Map
          ? ConversationLastMessage.fromJson(
              Map<String, dynamic>.from(lastRaw.map((k, v) => MapEntry('$k', v))),
            )
          : null,
      lastMessageText: lastMessageText,
      lastMessageAt: lastAtRaw != null ? DateTime.tryParse('$lastAtRaw') : null,
      unreadCount: unreadRaw is int ? unreadRaw : int.tryParse('$unreadRaw') ?? 0,
    );
  }
}

@immutable
class ConversationOtherUser {
  const ConversationOtherUser({
    required this.id,
    required this.displayName,
    this.profilePicture,
  });

  final int id;
  final String displayName;
  final String? profilePicture;

  factory ConversationOtherUser.fromJson(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    final fromParts = [first, last]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ');
    final profileRaw = json['profile'];
    final profileMap = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw.map((k, v) => MapEntry('$k', v)))
        : const <String, dynamic>{};
    return ConversationOtherUser(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      displayName: fromParts.isNotEmpty
          ? fromParts
          : (json['name']?.toString() ?? 'User'),
      profilePicture: (json['profile_picture'] ??
              json['avatar'] ??
              json['profile_image'] ??
              json['image'] ??
              profileMap['avatar'] ??
              profileMap['profile_picture'])
          ?.toString(),
    );
  }
}

@immutable
class ConversationLastMessage {
  const ConversationLastMessage({
    required this.id,
    required this.message,
    required this.senderId,
    required this.receiverId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String message;
  final int senderId;
  final int receiverId;
  final bool isRead;
  final DateTime? createdAt;

  factory ConversationLastMessage.fromJson(Map<String, dynamic> json) {
    return ConversationLastMessage(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      message: (json['message'] ?? json['text'] ?? json['body'])?.toString() ?? '',
      senderId: json['sender_id'] is int
          ? json['sender_id'] as int
          : int.tryParse('${json['sender_id']}') ?? 0,
      receiverId: json['receiver_id'] is int
          ? json['receiver_id'] as int
          : int.tryParse('${json['receiver_id']}') ?? 0,
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }
}

@immutable
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.message,
    this.type = 'text',
    required this.senderId,
    required this.receiverId,
    this.fileUrl,
    this.isRead = true,
    this.createdAt,
    this.isMineFromApi,
  });

  final int id;
  final String message;
  final String type;
  final int senderId;
  final int receiverId;
  final String? fileUrl;
  final bool isRead;
  final DateTime? createdAt;
  /// Set when API sends `is_mine` (thread payload may omit `receiver_id`).
  final bool? isMineFromApi;

  bool isMine(int myUserId) => isMineFromApi ?? (senderId == myUserId);

  ChatMessageModel copyWith({
    int? id,
    String? message,
    String? type,
    int? senderId,
    int? receiverId,
    String? fileUrl,
    bool? isRead,
    DateTime? createdAt,
    bool? isMineFromApi,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      fileUrl: fileUrl ?? this.fileUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      isMineFromApi: isMineFromApi ?? this.isMineFromApi,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      message: (json['message'] ?? json['text'])?.toString() ?? '',
      type: (json['type'] ?? 'text').toString().toLowerCase(),
      senderId: json['sender_id'] is int
          ? json['sender_id'] as int
          : int.tryParse('${json['sender_id']}') ?? 0,
      receiverId: json['receiver_id'] is int
          ? json['receiver_id'] as int
          : int.tryParse('${json['receiver_id']}') ?? 0,
      fileUrl: (json['file_url'] ?? json['file'] ?? json['fileUrl'])?.toString(),
      isRead: json['is_read'] != false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
      isMineFromApi: switch (json['is_mine']) {
        true => true,
        false => false,
        _ => null,
      },
    );
  }
}

/// Parses a paginated or bare list from a typical `success` + `data` API.
List<T> mapApiDataList<T>(Map<String, dynamic> body, T Function(Map<String, dynamic> row) from) {
  dynamic raw = body['data'] ?? body['conversations'] ?? body['items'];
  if (raw is Map && raw['data'] is List) {
    raw = raw['data'];
  }
  if (raw is! List) {
    return <T>[];
  }
  return raw
      .map((e) {
        if (e is! Map) return null;
        return from(Map<String, dynamic>.from(e.map((k, v) => MapEntry('$k', v))));
      })
      .whereType<T>()
      .toList();
}

/// Proxi returns `{ "success": true, "messages": { "data": [...], "current_page": 1, ... } }` for thread GET.
Map<String, dynamic>? conversationThreadPaginatedMap(Map<String, dynamic> body) {
  final m = body['messages'];
  if (m is Map) {
    return Map<String, dynamic>.from(m.map((k, v) => MapEntry('$k', v)));
  }
  return null;
}

/// Pulls a list of maps from a paginated or plain API envelope.
List<Map<String, dynamic>> extractListPayload(dynamic d) {
  if (d is List) {
    return d
        .map(
          (e) => e is Map ? Map<String, dynamic>.from(e.map((k, v) => MapEntry('$k', v))) : <String, dynamic>{},
        )
        .where((m) => m.isNotEmpty)
        .toList();
  }
  if (d is Map) {
    final m = Map<String, dynamic>.from(d.map((k, v) => MapEntry('$k', v)));
    if (m['data'] is List) {
      return extractListPayload(m['data']);
    }
  }
  return <Map<String, dynamic>>[];
}

int? readNextPage(Map<String, dynamic> body) {
  int page = 1;
  int last = 1;
  void from(Map? m) {
    if (m == null) return;
    if (m['current_page'] != null) {
      page = int.tryParse('${m['current_page']}') ?? page;
    }
    if (m['last_page'] != null) {
      last = int.tryParse('${m['last_page']}') ?? last;
    }
  }
  from(body);
  if (body['data'] is Map) {
    from(Map<String, dynamic>.from(body['data'] as Map));
  }
  if (body['meta'] is Map) {
    from(Map<String, dynamic>.from(body['meta'] as Map));
  }
  if (page < last) return page + 1;
  return null;
}
