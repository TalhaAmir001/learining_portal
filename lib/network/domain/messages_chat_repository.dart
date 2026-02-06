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
        endpoint: '/mobile_apis/create_chat_user.php',
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

  /// Create a chat connection between two users via HTTP API
  ///
  /// [userOneId] - The first user's ID (staff_id or student_id)
  /// [userOneType] - The first user's type ('staff' or 'student')
  /// [userTwoId] - The second user's ID (staff_id or student_id)
  /// [userTwoType] - The second user's type ('staff' or 'student')
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'connection_id': String? the connection ID if successful
  /// - 'is_new': bool? indicating if this is a new connection
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> createConnection({
    required String userOneId,
    required String userOneType,
    required String userTwoId,
    required String userTwoType,
  }) async {
    try {
      debugPrint(
        'MessagesChatRepository: Creating connection - userOneId: $userOneId ($userOneType), userTwoId: $userTwoId ($userTwoType)',
      );

      // Validate user types
      if ((userOneType != 'staff' && userOneType != 'student') ||
          (userTwoType != 'staff' && userTwoType != 'student')) {
        return {
          'success': false,
          'error': 'Invalid user_type. Must be "staff" or "student"',
        };
      }

      // Call the HTTP API endpoint
      final response = await ApiClient.post(
        endpoint: '/mobile_apis/create_connection.php',
        body: {
          'user_one_id': userOneId,
          'user_one_type': userOneType,
          'user_two_id': userTwoId,
          'user_two_type': userTwoType,
        },
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
      if (response['status'] == 'success' ||
          response['connection_id'] != null) {
        return {
          'success': true,
          'connection_id': response['connection_id']?.toString(),
          'is_new': response['is_new'] ?? false,
        };
      } else {
        // Handle error response
        final errorMessage =
            response['message'] ??
            response['error'] ??
            'Failed to create connection';
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

  /// Get a single chat connection between two users via HTTP API
  ///
  /// [userOneId] - The first user's ID (staff_id or student_id)
  /// [userOneType] - The first user's type ('staff' or 'student')
  /// [userTwoId] - The second user's ID (staff_id or student_id)
  /// [userTwoType] - The second user's type ('staff' or 'student')
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'connection': Map<String, dynamic>? the connection if it exists, null if it doesn't
  /// - 'exists': bool? indicating if the connection exists
  /// - 'connection_id': String? the connection ID if exists
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> getConnection({
    required String userOneId,
    required String userOneType,
    required String userTwoId,
    required String userTwoType,
  }) async {
    try {
      debugPrint(
        'MessagesChatRepository: Getting connection - userOneId: $userOneId ($userOneType), userTwoId: $userTwoId ($userTwoType)',
      );

      // Validate user types
      if ((userOneType != 'staff' && userOneType != 'student') ||
          (userTwoType != 'staff' && userTwoType != 'student')) {
        return {
          'success': false,
          'error': 'Invalid user_type. Must be "staff" or "student"',
        };
      }

      // Call the HTTP API endpoint (POST request with body)
      final response = await ApiClient.post(
        endpoint: '/mobile_apis/get_connection.php',
        body: {
          'user_one_id': userOneId,
          'user_one_type': userOneType,
          'user_two_id': userTwoId,
          'user_two_type': userTwoType,
        },
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
      if (response['status'] == 'success') {
        final connection = response['connection'] as Map<String, dynamic>?;
        final exists = response['exists'] as bool? ?? false;
        final connectionId = connection?['id']?.toString();

        return {
          'success': true,
          'connection': connection,
          'exists': exists,
          'connection_id': connectionId,
        };
      } else {
        // Handle error response
        final errorMessage =
            response['message'] ??
            response['error'] ??
            'Failed to get connection';
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

  /// Get all chat connections for a user via HTTP API
  ///
  /// [userId] - The user ID (staff_id or student_id)
  /// [userType] - The user type ('staff' or 'student')
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'connections': List<Map<String, dynamic>>? the list of connections if successful
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> getConnections({
    required String userId,
    required String userType,
  }) async {
    try {
      debugPrint(
        'MessagesChatRepository: Getting connections - userId: $userId, userType: $userType',
      );

      // Validate userType
      if (userType != 'staff' && userType != 'student') {
        return {
          'success': false,
          'error': 'Invalid user_type. Must be "staff" or "student"',
        };
      }

      // Call the HTTP API endpoint (POST request with body)
      final response = await ApiClient.post(
        endpoint: '/mobile_apis/get_connections.php',
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
      if (response['status'] == 'success' || response['connections'] != null) {
        final connections = response['connections'];
        return {
          'success': true,
          'connections': connections is List
              ? connections.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[],
        };
      } else {
        // Handle error response
        final errorMessage =
            response['message'] ??
            response['error'] ??
            'Failed to get connections';
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
