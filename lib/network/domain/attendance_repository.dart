import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/attendance/attendance_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Attendance mobile APIs (Portal 2 admin Attendance menu parity).
class AttendanceRepository {
  static Future<List<AtTypeModel>> getStudentAttendanceTypes() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_at_attendance_types.php');
      if (r['success'] == true && r['types'] != null) {
        return (r['types'] as List<dynamic>)
            .map((e) => AtTypeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getStudentAttendanceTypes: ${e.message}');
      return [];
    }
  }

  static Future<List<AtTypeModel>> getStaffAttendanceTypes() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_at_staff_attendance_types.php');
      if (r['success'] == true && r['types'] != null) {
        return (r['types'] as List<dynamic>)
            .map((e) => AtTypeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getStaffAttendanceTypes: ${e.message}');
      return [];
    }
  }

  static Future<List<AtStaffRoleModel>> getStaffRoles() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_at_staff_roles.php');
      if (r['success'] == true && r['roles'] != null) {
        return (r['roles'] as List<dynamic>)
            .map((e) => AtStaffRoleModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getStaffRoles: ${e.message}');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getStudentDayAttendance({
    required int classId,
    required int sectionId,
    required String dateYmd,
  }) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_at_student_day_attendance.php',
        queryParameters: {
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
          'date': dateYmd,
        },
      );
      return r;
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getStudentDayAttendance: ${e.message}');
      return {'success': false, 'error': e.message, 'students': []};
    }
  }

  static Future<Map<String, dynamic>> saveStudentDayAttendance({
    required String dateYmd,
    required List<Map<String, dynamic>> rows,
  }) async {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_at_save_student_day_attendance.php',
      body: {'date': dateYmd, 'rows': rows},
    );
  }

  static Future<Map<String, dynamic>> getSubjectSlots({
    required int classId,
    required int sectionId,
    required String dateYmd,
  }) async {
    try {
      return await ApiClient.get(
        endpoint: '/mobile_apis/get_at_subject_slots.php',
        queryParameters: {
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
          'date': dateYmd,
        },
      );
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getSubjectSlots: ${e.message}');
      return {'success': false, 'error': e.message, 'slots': []};
    }
  }

  static Future<Map<String, dynamic>> getSubjectSlotAttendance({
    required int classId,
    required int sectionId,
    required int subjectTimetableId,
    required String dateYmd,
  }) async {
    try {
      return await ApiClient.get(
        endpoint: '/mobile_apis/get_at_subject_slot_attendance.php',
        queryParameters: {
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
          'subject_timetable_id': subjectTimetableId.toString(),
          'date': dateYmd,
        },
      );
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getSubjectSlotAttendance: ${e.message}');
      return {'success': false, 'error': e.message, 'students': []};
    }
  }

  static Future<Map<String, dynamic>> saveSubjectSlotAttendance({
    required int subjectTimetableId,
    required String dateYmd,
    required List<Map<String, dynamic>> rows,
  }) async {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_at_save_subject_slot_attendance.php',
      body: {
        'subject_timetable_id': subjectTimetableId,
        'date': dateYmd,
        'rows': rows,
      },
    );
  }

  static Future<Map<String, dynamic>> getStaffDayAttendance({
    required String roleName,
    required String dateYmd,
  }) async {
    try {
      return await ApiClient.get(
        endpoint: '/mobile_apis/get_at_staff_day_attendance.php',
        queryParameters: {'role': roleName, 'date': dateYmd},
      );
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getStaffDayAttendance: ${e.message}');
      return {'success': false, 'error': e.message, 'staff': []};
    }
  }

  static Future<Map<String, dynamic>> saveStaffDayAttendance({
    required String dateYmd,
    required List<Map<String, dynamic>> rows,
  }) async {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_at_save_staff_day_attendance.php',
      body: {'date': dateYmd, 'rows': rows},
    );
  }

  static Future<Map<String, dynamic>> getSubjectDayMatrix({
    required int classId,
    required int sectionId,
    required String dateYmd,
  }) async {
    try {
      return await ApiClient.get(
        endpoint: '/mobile_apis/get_at_subject_day_matrix.php',
        queryParameters: {
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
          'date': dateYmd,
        },
      );
    } on ApiException catch (e) {
      debugPrint('AttendanceRepository getSubjectDayMatrix: ${e.message}');
      return {'success': false, 'error': e.message, 'slots': [], 'students': []};
    }
  }
}
