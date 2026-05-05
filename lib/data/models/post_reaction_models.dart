class PostReactionUserRow {
  final int userId;
  final String name;
  final String emoji;
  final String? avatarUrl;

  const PostReactionUserRow({
    required this.userId,
    required this.name,
    required this.emoji,
    this.avatarUrl,
  });

  factory PostReactionUserRow.fromApi(Map<String, dynamic> json) {
    final u = json['user'];
    final um = u is Map ? Map<String, dynamic>.from(u) : const <String, dynamic>{};
    return PostReactionUserRow(
      userId: um['id'] is int ? um['id'] as int : int.tryParse(um['id']?.toString() ?? '') ?? 0,
      name: um['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      avatarUrl: um['avatar_url']?.toString() ?? um['avatar']?.toString(),
    );
  }

  /// Shape expected by [UserProfileDetailScreen].
  Map<String, dynamic> toUserProfileDetailData() {
    return {
      'user': {
        'id': userId,
        'name': name,
        'profile': {
          if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatar': avatarUrl,
        },
      },
      'in_inner_circle': false,
      'in_outer_circle': false,
      'inner_request_status': 'not_sent',
    };
  }
}

class PostReactionSummary {
  final Map<String, int> counts;
  final int total;
  final String? myEmoji;
  final List<PostReactionUserRow> users;

  const PostReactionSummary({
    required this.counts,
    required this.total,
    required this.myEmoji,
    required this.users,
  });

  factory PostReactionSummary.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    final rawCounts = json['counts'];
    if (rawCounts is Map) {
      rawCounts.forEach((key, value) {
        final k = key.toString();
        if (value is int) {
          counts[k] = value;
        } else {
          counts[k] = int.tryParse(value?.toString() ?? '') ?? 0;
        }
      });
    }

    String? myEmoji;
    final mine = json['mine'];
    if (mine is String && mine.isNotEmpty) {
      myEmoji = mine;
    } else if (mine is Map && mine['emoji'] != null) {
      myEmoji = mine['emoji'].toString();
    }

    final users = <PostReactionUserRow>[];
    final rawUsers = json['users'];
    if (rawUsers is List) {
      for (final item in rawUsers) {
        if (item is Map) {
          users.add(PostReactionUserRow.fromApi(Map<String, dynamic>.from(item)));
        }
      }
    }

    final total = json['total'] is int
        ? json['total'] as int
        : int.tryParse(json['total']?.toString() ?? '') ?? 0;

    return PostReactionSummary(
      counts: counts,
      total: total,
      myEmoji: myEmoji,
      users: users,
    );
  }
}
