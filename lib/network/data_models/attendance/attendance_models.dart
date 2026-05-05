/// Mobile API models for attendance (Portal 2 parity: student day, period, staff).

class AtTypeModel {
  AtTypeModel({
    required this.id,
    required this.type,
    required this.keyValue,
  });

  final int id;
  final String type;
  final String keyValue;

  factory AtTypeModel.fromJson(Map<String, dynamic> json) {
    return AtTypeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      keyValue: json['key_value']?.toString() ?? '',
    );
  }
}

class AtStaffRoleModel {
  AtStaffRoleModel({required this.id, required this.roleName});

  final int id;
  final String roleName;

  factory AtStaffRoleModel.fromJson(Map<String, dynamic> json) {
    return AtStaffRoleModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roleName: json['role_name']?.toString() ?? '',
    );
  }
}

class AtStudentDayRowModel {
  AtStudentDayRowModel({
    required this.studentSessionId,
    required this.studentId,
    required this.admissionNo,
    required this.rollNo,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.attendanceRowId,
    required this.attendenceTypeId,
    required this.remark,
    required this.feedback,
    this.inTime,
    this.outTime,
  });

  final int studentSessionId;
  final int studentId;
  final String admissionNo;
  final String rollNo;
  final String firstname;
  final String middlename;
  final String lastname;
  final int attendanceRowId;
  final int? attendenceTypeId;
  final String remark;
  final String feedback;
  final String? inTime;
  final String? outTime;

  String get displayName =>
      [firstname, middlename, lastname].where((e) => e.trim().isNotEmpty).join(' ');

  factory AtStudentDayRowModel.fromJson(Map<String, dynamic> json) {
    return AtStudentDayRowModel(
      studentSessionId: (json['student_session_id'] as num?)?.toInt() ?? 0,
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      admissionNo: json['admission_no']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? '',
      firstname: json['firstname']?.toString() ?? '',
      middlename: json['middlename']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      attendanceRowId: (json['attendance_row_id'] as num?)?.toInt() ?? 0,
      attendenceTypeId: json['attendence_type_id'] == null
          ? null
          : (json['attendence_type_id'] as num).toInt(),
      remark: json['remark']?.toString() ?? '',
      feedback: json['feedback']?.toString() ?? '',
      inTime: json['in_time']?.toString(),
      outTime: json['out_time']?.toString(),
    );
  }
}

class AtSubjectSlotModel {
  AtSubjectSlotModel({
    required this.subjectTimetableId,
    required this.subjectName,
    required this.code,
    required this.timeFrom,
    required this.timeTo,
    required this.startTime,
    required this.staffLabel,
  });

  final int subjectTimetableId;
  final String subjectName;
  final String code;
  final String timeFrom;
  final String timeTo;
  final String startTime;
  final String staffLabel;

  factory AtSubjectSlotModel.fromJson(Map<String, dynamic> json) {
    final fn = json['staff_firstname']?.toString() ?? '';
    final sn = json['staff_surname']?.toString() ?? '';
    final em = json['employee_id']?.toString() ?? '';
    final label = [fn, sn].where((e) => e.isNotEmpty).join(' ');
    return AtSubjectSlotModel(
      subjectTimetableId: (json['subject_timetable_id'] as num?)?.toInt() ?? 0,
      subjectName: json['subject_name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      timeFrom: json['time_from']?.toString() ?? '',
      timeTo: json['time_to']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      staffLabel: em.isNotEmpty ? '$label ($em)' : label,
    );
  }
}

class AtSubjectStudentRowModel {
  AtSubjectStudentRowModel({
    required this.studentSessionId,
    required this.studentId,
    required this.admissionNo,
    required this.rollNo,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.attendenceTypeId,
    required this.remark,
  });

  final int studentSessionId;
  final int studentId;
  final String admissionNo;
  final String rollNo;
  final String firstname;
  final String middlename;
  final String lastname;
  final int? attendenceTypeId;
  final String remark;

  String get displayName =>
      [firstname, middlename, lastname].where((e) => e.trim().isNotEmpty).join(' ');

  factory AtSubjectStudentRowModel.fromJson(Map<String, dynamic> json) {
    return AtSubjectStudentRowModel(
      studentSessionId: (json['student_session_id'] as num?)?.toInt() ?? 0,
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      admissionNo: json['admission_no']?.toString() ?? '',
      rollNo: json['roll_no']?.toString() ?? '',
      firstname: json['firstname']?.toString() ?? '',
      middlename: json['middlename']?.toString() ?? '',
      lastname: json['lastname']?.toString() ?? '',
      attendenceTypeId: json['attendence_type_id'] == null
          ? null
          : (json['attendence_type_id'] as num).toInt(),
      remark: json['remark']?.toString() ?? '',
    );
  }
}

class AtStaffDayRowModel {
  AtStaffDayRowModel({
    required this.staffId,
    required this.name,
    required this.employeeId,
    required this.staffAttendanceTypeId,
    required this.remark,
    this.inTime,
    this.outTime,
  });

  final int staffId;
  final String name;
  final String employeeId;
  final int? staffAttendanceTypeId;
  final String remark;
  final String? inTime;
  final String? outTime;

  factory AtStaffDayRowModel.fromJson(Map<String, dynamic> json) {
    return AtStaffDayRowModel(
      staffId: (json['staff_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      staffAttendanceTypeId: json['staff_attendance_type_id'] == null
          ? null
          : (json['staff_attendance_type_id'] as num).toInt(),
      remark: json['remark']?.toString() ?? '',
      inTime: json['in_time']?.toString(),
      outTime: json['out_time']?.toString(),
    );
  }
}

class AtMatrixSlotModel {
  AtMatrixSlotModel({
    required this.subjectTimetableId,
    required this.subjectName,
    required this.code,
    required this.timeLabel,
  });

  final int subjectTimetableId;
  final String subjectName;
  final String code;
  final String timeLabel;

  factory AtMatrixSlotModel.fromJson(Map<String, dynamic> json) {
    final tf = json['time_from']?.toString() ?? '';
    final tt = json['time_to']?.toString() ?? '';
    final st = json['start_time']?.toString() ?? '';
    final tl = [st, tf, tt].where((e) => e.isNotEmpty).join(' · ');
    return AtMatrixSlotModel(
      subjectTimetableId: (json['subject_timetable_id'] as num?)?.toInt() ?? 0,
      subjectName: json['subject_name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      timeLabel: tl,
    );
  }
}

class AtMatrixStudentModel {
  AtMatrixStudentModel({
    required this.studentSessionId,
    required this.admissionNo,
    required this.displayName,
    required this.bySlotTypeIds,
  });

  final int studentSessionId;
  final String admissionNo;
  final String displayName;
  /// subject_timetable_id (as string key from JSON) -> attendence_type_id or null
  final Map<int, int?> bySlotTypeIds;

  factory AtMatrixStudentModel.fromJson(Map<String, dynamic> json) {
    final fn = json['firstname']?.toString() ?? '';
    final mn = json['middlename']?.toString() ?? '';
    final ln = json['lastname']?.toString() ?? '';
    final name = [fn, mn, ln].where((e) => e.trim().isNotEmpty).join(' ');
    final raw = json['by_slot'];
    final map = <int, int?>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id == null) return;
        if (v is Map<String, dynamic>) {
          final tid = v['attendence_type_id'];
          map[id] = tid == null ? null : (tid as num).toInt();
        }
      });
    }
    return AtMatrixStudentModel(
      studentSessionId: (json['student_session_id'] as num?)?.toInt() ?? 0,
      admissionNo: json['admission_no']?.toString() ?? '',
      displayName: name,
      bySlotTypeIds: map,
    );
  }
}
