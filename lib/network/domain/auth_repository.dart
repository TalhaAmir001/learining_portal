import 'package:flutter/foundation.dart';
import 'package:learining_portal/services/mobile_device_session_service.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/portal_auth_error.dart';
import 'package:learining_portal/network/data_models/auth/admin_data_model.dart';
import 'package:learining_portal/network/data_models/auth/user_data_model.dart';

/// Repository for authentication-related API operations
class AuthRepository {
  static String? _extractMobileSessionToken(Map<String, dynamic> response) {
    final raw = response['mobile_session_token'];
    if (raw == null) return null;
    final token = raw.toString().trim();
    return token.isEmpty ? null : token;
  }

  static Future<Map<String, String>> _mobileDeviceLoginFields() async {
    return {
      'device_id': await MobileDeviceSessionService.getOrCreateDeviceId(),
      'device_label': MobileDeviceSessionService.getDeviceLabel(),
    };
  }

  static String _loginErrorMessage({
    required Map<String, dynamic> response,
    String? parsedModelError,
  }) {
    final fromResponse = parsePortalAuthErrorMessage(response['error']);
    if (fromResponse != null && fromResponse.isNotEmpty) {
      return fromResponse;
    }

    final fromModel = parsePortalAuthErrorMessage(parsedModelError);
    if (fromModel != null && fromModel.isNotEmpty) {
      return fromModel;
    }

    return 'Authentication failed';
  }

  static String? _extractLoginErrorCode(Map<String, dynamic> response) {
    final code = response['error_code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;
    return null;
  }

  static Map<String, dynamic> _loginFailure({
    required Map<String, dynamic> response,
    String? parsedModelError,
  }) {
    return {
      'success': false,
      'error': _loginErrorMessage(
        response: response,
        parsedModelError: parsedModelError,
      ),
      'error_code': _extractLoginErrorCode(response),
    };
  }

  static Map<String, String> _optionalDeviceTransferOtp(String? deviceTransferOtp) {
    final otp = deviceTransferOtp?.trim() ?? '';
    if (otp.isEmpty) return {};
    return {'device_transfer_otp': otp};
  }

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
    String? deviceTransferOtp,
  }) async {
    try {
      debugPrint('AuthRepository: Logging in staff - username: $username');

      final deviceFields = await _mobileDeviceLoginFields();

      // Call the API authentication endpoint
      final response = await ApiClient.post(
        endpoint: '/gauthenticate/verfiy_login',
        body: {
          'username': username,
          'password': password,
          ...deviceFields,
          ..._optionalDeviceTransferOtp(deviceTransferOtp),
        },
      );

      // debugPrint('AuthRepository: API response received for staff login: ${response}');
      debugPrint('AuthRepository: API response received for staff login');

      // Parse the response
      final adminData = AdminDataModel.fromJson(response);

      // Check if authentication was successful
      if (!adminData.isSuccess || adminData.result == null) {
        return _loginFailure(
          response: response,
          parsedModelError: adminData.error,
        );
      }

      return {
        'success': true,
        'data': adminData,
        'mobile_session_token': _extractMobileSessionToken(response),
      };
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
    String? deviceTransferOtp,
  }) async {
    try {
      debugPrint('AuthRepository: Logging in user - username: $username');

      final deviceFields = await _mobileDeviceLoginFields();

      // Call the API authentication endpoint
      final response = await ApiClient.post(
        endpoint: '/gauthenticate/verfiy_userlogin',
        body: {
          'username': username,
          'password': password,
          ...deviceFields,
          ..._optionalDeviceTransferOtp(deviceTransferOtp),
        },
      );

      debugPrint(
        'AuthRepository: API response received for user login: ${response}',
      );

      // Parse the response
      final userData = UserDataModel.fromJson(response);

      // Check if authentication was successful
      if (!userData.isSuccess || userData.firstResult == null) {
        return _loginFailure(
          response: response,
          parsedModelError: userData.error,
        );
      }

      return {
        'success': true,
        'data': userData,
        'mobile_session_token': _extractMobileSessionToken(response),
      };
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

  /// Mobile-only parent login against the `app_parent_users` table
  /// (`/mobile_apis/parent_login.php`). Bcrypt-verified on the server.
  ///
  /// [identifier] — username OR email (case-insensitive).
  /// [password]   — plaintext, never logged.
  ///
  /// Returns a Map containing:
  ///   • 'success': bool
  ///   • 'data':    `Map<String, dynamic>` (the inner `result` block on success)
  ///   • 'error':   String? error message on failure
  static Future<Map<String, dynamic>> loginAppParent({
    required String identifier,
    required String password,
    String? deviceTransferOtp,
  }) async {
    try {
      debugPrint(
        'AuthRepository: Logging in app parent - identifier: $identifier',
      );

      final deviceFields = await _mobileDeviceLoginFields();

      final response = await ApiClient.postJson(
        endpoint: '/mobile_apis/parent_login.php',
        body: {
          'identifier': identifier,
          'password': password,
          ...deviceFields,
          ..._optionalDeviceTransferOtp(deviceTransferOtp),
        },
      );

      debugPrint('AuthRepository: API response received for parent login');

      if (response['success'] != true) {
        final err = response['error']?.toString();
        return {
          'success': false,
          'error': (err == null || err.isEmpty)
              ? 'Invalid username or password.'
              : err,
          'error_code': _extractLoginErrorCode(response),
        };
      }

      final raw = response['result'];
      if (raw is! Map<String, dynamic>) {
        return {
          'success': false,
          'error': 'Unexpected login response shape.',
        };
      }
      return {
        'success': true,
        'data': raw,
        'mobile_session_token': _extractMobileSessionToken(raw) ??
            _extractMobileSessionToken(response),
      };
    } on ApiException catch (e) {
      debugPrint('AuthRepository: ApiException for parent login: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('AuthRepository: Unexpected error in parent login: $e');
      return {
        'success': false,
        'error': 'An error occurred in api: ${e.toString()}',
      };
    }
  }
}
