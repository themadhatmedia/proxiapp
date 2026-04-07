import 'post_model.dart';

class PostLikesPagination {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final bool hasMore;

  PostLikesPagination({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });

  factory PostLikesPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PostLikesPagination(
        total: 0,
        perPage: 15,
        currentPage: 1,
        lastPage: 1,
        hasMore: false,
      );
    }
    return PostLikesPagination(
      total: json['total'] is int ? json['total'] as int : int.tryParse('${json['total']}') ?? 0,
      perPage: json['per_page'] is int ? json['per_page'] as int : int.tryParse('${json['per_page']}') ?? 15,
      currentPage:
          json['current_page'] is int ? json['current_page'] as int : int.tryParse('${json['current_page']}') ?? 1,
      lastPage: json['last_page'] is int ? json['last_page'] as int : int.tryParse('${json['last_page']}') ?? 1,
      hasMore: json['has_more'] == true,
    );
  }
}

/// One liker row from GET /posts/{id}/likes.
class PostLikeUser {
  final int id;
  final String name;
  final String? email;
  final DateTime? likedAt;
  final bool inInnerCircle;
  final bool inOuterCircle;
  final String innerRequestStatus;
  final int? innerRequestId;
  final bool isFavorite;
  final Map<String, dynamic> profile;

  PostLikeUser({
    required this.id,
    required this.name,
    this.email,
    this.likedAt,
    this.inInnerCircle = false,
    this.inOuterCircle = false,
    this.innerRequestStatus = 'not_sent',
    this.innerRequestId,
    this.isFavorite = false,
    this.profile = const {},
  });

  factory PostLikeUser.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> profileMap = {};
    final p = json['profile'];
    if (p is Map) {
      profileMap = Map<String, dynamic>.from(p);
    }

    return PostLikeUser(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      likedAt: json['liked_at'] != null ? DateTime.tryParse(json['liked_at'].toString()) : null,
      inInnerCircle: json['in_inner_circle'] == true,
      inOuterCircle: json['in_outer_circle'] == true,
      innerRequestStatus: json['inner_request_status']?.toString() ?? 'not_sent',
      innerRequestId: json['inner_request_id'] is int ? json['inner_request_id'] as int : int.tryParse('${json['inner_request_id']}'),
      isFavorite: json['isFavorite'] == true,
      profile: profileMap,
    );
  }

  /// Shape expected by [UserProfileDetailScreen].
  Map<String, dynamic> toUserProfileDetailData() {
    return {
      'user': {
        'id': id,
        'name': name,
        if (email != null) 'email': email,
        'isFavorite': isFavorite,
        'profile': profile,
      },
      'in_inner_circle': inInnerCircle,
      'in_outer_circle': inOuterCircle,
      'inner_request_status': innerRequestStatus,
      if (innerRequestId != null) 'inner_request_id': innerRequestId,
    };
  }
}

class PostLikesResult {
  final List<PostLikeUser> users;
  final PostLikesPagination pagination;
  final PostPermissions? permissions;

  PostLikesResult({
    required this.users,
    required this.pagination,
    this.permissions,
  });

  factory PostLikesResult.fromJson(Map<String, dynamic> json) {
    PostPermissions? perms;
    if (json['permissions'] is Map<String, dynamic>) {
      perms = PostPermissions.fromJson(json['permissions'] as Map<String, dynamic>);
    }

    final data = json['data'];
    List<dynamic> rawUsers = [];
    Map<String, dynamic>? paginationJson;
    if (data is Map<String, dynamic>) {
      rawUsers = data['users'] is List ? data['users'] as List<dynamic> : [];
      paginationJson = data['pagination'] is Map<String, dynamic> ? data['pagination'] as Map<String, dynamic> : null;
    }

    final users = rawUsers
        .map((e) => PostLikeUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PostLikesResult(
      users: users,
      pagination: PostLikesPagination.fromJson(paginationJson),
      permissions: perms,
    );
  }
}
