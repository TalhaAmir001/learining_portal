import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
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

    return MessageModel(
      messageId: messageId,
      chatId: chatConnectionId,
      senderId: senderId,
      text: message,
      timestamp: timestamp,
      isRead: isRead,
    );
  }

  // Create MessageModel from Map (for Firestore compatibility)
  factory MessageModel.fromMap(Map<String, dynamic> map, String messageId) {
    return MessageModel(
      messageId: messageId,
      chatId:
          map['chatId'] as String? ??
          map['chat_connection_id']?.toString() ??
          '',
      senderId:
          map['senderId'] as String? ?? map['sender_id']?.toString() ?? '',
      text: map['text'] as String? ?? map['message'] as String? ?? '',
      timestamp:
          (map['timestamp'] as Timestamp?)?.toDate() ??
          (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null) ??
          DateTime.now(),
      isRead: MessageModel._parseBool(map['isRead'] ?? map['is_read']),
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

  // Copy with method
  MessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() {
    return 'MessageModel(messageId: $messageId, chatId: $chatId, senderId: $senderId, text: $text)';
  }
}
