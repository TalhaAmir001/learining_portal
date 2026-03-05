// lib/utils/widgets/chat_input_bar.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/messages/chat_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class ChatInputBar extends StatefulWidget {
  final ScrollController scrollController;

  const ChatInputBar({super.key, required this.scrollController});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isUploadingDocument = false;
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Image picker button
              IconButton(
                icon: Icon(
                  Icons.image_outlined,
                  color: AppColors.accentTeal,
                  size: 26,
                ),
                onPressed:
                    _isUploadingImage || _isUploadingDocument || _isSending
                    ? null
                    : _pickAndSendImage,
                tooltip: 'Send image',
              ),

              // Document picker button
              IconButton(
                icon: _isUploadingDocument
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentTeal,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.accentTeal,
                        size: 24,
                      ),
                onPressed:
                    _isUploadingImage || _isUploadingDocument || _isSending
                    ? null
                    : _pickAndSendDocument,
                tooltip: 'Send document',
              ),

              // Message input field
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue.withOpacity(0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppColors.accentTeal,
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSending ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _isSending
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.secondaryPurple,
                              ],
                            ),
                      color: _isSending
                          ? AppColors.textSecondary.withOpacity(0.3)
                          : null,
                      shape: BoxShape.circle,
                      boxShadow: _isSending
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
            if (widget.scrollController.hasClients) {
              widget.scrollController.animateTo(
                widget.scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error']?.toString() ?? 'Failed to upload image',
              ),
            ),
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
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'rtf',
      ],
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
      if (uploadResult['success'] == true &&
          uploadResult['document_url'] != null) {
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
            if (widget.scrollController.hasClients) {
              widget.scrollController.animateTo(
                widget.scrollController.position.maxScrollExtent,
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
            SnackBar(
              content: Text(
                uploadResult['error']?.toString() ??
                    'Failed to upload document',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingDocument = false);
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
      // Scroll to bottom after message is added
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (widget.scrollController.hasClients) {
            widget.scrollController.animateTo(
              widget.scrollController.position.maxScrollExtent,
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
