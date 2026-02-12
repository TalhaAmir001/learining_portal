import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:learining_portal/utils/api_client.dart';
import 'package:path_provider/path_provider.dart';

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
  /// [requestingStaffId] - When loading Support inbox (userId=0), pass current admin's staff_id so only unclaimed or claimed-by-me threads are returned
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'connections': List<Map<String, dynamic>>? the list of connections if successful
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> getConnections({
    required String userId,
    required String userType,
    String? requestingStaffId,
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

      final body = <String, String>{
        'user_id': userId,
        'user_type': userType,
      };
      if (requestingStaffId != null && requestingStaffId.isNotEmpty) {
        body['requesting_staff_id'] = requestingStaffId;
      }

      // Call the HTTP API endpoint (POST request with body)
      final response = await ApiClient.post(
        endpoint: '/mobile_apis/get_connections.php',
        body: body,
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

  /// Claim a support connection so only this admin sees it in Support Inbox
  static Future<Map<String, dynamic>> claimSupportConnection({
    required String connectionId,
    required String staffId,
  }) async {
    try {
      final response = await ApiClient.post(
        endpoint: '/mobile_apis/claim_support_connection.php',
        body: {'connection_id': connectionId, 'staff_id': staffId},
      );
      if (response['success'] == true) {
        return {'success': true, 'claimed': response['claimed'] ?? true};
      }
      return {
        'success': false,
        'error': response['error']?.toString() ?? 'Failed to claim',
      };
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Save FCM token to database for a chat user
  ///
  /// [userId] - The user ID (staff_id or student_id)
  /// [userType] - The user type ('staff' or 'student')
  /// [fcmToken] - The FCM token to save
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> saveFCMToken({
    required String userId,
    required String userType,
    required String fcmToken,
  }) async {
    try {
      debugPrint(
        'MessagesChatRepository: Saving FCM token - userId: $userId, userType: $userType',
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
        endpoint: '/mobile_apis/save_fcm_token.php',
        body: {'user_id': userId, 'user_type': userType, 'fcm_token': fcmToken},
      );

      debugPrint('MessagesChatRepository: FCM token save response: $response');

      // Check if we got an HTML response (login page redirect)
      if (response.containsKey('raw')) {
        final rawBody = response['raw'] as String?;
        if (rawBody != null &&
            (rawBody.contains('<!DOCTYPE html>') ||
                rawBody.contains('<html') ||
                rawBody.contains('User Login') ||
                rawBody.contains('Login : GCSE With Rosi'))) {
          debugPrint(
            'MessagesChatRepository: Received HTML login page - endpoint may require authentication',
          );
          return {
            'success': false,
            'error':
                'API endpoint requires authentication. Please ensure you are logged in.',
          };
        }
      }

      // Check if the response indicates success
      if (response['status'] == 'success' ||
          response['success'] == true ||
          response['message'] == 'FCM token saved successfully') {
        return {'success': true};
      } else {
        // Handle error response
        final errorMessage =
            response['message'] ??
            response['error'] ??
            'Failed to save FCM token';
        return {'success': false, 'error': errorMessage.toString()};
      }
    } on ApiException catch (e) {
      debugPrint(
        'MessagesChatRepository: ApiException saving FCM token: ${e.message}',
      );
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint(
        'MessagesChatRepository: Unexpected error saving FCM token: $e',
      );
      return {'success': false, 'error': 'Unexpected error: ${e.toString()}'};
    }
  }

  /// Upload a chat image. Returns image URL on success.
  static Future<Map<String, dynamic>> uploadChatImage(File imageFile) async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/mobile_apis/upload_chat_image.php');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {'success': false, 'error': 'Upload failed: ${response.statusCode}'};
      }
      final data = (await _decodeJson(response.body)) as Map<String, dynamic>?;
      if (data == null) return {'success': false, 'error': 'Invalid response'};
      if (data['success'] == true && data['image_url'] != null) {
        return {'success': true, 'image_url': data['image_url'] as String};
      }
      return {'success': false, 'error': data['error']?.toString() ?? 'Upload failed'};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload a chat document. [onProgress] is called with (sent, total) for progress (e.g. progress bar).
  static Future<Map<String, dynamic>> uploadChatDocument(
    File documentFile, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ));
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          documentFile.path,
          filename: documentFile.path.split(RegExp(r'[/\\]')).last,
        ),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/mobile_apis/upload_chat_document.php',
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          responseType: ResponseType.json,
        ),
        onSendProgress: onProgress != null
            ? (sent, total) => onProgress(sent, total)
            : null,
      );
      final data = response.data;
      if (data == null) return {'success': false, 'error': 'Invalid response'};
      if (data['success'] == true && data['document_url'] != null) {
        return {
          'success': true,
          'document_url': data['document_url'] as String,
          'filename': data['filename'] as String?,
        };
      }
      return {'success': false, 'error': data['error']?.toString() ?? 'Upload failed'};
    } on DioException catch (e) {
      return {'success': false, 'error': e.message ?? e.toString()};
    } on Exception catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Download a document from [url] and save as [filename]. Returns local file path on success.
  static Future<String?> downloadChatDocument(String url, String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final safeName = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final path = '${downloadsDir.path}/$safeName';
      final dio = Dio();
      await dio.download(url, path);
      return path;
    } on DioException catch (e) {
      debugPrint('downloadChatDocument: ${e.message}');
      return null;
    } on Exception catch (e) {
      debugPrint('downloadChatDocument: $e');
      return null;
    }
  }

  static dynamic _decodeJson(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }
}
