import 'post_model.dart';

/// One cursor-paginated wall from GET /posts (`inner_proxy`, `outer_proxy`, etc.).
class FeedWallPage {
  const FeedWallPage({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
  });

  final List<Post> posts;
  final String? nextCursor;
  final bool hasMore;

  factory FeedWallPage.empty() => const FeedWallPage(posts: [], hasMore: false);

  factory FeedWallPage.fromSection(
    dynamic section,
    List<Post> Function(List<dynamic> raw) parsePosts,
  ) {
    if (section == null) return FeedWallPage.empty();

    if (section is List) {
      final posts = parsePosts(section);
      return FeedWallPage(posts: posts, hasMore: false);
    }

    if (section is! Map) return FeedWallPage.empty();

    final map = Map<String, dynamic>.from(section);
    final raw = map['data'] as List? ??
        map['posts'] as List? ??
        map['items'] as List? ??
        [];

    final nextCursor = map['next_cursor']?.toString();
    final hasMore = map['has_more'] == true ||
        (nextCursor != null && nextCursor.isNotEmpty);

    return FeedWallPage(
      posts: parsePosts(raw),
      nextCursor: hasMore ? nextCursor : null,
      hasMore: hasMore,
    );
  }
}

/// Normalizes `{ success, data: { inner_proxy, ... } }` and flat `{ inner_proxy }`.
Map<String, dynamic> unwrapDiscoverFeedPayload(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return response;
}
