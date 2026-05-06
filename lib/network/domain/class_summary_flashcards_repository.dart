import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/class_summary_flashcards/class_summary_flashcards_models.dart';
import 'package:learining_portal/utils/api_client.dart';

class ClassSummaryFlashcardsRepository {
  static Future<ClassSummaryFlashcardSetListPayload> getForStudent({
    required int studentId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_class_summary_flashcards_student.php',
        body: {'student_id': studentId},
      );
      return ClassSummaryFlashcardSetListPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('ClassSummaryFlashcardsRepository getForStudent: ${e.message}');
      return ClassSummaryFlashcardSetListPayload(
        success: false,
        items: const [],
        error: e.message,
      );
    }
  }

  static Future<ClassSummaryFlashcardSetDetailPayload> getSetDetailForStudent({
    required int studentId,
    required int setId,
  }) async {
    try {
      final r = await ApiClient.postJson(
        endpoint: '/mobile_apis/get_class_summary_flashcard_set_detail_student.php',
        body: {'student_id': studentId, 'set_id': setId},
      );
      return ClassSummaryFlashcardSetDetailPayload.fromJson(r);
    } on ApiException catch (e) {
      debugPrint('ClassSummaryFlashcardsRepository getSetDetailForStudent: ${e.message}');
      return ClassSummaryFlashcardSetDetailPayload(
        success: false,
        set: null,
        error: e.message,
      );
    }
  }
}

