import 'package:flutter/foundation.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/network/data_models/auth/admin_data_model.dart';
import 'package:learining_portal/network/data_models/auth/user_data_model.dart';

/// Repository for authentication-related API operations
class AuthRepository {
  /// Login for Admin/Teacher users
  ///
  /// [username] - The username or email
  /// [password] - The password
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'data': AdminDataModel? the parsed admin data if successful
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> loginStaff({
    required String username,
    required String password,
  }) async {
    try {
      debugPrint('AuthRepository: Logging in staff - username: $username');

      // Call the API authentication endpoint
      final response = await ApiClient.post(
        endpoint: '/gauthenticate/verfiy_login',
        body: {
          'username': username,
          'password': password,
          // captcha is omitted if not needed (null values are filtered out)
        },
      );

      debugPrint('AuthRepository: API response received for staff login');

      // Parse the response
      final adminData = AdminDataModel.fromJson(response);

      // Check if authentication was successful
      if (!adminData.isSuccess || adminData.result == null) {
        // Handle error response
        String errorMsg = 'Authentication failed';
        if (adminData.error != null && adminData.error!.isNotEmpty) {
          errorMsg = adminData.error!;
        } else if (response['error'] != null) {
          final errorObj = response['error'] as Map<String, dynamic>?;
          if (errorObj != null) {
            final errors = <String>[];
            if (errorObj['username'] != null &&
                errorObj['username'].toString().isNotEmpty) {
              errors.add('Username: ${errorObj['username']}');
            }
            if (errorObj['password'] != null &&
                errorObj['password'].toString().isNotEmpty) {
              errors.add('Password: ${errorObj['password']}');
            }
            if (errorObj['captcha'] != null &&
                errorObj['captcha'].toString().isNotEmpty) {
              errors.add('Captcha: ${errorObj['captcha']}');
            }
            if (errors.isNotEmpty) {
              errorMsg = errors.join(', ');
            }
          }
        }
        return {'success': false, 'error': errorMsg};
      }

      return {'success': true, 'data': adminData};
    } on ApiException catch (e) {
      debugPrint('AuthRepository: ApiException for staff login: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('AuthRepository: Unexpected error in staff login: $e');
      return {
        'success': false,
        'error': 'An error occurred in api: ${e.toString()}',
      };
    }
  }

  /// Login for Student/Guardian users
  ///
  /// [username] - The username
  /// [password] - The password
  ///
  /// Returns a Map containing:
  /// - 'success': bool indicating if the operation was successful
  /// - 'data': UserDataModel? the parsed user data if successful
  /// - 'error': String? error message if failed
  static Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async {
    try {
      debugPrint('AuthRepository: Logging in user - username: $username');

      // Call the API authentication endpoint
      final response = await ApiClient.post(
        endpoint: '/gauthenticate/verfiy_userlogin',
        body: {
          'username': username,
          'password': password,
          // captcha is omitted if not needed (null values are filtered out)
        },
      );

      debugPrint('AuthRepository: API response received for user login');

      // Parse the response
      final userData = UserDataModel.fromJson(response);

      // Check if authentication was successful
      if (!userData.isSuccess || userData.firstResult == null) {
        // Handle error response
        String errorMsg = 'Authentication failed';
        if (userData.error != null && userData.error!.isNotEmpty) {
          errorMsg = userData.error!;
        } else if (response['error'] != null) {
          final errorObj = response['error'] as Map<String, dynamic>?;
          if (errorObj != null) {
            final errors = <String>[];
            if (errorObj['username'] != null &&
                errorObj['username'].toString().isNotEmpty) {
              errors.add('Username: ${errorObj['username']}');
            }
            if (errorObj['password'] != null &&
                errorObj['password'].toString().isNotEmpty) {
              errors.add('Password: ${errorObj['password']}');
            }
            if (errorObj['captcha'] != null &&
                errorObj['captcha'].toString().isNotEmpty) {
              errors.add('Captcha: ${errorObj['captcha']}');
            }
            if (errors.isNotEmpty) {
              errorMsg = errors.join(', ');
            }
          }
        }
        return {'success': false, 'error': errorMsg};
      }

      return {'success': true, 'data': userData};
    } on ApiException catch (e) {
      debugPrint('AuthRepository: ApiException for user login: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('AuthRepository: Unexpected error in user login: $e');
      return {
        'success': false,
        'error': 'An error occurred in api: ${e.toString()}',
      };
    }
  }
}
