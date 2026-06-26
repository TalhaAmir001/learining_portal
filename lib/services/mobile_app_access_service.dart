import 'package:flutter/foundation.dart';
import 'package:learining_portal/utils/api_client.dart';

/// Polls whether the logged-in mobile actor is still allowed to use the app.
class MobileAppAccessService {
  MobileAppAccessService._();

  static const String _endpoint = '/mobile_apis/check_mobile_app_access.php';

  static const String revokedMessage =
      'Your access to the Learning Portal mobile app has been disabled. Please contact the school office.';

  /// Returns `true` when the server reports this actor is revoked.
  /// Returns `false` when allowed or when the check cannot be completed (fail-open).
  static Future<bool> isAccessRevoked({
    required String actorType,
    required int actorId,
  }) async {
    if (actorId < 1 || actorType.trim().isEmpty) return false;
    try {
      final response = await ApiClient.postJson(
        endpoint: _endpoint,
        body: {
          'actor_type': actorType,
          'actor_id': actorId,
        },
      );
      if (response['success'] != true) {
        if (kDebugMode) {
          debugPrint(
            'MobileAppAccessService: check failed: ${response['error']}',
          );
        }
        return false;
      }
      if (response['revoked'] == true || response['allowed'] == false) {
        return true;
      }
      return false;
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('MobileAppAccessService: ApiException: ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MobileAppAccessService: $e');
      }
      return false;
    }
  }
}
