import 'package:flutter/material.dart';

import '../config/post_reaction_emojis.dart';
import '../data/models/post_model.dart';
import 'emoji_reaction_action_button.dart';

/// Tap = quick 👍🏻 toggle; long-press = floating pill above the button (Messenger / Facebook-style).
class PostReactionActionButton extends StatelessWidget {
  const PostReactionActionButton({
    super.key,
    required this.post,
    required this.enabled,
    required this.isLoading,
    required this.onQuickTap,
    required this.onEmojiChosen,
  });

  final Post post;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onQuickTap;
  final Future<void> Function(String emoji) onEmojiChosen;

  /// Forwards to [EmojiReactionActionButton] (same overlay slot as messages).
  static void dismissFloatingReactionPicker() =>
      EmojiReactionActionButton.dismissFloatingReactionPicker();

  @override
  Widget build(BuildContext context) {
    final emoji =
        post.reactions?.myEmoji ?? (post.liked ? PostReactionEmojis.thumbsUp : null);
    return EmojiReactionActionButton(
      reactionEmojis: PostReactionEmojis.all,
      pickerSelectionEmoji: post.reactions?.myEmoji,
      displayEmoji: emoji,
      hasMine: post.reactions?.myEmoji != null || post.liked,
      enabled: enabled,
      isLoading: isLoading,
      compact: false,
      onQuickTap: onQuickTap,
      onEmojiChosen: onEmojiChosen,
    );
  }
}
