class ClassSummary {
  ClassSummary({
    required this.id,
    required this.classId,
    required this.sectionId,
    required this.classDate,
    required this.title,
    required this.htmlContent,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.className,
    required this.sectionName,
  });

  final int id;
  final int classId;
  final int sectionId;
  final String classDate; // yyyy-mm-dd
  final String title;
  final String htmlContent;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final String className;
  final String sectionName;

  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final cls = className.trim();
    final sec = sectionName.trim();
    if (cls.isNotEmpty || sec.isNotEmpty) {
      return [cls, sec].where((e) => e.isNotEmpty).join(' • ');
    }
    return 'Class summary';
  }

  factory ClassSummary.fromJson(Map<String, dynamic> json) {
    int i(String k) => int.tryParse(json[k]?.toString() ?? '') ?? 0;
    String s(String k) => (json[k] ?? '').toString();

    return ClassSummary(
      id: i('id'),
      classId: i('class_id'),
      sectionId: i('section_id'),
      classDate: s('class_date'),
      title: s('title'),
      htmlContent: s('html_content'),
      createdBy: i('created_by'),
      createdAt: s('created_at'),
      updatedAt: s('updated_at'),
      className: s('class_name'),
      sectionName: s('section_name'),
    );
  }
}

class ClassSummaryListPayload {
  ClassSummaryListPayload({
    required this.success,
    required this.items,
    this.error,
  });

  final bool success;
  final List<ClassSummary> items;
  final String? error;

  factory ClassSummaryListPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => ClassSummary.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ClassSummary>[];
    return ClassSummaryListPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      items: items,
    );
  }
}

class ClassSummaryDetailPayload {
  ClassSummaryDetailPayload({
    required this.success,
    required this.summary,
    this.error,
  });

  final bool success;
  final ClassSummary? summary;
  final String? error;

  factory ClassSummaryDetailPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['summary'];
    return ClassSummaryDetailPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      summary: raw is Map ? ClassSummary.fromJson(raw.cast<String, dynamic>()) : null,
    );
  }
}

