import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/post_model.dart';
import '../../data/models/post_reaction_models.dart';
import '../../utils/app_vibration.dart';
import '../../widgets/post_reaction_action_button.dart';
import '../../widgets/safe_avatar.dart';
import '../pulse/user_profile_detail_screen.dart';

/// Shared by posts and DM messages (`users` shape matches API).
Future<void> showReactionParticipantsBottomSheet(
  BuildContext context, {
  required List<PostReactionUserRow> users,
}) async {
  if (users.isEmpty) return;

  PostReactionActionButton.dismissFloatingReactionPicker();
  await Future<void>.delayed(Duration.zero);

  AppVibration.likesListOpen();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PostReactionsSheetContent(users: users),
  );
}

Future<void> showPostReactionsBottomSheet(BuildContext context, Post post) async {
  final users = post.reactions?.users ?? [];
  await showReactionParticipantsBottomSheet(context, users: users);
}

class _PostReactionsSheetContent extends StatelessWidget {
  const _PostReactionsSheetContent({required this.users});

  final List<PostReactionUserRow> users;

  void _openUser(BuildContext context, PostReactionUserRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => UserProfileDetailScreen(
          userData: row.toUserProfileDetailData(),
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        gradient: AppTheme.scaffoldGradient(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Reactions',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${users.length}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withOpacity(0.2)),
              itemBuilder: (context, i) {
                final row = users[i];
                final authId = Get.isRegistered<AuthController>()
                    ? Get.find<AuthController>().user?.id
                    : null;
                final isSelf = authId != null && authId == row.userId;

                return ListTile(
                  leading: SafeAvatar(
                    imageUrl: row.avatarUrl,
                    size: 44,
                    fallbackText: row.name,
                  ),
                  title: Text(
                    row.name,
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                  ),
                  subtitle: isSelf ? Text('You', style: TextStyle(color: cs.primary, fontSize: 12)) : null,
                  trailing: Text(row.emoji, style: const TextStyle(fontSize: 26)),
                  onTap: row.userId > 0 ? () => _openUser(context, row) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
