import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:learining_portal/network/data_models/term_feedback/child_term_report_models.dart';
import 'package:learining_portal/network/data_models/term_feedback/term_feedback_models.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Parent-facing read: every term-feedback row saved for one of the
  /// guardian's linked children in the current session. The server enforces
  /// the (parent, child) link — callers don't need to filter on the client.
  ///
  /// [appParentId] — `app_parents.id` of the calling parent.
  /// [studentId]   — the child currently being viewed (e.g. the parent's
  ///                 selected/active child).
  static Future<ChildTermReportPayload> getChildTermReports({
    required int appParentId,
    required int studentId,
  }) async {
    if (appParentId <= 0 || studentId <= 0) {
      return ChildTermReportPayload(
        success: false,
        error: 'Missing parent or child identifier.',
      );
    }
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_child_term_reports.php',
        body: {
          'caller_user_type': 'app_parent',
          'caller_user_id': appParentId,
          'student_id': studentId,
        },
      );
      return ChildTermReportPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('TermFeedbackRepository getChildTermReports: ${e.message}');
      return ChildTermReportPayload(success: false, error: e.message);
    }
  }

  /// Parent-facing list of the school's *published* term-report PDFs for one
  /// of the guardian's linked children. Server filters drafts out; we only
  /// ever see published rows in the current session.
  ///
  /// Pair with [downloadPublishedReportPdf] to fetch the actual PDF bytes
  /// for inline rendering.
  static Future<ChildPublishedReportsPayload> getChildPublishedReports({
    required int appParentId,
    required int studentId,
  }) async {
    if (appParentId <= 0 || studentId <= 0) {
      return ChildPublishedReportsPayload(
        success: false,
        error: 'Missing parent or child identifier.',
      );
    }
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_child_published_reports.php',
        body: {
          'caller_user_type': 'app_parent',
          'caller_user_id': appParentId,
          'student_id': studentId,
        },
      );
      return ChildPublishedReportsPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint(
        'TermFeedbackRepository getChildPublishedReports: ${e.message}',
      );
      return ChildPublishedReportsPayload(success: false, error: e.message);
    }
  }

  /// Download the PDF bytes for one published `student_term_reports` row and
  /// save them under the app's temp directory. Returns the local file path
  /// on success, or throws [ApiException] when the server replied with a
  /// JSON error (e.g. parent not linked, report unpublished).
  ///
  /// The endpoint never serves an "attachment" disposition by default — the
  /// file is meant to be opened in the in-app viewer, not handed off to the
  /// system downloader.
  static Future<String> downloadPublishedReportPdf({
    required int appParentId,
    required int studentId,
    required int reportId,
  }) async {
    if (appParentId <= 0 || studentId <= 0 || reportId <= 0) {
      throw ApiException('Missing parent / child / report identifier.');
    }

    final uri = Uri.parse(
      '${ApiClient.baseUrl}/mobile_apis/view_term_report_pdf.php',
    );
    final response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/pdf, application/json',
          },
          body: json.encode({
            'caller_user_type': 'app_parent',
            'caller_user_id': appParentId,
            'student_id': studentId,
            'report_id': reportId,
            'mode': 'inline',
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch report (status ${response.statusCode}).',
      );
    }

    final contentType =
        response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('pdf')) {
      String message = 'Failed to fetch report.';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      } catch (_) {
        // body wasn't JSON either — fall back to generic message
      }
      throw ApiException(message);
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/term_report_${studentId}_$reportId.pdf',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
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
