import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/utils/api_client.dart';

class CommunicateRepository {
  static Future<List<CommMessageListModel>> getMessagesLog({int limit = 200}) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_comm_messages_log.php',
        queryParameters: {'limit': limit.toString()},
      );
      if (r['success'] == true && r['messages'] != null) {
        return (r['messages'] as List<dynamic>)
            .map((e) => CommMessageListModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('CommunicateRepository getMessagesLog: ${e.message}');
      return [];
    }
  }

  static Future<List<CommMessageListModel>> getScheduledMessages({int limit = 150}) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_comm_messages_scheduled.php',
        queryParameters: {'limit': limit.toString()},
      );
      if (r['success'] == true && r['messages'] != null) {
        return (r['messages'] as List<dynamic>)
            .map((e) => CommMessageListModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('CommunicateRepository getScheduledMessages: ${e.message}');
      return [];
    }
  }

  static Future<List<CommTemplateModel>> getEmailTemplates() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_comm_email_templates.php');
      if (r['success'] == true && r['templates'] != null) {
        return (r['templates'] as List<dynamic>)
            .map((e) => CommTemplateModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('CommunicateRepository getEmailTemplates: ${e.message}');
      return [];
    }
  }

  static Future<List<CommTemplateModel>> getSmsTemplates() async {
    try {
      final r = await ApiClient.get(endpoint: '/mobile_apis/get_comm_sms_templates.php');
      if (r['success'] == true && r['templates'] != null) {
        return (r['templates'] as List<dynamic>)
            .map((e) => CommTemplateModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('CommunicateRepository getSmsTemplates: ${e.message}');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getMessageDetail(int id) async {
    try {
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_comm_message_detail.php',
        queryParameters: {'id': id.toString()},
      );
      if (r['success'] == true && r['message'] != null) {
        return Map<String, dynamic>.from(r['message'] as Map<String, dynamic>);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('CommunicateRepository getMessageDetail: ${e.message}');
      return null;
    }
  }
}
