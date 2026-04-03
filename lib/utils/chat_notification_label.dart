import 'package:learining_portal/utils/constants.dart';

/// Whether the message is from the Support side (virtual user or staff reply in a Support thread).
bool isSupportSideMessageSender({
  required String senderId,
  String? actualSenderStaffId,
}) {
  final sid = senderId.trim();
  return sid == supportUserId ||
      (actualSenderStaffId != null && actualSenderStaffId.trim().isNotEmpty);
}

/// Title for local chat notifications: admins see [senderDisplayNameOrTitleFromPayload];
/// other roles see "Support" for Support-side messages (same idea as [MessageBubble]).
String chatNotificationSenderTitle({
  required bool viewerIsAdmin,
  required String senderId,
  String? actualSenderStaffId,
  String? senderDisplayNameOrTitleFromPayload,
}) {
  final fromSupport = isSupportSideMessageSender(
    senderId: senderId,
    actualSenderStaffId: actualSenderStaffId,
  );
  if (!viewerIsAdmin && fromSupport) return 'Support';
  final t = senderDisplayNameOrTitleFromPayload?.trim();
  if (t != null && t.isNotEmpty) return t;
  if (senderId.trim() == supportUserId) return 'Support';
  return 'New message';
}
