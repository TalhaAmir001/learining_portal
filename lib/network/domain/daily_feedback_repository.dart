import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for admin daily feedback API (get list, save, upload file, classes, sections, students).
class DailyFeedbackRepository {
  /// Fetch all daily feedbacks for the given staff (admin).
  static Future<List<DailyFeedbackModel>> getFeedbacks({
    required String staffId,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_daily_feedbacks.php',
        queryParameters: {'staff_id': staffId},
      );
      if (response['success'] == true && response['feedbacks'] != null) {
        final list = response['feedbacks'] as List<dynamic>;
        return list
            .map((e) =>
                DailyFeedbackModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('DailyFeedbackRepository getFeedbacks: ${e.message}');
      return [];
    }
  }

  /// Fetch daily feedbacks for a guardian/parent (feedbacks where recipient includes any of their children).
  static Future<List<DailyFeedbackModel>> getFeedbacksForGuardian({
    required String parentId,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_daily_feedbacks_for_guardian.php',
        queryParameters: {'parent_id': parentId},
      );
      if (response['success'] == true && response['feedbacks'] != null) {
        final list = response['feedbacks'] as List<dynamic>;
        return list
            .map((e) =>
                DailyFeedbackModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('DailyFeedbackRepository getFeedbacksForGuardian: ${e.message}');
      return [];
    }
  }

  /// Fetch classes for feedback targeting.
  static Future<List<FeedbackClassModel>> getClasses() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_feedback_classes.php',
      );
      if (response['success'] == true && response['classes'] != null) {
        final list = response['classes'] as List<dynamic>;
        return list
            .map((e) =>
                FeedbackClassModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('DailyFeedbackRepository getClasses: ${e.message}');
      return [];
    }
  }

  /// Fetch sections for feedback targeting. If [classId] is provided, returns only sections for that class.
  static Future<List<FeedbackSectionModel>> getSections({int? classId}) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_feedback_sections.php',
        queryParameters: classId != null && classId > 0
            ? {'class_id': classId.toString()}
            : null,
      );
      if (response['success'] == true && response['sections'] != null) {
        final list = response['sections'] as List<dynamic>;
        return list
            .map((e) =>
                FeedbackSectionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('DailyFeedbackRepository getSections: ${e.message}');
      return [];
    }
  }

  /// Fetch students in fl_chat_users for the given class and section.
  static Future<List<FeedbackStudentModel>> getFeedbackStudents({
    required int classId,
    required int sectionId,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_feedback_students.php',
        queryParameters: {
          'class_id': classId.toString(),
          'section_id': sectionId.toString(),
        },
      );
      if (response['success'] == true && response['students'] != null) {
        final list = response['students'] as List<dynamic>;
        return list
            .map((e) =>
                FeedbackStudentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('DailyFeedbackRepository getFeedbackStudents: ${e.message}');
      return [];
    }
  }

  /// Save or update daily feedback. One per day per staff; pass [feedbackId] to update today's.
  static Future<Map<String, dynamic>> saveFeedback({
    required String staffId,
    int? feedbackId,
    int? classId,
    int? sectionId,
    List<int>? recipientStudentIds,
    String? messageText,
    String? voiceUrl,
    List<String>? attachmentUrls,
  }) async {
    try {
      final body = <String, dynamic>{
        'staff_id': staffId,
        if (feedbackId != null && feedbackId > 0) 'feedback_id': feedbackId,
        if (classId != null && classId > 0) 'class_id': classId,
        if (sectionId != null && sectionId > 0) 'section_id': sectionId,
        if (recipientStudentIds != null && recipientStudentIds.isNotEmpty)
          'recipient_student_ids': recipientStudentIds,
        if (messageText != null && messageText.isNotEmpty) 'message_text': messageText,
        if (voiceUrl != null && voiceUrl.isNotEmpty) 'voice_url': voiceUrl,
        if (attachmentUrls != null && attachmentUrls.isNotEmpty)
          'attachment_urls': attachmentUrls,
      };
      final response = await ApiClient.postJson(
        endpoint: '/mobile_apis/save_daily_feedback.php',
        body: body,
      );
      if (response['success'] == true) {
        return {
          'success': true,
          'feedback_id': response['feedback_id'],
        };
      }
      return {
        'success': false,
        'error': response['error']?.toString() ?? 'Failed to save feedback',
        if (response['existing_feedback_id'] != null)
          'existing_feedback_id': response['existing_feedback_id'],
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Mark feedback voice as played by a parent/guardian (for guardian view).
  static Future<bool> markFeedbackVoicePlayed({
    required int feedbackId,
    required String parentId,
  }) async {
    try {
      final response = await ApiClient.postJson(
        endpoint: '/mobile_apis/mark_feedback_voice_played.php',
        body: {
          'feedback_id': feedbackId,
          'parent_id': parentId,
        },
      );
      return response['success'] == true;
    } on ApiException catch (_) {
      return false;
    }
  }

  /// Upload a file (voice or document) for feedback. Returns file_url and filename on success.
  static Future<Map<String, dynamic>> uploadFeedbackFile(File file) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiClient.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(RegExp(r'[/\\]')).last,
        ),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/mobile_apis/upload_feedback_file.php',
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = response.data;
      if (data == null) return {'success': false, 'error': 'Invalid response'};
      if (data['success'] == true && data['file_url'] != null) {
        return {
          'success': true,
          'file_url': data['file_url'] as String,
          'filename': data['filename'] as String?,
        };
      }
      return {
        'success': false,
        'error': data['error']?.toString() ?? 'Upload failed',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': e.message ?? e.toString()};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
