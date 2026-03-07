import 'dart:convert';

/// Class option for feedback targeting.
class FeedbackClassModel {
  final int id;
  final String className;

  FeedbackClassModel({required this.id, required this.className});

  factory FeedbackClassModel.fromJson(Map<String, dynamic> json) {
    return FeedbackClassModel(
      id: _parseInt(json['id']),
      className: json['class_name'] as String? ?? '',
    );
  }
}

/// Section option for feedback targeting.
class FeedbackSectionModel {
  final int id;
  final String sectionName;

  FeedbackSectionModel({required this.id, required this.sectionName});

  factory FeedbackSectionModel.fromJson(Map<String, dynamic> json) {
    return FeedbackSectionModel(
      id: _parseInt(json['id']),
      sectionName: json['section_name'] as String? ?? '',
    );
  }
}

/// Student from fl_chat_users for a given class/section.
class FeedbackStudentModel {
  final int chatUserId;
  final int studentId;
  final String? className;
  final String? sectionName;

  FeedbackStudentModel({
    required this.chatUserId,
    required this.studentId,
    this.className,
    this.sectionName,
  });

  factory FeedbackStudentModel.fromJson(Map<String, dynamic> json) {
    return FeedbackStudentModel(
      chatUserId: _parseInt(json['chat_user_id']),
      studentId: _parseInt(json['student_id']),
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
    );
  }
}

/// One attachment for a daily feedback entry.
class DailyFeedbackAttachmentModel {
  final int id;
  final String fileUrl;
  final String? filename;
  final String? createdAt;

  DailyFeedbackAttachmentModel({
    required this.id,
    required this.fileUrl,
    this.filename,
    this.createdAt,
  });

  factory DailyFeedbackAttachmentModel.fromJson(Map<String, dynamic> json) {
    return DailyFeedbackAttachmentModel(
      id: _parseInt(json['id']),
      fileUrl: json['file_url'] as String? ?? '',
      filename: json['filename'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// One daily feedback entry (written + optional voice + attachments + class/section/students).
class DailyFeedbackModel {
  final int id;
  final int staffId;
  final String? messageText;
  final String? voiceUrl;
  final int? classId;
  final int? sectionId;
  final List<int> recipientStudentIds;
  final String? className;
  final String? sectionName;
  final String? createdAt;
  final String? updatedAt;
  final List<DailyFeedbackAttachmentModel> attachments;

  DailyFeedbackModel({
    required this.id,
    required this.staffId,
    this.messageText,
    this.voiceUrl,
    this.classId,
    this.sectionId,
    this.recipientStudentIds = const [],
    this.className,
    this.sectionName,
    this.createdAt,
    this.updatedAt,
    this.attachments = const [],
  });

  factory DailyFeedbackModel.fromJson(Map<String, dynamic> json) {
    final attList = json['attachments'];
    List<DailyFeedbackAttachmentModel> attachments = [];
    if (attList is List) {
      for (final e in attList) {
        if (e is Map<String, dynamic>) {
          attachments.add(DailyFeedbackAttachmentModel.fromJson(e));
        }
      }
    }
    List<int> recipientIds = [];
    final rec = json['recipient_student_ids'];
    if (rec is String) {
      final decoded = _parseJsonIntList(rec);
      if (decoded != null) recipientIds = decoded;
    } else if (rec is List) {
      recipientIds = rec.map((e) => _parseInt(e)).where((e) => e > 0).toList();
    }
    return DailyFeedbackModel(
      id: _parseInt(json['id']),
      staffId: _parseInt(json['staff_id']),
      messageText: json['message_text'] as String?,
      voiceUrl: json['voice_url'] as String?,
      classId: _parseIntNullable(json['class_id']),
      sectionId: _parseIntNullable(json['section_id']),
      recipientStudentIds: recipientIds,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      attachments: attachments,
    );
  }
}

List<int>? _parseJsonIntList(String s) {
  try {
    final list = (jsonDecode(s) as List<dynamic>?) ?? [];
    return list.map((e) => _parseInt(e)).where((e) => e > 0).toList();
  } catch (_) {
    return null;
  }
}

int? _parseIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) {
    final n = int.tryParse(v);
    return n != null && n > 0 ? n : null;
  }
  return null;
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
