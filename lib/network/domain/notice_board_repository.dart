import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:learining_portal/network/data_models/notice_board/send_notification_data_model.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for notice board API (send_notifications, read_notifications).
class NoticeBoardRepository {
  /// Fetch notices from send_notifications visible to the given user type.
  /// [userType] - 'student' | 'staff' | 'parent'
  /// Returns list of SendNotificationDataModel; empty on error.
  static Future<List<SendNotificationDataModel>> getSendNotifications({
    required String userType,
  }) async {
    try {
      // Use GET so redirects (e.g. auth) do not lose the body; server accepts user_type from query
      final response = await ApiClient.get(
        endpoint: '/mobile_apis/get_send_notifications.php',
        queryParameters: {'user_type': userType},
      );
      // Server returned non-JSON or empty body (e.g. redirect, wrong URL, or PHP error)
      if (response.containsKey('raw')) {
        final raw = response['raw']?.toString() ?? '';
        debugPrint(
          'NoticeBoardRepository: getSendNotifications server returned non-JSON or empty body (statusCode: ${response['statusCode']}). '
          'Check that the endpoint returns JSON. Raw length: ${raw.length}',
        );
        if (raw.isNotEmpty && raw.trim().isNotEmpty) {
          try {
            final decoded = json.decode(raw);
            if (decoded is Map<String, dynamic> &&
                decoded['success'] == true &&
                decoded['notifications'] != null) {
              final list = decoded['notifications'] as List<dynamic>;
              return list
                  .map(
                    (e) => SendNotificationDataModel.fromJson(
                      e as Map<String, dynamic>,
                    ),
                  )
                  .toList();
            }
            if (decoded is List) {
              return decoded
                  .map(
                    (e) => SendNotificationDataModel.fromJson(
                      e as Map<String, dynamic>,
                    ),
                  )
                  .toList();
            }
          } catch (_) {}
        }
        return [];
      }

      if (response['success'] == true && response['notifications'] != null) {
        final list = response['notifications'] as List<dynamic>;
        return list
            .map(
              (e) =>
                  SendNotificationDataModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint(
        'NoticeBoardRepository: getSendNotifications ApiException: ${e.message}',
      );
      return [];
    } catch (e) {
      debugPrint('NoticeBoardRepository: getSendNotifications error: $e');
      return [];
    }
  }

  /// Record that the current user has viewed a notice (insert/update read_notifications).
  /// [notificationId] - id from send_notifications
  /// [userType] - 'student' | 'staff' | 'parent'
  /// [userId] - API user id (student_id, staff_id, or parent_id as string/int)
  static Future<bool> markNotificationAsRead({
    required int notificationId,
    required String userType,
    required String userId,
  }) async {
    try {
      final body = <String, dynamic>{
        'notification_id': notificationId,
        'user_type': userType,
        'user_id': userId,
      };

      final response = await ApiClient.post(
        endpoint: '/mobile_apis/mark_notification_read.php',
        body: body,
      );

      return response['success'] == true;
    } on ApiException catch (e) {
      debugPrint(
        'NoticeBoardRepository: markNotificationAsRead ApiException: ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('NoticeBoardRepository: markNotificationAsRead error: $e');
      return false;
    }
  }
}
