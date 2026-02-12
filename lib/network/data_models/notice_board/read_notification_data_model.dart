/// Request/response for read_notifications table (record that user viewed a notice).
class ReadNotificationDataModel {
  final int? id;
  final int? studentId;
  final int? parentId;
  final int? staffId;
  final int notificationId;
  final String isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReadNotificationDataModel({
    this.id,
    this.studentId,
    this.parentId,
    this.staffId,
    required this.notificationId,
    this.isActive = 'yes',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toRequest() {
    final map = <String, dynamic>{
      'notification_id': notificationId,
      'is_active': isActive,
    };
    if (studentId != null) map['student_id'] = studentId;
    if (parentId != null) map['parent_id'] = parentId;
    if (staffId != null) map['staff_id'] = staffId;
    return map;
  }

  factory ReadNotificationDataModel.fromJson(Map<String, dynamic> json) {
    return ReadNotificationDataModel(
      id: _parseIntNullable(json['id']),
      studentId: _parseIntNullable(json['student_id']),
      parentId: _parseIntNullable(json['parent_id']),
      staffId: _parseIntNullable(json['staff_id']),
      notificationId: _parseInt(json['notification_id']),
      isActive: (json['is_active'] as String?) ?? 'yes',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static int? _parseIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
