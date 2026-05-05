/// Allowed reaction glyph strings for `POST .../messages/{id}/react` (match server allow-list).
abstract final class MessageReactionEmojis {
  static const thumbsUp = '\u{1F44D}\u{1F3FB}';
  static const thumbsDown = '\u{1F44E}\u{1F3FB}';
  static const muscle = '\u{1F4AA}\u{1F3FB}';
  static const joy = '\u{1F602}';
  /// 😮 — messages API uses this instead of posts’ 😊.
  static const wow = '\u{1F62E}';
  static const heart = '\u{2764}\u{FE0F}';

  static const List<String> all = [
    thumbsUp,
    thumbsDown,
    muscle,
    joy,
    wow,
    heart,
  ];

  static bool isAllowed(String emoji) => all.contains(emoji);
}
