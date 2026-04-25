import 'package:get/get.dart';

import '../views/messages/conversation_screen.dart';

/// Navigates to a 1:1 thread with the given [otherUserId].
void openProxiConversation({
  required int otherUserId,
  String displayName = 'User',
  String? profilePicture,
}) {
  if (otherUserId <= 0) return;
  Get.to<void>(
    () => ConversationScreen(
      otherUserId: otherUserId,
      otherDisplayName: displayName,
      otherAvatarUrl: profilePicture,
    ),
  );
}

int? intFromFcmData(Map<String, dynamic> data) {
  final c = int.tryParse(
    '${data['other_user_id'] ?? data['sender_id'] ?? data['user_id'] ?? data['conversation_id'] ?? data['receiver_id'] ?? ''}',
  );
  if (c != null && c > 0) return c;
  return null;
}

void openProxiConversationIfPossible(Map<String, dynamic> data) {
  final id = intFromFcmData(data);
  if (id == null) return;
  final name = (data['sender_name'] ?? data['user_name'] ?? data['name'] ?? 'User')?.toString() ?? 'User';
  final avatar = (data['profile_picture'] ?? data['avatar'] ?? data['sender_avatar'])?.toString();
  openProxiConversation(
    otherUserId: id,
    displayName: name,
    profilePicture: avatar?.isNotEmpty == true ? avatar : null,
  );
}
