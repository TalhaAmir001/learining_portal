import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart' show AuthProvider, UserType;
import 'package:learining_portal/providers/messages/chat_provider.dart';
import 'package:learining_portal/services/notification_service.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/constants.dart';
import 'package:learining_portal/utils/widgets/messages/chat_input_bar.dart';
import 'package:learining_portal/utils/widgets/messages/message_bubble.dart';
import 'package:learining_portal/utils/widgets/messages/ticket_floating_bar.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final UserModel? otherUser;
  final String? chatId; // Optional: if chat already exists

  const ChatScreen({super.key, this.otherUser, this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Wrapper widget to provide ChatProvider
class ChatScreenWrapper extends StatelessWidget {
  final UserModel? otherUser;
  final String? chatId;

  const ChatScreenWrapper({super.key, this.otherUser, this.chatId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: ChatScreen(otherUser: otherUser, chatId: chatId),
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lastNotifiedChatId;
  String? _lastMarkedReadChatId;
  bool _hasScrolledToBottomOnLoad = false;
  int _previousMessageCount = 0;

  @override
  void dispose() {
    // Clear the current open chat when leaving the chat screen
    final notificationService = NotificationService();
    notificationService.clearCurrentOpenChat();

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  void _initializeChat() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationService = NotificationService();

    if (widget.chatId != null) {
      chatProvider.setChatId(widget.chatId!, authProvider: authProvider).then((
        _,
      ) async {
        if (chatProvider.chatId != null) {
          notificationService.setCurrentOpenChat(chatProvider.chatId);
          final other = widget.otherUser;
          final isAdminOpeningSupportThread =
              authProvider.userType == UserType.admin &&
              authProvider.currentUser?.uid != null &&
              (other == null ||
                  other.userType == UserType.student ||
                  other.userType == UserType.teacher ||
                  other.userType == UserType.guardian);
          if (isAdminOpeningSupportThread) {
            await MessagesChatRepository.claimSupportConnection(
              connectionId: chatProvider.chatId!,
              staffId: authProvider.currentUser!.uid,
            );
          }
        }
      });
    } else if (widget.otherUser != null) {
      // Initialize chat with the other user. Pass otherUserType so backend finds the right fl_chat_users row (teacher_id, student_id, parent_id).
      final otherUser = widget.otherUser!;
      final otherUserType = otherUser.uid == supportUserId
          ? null
          : UserModel.userTypeToApiString(otherUser.userType);
      chatProvider
          .initializeChat(
            otherUser.uid,
            authProvider: authProvider,
            otherUserType: otherUserType,
          )
          .then((_) async {
            if (chatProvider.chatId != null) {
              notificationService.setCurrentOpenChat(chatProvider.chatId);
              // When admin opens a support thread (chat with student, teacher, or guardian), claim it
              final isAdminOpeningSupportThread =
                  authProvider.userType == UserType.admin &&
                  authProvider.currentUser?.uid != null &&
                  (otherUser.userType == UserType.student ||
                      otherUser.userType == UserType.teacher ||
                      otherUser.userType == UserType.guardian);
              if (isAdminOpeningSupportThread) {
                await MessagesChatRepository.claimSupportConnection(
                  connectionId: chatProvider.chatId!,
                  staffId: authProvider.currentUser!.uid,
                );
              }
            }
          });
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  void _showReportDialog(BuildContext context, UserModel reportedUser) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 10),
            const Text('Report user'),
          ],
        ),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: 'Reason for report (optional)',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primaryBlue.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primaryBlue.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryBlue,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: AppColors.backgroundLight,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final chatProvider = Provider.of<ChatProvider>(
                context,
                listen: false,
              );
              chatProvider.reportUser(
                reportedUserId: reportedUser.uid,
                reportedUserType: UserModel.userTypeToApiString(
                  reportedUser.userType,
                ),
                reason: reasonController.text.trim().isEmpty
                    ? 'No reason provided'
                    : reasonController.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Report submitted. Thank you.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherUser = widget.otherUser;

    if (otherUser == null && widget.chatId == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryBlue, AppColors.backgroundLight],
              stops: [0.0, 0.5],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Text(
                'Error: No user or chat ID provided',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Gradient app bar
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  if (otherUser != null) ...[
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage:
                          otherUser.photoUrl != null &&
                              otherUser.photoUrl!.isNotEmpty
                          ? NetworkImage(otherUser.photoUrl!)
                          : null,
                      child:
                          otherUser.photoUrl == null ||
                              otherUser.photoUrl!.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        otherUser.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (value) {
                        if (value == 'report')
                          _showReportDialog(context, otherUser);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Report user'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chat',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Messages List
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  // Use same ID as backend/WebSocket: guardian = parent id (user.id), others = uid
                  final currentUser = authProvider.currentUser;
                  final myApiId = currentUser == null
                      ? null
                      : (currentUser.userType == UserType.guardian
                          ? currentUser.id
                          : currentUser.uid);
                  // Update notification service when chatId becomes available
                  if (chatProvider.chatId != null &&
                      chatProvider.chatId != _lastNotifiedChatId) {
                    _lastNotifiedChatId = chatProvider.chatId;
                    _hasScrolledToBottomOnLoad =
                        false; // New chat: scroll to bottom when messages load
                    _previousMessageCount = 0;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final notificationService = NotificationService();
                      notificationService.setCurrentOpenChat(
                        chatProvider.chatId,
                      );
                    });
                  }
                  if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentTeal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading conversation...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (chatProvider.errorMessage != null &&
                      chatProvider.messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: Colors.red.shade400,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              chatProvider.errorMessage!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (chatProvider.messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: AppColors.accentTeal.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No messages yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Mark messages as read whenever there are unread incoming messages visible.
                  // Runs on every build so new arrivals while the screen is open are caught.
                  final chatId = chatProvider.chatId;
                  if (chatId != null) {
                    final hasUnread = chatProvider.messages.any((m) {
                      final isIncoming = myApiId != null &&
                          m.senderId != myApiId &&
                          m.actualSenderId != myApiId;
                      return isIncoming && !m.isRead;
                    });
                    if (hasUnread || chatId != _lastMarkedReadChatId) {
                      _lastMarkedReadChatId = chatId;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        chatProvider.markMessagesAsRead(
                          authProvider: authProvider,
                        );
                      });
                    }
                  }

                  // Scroll to bottom once when messages first load (chronological: newest at bottom)
                  if (!_hasScrolledToBottomOnLoad &&
                      chatProvider.messages.isNotEmpty) {
                    _hasScrolledToBottomOnLoad = true;
                    _previousMessageCount = chatProvider.messages.length;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                            _scrollController.position.maxScrollExtent,
                          );
                        }
                      });
                    });
                  }

                  // Scroll to bottom whenever a new chat bubble is added (sent or received)
                  if (chatProvider.messages.length > _previousMessageCount) {
                    _previousMessageCount = chatProvider.messages.length;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    });
                  }

                  final hasMore =
                      chatProvider.hasMore && !chatProvider.isLoadingMore;
                  final itemCount =
                      chatProvider.messages.length + (hasMore ? 1 : 0);

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (hasMore && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: chatProvider.isLoadingMore
                                  ? null
                                  : () => chatProvider.loadMoreOlderMessages(),
                              icon: chatProvider.isLoadingMore
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.expand_less),
                              label: Text(
                                chatProvider.isLoadingMore
                                    ? 'Loading...'
                                    : 'Load older messages',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final msgIndex = hasMore ? index - 1 : index;
                      final message = chatProvider.messages[msgIndex];
                      final bool isCurrentUser =
                          myApiId != null &&
                          (message.senderId == myApiId ||
                              message.actualSenderId == myApiId);

                      return MessageBubble(
                        message: message,
                        isCurrentUser: isCurrentUser,
                        formatTime: _formatTime,
                      );
                    },
                  );
                },
              ),
            ),
            const TicketFloatingBar(),
            ChatInputBar(scrollController: _scrollController),
          ],
        ),
      ),
    );
  }
}
