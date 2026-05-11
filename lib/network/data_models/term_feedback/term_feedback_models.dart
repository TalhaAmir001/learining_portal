// Data models for the Term Feedback feature (admin / teacher).
//
// Mirrors the payloads of the `mobile_apis/get_termfeedback_*.php` and
// `save_termfeedback.php` endpoints, which themselves mirror the web admin
// `Termfeedback` controller and `Termfeedback_model`.

int _readInt(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int? _readNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String _readStr(Map<String, dynamic> json, String key) =>
    (json[key] ?? '').toString();

/// Allowed values for the per-class summary rating used at the top of the form.
enum TermFeedbackOverall {
  excellent,
  good,
  mixed,
  needsImprovement;

  String get apiValue {
    switch (this) {
      case TermFeedbackOverall.excellent:
        return 'excellent';
      case TermFeedbackOverall.good:
        return 'good';
      case TermFeedbackOverall.mixed:
        return 'mixed';
      case TermFeedbackOverall.needsImprovement:
        return 'needs_improvement';
    }
  }

  String get label {
    switch (this) {
      case TermFeedbackOverall.excellent:
        return 'Excellent';
      case TermFeedbackOverall.good:
        return 'Good';
      case TermFeedbackOverall.mixed:
        return 'Mixed';
      case TermFeedbackOverall.needsImprovement:
        return 'Needs improvement';
    }
  }

  static TermFeedbackOverall? fromApi(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    for (final e in TermFeedbackOverall.values) {
      if (e.apiValue == v) return e;
    }
    return null;
  }
}

class TermFeedbackClass {
  TermFeedbackClass({required this.id, required this.name});
  final int id;
  final String name;

  factory TermFeedbackClass.fromJson(Map<String, dynamic> json) {
    return TermFeedbackClass(
      id: _readInt(json, 'id'),
      name: _readStr(json, 'class_name'),
    );
  }
}

class TermFeedbackSection {
  TermFeedbackSection({required this.id, required this.name});
  final int id;
  final String name;

  factory TermFeedbackSection.fromJson(Map<String, dynamic> json) {
    return TermFeedbackSection(
      id: _readInt(json, 'id'),
      name: _readStr(json, 'section_name'),
    );
  }
}

/// Saved feedback row for a single student in a given period.
class TermFeedbackEntry {
  TermFeedbackEntry({
    required this.id,
    required this.participation,
    required this.behaviour,
    required this.classwork,
    required this.confidence,
    required this.homework,
    required this.remarks,
    required this.overall,
    required this.teacherStaffId,
    required this.updatedAt,
  });

  final int id;
  final int? participation;
  final int? behaviour;
  final int? classwork;
  final int? confidence;
  final int? homework;
  final String remarks;
  final TermFeedbackOverall? overall;
  final int? teacherStaffId;
  final String updatedAt;

  factory TermFeedbackEntry.fromJson(Map<String, dynamic> json) {
    return TermFeedbackEntry(
      id: _readInt(json, 'id'),
      participation: _readNullableInt(json['participation_rating']),
      behaviour: _readNullableInt(json['behaviour_rating']),
      classwork: _readNullableInt(json['classwork_rating']),
      confidence: _readNullableInt(json['confidence_rating']),
      homework: _readNullableInt(json['homework_rating']),
      remarks: (json['remarks'] ?? '').toString(),
      overall: TermFeedbackOverall.fromApi(json['overall_class_performance']?.toString()),
      teacherStaffId: _readNullableInt(json['teacher_staff_id']),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

class TermFeedbackStudent {
  TermFeedbackStudent({
    required this.id,
    required this.fullName,
    required this.admissionNo,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.feedback,
  });

  final int id;
  final String fullName;
  final String admissionNo;
  final String firstname;
  final String middlename;
  final String lastname;
  final TermFeedbackEntry? feedback;

  factory TermFeedbackStudent.fromJson(Map<String, dynamic> json) {
    final fbRaw = json['feedback'];
    final fb = fbRaw is Map
        ? TermFeedbackEntry.fromJson(fbRaw.cast<String, dynamic>())
        : null;
    return TermFeedbackStudent(
      id: _readInt(json, 'student_id'),
      fullName: _readStr(json, 'full_name'),
      admissionNo: _readStr(json, 'admission_no'),
      firstname: _readStr(json, 'firstname'),
      middlename: _readStr(json, 'middlename'),
      lastname: _readStr(json, 'lastname'),
      feedback: fb,
    );
  }
}

/// One row of the "All saved term feedback" history table (admin only).
class TermFeedbackHistoryItem {
  TermFeedbackHistoryItem({
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.startMonth,
    required this.endMonth,
  });

  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;
  final String startMonth; // YYYY-MM
  final String endMonth;   // YYYY-MM

  factory TermFeedbackHistoryItem.fromJson(Map<String, dynamic> json) {
    return TermFeedbackHistoryItem(
      classId: _readInt(json, 'class_id'),
      sectionId: _readInt(json, 'section_id'),
      className: _readStr(json, 'class_name'),
      sectionName: _readStr(json, 'section_name'),
      startMonth: _readStr(json, 'period_start_month'),
      endMonth: _readStr(json, 'period_end_month'),
    );
  }
}

/// Payloads.

class TermFeedbackClassesPayload {
  TermFeedbackClassesPayload({
    required this.success,
    required this.classes,
    required this.canSave,
    required this.showHistory,
    this.error,
  });

  final bool success;
  final List<TermFeedbackClass> classes;
  final bool canSave;
  final bool showHistory;
  final String? error;

  factory TermFeedbackClassesPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['classes'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => TermFeedbackClass.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <TermFeedbackClass>[];
    return TermFeedbackClassesPayload(
      success: json['success'] == true,
      classes: list,
      canSave: json['can_save'] == true,
      showHistory: json['show_history'] == true,
      error: json['error']?.toString(),
    );
  }
}

class TermFeedbackSectionsPayload {
  TermFeedbackSectionsPayload({
    required this.success,
    required this.sections,
    this.error,
  });

  final bool success;
  final List<TermFeedbackSection> sections;
  final String? error;

  factory TermFeedbackSectionsPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['sections'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => TermFeedbackSection.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <TermFeedbackSection>[];
    return TermFeedbackSectionsPayload(
      success: json['success'] == true,
      sections: list,
      error: json['error']?.toString(),
    );
  }
}

class TermFeedbackStudentsPayload {
  TermFeedbackStudentsPayload({
    required this.success,
    required this.students,
    required this.overall,
    this.error,
  });

  final bool success;
  final List<TermFeedbackStudent> students;
  final TermFeedbackOverall? overall;
  final String? error;

  factory TermFeedbackStudentsPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['students'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => TermFeedbackStudent.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <TermFeedbackStudent>[];
    return TermFeedbackStudentsPayload(
      success: json['success'] == true,
      students: list,
      overall: TermFeedbackOverall.fromApi(json['overall_class_performance']?.toString()),
      error: json['error']?.toString(),
    );
  }
}

class TermFeedbackHistoryPayload {
  TermFeedbackHistoryPayload({
    required this.success,
    required this.items,
    this.error,
  });

  final bool success;
  final List<TermFeedbackHistoryItem> items;
  final String? error;

  factory TermFeedbackHistoryPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => TermFeedbackHistoryItem.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <TermFeedbackHistoryItem>[];
    return TermFeedbackHistoryPayload(
      success: json['success'] == true,
      items: list,
      error: json['error']?.toString(),
    );
  }
}

/// Local mutable state for one row in the editing table.
class TermFeedbackDraft {
  TermFeedbackDraft({
    required this.studentId,
    this.participation,
    this.behaviour,
    this.classwork,
    this.confidence,
    this.homework,
    this.remarks = '',
  });

  final int studentId;
  int? participation;
  int? behaviour;
  int? classwork;
  int? confidence;
  int? homework;
  String remarks;

  factory TermFeedbackDraft.fromStudent(TermFeedbackStudent st) {
    final fb = st.feedback;
    return TermFeedbackDraft(
      studentId: st.id,
      participation: fb?.participation,
      behaviour: fb?.behaviour,
      classwork: fb?.classwork,
      confidence: fb?.confidence,
      homework: fb?.homework,
      remarks: fb?.remarks ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'participation_rating': participation,
        'behaviour_rating': behaviour,
        'classwork_rating': classwork,
        'confidence_rating': confidence,
        'homework_rating': homework,
        'remarks': remarks,
      };
}
