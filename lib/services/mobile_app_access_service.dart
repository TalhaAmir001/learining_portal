import 'package:flutter/foundation.dart';
import 'package:learining_portal/services/mobile_device_session_service.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Outcome of polling mobile app access / session validity.
enum MobileAppAccessStatus {
  allowed,
  revoked,
  sessionInvalid,
  checkFailed,
}

/// Polls whether the logged-in mobile actor is still allowed to use the app.
class MobileAppAccessService {
  MobileAppAccessService._();

  static const String _checkEndpoint = '/mobile_apis/check_mobile_app_access.php';
  static const String _logoutEndpoint =
      '/mobile_apis/logout_mobile_app_session.php';

  static const String revokedMessage =
      'Your access to the Learning Portal mobile app has been disabled. Please contact the school office.';

  static const String sessionInvalidMessage =
      'Your mobile app session is no longer valid. Please log in again.';

  /// Poll server for revocation and single-device session validity.
  static Future<MobileAppAccessStatus> checkAccess({
    required String actorType,
    required int actorId,
  }) async {
    if (actorId < 1 || actorType.trim().isEmpty) {
      return MobileAppAccessStatus.checkFailed;
    }

    final deviceId = await MobileDeviceSessionService.getOrCreateDeviceId();
    final sessionToken = await MobileDeviceSessionService.getSessionToken();
    if (sessionToken == null || sessionToken.isEmpty) {
      return MobileAppAccessStatus.sessionInvalid;
    }

    try {
      final response = await ApiClient.postJson(
        endpoint: _checkEndpoint,
        body: {
          'actor_type': actorType,
          'actor_id': actorId,
          'device_id': deviceId,
          'session_token': sessionToken,
        },
      );
      if (response['success'] != true) {
        if (kDebugMode) {
          debugPrint(
            'MobileAppAccessService: check failed: ${response['error']}',
          );
        }
        return MobileAppAccessStatus.checkFailed;
      }
      if (response['revoked'] == true) {
        return MobileAppAccessStatus.revoked;
      }
      if (response['session_invalid'] == true) {
        return MobileAppAccessStatus.sessionInvalid;
      }
      if (response['allowed'] == false) {
        return MobileAppAccessStatus.sessionInvalid;
      }
      return MobileAppAccessStatus.allowed;
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('MobileAppAccessService: ApiException: ${e.message}');
      }
      return MobileAppAccessStatus.checkFailed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MobileAppAccessService: $e');
      }
      return MobileAppAccessStatus.checkFailed;
    }
  }

  /// Best-effort server logout to release the single-device session slot.
  static Future<void> releaseSessionOnLogout({
    required String actorType,
    required int actorId,
  }) async {
    if (actorId < 1 || actorType.trim().isEmpty) return;

    final deviceId = await MobileDeviceSessionService.getOrCreateDeviceId();
    final sessionToken = await MobileDeviceSessionService.getSessionToken();
    if (sessionToken == null || sessionToken.isEmpty) return;

    try {
      await ApiClient.postJson(
        endpoint: _logoutEndpoint,
        body: {
          'actor_type': actorType,
          'actor_id': actorId,
          'device_id': deviceId,
          'session_token': sessionToken,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MobileAppAccessService: logout release failed: $e');
      }
    }
  }
}
