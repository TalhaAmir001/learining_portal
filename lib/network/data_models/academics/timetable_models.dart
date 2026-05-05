/// Academics — timetable mobile API models (`mobile_apis/get_ac_*.php`).

class AcTimetableEntry {
  AcTimetableEntry({
    required this.id,
    required this.subjectTimetableId,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.staffId,
    required this.staffFirstname,
    required this.staffSurname,
    required this.employeeId,
    required this.day,
    required this.timeFrom,
    required this.timeTo,
    required this.startTime,
    required this.endTime,
    required this.roomNo,
    required this.subjectGroupSubjectId,
    required this.subjectGroupId,
  });

  final int id;
  final int subjectTimetableId;
  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;
  final int subjectId;
  final String subjectName;
  final String subjectCode;
  final int staffId;
  final String staffFirstname;
  final String staffSurname;
  final String employeeId;
  final String day;
  final String timeFrom;
  final String timeTo;
  final String startTime;
  final String endTime;
  final String roomNo;
  final int subjectGroupSubjectId;
  final int subjectGroupId;

  String get staffDisplayName {
    final n = [staffFirstname, staffSurname].where((e) => e.trim().isNotEmpty).join(' ');
    return employeeId.isNotEmpty ? '$n (${employeeId.trim()})' : n;
  }

  factory AcTimetableEntry.fromJson(Map<String, dynamic> json) {
    final sid = (json['subject_timetable_id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0;
    return AcTimetableEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subjectTimetableId: sid,
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      sectionId: (json['section_id'] as num?)?.toInt() ?? 0,
      className: json['class_name']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      staffId: (json['staff_id'] as num?)?.toInt() ?? 0,
      staffFirstname: json['staff_firstname']?.toString() ?? '',
      staffSurname: json['staff_surname']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      day: json['day']?.toString() ?? '',
      timeFrom: json['time_from']?.toString() ?? '',
      timeTo: json['time_to']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      roomNo: json['room_no']?.toString() ?? '',
      subjectGroupSubjectId: (json['subject_group_subject_id'] as num?)?.toInt() ?? 0,
      subjectGroupId: (json['subject_group_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class AcClassOption {
  AcClassOption({required this.id, required this.name});
  final int id;
  final String name;
  factory AcClassOption.fromJson(Map<String, dynamic> json) => AcClassOption(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

class AcSectionOption {
  AcSectionOption({
    required this.classId,
    required this.sectionId,
    required this.name,
  });
  final int classId;
  final int sectionId;
  final String name;
  factory AcSectionOption.fromJson(Map<String, dynamic> json) => AcSectionOption(
        classId: (json['class_id'] as num?)?.toInt() ?? 0,
        sectionId: (json['section_id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

class AcSubjectGroupOption {
  AcSubjectGroupOption({required this.id, required this.name});
  final int id;
  final String name;
  factory AcSubjectGroupOption.fromJson(Map<String, dynamic> json) => AcSubjectGroupOption(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

class AcClassSectionGroupLink {
  AcClassSectionGroupLink({
    required this.classId,
    required this.sectionId,
    required this.subjectGroupId,
  });
  final int classId;
  final int sectionId;
  final int subjectGroupId;
  factory AcClassSectionGroupLink.fromJson(Map<String, dynamic> json) => AcClassSectionGroupLink(
        classId: (json['class_id'] as num?)?.toInt() ?? 0,
        sectionId: (json['section_id'] as num?)?.toInt() ?? 0,
        subjectGroupId: (json['subject_group_id'] as num?)?.toInt() ?? 0,
      );
}

class AcSubjectGroupSubjectOption {
  AcSubjectGroupSubjectOption({
    required this.subjectGroupSubjectId,
    required this.subjectGroupId,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
  });
  final int subjectGroupSubjectId;
  final int subjectGroupId;
  final int subjectId;
  final String subjectName;
  final String subjectCode;

  String get label =>
      subjectName.isNotEmpty ? '$subjectName (${subjectCode.trim()})' : subjectCode;

  factory AcSubjectGroupSubjectOption.fromJson(Map<String, dynamic> json) => AcSubjectGroupSubjectOption(
        subjectGroupSubjectId: (json['subject_group_subject_id'] as num?)?.toInt() ?? 0,
        subjectGroupId: (json['subject_group_id'] as num?)?.toInt() ?? 0,
        subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
        subjectName: json['subject_name']?.toString() ?? '',
        subjectCode: json['subject_code']?.toString() ?? '',
      );
}

class AcStaffTeacherOption {
  AcStaffTeacherOption({
    required this.id,
    required this.name,
    required this.surname,
    required this.employeeId,
  });
  final int id;
  final String name;
  final String surname;
  final String employeeId;

  String get displayName {
    final n = [name, surname].where((e) => e.trim().isNotEmpty).join(' ');
    return employeeId.isNotEmpty ? '$n (${employeeId.trim()})' : n;
  }

  factory AcStaffTeacherOption.fromJson(Map<String, dynamic> json) => AcStaffTeacherOption(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        surname: json['surname']?.toString() ?? '',
        employeeId: json['employee_id']?.toString() ?? '',
      );
}

class AcTimetableMeta {
  AcTimetableMeta({
    required this.sessionId,
    required this.dayOrder,
    required this.classes,
    required this.sections,
    required this.subjectGroups,
    required this.classSectionSubjectGroups,
    required this.subjectGroupSubjects,
    required this.rooms,
    required this.staffTeachers,
  });

  final int sessionId;
  final List<String> dayOrder;
  final List<AcClassOption> classes;
  final List<AcSectionOption> sections;
  final List<AcSubjectGroupOption> subjectGroups;
  final List<AcClassSectionGroupLink> classSectionSubjectGroups;
  final List<AcSubjectGroupSubjectOption> subjectGroupSubjects;
  final List<String> rooms;
  final List<AcStaffTeacherOption> staffTeachers;

  factory AcTimetableMeta.fromJson(Map<String, dynamic> json) {
    return AcTimetableMeta(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      dayOrder: (json['day_order'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      classes: (json['classes'] as List<dynamic>?)
              ?.map((e) => AcClassOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => AcSectionOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      subjectGroups: (json['subject_groups'] as List<dynamic>?)
              ?.map((e) => AcSubjectGroupOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      classSectionSubjectGroups: (json['class_section_subject_groups'] as List<dynamic>?)
              ?.map((e) => AcClassSectionGroupLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      subjectGroupSubjects: (json['subject_group_subjects'] as List<dynamic>?)
              ?.map((e) => AcSubjectGroupSubjectOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rooms: (json['rooms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      staffTeachers: (json['staff_teachers'] as List<dynamic>?)
              ?.map((e) => AcStaffTeacherOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class AcTimetablePayload {
  AcTimetablePayload({
    required this.success,
    required this.dayOrder,
    this.error,
    this.entries = const [],
    this.byDay,
  });

  final bool success;
  final String? error;
  final List<String> dayOrder;
  final List<AcTimetableEntry> entries;
  final Map<String, List<AcTimetableEntry>>? byDay;

  factory AcTimetablePayload.fromJson(Map<String, dynamic> json) {
    final rawBy = json['by_day'];
    Map<String, List<AcTimetableEntry>>? byDay;
    if (rawBy is Map<String, dynamic>) {
      byDay = {};
      for (final e in rawBy.entries) {
        final list = e.value;
        if (list is List<dynamic>) {
          byDay[e.key] = list
              .map((x) => AcTimetableEntry.fromJson(x as Map<String, dynamic>))
              .toList();
        }
      }
    }
    final rawEntries = json['entries'];
    final entries = rawEntries is List<dynamic>
        ? rawEntries.map((e) => AcTimetableEntry.fromJson(e as Map<String, dynamic>)).toList()
        : const <AcTimetableEntry>[];
    return AcTimetablePayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      dayOrder: (json['day_order'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      entries: entries,
      byDay: byDay,
    );
  }
}
