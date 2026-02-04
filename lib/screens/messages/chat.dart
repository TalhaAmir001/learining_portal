import 'package:flutter/material.dart';
import 'package:learining_portal/providers/messages/chat_provider.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/utils/widgets/messages/message_bubble.dart';
import 'package:learining_portal/services/notification_service.dart';
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
  bool _isSending = false;
  String? _lastNotifiedChatId; // Track the last chatId we notified about

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
      // If chat ID is provided, we need to set it and load messages
      // This will convert Firestore chat ID to database connection ID if needed
      chatProvider.setChatId(widget.chatId!, authProvider: authProvider).then((
        _,
      ) {
        // Set the current open chat after conversion
        if (chatProvider.chatId != null) {
          notificationService.setCurrentOpenChat(chatProvider.chatId);
        }
      });
    } else if (widget.otherUser != null) {
      // Initialize chat with the other user
      // The uid is the Firestore document ID (which is actually the API user ID)
      chatProvider
          .initializeChat(widget.otherUser!.uid, authProvider: authProvider)
          .then((_) {
            // After chat is initialized, set the current open chat
            if (chatProvider.chatId != null) {
              notificationService.setCurrentOpenChat(chatProvider.chatId);
            }
          });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await chatProvider.sendMessage(
      messageText,
      authProvider: authProvider,
    );

    if (success) {
      // Scroll to bottom after message is added (message appears optimistically)
      // Wait for next frame to ensure message is rendered
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
    } else {
      // Restore message text if sending failed
      _messageController.text = messageText;
    }

    setState(() {
      _isSending = false;
    });
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final otherUser = widget.otherUser;

    if (otherUser == null && widget.chatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Error: No user or chat ID provided')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: otherUser != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 18,
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
                            size: 18,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      otherUser.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : const Text('Chat', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                // Update notification service when chatId becomes available
                if (chatProvider.chatId != null &&
                    chatProvider.chatId != _lastNotifiedChatId) {
                  _lastNotifiedChatId = chatProvider.chatId;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final notificationService = NotificationService();
                    notificationService.setCurrentOpenChat(chatProvider.chatId);
                  });
                }
                if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatProvider.errorMessage != null &&
                    chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          chatProvider.errorMessage!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark messages as read when viewing
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  chatProvider.markMessagesAsRead(authProvider: authProvider);
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    // Compare with API user ID (uid) not Firestore document ID
                    final isCurrentUser =
                        message.senderId == authProvider.currentUser?.uid;

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

          // Message Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _isSending
                          ? Colors.grey
                          : colorScheme.primary,
                      child: IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
