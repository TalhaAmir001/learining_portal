import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String noticeId;
  final String title;
  final String content;
  final String? authorId;
  final String? authorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final List<String>? targetUserTypes; // e.g., ['student', 'teacher', 'guardian']
  final Map<String, dynamic>? additionalData;

  NoticeModel({
    required this.noticeId,
    required this.title,
    required this.content,
    this.authorId,
    this.authorName,
    required this.createdAt,
    this.updatedAt,
    this.isPinned = false,
    this.targetUserTypes,
    this.additionalData,
  });

  // Create NoticeModel from Firestore document
  factory NoticeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoticeModel.fromMap(data, doc.id);
  }

  // Create NoticeModel from Map
  factory NoticeModel.fromMap(Map<String, dynamic> map, String noticeId) {
    return NoticeModel(
      noticeId: noticeId,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorId: map['authorId'] as String?,
      authorName: map['authorName'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isPinned: map['isPinned'] as bool? ?? false,
      targetUserTypes: map['targetUserTypes'] != null
          ? List<String>.from(map['targetUserTypes'] as List)
          : null,
      additionalData: map['additionalData'] as Map<String, dynamic>?,
    );
  }

  // Convert NoticeModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      if (authorId != null) 'authorId': authorId,
      if (authorName != null) 'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isPinned': isPinned,
      if (targetUserTypes != null) 'targetUserTypes': targetUserTypes,
      if (additionalData != null) 'additionalData': additionalData,
    };
  }

  // Copy with method
  NoticeModel copyWith({
    String? noticeId,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    List<String>? targetUserTypes,
    Map<String, dynamic>? additionalData,
  }) {
    return NoticeModel(
      noticeId: noticeId ?? this.noticeId,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      targetUserTypes: targetUserTypes ?? this.targetUserTypes,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  String toString() {
    return 'NoticeModel(noticeId: $noticeId, title: $title, createdAt: $createdAt)';
  }
}
