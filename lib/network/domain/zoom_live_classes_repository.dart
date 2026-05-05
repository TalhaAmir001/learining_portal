import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/zoom_live_classes/zoom_live_classes_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Optional shared secret for mutating `mobile_apis/post_zlc_*.php` when server sets `ZLC_API_SECRET`.
/// Leave empty to match default PHP (no secret required).
const String kZlcApiSecret = '';

class ZoomLiveClassesRepository {
  static Map<String, dynamic> _withSecret(Map<String, dynamic> body) {
    if (kZlcApiSecret.isEmpty) return body;
    return {...body, 'api_secret': kZlcApiSecret};
  }

  static Future<ZlcSettingsModel?> getSettings() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_zlc_settings.php');
      if (r['success'] == true && r['settings'] is Map<String, dynamic>) {
        return ZlcSettingsModel.fromJson(r['settings'] as Map<String, dynamic>);
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getSettings: ${e.message}');
    }
    return null;
  }

  static Future<List<ZlcConferenceListItem>> getLiveClasses({
    required String role,
    int staffId = 0,
    int studentId = 0,
  }) async {
    try {
      final q = <String, String>{
        'role': role,
        if (staffId > 0) 'staff_id': '$staffId',
        if (studentId > 0) 'student_id': '$studentId',
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_live_classes.php',
        queryParameters: q,
      );
      if (r['success'] == true && r['items'] is List) {
        return (r['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ZlcConferenceListItem.fromJson)
            .toList();
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getLiveClasses: ${e.message}');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getMeetings({int staffId = 0}) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_meetings.php',
        queryParameters: {if (staffId > 0) 'staff_id': '$staffId'},
      );
      if (r['success'] == true && r['items'] is List) {
        return (r['items'] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getMeetings: ${e.message}');
    }
    return [];
  }

  static Future<ZlcJoinLinkModel?> getJoinLink({
    required int conferenceId,
    int viewerStaffId = 0,
  }) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_join_link.php',
        queryParameters: {
          'conference_id': '$conferenceId',
          if (viewerStaffId > 0) 'viewer_staff_id': '$viewerStaffId',
        },
      );
      if (r['success'] == true) {
        return ZlcJoinLinkModel.fromJson(r);
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getJoinLink: ${e.message}');
    }
    return null;
  }

  static Future<bool> trackJoin({
    required int conferenceId,
    int studentId = 0,
    int staffId = 0,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/post_zlc_track_join.php',
        body: _withSecret({
          'conference_id': conferenceId,
          if (studentId > 0) 'student_id': studentId,
          if (staffId > 0) 'staff_id': staffId,
        }),
      );
      return r['success'] == true;
    } on ApiException catch (e) {
      debugPrint('ZLC trackJoin: ${e.message}');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getMeetingReport() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_zlc_meeting_report.php');
      if (r['success'] == true && r['items'] is List) {
        return (r['items'] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getMeetingReport: ${e.message}');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getClassReport({
    required int classId,
    required int sectionId,
  }) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_class_report.php',
        queryParameters: {
          'class_id': '$classId',
          'section_id': '$sectionId',
        },
      );
      if (r['success'] == true && r['items'] is List) {
        return (r['items'] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getClassReport: ${e.message}');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getViewers({
    required int conferenceId,
    required String type,
    int classId = 0,
    int sectionId = 0,
  }) async {
    try {
      final q = <String, String>{
        'conference_id': '$conferenceId',
        'type': type,
        if (classId > 0) 'class_id': '$classId',
        if (sectionId > 0) 'section_id': '$sectionId',
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_viewers.php',
        queryParameters: q,
      );
      if (r['success'] == true && r['viewers'] is List) {
        return (r['viewers'] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getViewers: ${e.message}');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getLiveFeedbackMeta({
    required int studentId,
    required int conferenceId,
  }) async {
    try {
      return await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_live_feedback_meta.php',
        queryParameters: {
          'student_id': '$studentId',
          'conference_id': '$conferenceId',
        },
      );
    } on ApiException catch (e) {
      debugPrint('ZLC getLiveFeedbackMeta: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> saveLiveFeedback({
    required int studentId,
    required int conferenceId,
    required int rating,
    String comment = '',
  }) async {
    try {
      return await ApiClient.postJson(
        endpoint: '/mobile_apis/post_zlc_save_live_feedback.php',
        body: _withSecret({
          'student_id': studentId,
          'conference_id': conferenceId,
          'behavior_rating': rating,
          'comment': comment,
        }),
      );
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<ZlcFeedbackSummaryModel?> getAdminFeedbackSummary({int sessionId = 0}) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_admin_feedback_summary.php',
        queryParameters: {if (sessionId > 0) 'session_id': '$sessionId'},
      );
      if (r['success'] == true && r['summary'] is Map<String, dynamic>) {
        return ZlcFeedbackSummaryModel.fromJson(r['summary'] as Map<String, dynamic>);
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getAdminFeedbackSummary: ${e.message}');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getAdminFeedbackList({
    int sessionId = 0,
    int start = 0,
    int length = 50,
  }) async {
    try {
      final q = <String, String>{
        'start': '$start',
        'length': '$length',
        if (sessionId > 0) 'session_id': '$sessionId',
      };
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_zlc_admin_feedback_list.php',
        queryParameters: q,
      );
      if (r['success'] == true && r['items'] is List) {
        return (r['items'] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      }
    } on ApiException catch (e) {
      debugPrint('ZLC getAdminFeedbackList: ${e.message}');
    }
    return [];
  }

  static Future<bool> adminMarkFeedbackRead({required int id, required int staffId}) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/post_zlc_admin_feedback_mark_read.php',
        body: _withSecret({'id': id, 'staff_id': staffId}),
      );
      return r['success'] == true;
    } on ApiException catch (e) {
      debugPrint('ZLC adminMarkFeedbackRead: ${e.message}');
      return false;
    }
  }

  static Future<bool> adminMarkFeedbackUnread({required int id}) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/post_zlc_admin_feedback_mark_unread.php',
        body: _withSecret({'id': id}),
      );
      return r['success'] == true;
    } on ApiException catch (e) {
      debugPrint('ZLC adminMarkFeedbackUnread: ${e.message}');
      return false;
    }
  }
}
