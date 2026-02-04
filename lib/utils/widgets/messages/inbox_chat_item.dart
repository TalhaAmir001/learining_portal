import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:learining_portal/models/chat_model.dart';
import 'package:learining_portal/screens/messages/chat.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ChatListItem extends StatelessWidget {
  final ChatModel chat;

  const ChatListItem({super.key, required this.chat});

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // Show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserId;
    
    if (currentUserId == null) {
      debugPrint('ChatListItem: currentUserId is null');
      return const SizedBox.shrink();
    }

    final otherUser = chat.getOtherUser(currentUserId);
    if (otherUser == null) {
      debugPrint('ChatListItem: otherUser is null for chat ${chat.chatId}, currentUserId: $currentUserId, user1Id: ${chat.user1Id}, user2Id: ${chat.user2Id}');
      return const SizedBox.shrink();
    }

    final isLastMessageFromCurrentUser =
        chat.lastMessageSenderId == currentUserId;
    final lastMessagePreview = chat.lastMessage ?? 'No messages yet';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatScreenWrapper(otherUser: otherUser, chatId: chat.chatId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  backgroundImage:
                      otherUser.photoUrl != null &&
                          otherUser.photoUrl!.isNotEmpty
                      ? NetworkImage(otherUser.photoUrl!)
                      : null,
                  child:
                      otherUser.photoUrl == null ||
                          otherUser.photoUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          size: 28,
                        )
                      : null,
                ),
                // Unread indicator
                if (chat.hasUnreadMessages)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Time Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUser.fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: chat.hasUnreadMessages
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Time
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.hasUnreadMessages
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[500],
                          fontWeight: chat.hasUnreadMessages
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message preview
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isLastMessageFromCurrentUser
                              ? 'You: $lastMessagePreview'
                              : lastMessagePreview,
                          style: TextStyle(
                            fontSize: 14,
                            color: chat.hasUnreadMessages
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: chat.hasUnreadMessages
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
