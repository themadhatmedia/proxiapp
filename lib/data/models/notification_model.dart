class NotificationModel {
  final String id;
  final String type;
  final String message;
  final String? userProfileImage;
  final String userName;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    this.userProfileImage,
    required this.userName,
    required this.timestamp,
    this.isRead = false,
  });

  NotificationModel copyWith({
    String? id,
    String? type,
    String? message,
    String? userProfileImage,
    String? userName,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
