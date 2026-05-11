import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/smart_monitoring/smart_monitoring_models.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for the Smart Monitoring feature (Super Admin only).
///
/// Each method calls one of the `/mobile_apis/get_smartmonitoring_*.php`
/// endpoints. Every endpoint requires `caller_staff_id`; the server verifies
/// the staff has the "super admin" role before responding.
class SmartMonitoringRepository {
  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static Future<SmartMonitoringOverview> getOverview({
    required int callerStaffId,
    required DateTime from,
    required DateTime to,
    int classId = 0,
    int sectionId = 0,
    String status = '',
    String q = '',
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_smartmonitoring_overview.php',
        body: {
          'caller_staff_id': callerStaffId,
          'date_from': _formatDate(from),
          'date_to': _formatDate(to),
          if (classId > 0) 'class_id': classId,
          if (sectionId > 0) 'section_id': sectionId,
          if (status.isNotEmpty) 'status': status,
          if (q.trim().isNotEmpty) 'q': q.trim(),
        },
      );
      return SmartMonitoringOverview.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('SmartMonitoringRepository getOverview: ${e.message}');
      return SmartMonitoringOverview.error(e.message);
    }
  }

  static Future<SmartMonitoringSectionsPayload> getSections({
    required int callerStaffId,
    required int classId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_smartmonitoring_sections.php',
        body: {
          'caller_staff_id': callerStaffId,
          'class_id': classId,
        },
      );
      return SmartMonitoringSectionsPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('SmartMonitoringRepository getSections: ${e.message}');
      return SmartMonitoringSectionsPayload(
        success: false,
        sections: const [],
        error: e.message,
      );
    }
  }

  static Future<SmartMonitoringSnapshotPayload> getSnapshot({
    required int callerStaffId,
    required int studentId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_smartmonitoring_snapshot.php',
        body: {
          'caller_staff_id': callerStaffId,
          'student_id': studentId,
          'date_from': _formatDate(from),
          'date_to': _formatDate(to),
        },
      );
      return SmartMonitoringSnapshotPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('SmartMonitoringRepository getSnapshot: ${e.message}');
      return SmartMonitoringSnapshotPayload(
        success: false,
        tableOk: false,
        period: SmartMonitoringPeriod.fromJson(const {}),
        snapshot: null,
        error: e.message,
      );
    }
  }
}
