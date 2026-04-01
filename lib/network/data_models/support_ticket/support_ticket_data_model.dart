/// Category for support tickets (from support_ticket_categories).
class SupportTicketCategoryModel {
  final int id;
  final String name;
  final String slug;
  final int sortOrder;
  final bool isActive;

  SupportTicketCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory SupportTicketCategoryModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketCategoryModel(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      sortOrder: _parseInt(json['sort_order']),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}

/// Single reply in a ticket (support_ticket_replies).
class SupportTicketReplyModel {
  final int id;
  final int supportTicketId;
  final String replyBy; // student | parent | staff
  final int replyById;
  final String message;
  final String? attachment;
  final String? createdAt;
  final String? updatedAt;

  SupportTicketReplyModel({
    required this.id,
    required this.supportTicketId,
    required this.replyBy,
    required this.replyById,
    required this.message,
    this.attachment,
    this.createdAt,
    this.updatedAt,
  });

  bool get isFromStaff => replyBy == 'staff';
  bool get isFromUser => replyBy == 'student' || replyBy == 'parent';

  factory SupportTicketReplyModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketReplyModel(
      id: _parseInt(json['id']),
      supportTicketId: _parseInt(json['support_ticket_id']),
      replyBy: json['reply_by'] as String? ?? 'student',
      replyById: _parseInt(json['reply_by_id']),
      message: json['message'] as String? ?? '',
      attachment: json['attachment'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// One support ticket (support_tickets).
class SupportTicketModel {
  final int id;
  final String ticketId; // e.g. TKT-20250310-0001
  final String subject;
  final String? category;
  final String status; // open, in_progress, pending, resolved, closed
  final String? priority; // low, medium, high
  final String submittedByRole; // student | parent
  final int submittedById;
  final int? relatedStudentId;
  final int? assignedTo;
  final String? description;
  final String? attachment;
  final String? firstReplyAt;
  final String? resolvedAt;
  final String? createdAt;
  final String? updatedAt;
  /// Replies when loaded from detail API.
  final List<SupportTicketReplyModel> replies;

  SupportTicketModel({
    required this.id,
    required this.ticketId,
    required this.subject,
    this.category,
    this.status = 'open',
    this.priority,
    required this.submittedByRole,
    required this.submittedById,
    this.relatedStudentId,
    this.assignedTo,
    this.description,
    this.attachment,
    this.firstReplyAt,
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
    this.replies = const [],
  });

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final repliesList = json['replies'] as List<dynamic>?;
    final replies = repliesList != null
        ? repliesList
            .map((e) =>
                SupportTicketReplyModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <SupportTicketReplyModel>[];

    return SupportTicketModel(
      id: _parseInt(json['id']),
      ticketId: json['ticket_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String?,
      submittedByRole: json['submitted_by_role'] as String? ?? 'student',
      submittedById: _parseInt(json['submitted_by_id']),
      relatedStudentId: _parseIntNullable(json['related_student_id']),
      assignedTo: _parseIntNullable(json['assigned_to']),
      description: json['description'] as String?,
      attachment: json['attachment'] as String?,
      firstReplyAt: json['first_reply_at'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      replies: replies,
    );
  }
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? _parseIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}
