import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String? actualSenderId; // Staff who sent when replying as Support (support thread)
  final String? senderDisplayName; // Display name for actual sender (e.g. admin name above message)
  final String text;
  final DateTime timestamp;
  final bool isRead;
  /// 'text', 'image', or 'document'
  final String messageType;
  /// URL when messageType is 'image' or 'document'
  final String? imageUrl;
  /// Upload progress 0.0–1.0 for outgoing document/image; null when not uploading
  final double? uploadProgress;

  MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    this.actualSenderId,
    this.senderDisplayName,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
    this.imageUrl,
    this.uploadProgress,
  });

  // Create MessageModel from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel.fromMap(data, doc.id);
  }

  // Helper function to safely parse int from dynamic value (handles both int and String)
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }

  // Helper function to safely parse bool from dynamic value
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      if (value == '1' || value.toLowerCase() == 'true') return true;
      if (value == '0' || value.toLowerCase() == 'false') return false;
      return int.tryParse(value) == 1;
    }
    return false;
  }

  // Create MessageModel from WebSocket/database format
  // Database format: {id, chat_connection_id, chat_user_id, message, created_at, is_read, sender_id}
  factory MessageModel.fromWebSocket(Map<String, dynamic> data) {
    final messageId =
        data['id']?.toString() ?? data['message_id']?.toString() ?? '';
    final chatConnectionId = data['chat_connection_id']?.toString() ?? '';
    final message = data['message'] as String? ?? '';
    final senderId = data['sender_id']?.toString() ?? '';

    // Safely parse is_read (can be int, bool, or String from MySQL)
    final isRead = _parseBool(data['is_read']);

    // Parse timestamp - can be Unix timestamp (int/String) or MySQL datetime string
    DateTime timestamp;
    if (data['created_at'] != null) {
      if (data['created_at'] is String) {
        // MySQL datetime format: "2024-01-01 12:00:00"
        try {
          timestamp = DateTime.parse(data['created_at'] as String);
        } catch (e) {
          timestamp = DateTime.now();
        }
      } else {
        // Try to parse as Unix timestamp (int or String)
        final timestampValue = _parseInt(data['created_at']);
        if (timestampValue != null) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(
            timestampValue * 1000,
          );
        } else {
          timestamp = DateTime.now();
        }
      }
    } else if (data['time'] != null) {
      // Unix timestamp from 'time' field (can be int or String)
      final timeValue = _parseInt(data['time']);
      if (timeValue != null) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(timeValue * 1000);
      } else {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    final actualSenderId = data['actual_sender_staff_id']?.toString();
    final senderDisplayName = data['sender_display_name'] as String?;
    final rawType = data['message_type'] as String?;
    final imageUrl = (data['image_url'] ?? data['document_url']) as String?;
    // Infer document when we have image_url but type is missing/text (e.g. loaded from server after reopen)
    final messageType = rawType == 'image'
        ? 'image'
        : (rawType == 'document'
            ? 'document'
            : (imageUrl != null && imageUrl.isNotEmpty
                ? 'document'
                : 'text'));

    return MessageModel(
      messageId: messageId,
      chatId: chatConnectionId,
      senderId: senderId,
      actualSenderId: actualSenderId?.isNotEmpty == true ? actualSenderId : null,
      senderDisplayName: senderDisplayName?.isNotEmpty == true ? senderDisplayName : null,
      text: message,
      timestamp: timestamp,
      isRead: isRead,
      messageType: messageType,
      imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
      uploadProgress: null,
    );
  }

  // Create MessageModel from Map (for Firestore compatibility)
  factory MessageModel.fromMap(Map<String, dynamic> map, String messageId) {
    final actualSenderId = map['actualSenderId'] as String? ?? map['actual_sender_staff_id']?.toString();
    final senderDisplayName = map['senderDisplayName'] as String? ?? map['sender_display_name'] as String?;
    final rawType = map['messageType'] as String? ?? map['message_type'] as String?;
    final messageType = rawType == 'image' ? 'image' : (rawType == 'document' ? 'document' : 'text');
    final imageUrl = map['imageUrl'] as String? ?? map['image_url'] as String?;
    return MessageModel(
      messageId: messageId,
      chatId:
          map['chatId'] as String? ??
          map['chat_connection_id']?.toString() ??
          '',
      senderId:
          map['senderId'] as String? ?? map['sender_id']?.toString() ?? '',
      actualSenderId: actualSenderId?.isNotEmpty == true ? actualSenderId : null,
      senderDisplayName: senderDisplayName?.isNotEmpty == true ? senderDisplayName : null,
      text: map['text'] as String? ?? map['message'] as String? ?? '',
      timestamp:
          (map['timestamp'] as Timestamp?)?.toDate() ??
          (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null) ??
          DateTime.now(),
      isRead: MessageModel._parseBool(map['isRead'] ?? map['is_read']),
      messageType: messageType,
      imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
      uploadProgress: null,
    );
  }

  // Convert MessageModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  // Copy with method. Pass [clearUploadProgress: true] to set uploadProgress to null.
  MessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? actualSenderId,
    String? senderDisplayName,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    String? messageType,
    String? imageUrl,
    double? uploadProgress,
    bool clearUploadProgress = false,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      actualSenderId: actualSenderId ?? this.actualSenderId,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      uploadProgress: clearUploadProgress ? null : (uploadProgress ?? this.uploadProgress),
    );
  }

  @override
  String toString() {
    return 'MessageModel(messageId: $messageId, chatId: $chatId, senderId: $senderId, text: $text)';
  }
}
