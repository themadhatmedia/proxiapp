class Post {
  final int? id;
  final int? userId;
  final String content;
  final List<String>? mediaUrls;
  final int? likes;
  final int? comments;
  final DateTime? createdAt;
  final PostUser? user;

  Post({
    this.id,
    this.userId,
    required this.content,
    this.mediaUrls,
    this.likes,
    this.comments,
    this.createdAt,
    this.user,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<String>? mediaUrls;
    if (json['media'] != null) {
      if (json['media'] is List) {
        mediaUrls = List<String>.from(json['media']);
      } else if (json['media'] is String) {
        mediaUrls = [json['media']];
      }
    }

    return Post(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'] ?? '',
      mediaUrls: mediaUrls,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      user: json['user'] != null ? PostUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'content': content,
      if (mediaUrls != null) 'media': mediaUrls,
      if (likes != null) 'likes': likes,
      if (comments != null) 'comments': comments,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
    };
  }
}

class PostUser {
  final int id;
  final String name;
  final String? displayName;
  final String? avatarUrl;

  PostUser({
    required this.id,
    required this.name,
    this.displayName,
    this.avatarUrl,
  });

  factory PostUser.fromJson(Map<String, dynamic> json) {
    return PostUser(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
