import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:learining_portal/providers/messages/chat_provider.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/models/user_model.dart';
import 'package:learining_portal/utils/widgets/messages/message_bubble.dart';
import 'package:learining_portal/services/notification_service.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
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
  bool _isUploadingImage = false;
  bool _isUploadingDocument = false;
  String? _lastNotifiedChatId;
  bool _hasScrolledToBottomOnLoad = false;
  final ImagePicker _imagePicker = ImagePicker();

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
      ) async {
        if (chatProvider.chatId != null) {
          notificationService.setCurrentOpenChat(chatProvider.chatId);
          // When admin opens a support thread (chat with student), claim it
          if (authProvider.userType == UserType.admin &&
              widget.otherUser?.userType == UserType.student &&
              authProvider.currentUser?.uid != null) {
            await MessagesChatRepository.claimSupportConnection(
              connectionId: chatProvider.chatId!,
              staffId: authProvider.currentUser!.uid,
            );
          }
        }
      });
    } else if (widget.otherUser != null) {
      // Initialize chat with the other user
      // The uid is the Firestore document ID (which is actually the API user ID)
      chatProvider
          .initializeChat(widget.otherUser!.uid, authProvider: authProvider)
          .then((_) async {
            if (chatProvider.chatId != null) {
              notificationService.setCurrentOpenChat(chatProvider.chatId);
              // When admin opens a support thread (chat with student), claim it so other admins don't see it
              if (authProvider.userType == UserType.admin &&
                  widget.otherUser?.userType == UserType.student &&
                  authProvider.currentUser?.uid != null) {
                await MessagesChatRepository.claimSupportConnection(
                  connectionId: chatProvider.chatId!,
                  staffId: authProvider.currentUser!.uid,
                );
              }
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

  Future<void> _pickAndSendImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    setState(() => _isUploadingImage = true);
    try {
      final result = await MessagesChatRepository.uploadChatImage(file);
      if (!mounted) return;
      if (result['success'] == true && result['image_url'] != null) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await chatProvider.sendMessage(
          '',
          authProvider: authProvider,
          messageType: 'image',
          imageUrl: result['image_url'] as String,
        );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error']?.toString() ?? 'Failed to upload image')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final platformFile = result.files.single;
    final path = platformFile.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access file path')),
        );
      }
      return;
    }
    final file = File(path);
    if (!file.existsSync()) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final filename = platformFile.name;
    final tempId = chatProvider.addOptimisticDocumentMessage(filename);
    if (tempId == null || !mounted) return;
    setState(() => _isUploadingDocument = true);
    try {
      final uploadResult = await MessagesChatRepository.uploadChatDocument(
        file,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            chatProvider.updateDocumentUploadProgress(tempId, sent / total);
          }
        },
      );
      if (!mounted) return;
      if (uploadResult['success'] == true && uploadResult['document_url'] != null) {
        final docUrl = uploadResult['document_url'] as String;
        final name = uploadResult['filename'] as String? ?? filename;
        await chatProvider.finalizeAndSendDocumentMessage(
          tempId,
          docUrl,
          name,
          authProvider: authProvider,
        );
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
        chatProvider.removeOptimisticDocumentMessage(tempId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(uploadResult['error']?.toString() ?? 'Failed to upload document')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingDocument = false);
    }
  }

  void _showReportDialog(BuildContext context, UserModel reportedUser) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report user'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Reason for report (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              chatProvider.reportUser(
                reportedUserId: reportedUser.uid,
                reportedUserType: reportedUser.userType == UserType.teacher || reportedUser.userType == UserType.admin ? 'staff' : 'student',
                reason: reasonController.text.trim().isEmpty ? 'No reason provided' : reasonController.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted. Thank you.')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
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
        actions: otherUser != null
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'report') _showReportDialog(context, otherUser);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'report', child: Text('Report user')),
                  ],
                ),
              ]
            : null,
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
                  _hasScrolledToBottomOnLoad = false; // New chat: scroll to bottom when messages load
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

                // Scroll to bottom once when messages first load (chronological: newest at bottom)
                if (!_hasScrolledToBottomOnLoad && chatProvider.messages.isNotEmpty) {
                  _hasScrolledToBottomOnLoad = true;
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

                final hasMore = chatProvider.hasMore && !chatProvider.isLoadingMore;
                final itemCount = chatProvider.messages.length + (hasMore ? 1 : 0);

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
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.expand_less),
                            label: Text(
                              chatProvider.isLoadingMore
                                  ? 'Loading...'
                                  : 'Load older messages',
                              style: TextStyle(color: colorScheme.primary),
                            ),
                          ),
                        ),
                      );
                    }
                    final msgIndex = hasMore ? index - 1 : index;
                    final message = chatProvider.messages[msgIndex];
                    final bool isCurrentUser =
                        message.senderId == authProvider.currentUser?.uid ||
                        message.actualSenderId == authProvider.currentUser?.uid;

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
                    IconButton(
                      icon: Icon(Icons.image_outlined, color: colorScheme.primary),
                      onPressed: _isUploadingImage || _isUploadingDocument || _isSending ? null : _pickAndSendImage,
                      tooltip: 'Send image',
                    ),
                    IconButton(
                      icon: _isUploadingDocument
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.attach_file, color: colorScheme.primary),
                      onPressed: _isUploadingImage || _isUploadingDocument || _isSending ? null : _pickAndSendDocument,
                      tooltip: 'Send document',
                    ),
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
