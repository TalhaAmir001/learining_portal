import 'package:flutter/foundation.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Repository for chat-related API operations
class MessagesChatRepository {
  /// Create a chat user entry in the database via HTTP API
  ///
  /// [userId] - The user ID (staff_id or student_id)
  /// [userType] - The user type ('staff' or 'student')
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'chat_user_id': int? the chat user ID if successful
  /// - 'is_new': bool? indicating if this is a new entry
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> createChatUser({
    required String userId,
    required String userType,
  }) async {
    try {
      debugPrint(
        'MessagesChatRepository: Creating chat user - userId: $userId, userType: $userType',
      );

      // Validate userType
      if (userType != 'staff' && userType != 'student') {
        return {
          'success': false,
          'error': 'Invalid user_type. Must be "staff" or "student"',
        };
      }

      // Call the HTTP API endpoint
      final response = await ApiClient.post(
        endpoint: '/websocket/create_chat_user',
        body: {'user_id': userId, 'user_type': userType},
      );

      debugPrint('MessagesChatRepository: API response received: $response');

      // Check if we got an HTML response (login page redirect)
      if (response.containsKey('raw')) {
        final rawBody = response['raw'] as String?;
        if (rawBody != null &&
            (rawBody.contains('<!DOCTYPE html>') ||
                rawBody.contains('<html') ||
                rawBody.contains('User Login') ||
                rawBody.contains('Login : GCSE With Rosi'))) {
          debugPrint(
            'MessagesChatRepository: Received HTML login page - endpoint may require authentication or session',
          );
          return {
            'success': false,
            'error':
                'API endpoint requires authentication. Please ensure you are logged in and the endpoint is accessible.',
          };
        }
      }

      // Check if the response indicates success
      // The API should return a structure similar to the WebSocket response
      if (response['status'] == 'success' || response['chat_user_id'] != null) {
        return {
          'success': true,
          'chat_user_id': response['chat_user_id'],
          'is_new': response['is_new'] ?? false,
        };
      } else {
        // Handle error response
        final errorMessage =
            response['message'] ??
            response['error'] ??
            'Failed to create chat user';
        return {'success': false, 'error': errorMessage.toString()};
      }
    } on ApiException catch (e) {
      debugPrint('MessagesChatRepository: ApiException: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('MessagesChatRepository: Unexpected error: $e');
      return {'success': false, 'error': 'Unexpected error: ${e.toString()}'};
    }
  }
}
