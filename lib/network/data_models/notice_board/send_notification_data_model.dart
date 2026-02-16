/// Response model for a row from send_notifications table.
class SendNotificationDataModel {
  final int id;
  final String? title;
  final DateTime? publishDate;
  final DateTime? date;
  final String? attachment;
  final String? message;
  final String visibleStudent;
  final String visibleStaff;
  final String visibleParent;
  final String? createdBy;
  final int? createdId;
  final String isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final int? days;
  final bool isRead;

  SendNotificationDataModel({
    required this.id,
    this.title,
    this.publishDate,
    this.date,
    this.attachment,
    this.message,
    this.visibleStudent = 'no',
    this.visibleStaff = 'no',
    this.visibleParent = 'no',
    this.createdBy,
    this.createdId,
    this.isActive = 'no',
    this.createdAt,
    this.updatedAt,
    this.isPinned = false,
    this.days,
    this.isRead = true,
  });

  factory SendNotificationDataModel.fromJson(Map<String, dynamic> json) {
    return SendNotificationDataModel(
      id: _parseInt(json['id']),
      title: json['title'] as String?,
      publishDate: _parseDate(json['publish_date']),
      date: _parseDate(json['date']),
      attachment: json['attachment'] as String?,
      message: json['message'] as String?,
      visibleStudent: (json['visible_student'] as String?) ?? 'no',
      visibleStaff: (json['visible_staff'] as String?) ?? 'no',
      visibleParent: (json['visible_parent'] as String?) ?? 'no',
      createdBy: json['created_by'] as String?,
      createdId: _parseIntNullable(json['created_id']),
      isActive: (json['is_active'] as String?) ?? 'no',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      isPinned: _parseBool(json['is_pinned']),
      days: _parseIntNullable(json['days']),
      isRead: _parseBool(json['is_read']),
    );
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'yes' || s == 'true';
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _parseIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  bool get isActiveBool => isActive.toLowerCase() == 'yes';
  bool get visibleToStudent => visibleStudent.toLowerCase() == 'yes';
  bool get visibleToStaff => visibleStaff.toLowerCase() == 'yes';
  bool get visibleToParent => visibleParent.toLowerCase() == 'yes';
}
