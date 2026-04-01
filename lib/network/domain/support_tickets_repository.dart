import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/support_ticket/support_ticket_data_model.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for support tickets: list, create, detail, reply, categories, upload.
class SupportTicketsRepository {
  /// submitted_by_role: "student" | "parent" (use "parent" for guardian).
  static Future<List<SupportTicketModel>> getTickets({
    required String submittedByRole,
    required String submittedById,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_support_tickets.php',
        queryParameters: {
          'submitted_by_role': submittedByRole,
          'submitted_by_id': submittedById,
        },
      );
      if (response['success'] == true && response['tickets'] != null) {
        final list = response['tickets'] as List<dynamic>;
        return list
            .map((e) =>
                SupportTicketModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('SupportTicketsRepository getTickets: ${e.message}');
      return [];
    }
  }

  /// Staff/admin: fetch all tickets (no filter by submitter).
  static Future<List<SupportTicketModel>> getTicketsForStaff() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_support_tickets.php',
        queryParameters: {'role': 'staff'},
      );
      if (response['success'] == true && response['tickets'] != null) {
        final list = response['tickets'] as List<dynamic>;
        return list
            .map((e) =>
                SupportTicketModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('SupportTicketsRepository getTicketsForStaff: ${e.message}');
      return [];
    }
  }

  static Future<List<SupportTicketCategoryModel>> getCategories() async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_support_ticket_categories.php',
      );
      if (response['success'] == true && response['categories'] != null) {
        final list = response['categories'] as List<dynamic>;
        return list
            .map((e) => SupportTicketCategoryModel.fromJson(
                e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('SupportTicketsRepository getCategories: ${e.message}');
      return [];
    }
  }

  /// Create a new ticket. category can be slug or name. related_student_id optional for parent.
  static Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String submittedByRole,
    required String submittedById,
    String? category,
    String? priority,
    int? relatedStudentId,
    String? description,
    String? attachment,
  }) async {
    try {
      final body = <String, dynamic>{
        'subject': subject,
        'submitted_by_role': submittedByRole,
        'submitted_by_id': submittedById,
        if (category != null && category.isNotEmpty) 'category': category,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (relatedStudentId != null && relatedStudentId > 0)
          'related_student_id': relatedStudentId,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (attachment != null && attachment.isNotEmpty) 'attachment': attachment,
      };
      final response = await ApiClient.postJson(
        endpoint: '/mobile_apis/create_support_ticket.php',
        body: body,
      );
      if (response['success'] == true) {
        return {
          'success': true,
          'ticket_id': response['ticket_id'],
          'id': response['id'],
        };
      }
      return {
        'success': false,
        'error': response['error']?.toString() ?? 'Failed to create ticket',
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  static Future<SupportTicketModel?> getTicketDetail({
    required int ticketId,
    required String submittedByRole,
    required String submittedById,
  }) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_support_ticket_detail.php',
        queryParameters: {
          'ticket_id': ticketId.toString(),
          'submitted_by_role': submittedByRole,
          'submitted_by_id': submittedById,
        },
      );
      if (response['success'] == true && response['ticket'] != null) {
        return SupportTicketModel.fromJson(
            response['ticket'] as Map<String, dynamic>);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('SupportTicketsRepository getTicketDetail: ${e.message}');
      return null;
    }
  }

  /// Staff/admin: fetch any ticket by id (no submitter check).
  static Future<SupportTicketModel?> getTicketDetailForStaff(int ticketId) async {
    try {
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_support_ticket_detail.php',
        queryParameters: {
          'ticket_id': ticketId.toString(),
          'role': 'staff',
        },
      );
      if (response['success'] == true && response['ticket'] != null) {
        return SupportTicketModel.fromJson(
            response['ticket'] as Map<String, dynamic>);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('SupportTicketsRepository getTicketDetailForStaff: ${e.message}');
      return null;
    }
  }

  static Future<Map<String, dynamic>> addReply({
    required int supportTicketId,
    required String replyBy,
    required String replyById,
    required String message,
    String? attachment,
  }) async {
    try {
      final body = <String, dynamic>{
        'support_ticket_id': supportTicketId,
        'reply_by': replyBy,
        'reply_by_id': replyById,
        'message': message,
        if (attachment != null && attachment.isNotEmpty) 'attachment': attachment,
      };
      final response = await ApiClient.postJson(
        endpoint: '/mobile_apis/add_support_ticket_reply.php',
        body: body,
      );
      if (response['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': response['error']?.toString() ?? 'Failed to add reply',
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Upload attachment for ticket or reply. Returns { success, file_url } or { success: false, error }.
  static Future<Map<String, dynamic>> uploadAttachment(File file) async {
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
        '/mobile_apis/upload_support_ticket_attachment.php',
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
