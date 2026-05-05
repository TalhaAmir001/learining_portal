class AdminAcSimpleItem {
  AdminAcSimpleItem({required this.id, required this.name});
  final int id;
  final String name;

  factory AdminAcSimpleItem.fromJson(Map<String, dynamic> json) {
    return AdminAcSimpleItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }
}

class AdminAcClassSectionItem {
  AdminAcClassSectionItem({
    required this.id,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
  });

  final int id;
  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;

  factory AdminAcClassSectionItem.fromJson(Map<String, dynamic> json) {
    return AdminAcClassSectionItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      classId: int.tryParse(json['class_id']?.toString() ?? '') ?? 0,
      sectionId: int.tryParse(json['section_id']?.toString() ?? '') ?? 0,
      className: (json['class_name'] ?? '').toString(),
      sectionName: (json['section_name'] ?? '').toString(),
    );
  }

  String get label => '$className · $sectionName';
}

class AdminAcSubjectItem {
  AdminAcSubjectItem({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
  });

  final int id;
  final String name;
  final String code;
  final String type;

  factory AdminAcSubjectItem.fromJson(Map<String, dynamic> json) {
    return AdminAcSubjectItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class AdminAcTeacherItem {
  AdminAcTeacherItem({
    required this.id,
    required this.name,
    required this.surname,
    required this.employeeId,
  });

  final int id;
  final String name;
  final String surname;
  final String employeeId;

  factory AdminAcTeacherItem.fromJson(Map<String, dynamic> json) {
    return AdminAcTeacherItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      surname: (json['surname'] ?? '').toString(),
      employeeId: (json['employee_id'] ?? '').toString(),
    );
  }

  String get displayName {
    final full = ('$name $surname').trim();
    return employeeId.isEmpty ? full : '$full ($employeeId)';
  }
}

class AdminAcMetaPayload {
  AdminAcMetaPayload({
    required this.success,
    required this.currentSessionId,
    required this.classes,
    required this.sections,
    required this.classSections,
    required this.subjects,
    required this.teachers,
    required this.sessions,
    this.error,
  });

  final bool success;
  final int currentSessionId;
  final List<AdminAcSimpleItem> classes;
  final List<AdminAcSimpleItem> sections;
  final List<AdminAcClassSectionItem> classSections;
  final List<AdminAcSubjectItem> subjects;
  final List<AdminAcTeacherItem> teachers;
  final List<AdminAcSimpleItem> sessions;
  final String? error;

  factory AdminAcMetaPayload.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    return AdminAcMetaPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      currentSessionId:
          int.tryParse(json['current_session_id']?.toString() ?? '') ??
              int.tryParse(json['session_id']?.toString() ?? '') ??
              0,
      classes: listOf('classes', AdminAcSimpleItem.fromJson),
      sections: listOf('sections', AdminAcSimpleItem.fromJson),
      classSections: listOf('class_sections', AdminAcClassSectionItem.fromJson),
      subjects: listOf('subjects', AdminAcSubjectItem.fromJson),
      teachers: listOf('teachers', AdminAcTeacherItem.fromJson),
      sessions: listOf('sessions', AdminAcSimpleItem.fromJson),
    );
  }
}

class AdminAcClassTeacherAssignment {
  AdminAcClassTeacherAssignment({
    required this.id,
    required this.staffId,
    required this.name,
    required this.surname,
    required this.employeeId,
  });

  final int id;
  final int staffId;
  final String name;
  final String surname;
  final String employeeId;

  factory AdminAcClassTeacherAssignment.fromJson(Map<String, dynamic> json) {
    return AdminAcClassTeacherAssignment(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      staffId: int.tryParse(json['staff_id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      surname: (json['surname'] ?? '').toString(),
      employeeId: (json['employee_id'] ?? '').toString(),
    );
  }
}

class AdminAcClassTeacherGroup {
  AdminAcClassTeacherGroup({
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.teachers,
  });

  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;
  final List<AdminAcClassTeacherAssignment> teachers;

  factory AdminAcClassTeacherGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['teachers'];
    final teachers = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AdminAcClassTeacherAssignment.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <AdminAcClassTeacherAssignment>[];
    return AdminAcClassTeacherGroup(
      classId: int.tryParse(json['class_id']?.toString() ?? '') ?? 0,
      sectionId: int.tryParse(json['section_id']?.toString() ?? '') ?? 0,
      className: (json['class_name'] ?? '').toString(),
      sectionName: (json['section_name'] ?? '').toString(),
      teachers: teachers,
    );
  }
}


