import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:learining_portal/models/message_model.dart';
import 'package:learining_portal/network/domain/messages_chat_repository.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

/// Regex to match URLs (http, https, optional www)
final RegExp _urlRegex = RegExp(
  r'(https?:\/\/[^\s<>\[\]()]+)|(www\.[^\s<>\[\]()]+)',
  caseSensitive: false,
);

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final String Function(DateTime) formatTime;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.formatTime,
  });

  Future<void> _downloadDocument(BuildContext context, String url, String filename) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 1)),
    );
    final path = await MessagesChatRepository.downloadChatDocument(url, filename);
    if (!context.mounted) return;
    if (path != null) {
      final result = await OpenFile.open(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.type == ResultType.done ? 'Downloaded' : result.message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    var uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) uri = Uri.parse('https://$url');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Open document URL: try browser first; if that fails (e.g. Android no handler), download and open locally.
  Future<void> _openDocumentUrl(
    BuildContext context,
    String url,
    String filename,
  ) async {
    var uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) uri = Uri.parse('https://$url');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    // Fallback: download and open with open_file (works when no browser handles the URL)
    if (!context.mounted) return;
    await _downloadDocument(context, url, filename);
  }

  Widget _buildLinkifiedText(String text, bool isCurrentUser) {
    final color = isCurrentUser ? Colors.white : Colors.black87;
    final linkColor = isCurrentUser
        ? Colors.lightBlueAccent
        : Colors.blue.shade700;
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: color, fontSize: 15),
          ),
        );
      }
      final url = match.group(0)!;
      final normalized = url.startsWith('www.') ? 'https://$url' : url;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            fontSize: 15,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(normalized),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: color, fontSize: 15),
        ),
      );
    }
    if (spans.isEmpty) {
      return Text(text, style: TextStyle(color: color, fontSize: 15));
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser ? colorScheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.senderDisplayName != null &&
                      message.senderDisplayName!.isNotEmpty) ...[
                    Text(
                      message.senderDisplayName!,
                      style: TextStyle(
                        color: isCurrentUser
                            ? Colors.white70
                            : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (message.messageType == 'image' &&
                      message.imageUrl != null &&
                      message.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.imageUrl!,
                        width: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            width: 220,
                            height: 160,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 220,
                          height: 120,
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey[600],
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  if (message.messageType == 'document' &&
                      (message.imageUrl != null &&
                              message.imageUrl!.isNotEmpty ||
                          message.uploadProgress != null ||
                          message.text.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: message.uploadProgress == null &&
                                message.imageUrl != null &&
                                message.imageUrl!.isNotEmpty
                            ? () => _openDocumentUrl(
                                  context,
                                  message.imageUrl!,
                                  message.text.isNotEmpty
                                      ? message.text
                                      : 'document',
                                )
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isCurrentUser
                                        ? Colors.white
                                        : Colors.grey.shade200)
                                    .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 28,
                                    color: isCurrentUser
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          message.text.isNotEmpty
                                              ? message.text
                                              : 'Document',
                                          style: TextStyle(
                                            color: isCurrentUser
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (message.uploadProgress != null)
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              color: isCurrentUser
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          )
                                        else if (message.imageUrl != null &&
                                            message.imageUrl!.isNotEmpty) ...[
                                          Text(
                                            'Tap to open',
                                            style: TextStyle(
                                              color: isCurrentUser
                                                  ? Colors.white70
                                                  : Colors.blue.shade700,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                          if (!isCurrentUser)
                                            GestureDetector(
                                              onTap: () =>
                                                  _downloadDocument(
                                                context,
                                                message.imageUrl!,
                                                message.text.isNotEmpty
                                                    ? message.text
                                                    : 'document',
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Text(
                                                  'Download',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    decoration:
                                                        TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (message.uploadProgress != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: message.uploadProgress,
                                    minHeight: 4,
                                    backgroundColor: (isCurrentUser
                                            ? Colors.white
                                            : Colors.grey)
                                        .withOpacity(0.3),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isCurrentUser
                                          ? Colors.white70
                                          : colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty &&
                      message.messageType != 'document') ...[
                    if (message.messageType == 'image')
                      const SizedBox(height: 6),
                    _buildLinkifiedText(message.text, isCurrentUser),
                  ],
                  if (message.messageType == 'document' &&
                      message.text.isEmpty &&
                      (message.imageUrl == null || message.imageUrl!.isEmpty))
                    Text(
                      'Document',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        formatTime(message.timestamp),
                        style: TextStyle(
                          color: isCurrentUser
                              ? Colors.white70
                              : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
