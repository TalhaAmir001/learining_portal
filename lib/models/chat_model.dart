import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learining_portal/models/user_model.dart';

class ChatModel {
  final String chatId;
  final String user1Id;
  final String user2Id;
  final UserModel? user1; // Other user's data (not current user)
  final UserModel? user2; // Other user's data (not current user)
  /// Display name from API (e.g. for parents when Firestore doc id differs). Use when otherUser.fullName is empty.
  final String? otherUserDisplayName;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final bool hasUnreadMessages;
  /// Number of messages unread by the current user in this chat (for WhatsApp-style badge).
  final int unreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatModel({
    required this.chatId,
    required this.user1Id,
    required this.user2Id,
    this.user1,
    this.user2,
    this.otherUserDisplayName,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.hasUnreadMessages = false,
    this.unreadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  // Get the other user (not the current user)
  UserModel? getOtherUser(String currentUserId) {
    if (user1Id == currentUserId) {
      return user2;
    } else if (user2Id == currentUserId) {
      return user1;
    }
    return null;
  }

  /// Best display name for the other user: from UserModel or API fallback (for parents).
  String getOtherUserDisplayName(String currentUserId) {
    final other = getOtherUser(currentUserId);
    if (other != null && other.fullName.isNotEmpty) return other.fullName;
    if (otherUserDisplayName != null && otherUserDisplayName!.isNotEmpty) {
      return otherUserDisplayName!;
    }
    return 'Unknown';
  }

  // Get the other user's ID
  String getOtherUserId(String currentUserId) {
    if (user1Id == currentUserId) {
      return user2Id;
    } else if (user2Id == currentUserId) {
      return user1Id;
    }
    return '';
  }

  // Create ChatModel from Firestore document
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel.fromMap(data, doc.id);
  }

  // Create ChatModel from Map
  factory ChatModel.fromMap(Map<String, dynamic> map, String chatId) {
    return ChatModel(
      chatId: chatId,
      user1Id: map['user1Id'] as String? ?? '',
      user2Id: map['user2Id'] as String? ?? '',
      otherUserDisplayName: map['otherUserDisplayName'] as String?,
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      hasUnreadMessages: map['hasUnreadMessages'] as bool? ?? false,
      unreadCount: map['unreadCount'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert ChatModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageTime != null)
        'lastMessageTime': Timestamp.fromDate(lastMessageTime!),
      if (lastMessageSenderId != null) 'lastMessageSenderId': lastMessageSenderId,
      'hasUnreadMessages': hasUnreadMessages,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  // Copy with method
  ChatModel copyWith({
    String? chatId,
    String? user1Id,
    String? user2Id,
    UserModel? user1,
    UserModel? user2,
    String? otherUserDisplayName,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    bool? hasUnreadMessages,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      chatId: chatId ?? this.chatId,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      user1: user1 ?? this.user1,
      user2: user2 ?? this.user2,
      otherUserDisplayName: otherUserDisplayName ?? this.otherUserDisplayName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ChatModel(chatId: $chatId, user1Id: $user1Id, user2Id: $user2Id, lastMessage: $lastMessage)';
  }
}
