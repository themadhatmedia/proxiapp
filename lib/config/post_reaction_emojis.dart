/// Allowed reaction glyph strings sent to `POST .../posts/{id}/react` (must match server allow-list).
abstract final class PostReactionEmojis {
  static const thumbsUp = '\u{1F44D}\u{1F3FB}';
  static const thumbsDown = '\u{1F44E}\u{1F3FB}';
  static const muscle = '\u{1F4AA}\u{1F3FB}';
  static const joy = '\u{1F602}';
  static const smile = '\u{1F60A}';
  static const heart = '\u{2764}\u{FE0F}';

  static const List<String> all = [
    thumbsUp,
    thumbsDown,
    muscle,
    joy,
    smile,
    heart,
  ];

  static bool isAllowed(String emoji) => all.contains(emoji);
}
