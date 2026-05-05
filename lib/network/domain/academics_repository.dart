import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/academics/academics_modules_models.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/data_models/academics/timetable_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Optional shared secret when server sets `AC_API_SECRET` on timetable write endpoints.
const String kAcApiSecret = '';

class AcademicsRepository {
  static Map<String, String> _secretQuery() {
    if (kAcApiSecret.isEmpty) return {};
    return {'api_secret': kAcApiSecret};
  }

  static Map<String, dynamic> _withSecretBody(Map<String, dynamic> body) {
    if (kAcApiSecret.isEmpty) return body;
    return {...body, 'api_secret': kAcApiSecret};
  }

  static Future<AcTimetableMeta?> getTimetableMeta() async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_timetable_meta.php',
        queryParameters: _secretQuery(),
      );
      if (r['success'] == true) {
        return AcTimetableMeta.fromJson(r);
      }
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getTimetableMeta: ${e.message}');
    }
    return null;
  }

  static Future<AcModuleStatusPayload> getAcademicsModuleStatus() async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_module_status.php',
        queryParameters: _secretQuery(),
      );
      return AcModuleStatusPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getAcademicsModuleStatus: ${e.message}');
      return AcModuleStatusPayload(success: false, error: e.message, modules: const []);
    }
  }

  static Future<AdminAcMetaPayload> getAdminAcademicsMeta() async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_admin_meta.php',
        queryParameters: _secretQuery(),
      );
      return AdminAcMetaPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getAdminAcademicsMeta: ${e.message}');
      return AdminAcMetaPayload(
        success: false,
        error: e.message,
        currentSessionId: 0,
        classes: const [],
        sections: const [],
        classSections: const [],
        subjects: const [],
        teachers: const [],
        sessions: const [],
      );
    }
  }

  static Future<Map<String, dynamic>> upsertClass({
    int? id,
    required String name,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_upsert_class.php',
      body: _withSecretBody({'id': id, 'name': name}),
    );
  }

  static Future<Map<String, dynamic>> deleteClass({required int id}) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_delete_class.php',
      body: _withSecretBody({'id': id}),
    );
  }

  static Future<Map<String, dynamic>> upsertSection({
    int? id,
    required String name,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_upsert_section.php',
      body: _withSecretBody({'id': id, 'name': name}),
    );
  }

  static Future<Map<String, dynamic>> deleteSection({required int id}) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_delete_section.php',
      body: _withSecretBody({'id': id}),
    );
  }

  static Future<Map<String, dynamic>> upsertSubject({
    int? id,
    required String name,
    String? code,
    required String type,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_upsert_subject.php',
      body: _withSecretBody({'id': id, 'name': name, 'code': code ?? '', 'type': type}),
    );
  }

  static Future<Map<String, dynamic>> deleteSubject({required int id}) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_delete_subject.php',
      body: _withSecretBody({'id': id}),
    );
  }

  static Future<Map<String, dynamic>> setClassTeachers({
    required int classId,
    required int sectionId,
    required List<int> staffIds,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_set_class_teachers.php',
      body: _withSecretBody({
        'class_id': classId,
        'section_id': sectionId,
        'staff_ids': staffIds,
      }),
    );
  }

  static Future<List<AdminAcClassTeacherGroup>> getClassTeachersAdmin() async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_class_teachers_admin.php',
        queryParameters: _secretQuery(),
      );
      final raw = r['items'];
      if (r['success'] == true && raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => AdminAcClassTeacherGroup.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getClassTeachersAdmin: ${e.message}');
      return const [];
    }
  }

  static Future<Map<String, dynamic>> upsertSubjectGroup({
    int? id,
    required String name,
    String? description,
    required List<int> subjectIds,
    required List<int> classSectionIds,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_upsert_subject_group.php',
      body: _withSecretBody({
        'id': id,
        'name': name,
        'description': description ?? '',
        'subject_ids': subjectIds,
        'class_section_ids': classSectionIds,
      }),
    );
  }

  static Future<Map<String, dynamic>> deleteSubjectGroup({required int id}) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_delete_subject_group.php',
      body: _withSecretBody({'id': id}),
    );
  }

  static Future<Map<String, dynamic>> promotePreview({
    required int fromClassId,
    required int fromSectionId,
    required int toSessionId,
    required int toClassId,
    required int toSectionId,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_promote_preview.php',
      body: _withSecretBody({
        'from_class_id': fromClassId,
        'from_section_id': fromSectionId,
        'to_session_id': toSessionId,
        'to_class_id': toClassId,
        'to_section_id': toSectionId,
      }),
    );
  }

  static Future<Map<String, dynamic>> promoteApply({
    required int fromClassId,
    required int fromSectionId,
    required int toSessionId,
    required int toClassId,
    required int toSectionId,
    required List<Map<String, dynamic>> students,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_promote_apply.php',
      body: _withSecretBody({
        'from_class_id': fromClassId,
        'from_section_id': fromSectionId,
        'to_session_id': toSessionId,
        'to_class_id': toClassId,
        'to_section_id': toSectionId,
        'students': students,
      }),
    );
  }

  static Future<AcTimetablePayload> getTeacherTimetable({
    required int staffId,
    String? day,
  }) async {
    try {
      final q = <String, String>{
        'staff_id': '$staffId',
        ..._secretQuery(),
        if (day != null && day.isNotEmpty) 'day': day,
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_teacher_timetable.php',
        queryParameters: q,
      );
      return AcTimetablePayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getTeacherTimetable: ${e.message}');
      return AcTimetablePayload(success: false, error: e.message, dayOrder: const []);
    }
  }

  static Future<AcTimetablePayload> getClassTimetable({
    required int classId,
    required int sectionId,
    String? day,
  }) async {
    try {
      final q = <String, String>{
        'class_id': '$classId',
        'section_id': '$sectionId',
        ..._secretQuery(),
        if (day != null && day.isNotEmpty) 'day': day,
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_class_timetable.php',
        queryParameters: q,
      );
      return AcTimetablePayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getClassTimetable: ${e.message}');
      return AcTimetablePayload(success: false, error: e.message, dayOrder: const []);
    }
  }

  static Future<AcTimetablePayload> getRoomTimetable({
    required String roomNo,
    String? day,
  }) async {
    try {
      final q = <String, String>{
        'room_no': roomNo,
        ..._secretQuery(),
        if (day != null && day.isNotEmpty) 'day': day,
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_room_timetable.php',
        queryParameters: q,
      );
      return AcTimetablePayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getRoomTimetable: ${e.message}');
      return AcTimetablePayload(success: false, error: e.message, dayOrder: const []);
    }
  }

  static Future<AcTimetablePayload> getSubjectTimetable({
    required int classId,
    required int sectionId,
    int? subjectId,
    int? subjectGroupSubjectId,
    String? day,
  }) async {
    try {
      final q = <String, String>{
        'class_id': '$classId',
        'section_id': '$sectionId',
        ..._secretQuery(),
        if (day != null && day.isNotEmpty) 'day': day,
        if (subjectGroupSubjectId != null && subjectGroupSubjectId > 0)
          'subject_group_subject_id': '$subjectGroupSubjectId',
        if ((subjectGroupSubjectId == null || subjectGroupSubjectId <= 0) &&
            subjectId != null &&
            subjectId > 0)
          'subject_id': '$subjectId',
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_subject_timetable.php',
        queryParameters: q,
      );
      return AcTimetablePayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('AcademicsRepository getSubjectTimetable: ${e.message}');
      return AcTimetablePayload(success: false, error: e.message, dayOrder: const []);
    }
  }

  static Future<Map<String, dynamic>> upsertSubjectTimetable({
    required List<Map<String, dynamic>> insert,
    required List<Map<String, dynamic>> update,
    required List<int> deleteIds,
  }) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_upsert_subject_timetable.php',
      body: _withSecretBody({
        'insert': insert,
        'update': update,
        'delete_ids': deleteIds,
      }),
    );
  }

  static Future<Map<String, dynamic>> deleteSubjectTimetableRow({required int id}) {
    return ApiClient.postJson(
      endpoint: '/mobile_apis/post_ac_delete_subject_timetable.php',
      body: _withSecretBody({'id': id}),
    );
  }
}
