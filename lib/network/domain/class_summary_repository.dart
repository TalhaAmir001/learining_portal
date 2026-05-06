import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/class_summary/class_summary_models.dart';
import 'package:learining_portal/utils/api_client.dart';

class ClassSummaryRepository {
  static Future<ClassSummaryListPayload> getForStudent({
    required int studentId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_class_summaries_student.php',
        body: {'student_id': studentId},
      );
      return ClassSummaryListPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('ClassSummaryRepository getForStudent: ${e.message}');
      return ClassSummaryListPayload(
        success: false,
        items: const [],
        error: e.message,
      );
    }
  }

  static Future<ClassSummaryDetailPayload> getDetailForStudent({
    required int studentId,
    required int summaryId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_class_summary_detail_student.php',
        body: {'student_id': studentId, 'summary_id': summaryId},
      );
      return ClassSummaryDetailPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('ClassSummaryRepository getDetailForStudent: ${e.message}');
      return ClassSummaryDetailPayload(
        success: false,
        summary: null,
        error: e.message,
      );
    }
  }
}

