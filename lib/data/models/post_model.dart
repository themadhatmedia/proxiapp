class Post {
  final int? id;
  final int? userId;
  final String content;
  final String? type;
  final String? visibility;
  final List<MediaItem>? media;
  final int? likesCount;
  final int? commentsCount;
  final bool? liked;
  final bool? isModerated;
  final bool? isFlagged;
  final DateTime? createdAt;
  final PostUser? user;
  final PostPermissions? permissions;

  Post({
    this.id,
    this.userId,
    required this.content,
    this.type,
    this.visibility,
    this.media,
    this.likesCount,
    this.commentsCount,
    this.liked,
    this.isModerated,
    this.isFlagged,
    this.createdAt,
    this.user,
    this.permissions,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<MediaItem>? mediaItems;
    if (json['media'] != null && json['media'] is List) {
      final mediaList = json['media'] as List;
      mediaItems = mediaList.map((media) => MediaItem.fromJson(media as Map<String, dynamic>)).toList();
    }

    return Post(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'] ?? '',
      type: json['type'],
      visibility: json['visibility'],
      media: mediaItems,
      likesCount: json['likes_count'] ?? json['likes'] ?? 0,
      commentsCount: json['comments_count'] ?? json['comments'] ?? 0,
      liked: json['liked'] ?? false,
      isModerated: json['is_moderated'] ?? false,
      isFlagged: json['is_flagged'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      user: json['user'] != null ? PostUser.fromJson(json['user']) : null,
      permissions: json['permissions'] != null ? PostPermissions.fromJson(json['permissions']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'content': content,
      if (type != null) 'type': type,
      if (visibility != null) 'visibility': visibility,
      if (media != null) 'media': media!.map((m) => m.toJson()).toList(),
      if (likesCount != null) 'likes_count': likesCount,
      if (commentsCount != null) 'comments_count': commentsCount,
      if (liked != null) 'liked': liked,
      if (isModerated != null) 'is_moderated': isModerated,
      if (isFlagged != null) 'is_flagged': isFlagged,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
      if (permissions != null) 'permissions': permissions!.toJson(),
    };
  }
}

class MediaItem {
  final int? id;
  final int? postId;
  final String url;
  final String fullUrl;
  final String type;
  final String? thumbnail;
  final int? order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MediaItem({
    this.id,
    this.postId,
    required this.url,
    required this.fullUrl,
    required this.type,
    this.thumbnail,
    this.order,
    this.createdAt,
    this.updatedAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      postId: json['post_id'],
      url: json['url'] ?? '',
      fullUrl: json['full_url'] ?? json['url'] ?? '',
      type: json['type'] ?? 'image',
      thumbnail: json['thumbnail'],
      order: json['order'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      'url': url,
      'full_url': fullUrl,
      'type': type,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (order != null) 'order': order,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';
  bool get isGif => type == 'gif';
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

class PostPermissions {
  final bool canView;
  final bool canLike;
  final bool canComment;
  final bool canReply;
  final String? relationType;
  final bool? isMutualOuter;

  PostPermissions({
    required this.canView,
    required this.canLike,
    required this.canComment,
    required this.canReply,
    this.relationType,
    this.isMutualOuter,
  });

  factory PostPermissions.fromJson(Map<String, dynamic> json) {
    return PostPermissions(
      canView: json['can_view'] ?? true,
      canLike: json['can_like'] ?? true,
      canComment: json['can_comment'] ?? true,
      canReply: json['can_reply'] ?? true,
      relationType: json['relation_type'],
      isMutualOuter: json['is_mutual_outer'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_view': canView,
      'can_like': canLike,
      'can_comment': canComment,
      'can_reply': canReply,
      if (relationType != null) 'relation_type': relationType,
      if (isMutualOuter != null) 'is_mutual_outer': isMutualOuter,
    };
  }
}
