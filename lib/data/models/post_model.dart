class Post {
  final int? id;
  final int? userId;
  final String content;
  final String? type;
  final String? visibility;
  final List<String>? mediaUrls;
  final int? likes;
  final int? comments;
  final DateTime? createdAt;
  final PostUser? user;

  Post({
    this.id,
    this.userId,
    required this.content,
    this.type,
    this.visibility,
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
        final mediaList = json['media'] as List;
        if (mediaList.isNotEmpty) {
          if (mediaList.first is Map) {
            // API returns array of media objects with 'url' or 'full_url' property
            mediaUrls = mediaList
                .map((media) {
                  if (media is Map<String, dynamic>) {
                    // Prefer full_url, fallback to url
                    return (media['full_url'] ?? media['url'] ?? '') as String;
                  }
                  return '';
                })
                .where((url) => url.isNotEmpty)
                .toList();
          } else if (mediaList.first is String) {
            // API returns array of strings
            mediaUrls = List<String>.from(mediaList);
          }
        }
      } else if (json['media'] is String) {
        mediaUrls = [json['media']];
      }
    }

    return Post(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'] ?? '',
      type: json['type'],
      visibility: json['visibility'],
      mediaUrls: mediaUrls,
      likes: json['likes'] ?? json['likes_count'] ?? 0,
      comments: json['comments'] ?? json['comments_count'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      user: json['user'] != null ? PostUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'content': content,
      if (type != null) 'type': type,
      if (visibility != null) 'visibility': visibility,
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
