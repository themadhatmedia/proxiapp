class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? userProfileImage;
  final String userName;
  final DateTime timestamp;
  final bool isRead;
  final int? senderId;
  final int? conversationId;
  final int? messageId;
  final int? postId;
  final int? circleRequestId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.userProfileImage,
    required this.userName,
    required this.timestamp,
    this.isRead = false,
    this.senderId,
    this.conversationId,
    this.messageId,
    this.postId,
    this.circleRequestId,
  });

  String get message => body;
  String get normalizedType => type.toLowerCase().trim();

  factory NotificationModel.fromApi(Map<String, dynamic> json) {
    final payload = (json['data'] is Map) ? Map<String, dynamic>.from(json['data'] as Map) : <String, dynamic>{};
    final sender = (payload['sender'] is Map) ? Map<String, dynamic>.from(payload['sender'] as Map) : <String, dynamic>{};
    final postMap = (payload['post'] is Map) ? Map<String, dynamic>.from(payload['post'] as Map) : <String, dynamic>{};
    final createdAt = json['created_at']?.toString();

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: payload['type']?.toString() ?? json['type']?.toString() ?? 'general',
      title: payload['title']?.toString() ?? 'Notification',
      body: payload['body']?.toString() ?? '',
      userProfileImage: sender['avatar']?.toString(),
      userName: sender['name']?.toString() ?? 'System',
      timestamp: createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now() : DateTime.now(),
      isRead: json['read_at'] != null,
      senderId: sender['id'] is int ? sender['id'] as int : int.tryParse('${sender['id']}'),
      conversationId: payload['conversation_id'] is int
          ? payload['conversation_id'] as int
          : int.tryParse('${payload['conversation_id']}'),
      messageId: payload['message_id'] is int ? payload['message_id'] as int : int.tryParse('${payload['message_id']}'),
      postId: payload['post_id'] is int
          ? payload['post_id'] as int
          : int.tryParse('${payload['post_id']}') ?? (postMap['id'] is int ? postMap['id'] as int : int.tryParse('${postMap['id']}')),
      circleRequestId: payload['circle_request_id'] is int
          ? payload['circle_request_id'] as int
          : int.tryParse('${payload['circle_request_id']}') ??
              (payload['request_id'] is int ? payload['request_id'] as int : int.tryParse('${payload['request_id']}')),
    );
  }

  NotificationModel copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? userProfileImage,
    String? userName,
    DateTime? timestamp,
    bool? isRead,
    int? senderId,
    int? conversationId,
    int? messageId,
    int? postId,
    int? circleRequestId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      senderId: senderId ?? this.senderId,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      postId: postId ?? this.postId,
      circleRequestId: circleRequestId ?? this.circleRequestId,
    );
  }
}
