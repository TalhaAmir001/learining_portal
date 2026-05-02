// Data models for Student Information mobile APIs (tables: students, categories, etc.)

class SiClassModel {
  final int id;
  final String className;

  SiClassModel({required this.id, required this.className});

  factory SiClassModel.fromJson(Map<String, dynamic> json) {
    return SiClassModel(
      id: _parseInt(json['id']),
      className: _string(json['class_name']),
    );
  }
}

class SiSectionModel {
  final int id;
  final String sectionName;

  SiSectionModel({required this.id, required this.sectionName});

  factory SiSectionModel.fromJson(Map<String, dynamic> json) {
    return SiSectionModel(
      id: _parseInt(json['id']),
      sectionName: _string(json['section_name']),
    );
  }
}

/// Row from student search / active list.
class SiStudentRowModel {
  final int studentSessionId;
  final int studentId;
  final String admissionNo;
  final String rollNo;
  final String firstname;
  final String middlename;
  final String lastname;
  final String image;
  final String mobileno;
  final String email;
  final String gender;
  final String isActive;
  final int classId;
  final String className;
  final int sectionId;
  final String sectionName;
  final String category;

  SiStudentRowModel({
    required this.studentSessionId,
    required this.studentId,
    required this.admissionNo,
    required this.rollNo,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.image,
    required this.mobileno,
    required this.email,
    required this.gender,
    required this.isActive,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.category,
  });

  String get displayName {
    final parts = [firstname, middlename, lastname]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return parts.join(' ');
  }

  factory SiStudentRowModel.fromJson(Map<String, dynamic> json) {
    return SiStudentRowModel(
      studentSessionId: _parseInt(json['student_session_id']),
      studentId: _parseInt(json['student_id']),
      admissionNo: _string(json['admission_no']),
      rollNo: _string(json['roll_no']),
      firstname: _string(json['firstname']),
      middlename: _string(json['middlename']),
      lastname: _string(json['lastname']),
      image: _string(json['image']),
      mobileno: _string(json['mobileno']),
      email: _string(json['email']),
      gender: _string(json['gender']),
      isActive: _string(json['is_active']),
      classId: _parseInt(json['class_id']),
      className: _string(json['class_name']),
      sectionId: _parseInt(json['section_id']),
      sectionName: _string(json['section_name']),
      category: _string(json['category']),
    );
  }
}

/// Disabled student list row (extends search row with disable fields).
class SiDisabledStudentRowModel extends SiStudentRowModel {
  final String disReason;
  final String disNote;

  SiDisabledStudentRowModel({
    required super.studentSessionId,
    required super.studentId,
    required super.admissionNo,
    required super.rollNo,
    required super.firstname,
    required super.middlename,
    required super.lastname,
    required super.image,
    required super.mobileno,
    required super.email,
    required super.gender,
    required super.isActive,
    required super.classId,
    required super.className,
    required super.sectionId,
    required super.sectionName,
    required super.category,
    required this.disReason,
    required this.disNote,
  });

  factory SiDisabledStudentRowModel.fromJson(Map<String, dynamic> json) {
    return SiDisabledStudentRowModel(
      studentSessionId: _parseInt(json['student_session_id']),
      studentId: _parseInt(json['student_id']),
      admissionNo: _string(json['admission_no']),
      rollNo: _string(json['roll_no']),
      firstname: _string(json['firstname']),
      middlename: _string(json['middlename']),
      lastname: _string(json['lastname']),
      image: _string(json['image']),
      mobileno: _string(json['mobileno']),
      email: _string(json['email']),
      gender: _string(json['gender']),
      isActive: _string(json['is_active']),
      classId: _parseInt(json['class_id']),
      className: _string(json['class_name']),
      sectionId: _parseInt(json['section_id']),
      sectionName: _string(json['section_name']),
      category: _string(json['category']),
      disReason: _string(json['dis_reason']),
      disNote: _string(json['dis_note']),
    );
  }
}

class SiStudentDetailModel {
  final int studentId;
  final int studentSessionId;
  final String admissionNo;
  final String rollNo;
  final String admissionDate;
  final String firstname;
  final String middlename;
  final String lastname;
  final String image;
  final String mobileno;
  final String email;
  final String state;
  final String city;
  final String pincode;
  final String religion;
  final String cast;
  final String dob;
  final String currentAddress;
  final String permanentAddress;
  final String previousSchool;
  final int categoryId;
  final String category;
  final String bloodGroup;
  final String gender;
  final String isActive;
  final String fatherName;
  final String fatherPhone;
  final String fatherOccupation;
  final String motherName;
  final String motherPhone;
  final String motherOccupation;
  final String guardianIs;
  final String guardianName;
  final String guardianRelation;
  final String guardianPhone;
  final String guardianEmail;
  final String guardianAddress;
  final String guardianOccupation;
  final String rte;
  final String disReason;
  final String disNote;
  final String disableAt;
  final String about;
  final int classId;
  final String className;
  final int sectionId;
  final String sectionName;
  final String houseName;
  final String loginUsername;

  SiStudentDetailModel({
    required this.studentId,
    required this.studentSessionId,
    required this.admissionNo,
    required this.rollNo,
    required this.admissionDate,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.image,
    required this.mobileno,
    required this.email,
    required this.state,
    required this.city,
    required this.pincode,
    required this.religion,
    required this.cast,
    required this.dob,
    required this.currentAddress,
    required this.permanentAddress,
    required this.previousSchool,
    required this.categoryId,
    required this.category,
    required this.bloodGroup,
    required this.gender,
    required this.isActive,
    required this.fatherName,
    required this.fatherPhone,
    required this.fatherOccupation,
    required this.motherName,
    required this.motherPhone,
    required this.motherOccupation,
    required this.guardianIs,
    required this.guardianName,
    required this.guardianRelation,
    required this.guardianPhone,
    required this.guardianEmail,
    required this.guardianAddress,
    required this.guardianOccupation,
    required this.rte,
    required this.disReason,
    required this.disNote,
    required this.disableAt,
    required this.about,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.houseName,
    required this.loginUsername,
  });

  String get displayName {
    final parts = [firstname, middlename, lastname]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return parts.join(' ');
  }

  factory SiStudentDetailModel.fromJson(Map<String, dynamic> json) {
    return SiStudentDetailModel(
      studentId: _parseInt(json['student_id']),
      studentSessionId: _parseInt(json['student_session_id']),
      admissionNo: _string(json['admission_no']),
      rollNo: _string(json['roll_no']),
      admissionDate: _string(json['admission_date']),
      firstname: _string(json['firstname']),
      middlename: _string(json['middlename']),
      lastname: _string(json['lastname']),
      image: _string(json['image']),
      mobileno: _string(json['mobileno']),
      email: _string(json['email']),
      state: _string(json['state']),
      city: _string(json['city']),
      pincode: _string(json['pincode']),
      religion: _string(json['religion']),
      cast: _string(json['cast']),
      dob: _string(json['dob']),
      currentAddress: _string(json['current_address']),
      permanentAddress: _string(json['permanent_address']),
      previousSchool: _string(json['previous_school']),
      categoryId: _parseInt(json['category_id']),
      category: _string(json['category']),
      bloodGroup: _string(json['blood_group']),
      gender: _string(json['gender']),
      isActive: _string(json['is_active']),
      fatherName: _string(json['father_name']),
      fatherPhone: _string(json['father_phone']),
      fatherOccupation: _string(json['father_occupation']),
      motherName: _string(json['mother_name']),
      motherPhone: _string(json['mother_phone']),
      motherOccupation: _string(json['mother_occupation']),
      guardianIs: _string(json['guardian_is']),
      guardianName: _string(json['guardian_name']),
      guardianRelation: _string(json['guardian_relation']),
      guardianPhone: _string(json['guardian_phone']),
      guardianEmail: _string(json['guardian_email']),
      guardianAddress: _string(json['guardian_address']),
      guardianOccupation: _string(json['guardian_occupation']),
      rte: _string(json['rte']),
      disReason: _string(json['dis_reason']),
      disNote: _string(json['dis_note']),
      disableAt: _string(json['disable_at']),
      about: _string(json['about']),
      classId: _parseInt(json['class_id']),
      className: _string(json['class_name']),
      sectionId: _parseInt(json['section_id']),
      sectionName: _string(json['section_name']),
      houseName: _string(json['house_name']),
      loginUsername: _string(json['login_username']),
    );
  }
}

class SiCategoryModel {
  final int id;
  final String category;

  SiCategoryModel({required this.id, required this.category});

  factory SiCategoryModel.fromJson(Map<String, dynamic> json) {
    return SiCategoryModel(
      id: _parseInt(json['id']),
      category: _string(json['category']),
    );
  }
}

class SiSchoolHouseModel {
  final int id;
  final String houseName;

  SiSchoolHouseModel({required this.id, required this.houseName});

  factory SiSchoolHouseModel.fromJson(Map<String, dynamic> json) {
    return SiSchoolHouseModel(
      id: _parseInt(json['id']),
      houseName: _string(json['house_name']),
    );
  }
}

class SiDisableReasonModel {
  final int id;
  final String reason;
  final String createdAt;
  final String updatedAt;

  SiDisableReasonModel({
    required this.id,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiDisableReasonModel.fromJson(Map<String, dynamic> json) {
    return SiDisableReasonModel(
      id: _parseInt(json['id']),
      reason: _string(json['reason']),
      createdAt: _string(json['created_at']),
      updatedAt: _string(json['updated_at']),
    );
  }
}

class SiMulticlassSessionModel {
  final int studentSessionId;
  final int classId;
  final String className;
  final int sectionId;
  final String sectionName;

  SiMulticlassSessionModel({
    required this.studentSessionId,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
  });

  factory SiMulticlassSessionModel.fromJson(Map<String, dynamic> json) {
    return SiMulticlassSessionModel(
      studentSessionId: _parseInt(json['student_session_id']),
      classId: _parseInt(json['class_id']),
      className: _string(json['class_name']),
      sectionId: _parseInt(json['section_id']),
      sectionName: _string(json['section_name']),
    );
  }
}

class SiMulticlassStudentModel {
  final int studentId;
  final String admissionNo;
  final String rollNo;
  final String firstname;
  final String middlename;
  final String lastname;
  final String image;
  final String mobileno;
  final String email;
  final String gender;
  final int classId;
  final String className;
  final int sectionId;
  final String sectionName;
  final int studentSessionId;
  final List<SiMulticlassSessionModel> sessions;

  SiMulticlassStudentModel({
    required this.studentId,
    required this.admissionNo,
    required this.rollNo,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.image,
    required this.mobileno,
    required this.email,
    required this.gender,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.studentSessionId,
    required this.sessions,
  });

  String get displayName {
    final parts = [firstname, middlename, lastname]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return parts.join(' ');
  }

  factory SiMulticlassStudentModel.fromJson(Map<String, dynamic> json) {
    final raw = json['sessions'];
    final sessions = <SiMulticlassSessionModel>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          sessions.add(SiMulticlassSessionModel.fromJson(e));
        }
      }
    }
    return SiMulticlassStudentModel(
      studentId: _parseInt(json['student_id']),
      admissionNo: _string(json['admission_no']),
      rollNo: _string(json['roll_no']),
      firstname: _string(json['firstname']),
      middlename: _string(json['middlename']),
      lastname: _string(json['lastname']),
      image: _string(json['image']),
      mobileno: _string(json['mobileno']),
      email: _string(json['email']),
      gender: _string(json['gender']),
      classId: _parseInt(json['class_id']),
      className: _string(json['class_name']),
      sectionId: _parseInt(json['section_id']),
      sectionName: _string(json['section_name']),
      studentSessionId: _parseInt(json['student_session_id']),
      sessions: sessions,
    );
  }
}

class SiOnlineAdmissionListModel {
  final int id;
  final String referenceNo;
  final String firstname;
  final String middlename;
  final String lastname;
  final String admissionNo;
  final String rollNo;
  final String dob;
  final String gender;
  final String mobileno;
  final String email;
  final int formStatus;
  final String isEnroll;
  final String paidStatus;
  final String submitDate;
  final String createdAt;
  final String className;
  final String sectionName;

  SiOnlineAdmissionListModel({
    required this.id,
    required this.referenceNo,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.admissionNo,
    required this.rollNo,
    required this.dob,
    required this.gender,
    required this.mobileno,
    required this.email,
    required this.formStatus,
    required this.isEnroll,
    required this.paidStatus,
    required this.submitDate,
    required this.createdAt,
    required this.className,
    required this.sectionName,
  });

  String get displayName {
    final parts = [firstname, middlename, lastname]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    return parts.join(' ');
  }

  factory SiOnlineAdmissionListModel.fromJson(Map<String, dynamic> json) {
    return SiOnlineAdmissionListModel(
      id: _parseInt(json['id']),
      referenceNo: _string(json['reference_no']),
      firstname: _string(json['firstname']),
      middlename: _string(json['middlename']),
      lastname: _string(json['lastname']),
      admissionNo: _string(json['admission_no']),
      rollNo: _string(json['roll_no']),
      dob: _string(json['dob']),
      gender: _string(json['gender']),
      mobileno: _string(json['mobileno']),
      email: _string(json['email']),
      formStatus: _parseInt(json['form_status']),
      isEnroll: _string(json['is_enroll']),
      paidStatus: _string(json['paid_status']),
      submitDate: _string(json['submit_date']),
      createdAt: _string(json['created_at']),
      className: _string(json['class_name']),
      sectionName: _string(json['section_name']),
    );
  }
}

String _string(dynamic v) {
  if (v == null) return '';
  return v.toString();
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}
