class CommentModel {
  final int id;
  final int postId;
  final int userId;
  final String content;
  final int? parentId;
  final DateTime createdAt;
  final CommentUser user;
  List<CommentModel> replies;
  final String? replyingToName;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.parentId,
    required this.createdAt,
    required this.user,
    this.replies = const [],
    this.replyingToName,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final repliesList = json['replies'] as List? ?? [];
    final parsedReplies = repliesList.map((replyJson) => CommentModel.fromJson(replyJson)).toList();

    return CommentModel(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      content: json['content'] ?? '',
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      user: CommentUser.fromJson(json['user'] ?? {}),
      replies: parsedReplies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'user': user.toJson(),
    };
  }
}

class CommentUser {
  final int id;
  final String name;
  final String? avatar;

  CommentUser({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
    };
  }
}
