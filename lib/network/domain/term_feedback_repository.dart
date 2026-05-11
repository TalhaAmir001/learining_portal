import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/term_feedback/term_feedback_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for the Term Feedback feature (admin / teacher).
///
/// Each method calls one of the `/mobile_apis/*_termfeedback*.php` endpoints
/// and returns a typed payload. All endpoints take `user_type` and (for teachers)
/// `staff_id`; the server enforces RBAC and class/section scope.
class TermFeedbackRepository {
  static Future<TermFeedbackClassesPayload> getClasses({
    required String userType,
    int? staffId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_termfeedback_classes.php',
        body: _baseBody(userType: userType, staffId: staffId),
      );
      return TermFeedbackClassesPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('TermFeedbackRepository getClasses: ${e.message}');
      return TermFeedbackClassesPayload(
        success: false,
        classes: const [],
        canSave: false,
        showHistory: false,
        error: e.message,
      );
    }
  }

  static Future<TermFeedbackSectionsPayload> getSections({
    required String userType,
    int? staffId,
    required int classId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_termfeedback_sections.php',
        body: {
          ..._baseBody(userType: userType, staffId: staffId),
          'class_id': classId,
        },
      );
      return TermFeedbackSectionsPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('TermFeedbackRepository getSections: ${e.message}');
      return TermFeedbackSectionsPayload(
        success: false,
        sections: const [],
        error: e.message,
      );
    }
  }

  static Future<TermFeedbackStudentsPayload> loadStudents({
    required String userType,
    int? staffId,
    required int classId,
    required int sectionId,
    required String startMonth, // YYYY-MM
    required String endMonth,   // YYYY-MM
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_termfeedback_students.php',
        body: {
          ..._baseBody(userType: userType, staffId: staffId),
          'class_id': classId,
          'section_id': sectionId,
          'start_month': startMonth,
          'end_month': endMonth,
        },
      );
      return TermFeedbackStudentsPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('TermFeedbackRepository loadStudents: ${e.message}');
      return TermFeedbackStudentsPayload(
        success: false,
        students: const [],
        overall: null,
        error: e.message,
      );
    }
  }

  static Future<Map<String, dynamic>> save({
    required String userType,
    int? staffId,
    required int classId,
    required int sectionId,
    required String startMonth,
    required String endMonth,
    required TermFeedbackOverall? overall,
    required List<TermFeedbackDraft> items,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/save_termfeedback.php',
        body: {
          ..._baseBody(userType: userType, staffId: staffId),
          'class_id': classId,
          'section_id': sectionId,
          'start_month': startMonth,
          'end_month': endMonth,
          'overall_class_performance': overall?.apiValue ?? '',
          'items': items.map((e) => e.toJson()).toList(),
        },
      );
      if (r['success'] == true) {
        return {
          'success': true,
          'saved': r['saved'] is int
              ? r['saved'] as int
              : int.tryParse(r['saved']?.toString() ?? '') ?? 0,
        };
      }
      return {
        'success': false,
        'error': r['error']?.toString() ?? 'Failed to save term feedback.',
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<TermFeedbackHistoryPayload> getHistory({
    required String userType,
    int? staffId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_termfeedback_history.php',
        body: _baseBody(userType: userType, staffId: staffId),
      );
      return TermFeedbackHistoryPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('TermFeedbackRepository getHistory: ${e.message}');
      return TermFeedbackHistoryPayload(
        success: false,
        items: const [],
        error: e.message,
      );
    }
  }

  static Map<String, dynamic> _baseBody({
    required String userType,
    int? staffId,
  }) {
    return <String, dynamic>{
      'user_type': userType,
      if (staffId != null && staffId > 0) 'staff_id': staffId,
    };
  }
}
